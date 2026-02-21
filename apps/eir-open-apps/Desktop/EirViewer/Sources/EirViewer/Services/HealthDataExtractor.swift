import Foundation
import WebKit

/// Extracts health data from journalen.1177.se using an authenticated WKWebView session.
/// Uses the same DOM scraping strategy as the Chrome plugin: navigate to the overview page,
/// click "Load More" to get all entries, click each entry's expand arrow, extract text content.
@MainActor
class HealthDataExtractor: ObservableObject {

    enum Status: Equatable {
        case idle
        case navigating
        case extractingToken
        case loadingMore(Int)
        case expandingEntries(Int, Int)  // current, total
        case switchingJournal(String)
        case extractingCategory(String)  // category name
        case fetchingTimeline(Int, Int)  // fetched, total
        case fetchingDetails(Int, Int)   // current, total
        case parsingData
        case done(Int)  // total entries extracted
        case error(String)
    }

    struct ExtractedEntry: Identifiable, Codable {
        let id: String
        let date: String?
        let time: String?
        let category: String?
        let type: String?
        let provider: String?
        let responsiblePerson: String?
        let responsibleRole: String?
        let summary: String?
        let details: String?
        let notes: [String]?
        let person: String?  // which family member
    }

    struct ExtractionResult: Codable {
        let personName: String
        let personId: String
        var entries: [ExtractedEntry]
    }

    @Published var status: Status = .idle
    @Published var progress: Double = 0.0
    @Published var statusLog: [String] = []
    @Published var results: [ExtractionResult] = []
    @Published var isExtracting: Bool = false
    @Published var eirFilePaths: [String: URL] = [:]  // personId → file URL
    @Published var hasActiveSession: Bool = false  // true if we have a valid session + token

    private weak var webView: WKWebView?
    private let journalBaseURL = "https://journalen.1177.se"
    private var cachedCSRFToken: String?
    private var sessionKeepAliveTask: Task<Void, Never>?

    /// Family member with both raw API ID (for switching) and unique display ID (for storage).
    struct FamilyMember {
        let rawId: String    // from GetLegalRepresentation HTML, used for ChangeJournal
        let personId: String // unique, used for result storage and file naming
        let name: String
        let isSelf: Bool     // true for the logged-in user
    }

    func setWebView(_ webView: WKWebView) {
        self.webView = webView
    }

    /// Start periodic keep-alive calls to prevent session timeout (15 min TTL).
    func startSessionKeepAlive() {
        stopSessionKeepAlive()
        sessionKeepAliveTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 300_000_000_000) // every 5 min
                guard let self, let webView = self.webView else { break }
                let js = """
                fetch('/Handlers/Poller.ashx', {
                    method: 'POST',
                    headers: {'Content-Type': 'application/json;charset=UTF-8', 'X-Requested-With': 'XMLHttpRequest'},
                    body: '{"extendSession":true}'
                }).then(r => r.json()).then(d => JSON.stringify(d)).catch(e => JSON.stringify({error: e.message}));
                """
                if let result = try? await webView.callAsyncJavaScript(js, arguments: [:], contentWorld: .page) as? String {
                    await MainActor.run {
                        if result.contains("error") || result.contains("login") {
                            self.hasActiveSession = false
                            self.stopSessionKeepAlive()
                        }
                    }
                }
            }
        }
    }

    func stopSessionKeepAlive() {
        sessionKeepAliveTask?.cancel()
        sessionKeepAliveTask = nil
    }

    // MARK: - Main Extraction

    func startExtraction() async {
        guard let webView else {
            log("ERROR: No WebView available")
            status = .error("No WebView")
            return
        }

        let currentURL = webView.url?.absoluteString ?? ""
        guard currentURL.contains("journalen.1177.se") else {
            status = .error("Please navigate to journalen.1177.se first and make sure you're logged in.")
            return
        }

        isExtracting = true
        results = []
        statusLog = []
        eirFilePaths = [:]

        log("=== Starting Health Data Extraction (DOM scraping) ===")
        log("Current URL: \(currentURL)")

        // Step 1: Use JS navigation to overview (no full page reload)
        status = .navigating
        log("Navigating to JournalOverview via JS...")
        let navOK = await jsNavigateToOverview(webView)
        guard navOK else {
            status = .error("Could not navigate to overview. Are you logged in?")
            isExtracting = false
            return
        }

        // Wait for page to fully settle
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // Step 2: Get patient name and CSRF token
        let patientName = await getPatientName(webView) ?? "Du"
        log("Current patient: \(patientName)")

        status = .extractingToken
        guard let csrfToken = await extractCSRFToken(webView) else {
            status = .error("Could not extract CSRF token")
            isExtracting = false
            return
        }
        log("CSRF token: \(csrfToken.prefix(20))...")

        // Step 3: Get family members
        let familyMembers = await getFamilyMembers(webView, csrfToken: csrfToken, currentPatientName: patientName)

        // Step 4: Extract for each person
        // Put self first, then others
        let allMembers = familyMembers.isEmpty
            ? [FamilyMember(rawId: "__SELF__", personId: "person_0", name: patientName, isSelf: true)]
            : familyMembers.sorted { $0.isSelf && !$1.isSelf }

        for (memberIdx, member) in allMembers.enumerated() {
            log("\n--- Extracting for: \(member.name) (rawId: \(member.rawId), self: \(member.isSelf)) ---")
            progress = Double(memberIdx) / Double(allMembers.count)

            // Switch journal if not self
            if !member.isSelf {
                status = .switchingJournal(member.name)
                await switchJournal(webView, toId: member.rawId)
                try? await Task.sleep(nanoseconds: 3_000_000_000)

                // Force reload the overview page
                status = .navigating
                log("Force-reloading overview for \(member.name)...")
                try? await webView.evaluateJavaScript("window.location.href = '/Dashboard';")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                try? await webView.evaluateJavaScript("window.location.href = '/JournalCategories/JournalOverview';")
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }

            // Wait for timeline to load (poll every 1s, max 15s)
            let timelineReady = await waitForTimeline(webView)
            if !timelineReady {
                log("WARNING: Timeline did not load for \(member.name), trying anyway...")
            }
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            let loadMoreCount = await clickLoadMoreUntilDone(webView)
            log("Clicked 'Load More' \(loadMoreCount) times")

            let totalVisible = await countVisibleEntries(webView)
            log("Total visible entries: \(totalVisible)")

            status = .expandingEntries(0, totalVisible)
            var entries = await expandAndExtractAll(webView, personName: member.name, totalEntries: totalVisible)
            log("Extracted \(entries.count) entries from overview for \(member.name)")

            guard isExtracting else { break }
            let existingIDs = Set(entries.map { $0.id })
            let categoryEntries = await extractFromCategoryPages(webView, personName: member.name, existingIDs: existingIDs)
            if !categoryEntries.isEmpty {
                entries.append(contentsOf: categoryEntries)
                log("Category pages added \(categoryEntries.count) entries (total: \(entries.count))")
            }

            results.append(ExtractionResult(personName: member.name, personId: member.personId, entries: entries))

            if memberIdx < allMembers.count - 1 {
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }

        // Switch back to self by reloading overview
        if allMembers.contains(where: { !$0.isSelf }) {
            try? await webView.evaluateJavaScript("window.location.href = '/JournalCategories/JournalOverview';")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        let totalEntries = results.reduce(0) { $0 + $1.entries.count }
        log("\n=== Extraction Complete ===")
        log("Total: \(totalEntries) entries for \(results.count) people")
        status = .done(totalEntries)
        progress = 1.0
        isExtracting = false

        await saveResults()
    }

    func cancelExtraction() {
        isExtracting = false
        status = .idle
        log("Extraction cancelled by user")
    }

    // MARK: - API-Based Extraction

    /// Extract using direct API calls (fetch) instead of DOM scraping.
    /// Uses the same endpoints that 1177's frontend JS calls:
    ///   POST /journalcategories/journaloverview/polltimeline  → entry list (HTML)
    ///   POST /journalcategories/journaloverview/detailview    → full entry (HTML)
    func startAPIExtraction() async {
        guard let webView else {
            log("ERROR: No WebView available")
            status = .error("No WebView")
            return
        }

        let currentURL = webView.url?.absoluteString ?? ""
        guard currentURL.contains("journalen.1177.se") else {
            status = .error("Navigate to journalen.1177.se and log in first.")
            return
        }

        isExtracting = true
        results = []
        statusLog = []
        eirFilePaths = [:]

        log("=== Starting Health Data Extraction (API mode) ===")
        log("Current URL: \(currentURL)")

        // Step 1: Navigate to overview to ensure we have a valid page + CSRF token
        status = .navigating
        log("Navigating to JournalOverview...")
        let navOK = await jsNavigateToOverview(webView)
        guard navOK else {
            status = .error("Could not navigate to overview. Are you logged in?")
            isExtracting = false
            return
        }
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // Step 2: Get patient name and CSRF token
        let patientName = await getPatientName(webView) ?? "Du"
        log("Current patient: \(patientName)")

        status = .extractingToken
        guard let csrfToken = await extractCSRFToken(webView) else {
            status = .error("Could not extract CSRF token")
            isExtracting = false
            return
        }
        log("CSRF token: \(csrfToken.prefix(20))...")

        // Step 3: Get family members
        let familyMembers = await getFamilyMembers(webView, csrfToken: csrfToken, currentPatientName: patientName)

        // Step 4: Extract for each person via API
        // Self first, then others
        let allMembers = familyMembers.isEmpty
            ? [FamilyMember(rawId: "__SELF__", personId: "person_0", name: patientName, isSelf: true)]
            : familyMembers.sorted { $0.isSelf && !$1.isSelf }

        cachedCSRFToken = csrfToken
        hasActiveSession = true
        startSessionKeepAlive()

        for (memberIdx, member) in allMembers.enumerated() {
            guard isExtracting else { break }
            log("\n--- Extracting for: \(member.name) (rawId: \(member.rawId), self: \(member.isSelf)) ---")
            progress = Double(memberIdx) / Double(allMembers.count)

            // Switch journal if not self
            if !member.isSelf {
                status = .switchingJournal(member.name)
                await switchJournal(webView, toId: member.rawId)
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                // Reload overview to get fresh CSRF token for this person's context
                status = .navigating
                log("Reloading overview for \(member.name)...")
                try? await webView.evaluateJavaScript("window.location.href = '/JournalCategories/JournalOverview';")
                try? await Task.sleep(nanoseconds: 4_000_000_000)
            }

            // Re-extract CSRF token (it changes per page load)
            guard let token = await extractCSRFToken(webView) else {
                log("WARNING: Could not get CSRF token for \(member.name), skipping")
                continue
            }
            cachedCSRFToken = token

            // Fetch all entry summaries from the timeline API
            let entrySummaries = await fetchAllTimelineEntries(webView, csrfToken: token)
            log("Timeline API returned \(entrySummaries.count) entries for \(member.name)")

            guard !entrySummaries.isEmpty else {
                results.append(ExtractionResult(personName: member.name, personId: member.personId, entries: []))
                continue
            }

            // Fetch full details for each entry
            var entries: [ExtractedEntry] = []
            for (idx, summary) in entrySummaries.enumerated() {
                guard isExtracting else { break }
                status = .fetchingDetails(idx + 1, entrySummaries.count)
                progress = (Double(memberIdx) + Double(idx) / Double(entrySummaries.count)) / Double(allMembers.count)

                let detail = await fetchEntryDetail(webView, csrfToken: token, entryId: summary.id, endpoint: summary.detailEndpoint)

                entries.append(ExtractedEntry(
                    id: summary.id,
                    date: summary.date,
                    time: summary.time,
                    category: summary.category,
                    type: summary.type,
                    provider: detail?.provider ?? summary.provider,
                    responsiblePerson: detail?.responsiblePerson,
                    responsibleRole: detail?.responsibleRole,
                    summary: summary.summary,
                    details: detail?.details ?? summary.summary,
                    notes: detail?.notes,
                    person: member.name
                ))

                if (idx + 1) % 25 == 0 {
                    log("  Fetched details: \(idx + 1)/\(entrySummaries.count)")
                }

                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            log("Extracted \(entries.count) entries for \(member.name)")
            results.append(ExtractionResult(personName: member.name, personId: member.personId, entries: entries))

            if memberIdx < allMembers.count - 1 {
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }

        // Switch back to self by reloading overview
        if allMembers.count > 1 {
            try? await webView.evaluateJavaScript("window.location.href = '/JournalCategories/JournalOverview';")
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        }

        let totalEntries = results.reduce(0) { $0 + $1.entries.count }
        log("\n=== Extraction Complete (API mode) ===")
        log("Total: \(totalEntries) entries for \(results.count) people")
        status = .done(totalEntries)
        progress = 1.0
        isExtracting = false

        await saveResults()
    }

    // MARK: - Timeline API

    /// An entry summary parsed from the polltimeline HTML response.
    private struct TimelineEntry {
        let id: String          // UUID
        let date: String
        let time: String?
        let category: String?
        let type: String?       // CareContact, Diagnosis, etc.
        let provider: String?
        let summary: String
        let detailEndpoint: String  // which detailview endpoint to use
    }

    /// Parsed fields from a detailview HTML response.
    private struct EntryDetail {
        let provider: String?
        let responsiblePerson: String?
        let responsibleRole: String?
        let details: String
        let notes: [String]?
    }

    /// Fetch all timeline entries using paginated API calls.
    private func fetchAllTimelineEntries(_ webView: WKWebView, csrfToken: String) async -> [TimelineEntry] {
        var allEntries: [TimelineEntry] = []
        var skip = 0
        let take = 50  // bigger batches than the UI default of 10
        var totalRows: Int?
        var previousDate = ""
        var page = 0

        while true {
            guard isExtracting else { break }
            page += 1
            status = .fetchingTimeline(allEntries.count, totalRows ?? 0)

            let fsBody: String
            if skip == 0 {
                fsBody = """
                {"fs":{"Skip":0,"Take":\(take),"AuthorName":[],"Type":[],"InformationType":[],"CareUnit":[],"VaccineName":[],"VaccineDisease":[],"MedicationName":[],"OngoingTreatment":[],"LoggedPersonName":[],"LoggedPersonRole":[],"LoggedPersonCareProvider":[],"OrderDirection":"Descending","OrderByEnum":"DocumentTime","FilterArrays":{},"GetFiltersView":false}}
                """
            } else {
                let prevDateEscaped = previousDate.replacingOccurrences(of: "\"", with: "\\\"")
                fsBody = """
                {"fs":{"Skip":\(skip),"Take":\(take),"AuthorName":[],"Type":[],"InformationType":[],"CareUnit":[],"VaccineName":[],"VaccineDisease":[],"MedicationName":[],"OngoingTreatment":[],"LoggedPersonName":[],"LoggedPersonRole":[],"LoggedPersonCareProvider":[],"OrderDirection":"Descending","OrderByEnum":"DocumentTime","FilterArrays":{},"GetFiltersView":false,"previousDate":"\(prevDateEscaped)","ResetFiltersView":false}}
                """
            }

            let js = """
            try {
                const resp = await fetch('/journalcategories/journaloverview/polltimeline', {
                    method: 'POST',
                    headers: {
                        'Content-Type': 'application/json;charset=UTF-8',
                        'X-Requested-With': 'XMLHttpRequest',
                        '__RequestVerificationToken': '\(csrfToken.replacingOccurrences(of: "'", with: "\\'"))'
                    },
                    body: '\(fsBody.replacingOccurrences(of: "'", with: "\\'").replacingOccurrences(of: "\n", with: ""))'
                });
                const data = await resp.json();

                // Parse the HTML to extract entry metadata
                var parser = new DOMParser();
                var html = data.TimelineView || data.PartialView || '';
                var doc = parser.parseFromString(html, 'text/html');

                var entries = [];
                // Find all expandable entry buttons with data-id (UUID)
                var buttons = doc.querySelectorAll('button[data-id], [data-id]');
                buttons.forEach(function(btn) {
                    var id = btn.getAttribute('data-id');
                    if (!id || id.length < 10) return;  // skip non-UUID ids

                    var dateAttr = btn.getAttribute('data-date') || '';
                    var ariaLabel = btn.getAttribute('aria-label') || '';
                    var typeAttr = '';

                    // Try to find type from parent or sibling data attributes
                    var parent = btn.closest('[data-cy-journal-overview-item-type]');
                    if (parent) typeAttr = parent.getAttribute('data-cy-journal-overview-item-type') || '';
                    var dateParent = btn.closest('[data-cy-datetime]');
                    if (dateParent && !dateAttr) dateAttr = dateParent.getAttribute('data-cy-datetime') || '';

                    entries.push({
                        id: id,
                        date: dateAttr,
                        ariaLabel: ariaLabel,
                        type: typeAttr
                    });
                });

                return JSON.stringify({
                    entries: entries,
                    totalRows: data.TotalNumberOfRows || null,
                    dataLoading: data.DataIsLoading || false,
                    allDone: data.DataFetchingForAllBatchesIsDone !== false,
                    htmlLength: html.length
                });
            } catch(e) {
                return JSON.stringify({error: e.message});
            }
            """

            guard let result = try? await webView.callAsyncJavaScript(js, arguments: [:], contentWorld: .page) as? String,
                  let data = result.data(using: .utf8),
                  let response = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                log("  Timeline API call failed at page \(page)")
                break
            }

            if let error = response["error"] as? String {
                log("  Timeline API error: \(error)")
                break
            }

            // Check if data is still loading (async from multiple providers)
            if let dataLoading = response["dataLoading"] as? Bool, dataLoading {
                log("  Data still loading from providers, waiting...")
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                continue  // retry same page
            }

            if let total = response["totalRows"] as? Int {
                totalRows = total
            }

            guard let entries = response["entries"] as? [[String: Any]], !entries.isEmpty else {
                let htmlLen = response["htmlLength"] as? Int ?? 0
                log("  Page \(page): no entries found (HTML length: \(htmlLen))")
                break
            }

            // Parse entries from this page
            for e in entries {
                guard let id = e["id"] as? String else { continue }
                // Skip duplicates
                if allEntries.contains(where: { $0.id == id }) { continue }

                let dateRaw = e["date"] as? String ?? ""
                let ariaLabel = e["ariaLabel"] as? String ?? ""
                let typeRaw = e["type"] as? String ?? ""

                // Parse date and time from the date attribute (may be "2026-02-10" or "2026-02-10 10:52:00")
                var date = dateRaw
                var time: String?
                if dateRaw.contains(" ") {
                    let parts = dateRaw.split(separator: " ", maxSplits: 1)
                    date = String(parts[0])
                    if parts.count > 1 {
                        time = String(parts[1].prefix(5))
                    }
                }

                // Parse category and provider from aria-label
                // Format: "Datum 10 februari 2026, Vårdkontakter, Telefonkontakt, Östervåla vårdcentral,..."
                let labelParts = ariaLabel.components(separatedBy: ", ")
                var category: String?
                var provider: String?
                var summaryParts: [String] = []

                let categoryKeywords = Set(["Vårdkontakter", "Anteckningar", "Diagnoser", "Vaccinationer",
                    "Läkemedel", "Provsvar", "Remisser", "Tillväxt",
                    "Uppmärksamhetsinformation", "Vårdplaner"])

                for part in labelParts {
                    let trimmed = part.trimmingCharacters(in: .whitespaces)
                    if trimmed.hasPrefix("Datum ") { continue }
                    if categoryKeywords.contains(trimmed) { category = trimmed; continue }
                    if provider == nil {
                        let lower = trimmed.lowercased()
                        if lower.contains("vårdcentral") || lower.contains("sjukhus") || lower.contains("mottagning") ||
                           lower.contains("klinik") || lower.contains("tandvård") || lower.contains("region") ||
                           lower.contains("slso") || lower.contains("husläkar") || lower.contains("akut") {
                            provider = trimmed
                            continue
                        }
                    }
                    if !trimmed.isEmpty { summaryParts.append(trimmed) }
                }

                let summary = summaryParts.isEmpty ? ariaLabel : summaryParts.joined(separator: " — ")

                allEntries.append(TimelineEntry(
                    id: id,
                    date: date,
                    time: time,
                    category: category ?? mapTypeToCategory(typeRaw),
                    type: typeRaw,
                    provider: provider,
                    summary: summary,
                    detailEndpoint: "/journalcategories/journaloverview/detailview"
                ))

                previousDate = dateRaw
            }

            log("  Page \(page): \(entries.count) entries (total: \(allEntries.count)\(totalRows.map { "/\($0)" } ?? ""))")

            if let total = totalRows, allEntries.count >= total {
                break
            }

            skip += take
            try? await Task.sleep(nanoseconds: 500_000_000)  // 500ms between pages
        }

        return allEntries
    }

    /// Fetch full details for a single entry.
    private func fetchEntryDetail(_ webView: WKWebView, csrfToken: String, entryId: String, endpoint: String) async -> EntryDetail? {
        let js = """
        try {
            const resp = await fetch('\(endpoint)', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json;charset=UTF-8',
                    'X-Requested-With': 'XMLHttpRequest',
                    '__RequestVerificationToken': '\(csrfToken.replacingOccurrences(of: "'", with: "\\'"))'
                },
                body: JSON.stringify({id: '\(entryId.replacingOccurrences(of: "'", with: "\\'"))'})
            });
            const data = await resp.json();
            var html = data.PartialView || '';

            // Parse the detail HTML
            var parser = new DOMParser();
            var doc = parser.parseFromString(html, 'text/html');

            // Extract structured fields
            var result = {provider: '', responsiblePerson: '', responsibleRole: '', sections: [], fullText: ''};

            // Information type heading (e.g. "Telefonkontakt", "Mottagningsbesök")
            var heading = doc.querySelector('.nc-heading__information-type, .information-type, h2, h3');
            if (heading) result.informationType = heading.textContent.trim();

            // Timestamp
            var timestamp = doc.querySelector('.nc-document-timestamp, .document-timestamp, time');
            if (timestamp) result.timestamp = timestamp.textContent.trim();

            // Detail title/description pairs
            var titles = doc.querySelectorAll('.detail-title, dt, .nc-detail-title');
            var descs = doc.querySelectorAll('.detail-description, dd, .nc-detail-description');
            for (var i = 0; i < titles.length; i++) {
                var title = titles[i].textContent.trim();
                var desc = i < descs.length ? descs[i].textContent.trim() : '';
                if (title || desc) result.sections.push({title: title, desc: desc});
            }

            // Provider from detail fields
            doc.querySelectorAll('.detail-title, dt').forEach(function(el, idx) {
                var t = el.textContent.trim().toLowerCase();
                if (t.includes('vårdenhet') || t.includes('vårdgivare') || t.includes('enhet')) {
                    var dd = idx < descs.length ? descs[idx] : null;
                    if (dd) result.provider = dd.textContent.trim();
                }
                if (t.includes('författare') || t.includes('ansvarig') || t.includes('signerad av')) {
                    var dd = idx < descs.length ? descs[idx] : null;
                    if (dd) result.responsiblePerson = dd.textContent.trim();
                }
                if (t.includes('befattning') || t.includes('roll') || t.includes('yrkestitel')) {
                    var dd = idx < descs.length ? descs[idx] : null;
                    if (dd) result.responsibleRole = dd.textContent.trim();
                }
            });

            // Medical content — the main text blocks (docbook sections, daganteckning, etc.)
            var contentBlocks = doc.querySelectorAll('.information-details .docbook, .ids .docbook, .docbook, .nc-content, .journal-content, [class*="content-body"]');
            var contentTexts = [];
            contentBlocks.forEach(function(block) {
                var t = block.textContent.trim();
                if (t.length > 5) contentTexts.push(t);
            });

            // If no docbook content found, get all text from the detail view
            if (contentTexts.length === 0) {
                var body = doc.querySelector('.nc-journal-detail, .journal-detail, .detail-view, main') || doc.body;
                var uiNoise = ['Ladda ner', 'Stäng', 'Skriv ut', 'Tillbaka', 'Osignerad'];
                var lines = (body.textContent || '').split('\\n')
                    .map(function(l) { return l.replace(/[ \\t]+/g, ' ').trim(); })
                    .filter(function(l) { return l.length > 0 && uiNoise.indexOf(l) === -1; });
                contentTexts = [lines.join('\\n')];
            }

            result.fullText = contentTexts.join('\\n\\n');

            return JSON.stringify(result);
        } catch(e) {
            return JSON.stringify({error: e.message});
        }
        """

        guard let result = try? await webView.callAsyncJavaScript(js, arguments: [:], contentWorld: .page) as? String,
              let data = result.data(using: .utf8),
              let parsed = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }

        if parsed["error"] != nil { return nil }

        let fullText = parsed["fullText"] as? String ?? ""
        let sections = parsed["sections"] as? [[String: String]] ?? []

        // Build details text from sections + content
        var detailLines: [String] = []
        if let infoType = parsed["informationType"] as? String, !infoType.isEmpty {
            detailLines.append(infoType)
        }
        if let ts = parsed["timestamp"] as? String, !ts.isEmpty {
            detailLines.append(ts)
        }
        for s in sections {
            let title = s["title"] ?? ""
            let desc = s["desc"] ?? ""
            if !title.isEmpty && !desc.isEmpty {
                detailLines.append("\(title): \(desc)")
            } else if !title.isEmpty {
                detailLines.append(title)
            }
        }
        if !fullText.isEmpty {
            detailLines.append(fullText)
        }

        var notes: [String]?
        if sections.count > 1 {
            notes = sections.compactMap { s in
                let t = s["title"] ?? ""
                let d = s["desc"] ?? ""
                guard !t.isEmpty else { return nil }
                return d.isEmpty ? t : "\(t): \(d)"
            }
        }

        return EntryDetail(
            provider: (parsed["provider"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            responsiblePerson: (parsed["responsiblePerson"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            responsibleRole: (parsed["responsibleRole"] as? String).flatMap { $0.isEmpty ? nil : $0 },
            details: detailLines.joined(separator: "\n"),
            notes: notes
        )
    }

    /// Map API type strings to Swedish category names.
    private func mapTypeToCategory(_ type: String) -> String? {
        switch type {
        case "CareContact": return "Vårdkontakter"
        case "CareDocumentation": return "Anteckningar"
        case "Diagnosis": return "Diagnoser"
        case "VaccinationHistory": return "Vaccinationer"
        case "Medication": return "Läkemedel"
        case "LaboratoryOutcome": return "Provsvar"
        case "ReferralStatus": return "Remisser"
        case "GrowthObservation": return "Tillväxt"
        case "AttentionSignals": return "Uppmärksamhetsinformation"
        case "CarePlan": return "Vårdplaner"
        case "FunctionalStatus": return "Funktionstillstånd och ADL"
        default: return type.isEmpty ? nil : type
        }
    }

    // MARK: - Navigation

    /// Navigate to JournalOverview using window.location (stays within same session).
    @discardableResult
    private func jsNavigateToOverview(_ webView: WKWebView) async -> Bool {
        let currentURL = webView.url?.absoluteString ?? ""

        if currentURL.contains("JournalCategories/JournalOverview") {
            log("Already on JournalOverview")
            return true
        }

        // Use JS to navigate — gentler than webView.load() which can reset session state
        let js = "window.location.href = '/JournalCategories/JournalOverview';"
        try? await webView.evaluateJavaScript(js)

        for i in 0..<30 {
            try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1s intervals
            let url = webView.url?.absoluteString ?? ""
            if url.contains("JournalCategories/JournalOverview") || url.contains("journalcategories/journaloverview") {
                log("Arrived at JournalOverview")
                return true
            }
            // If redirected to login, session expired
            if url.contains("login") {
                log("ERROR: Redirected to login — session expired")
                return false
            }
            if i % 5 == 0 {
                log("Waiting for overview page... (\(url))")
            }
        }

        log("Timeout navigating to overview")
        return false
    }

    // MARK: - Wait for Timeline

    private func waitForTimeline(_ webView: WKWebView) async -> Bool {
        log("Waiting for timeline to load...")

        for i in 0..<20 {
            let js = """
            (function() {
                var tv = document.getElementById('timeline-view');
                if (tv && tv.children.length > 0) return tv.children.length;
                return 0;
            })();
            """
            if let count = try? await webView.evaluateJavaScript(js) as? Int, count > 0 {
                log("Timeline loaded with \(count) children")
                return true
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if i % 5 == 0 {
                log("Still waiting for timeline... (attempt \(i))")
            }
        }

        log("Timeline wait timed out")
        return false
    }

    /// Wait for category page content to load. Category pages don't use #timeline-view.
    /// Instead they use .ic-block-list or other list containers, or expandable sections.
    private func waitForCategoryContent(_ webView: WKWebView) async -> String? {
        log("Waiting for category page content...")

        for i in 0..<15 {
            let js = """
            (function() {
                // Check for timeline-view first (some category pages might use it)
                var tv = document.getElementById('timeline-view');
                if (tv && tv.children.length > 0) return JSON.stringify({type: 'timeline', count: tv.children.length});

                // Check for expand arrows (journal overview style)
                var arrows = document.getElementsByClassName('icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview');
                if (arrows.length > 0) return JSON.stringify({type: 'arrows', count: arrows.length});

                // Check for block list items (common 1177 component)
                var blockItems = document.querySelectorAll('.ic-block-list__item, .nc-block-list__item');
                if (blockItems.length > 0) return JSON.stringify({type: 'blocklist', count: blockItems.length});

                // Check for any expandable/collapsible elements
                var expandables = document.querySelectorAll('[aria-expanded], [data-toggle], .collapse, details, .accordion');
                if (expandables.length > 0) return JSON.stringify({type: 'expandable', count: expandables.length});

                // Check for any journal-related content containers
                var journalItems = document.querySelectorAll('[class*="journal"], [class*="entry"], [class*="record"], [data-cy-id]');
                if (journalItems.length > 0) return JSON.stringify({type: 'journal', count: journalItems.length});

                // Check for table-based layouts
                var tables = document.querySelectorAll('table.ic-table, table.nc-table, table');
                for (var t = 0; t < tables.length; t++) {
                    if (tables[t].rows && tables[t].rows.length > 1) {
                        return JSON.stringify({type: 'table', count: tables[t].rows.length - 1});
                    }
                }

                // Check for main content area with substantial content
                var main = document.querySelector('#main-content, main, [role="main"], .iu-main');
                if (main && main.textContent.trim().length > 200) {
                    return JSON.stringify({type: 'main-content', count: 1, textLength: main.textContent.trim().length});
                }

                return null;
            })();
            """
            if let result = try? await webView.evaluateJavaScript(js) as? String {
                log("Category content found: \(result)")
                return result
            }
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            if i % 5 == 0 && i > 0 {
                log("Still waiting for category content... (attempt \(i))")
            }
        }

        log("Category content wait timed out")
        return nil
    }

    /// Inspect the DOM structure of the current page and log what we find.
    /// This helps debug what selectors to use for pages with unknown structure.
    private func inspectPageDOM(_ webView: WKWebView) async {
        let js = """
        (function() {
            var info = {url: window.location.href, title: document.title};

            // Log all elements with IDs (main structural elements)
            var withIds = [];
            document.querySelectorAll('[id]').forEach(function(el) {
                if (el.children.length > 0 || el.textContent.trim().length > 20) {
                    withIds.push({
                        tag: el.tagName.toLowerCase(),
                        id: el.id,
                        classes: el.className.toString().substring(0, 100),
                        children: el.children.length,
                        textLen: el.textContent.trim().length
                    });
                }
            });
            info.elementsWithIds = withIds.slice(0, 30);

            // Log unique class patterns (look for list/entry/item patterns)
            var classPatterns = new Set();
            document.querySelectorAll('[class]').forEach(function(el) {
                var cls = el.className.toString();
                if (cls.match(/list|item|entry|journal|block|expand|arrow|table|row|card|panel|accordion|collapse/i)) {
                    classPatterns.add(el.tagName.toLowerCase() + '.' + cls.substring(0, 80));
                }
            });
            info.interestingClasses = Array.from(classPatterns).slice(0, 30);

            // Check for load-more or pagination elements
            var pagination = [];
            document.querySelectorAll('button, a').forEach(function(el) {
                var t = el.textContent.trim().toLowerCase();
                if (t.includes('visa fler') || t.includes('ladda fler') || t.includes('load more') ||
                    t.includes('nästa') || t.includes('visa alla') || t.includes('fler')) {
                    pagination.push({tag: el.tagName, text: el.textContent.trim().substring(0, 50), class: el.className.toString().substring(0, 80)});
                }
            });
            info.pagination = pagination;

            // Sample the first few list-like children of main content
            var mainContent = document.querySelector('#main-content, main, [role="main"], .iu-main') || document.body;
            var children = [];
            for (var i = 0; i < Math.min(mainContent.children.length, 15); i++) {
                var c = mainContent.children[i];
                children.push({
                    tag: c.tagName.toLowerCase(),
                    id: c.id || '',
                    classes: c.className.toString().substring(0, 100),
                    children: c.children.length,
                    textPreview: c.textContent.trim().substring(0, 100)
                });
            }
            info.mainChildren = children;

            return JSON.stringify(info, null, 2);
        })();
        """

        if let result = try? await webView.evaluateJavaScript(js) as? String {
            log("DOM Inspection:\n\(result)")
        } else {
            log("DOM inspection failed")
        }
    }

    // MARK: - Load More

    private func clickLoadMoreUntilDone(_ webView: WKWebView) async -> Int {
        var clicks = 0
        let maxClicks = 50

        while clicks < maxClicks {
            let js = """
            (function() {
                var buttons = document.getElementsByClassName('load-more ic-button ic-button--secondary iu-px-xxl');
                if (buttons.length === 0) return 'none';
                var btn = buttons[0];
                if (btn.offsetParent === null || btn.disabled) return 'hidden';
                btn.click();
                return 'clicked';
            })();
            """

            guard let result = try? await webView.evaluateJavaScript(js) as? String else { break }

            if result == "none" || result == "hidden" {
                break
            }

            clicks += 1
            status = .loadingMore(clicks)
            log("  Load More click #\(clicks)")
            try? await Task.sleep(nanoseconds: 3_000_000_000)  // 3s wait like chrome plugin recommends
        }

        return clicks
    }

    // MARK: - Count Entries

    private func countVisibleEntries(_ webView: WKWebView) async -> Int {
        let js = """
        (function() {
            return document.getElementsByClassName('icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview').length;
        })();
        """
        return (try? await webView.evaluateJavaScript(js) as? Int) ?? 0
    }

    // MARK: - Expand & Extract All Entries

    private func expandAndExtractAll(_ webView: WKWebView, personName: String, totalEntries: Int) async -> [ExtractedEntry] {
        // Done in batches to avoid JS timeout and rate limiting.
        // Chrome plugin uses 100ms per entry — we use the same.
        let batchSize = 15  // smaller batches to be gentler
        var allEntries: [ExtractedEntry] = []
        var offset = 0

        while offset < totalEntries {
            let currentBatch = min(batchSize, totalEntries - offset)
            status = .expandingEntries(offset, totalEntries)
            progress = Double(offset) / Double(max(totalEntries, 1))

            let js = """
                var expandButtons = document.getElementsByClassName('icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview');
                var results = [];
                var start = \(offset);
                var end = Math.min(start + \(currentBatch), expandButtons.length);

                var monthMap = {
                    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'maj': '05', 'jun': '06',
                    'jul': '07', 'aug': '08', 'sep': '09', 'okt': '10', 'nov': '11', 'dec': '12'
                };

                var categoryKeywords = [
                    'Vårdkontakter', 'Anteckningar', 'Diagnoser', 'Vaccinationer',
                    'Läkemedel', 'Provsvar', 'Remisser', 'Tillväxt',
                    'Uppmärksamhetsinformation', 'Vårdplaner'
                ];

                var providerKeywords = [
                    'vårdcentral', 'sjukhus', 'akut', 'tandvård', 'folktandvården',
                    'slso', 'region', 'klinik', 'mottagning', 'husläkar'
                ];

                for (var i = start; i < end; i++) {
                    try {
                        var btn = expandButtons[i];
                        btn.click();
                        await new Promise(r => setTimeout(r, 150));

                        // Find the parent container
                        var container = btn.closest('.ic-block-list__item, .journal-entry, .timeline-item, [data-cy-id]');
                        if (!container) container = btn.parentElement;
                        if (!container) continue;

                        var rawText = container.textContent || container.innerText || '';
                        var uiNoise = ['Ladda ner', 'Stäng', 'Nytt', 'Osignerad'];
                        var lines = rawText.split('\\n')
                            .map(function(l) { return l.replace(/[ \\t]+/g, ' ').trim(); })
                            .filter(function(l) { return l.length > 0 && uiNoise.indexOf(l) === -1; });
                        var cleanText = lines.join('\\n');

                        var entry = {
                            id: 'entry_' + String(i).padStart(3, '0'),
                            date: '',
                            time: '',
                            category: '',
                            type: '',
                            provider: '',
                            summary: '',
                            details: cleanText
                        };

                        // Try data attributes first
                        var parentWithData = btn.closest('[data-cy-datetime]');
                        if (parentWithData) {
                            entry.date = parentWithData.getAttribute('data-cy-datetime') || '';
                            entry.type = parentWithData.getAttribute('data-cy-journal-overview-item-type') || '';
                        }

                        var dataBtn = container.querySelector('button[data-id]');
                        if (dataBtn) {
                            entry.id = dataBtn.getAttribute('data-id') || entry.id;
                            var label = dataBtn.getAttribute('aria-label') || '';
                            if (label) entry.summary = label;
                        }

                        // Parse lines for date, category, provider
                        for (var li = 0; li < lines.length; li++) {
                            var line = lines[li];

                            // Date: "17 mar 2025" or "2024-06-11"
                            if (!entry.date) {
                                var swDateMatch = line.match(/(\\d{1,2})\\s+(jan|feb|mar|apr|maj|jun|jul|aug|sep|okt|nov|dec)\\s+(\\d{4})/i);
                                if (swDateMatch) {
                                    entry.date = swDateMatch[3] + '-' + monthMap[swDateMatch[2].toLowerCase()] + '-' + swDateMatch[1].padStart(2, '0');
                                }
                                var isoMatch = line.match(/(\\d{4}-\\d{2}-\\d{2})/);
                                if (isoMatch && !entry.date) {
                                    entry.date = isoMatch[1];
                                }
                            }

                            // Time: "klockan 10:52" or standalone "10:52"
                            if (!entry.time) {
                                var timeMatch = line.match(/(?:klockan\\s+)?(\\d{1,2}:\\d{2})/);
                                if (timeMatch) entry.time = timeMatch[1];
                            }

                            // Category
                            if (!entry.category) {
                                for (var ci = 0; ci < categoryKeywords.length; ci++) {
                                    if (line.includes(categoryKeywords[ci])) {
                                        entry.category = categoryKeywords[ci];
                                        break;
                                    }
                                }
                            }

                            // Provider
                            if (!entry.provider) {
                                for (var pi = 0; pi < providerKeywords.length; pi++) {
                                    if (line.toLowerCase().includes(providerKeywords[pi])) {
                                        entry.provider = line;
                                        break;
                                    }
                                }
                            }

                            // Title: first non-date, non-short line
                            if (!entry.summary && line.length > 5 && line.length < 100
                                && !line.match(/\\d{4}-\\d{2}-\\d{2}/)
                                && !line.match(/\\d{1,2}\\s+\\w{3}\\s+\\d{4}/)) {
                                entry.summary = line;
                            }
                        }

                        // Extract from date attribute if we got a datetime with time
                        if (entry.date && entry.date.includes(' ')) {
                            var parts = entry.date.split(' ');
                            entry.date = parts[0];
                            if (!entry.time && parts[1]) {
                                entry.time = parts[1].substring(0, 5);
                            }
                        }

                        results.push(entry);
                    } catch(err) {
                        results.push({ id: 'error_' + i, summary: 'Extraction error: ' + err.message });
                    }
                }

                return JSON.stringify(results);
            """

            do {
                let result = try await webView.callAsyncJavaScript(js, arguments: [:], contentWorld: .page)
                if let jsonStr = result as? String,
                   let data = jsonStr.data(using: .utf8),
                   let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                    for e in entries {
                        allEntries.append(ExtractedEntry(
                            id: e["id"] as? String ?? "entry_\(allEntries.count)",
                            date: e["date"] as? String,
                            time: e["time"] as? String,
                            category: e["category"] as? String,
                            type: e["type"] as? String,
                            provider: e["provider"] as? String,
                            responsiblePerson: e["responsiblePerson"] as? String,
                            responsibleRole: e["responsibleRole"] as? String,
                            summary: e["summary"] as? String,
                            details: e["details"] as? String,
                            notes: nil,
                            person: personName
                        ))
                    }
                    log("  Batch \(offset)-\(offset + currentBatch): extracted \(entries.count) entries")
                } else {
                    log("  Batch \(offset): result was nil or not a string (type: \(type(of: result)))")
                }
            } catch {
                log("  Batch error at offset \(offset): \(error.localizedDescription)")
            }

            offset += currentBatch

            // Pause between batches to avoid overwhelming the page
            if offset < totalEntries {
                try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1s between batches
            }
        }

        return allEntries
    }

    // MARK: - Category Pages Extraction

    private func extractFromCategoryPages(_ webView: WKWebView, personName: String, existingIDs: Set<String>) async -> [ExtractedEntry] {
        log("Checking category pages for additional entries...")

        // Navigate to JournalCategories listing page
        status = .navigating
        try? await webView.evaluateJavaScript("window.location.href = '/JournalCategories';")
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        // Get all category page URLs from the page
        let getCategoriesJS = """
        (function() {
            var links = [];
            var seen = {};
            document.querySelectorAll('a[href]').forEach(function(a) {
                var href = a.getAttribute('href') || '';
                if (href.includes('/JournalCategories/') && !href.includes('JournalOverview') && !seen[href]) {
                    seen[href] = true;
                    var name = a.textContent.trim().replace(/\\s+/g, ' ');
                    if (name) links.push({url: href, name: name});
                }
            });
            return JSON.stringify(links);
        })();
        """

        guard let result = try? await webView.evaluateJavaScript(getCategoriesJS) as? String,
              let data = result.data(using: .utf8),
              let categories = try? JSONSerialization.jsonObject(with: data) as? [[String: String]] else {
            log("Could not find category page URLs")
            return []
        }

        if categories.isEmpty {
            log("No category pages found")
            return []
        }

        log("Found \(categories.count) category pages")
        var allNewEntries: [ExtractedEntry] = []
        var seenIDs = existingIDs

        for (catIdx, cat) in categories.enumerated() {
            guard isExtracting else { break }
            guard let url = cat["url"], let name = cat["name"] else { continue }

            status = .extractingCategory(name)
            log("  Category \(catIdx + 1)/\(categories.count): \(name)")

            // Navigate to category page
            let escapedURL = url.replacingOccurrences(of: "'", with: "\\'")
            try? await webView.evaluateJavaScript("window.location.href = '\(escapedURL)';")
            try? await Task.sleep(nanoseconds: 3_000_000_000)

            // First try timeline-view (works on overview-style pages)
            let hasTimeline = await waitForTimeline(webView)

            if hasTimeline {
                // Standard timeline extraction path
                let clicks = await clickLoadMoreUntilDone(webView)
                if clicks > 0 { log("    Loaded \(clicks) more pages") }

                let count = await countVisibleEntries(webView)
                if count == 0 {
                    log("    No expand arrows in timeline")
                } else {
                    let entries = await expandAndExtractAll(webView, personName: personName, totalEntries: count)
                    var newCount = 0
                    for entry in entries {
                        if !seenIDs.contains(entry.id) {
                            seenIDs.insert(entry.id)
                            allNewEntries.append(entry)
                            newCount += 1
                        }
                    }
                    log("    \(name): \(entries.count) entries (\(newCount) new)")
                }
            } else {
                // Category page with different DOM structure — inspect and try alternatives
                log("    No timeline-view on \(name), inspecting DOM...")
                await inspectPageDOM(webView)

                // Wait for any content to appear
                guard let contentInfo = await waitForCategoryContent(webView) else {
                    log("    No extractable content found for \(name)")
                    continue
                }

                // Try to parse what type of content we found
                if let infoData = contentInfo.data(using: .utf8),
                   let info = try? JSONSerialization.jsonObject(with: infoData) as? [String: Any],
                   let contentType = info["type"] as? String {

                    switch contentType {
                    case "arrows":
                        // Same expand arrows as overview — use standard extraction
                        let clicks = await clickLoadMoreUntilDone(webView)
                        if clicks > 0 { log("    Loaded \(clicks) more pages") }
                        let count = await countVisibleEntries(webView)
                        let entries = await expandAndExtractAll(webView, personName: personName, totalEntries: count)
                        var newCount = 0
                        for entry in entries {
                            if !seenIDs.contains(entry.id) {
                                seenIDs.insert(entry.id)
                                allNewEntries.append(entry)
                                newCount += 1
                            }
                        }
                        log("    \(name): \(entries.count) entries (\(newCount) new)")

                    case "blocklist", "expandable", "journal":
                        // Block list or expandable items — try generic extraction
                        let entries = await extractFromBlockList(webView, personName: personName, category: name)
                        var newCount = 0
                        for entry in entries {
                            if !seenIDs.contains(entry.id) {
                                seenIDs.insert(entry.id)
                                allNewEntries.append(entry)
                                newCount += 1
                            }
                        }
                        log("    \(name): \(entries.count) entries (\(newCount) new)")

                    case "table":
                        // Table-based layout — extract rows
                        let entries = await extractFromTable(webView, personName: personName, category: name)
                        var newCount = 0
                        for entry in entries {
                            if !seenIDs.contains(entry.id) {
                                seenIDs.insert(entry.id)
                                allNewEntries.append(entry)
                                newCount += 1
                            }
                        }
                        log("    \(name): \(entries.count) entries (\(newCount) new)")

                    case "main-content":
                        // Page has content but in an unstructured form — extract as single entry
                        let entries = await extractFromMainContent(webView, personName: personName, category: name)
                        var newCount = 0
                        for entry in entries {
                            if !seenIDs.contains(entry.id) {
                                seenIDs.insert(entry.id)
                                allNewEntries.append(entry)
                                newCount += 1
                            }
                        }
                        log("    \(name): \(entries.count) items (\(newCount) new)")

                    default:
                        log("    Unhandled content type '\(contentType)' for \(name)")
                    }
                }
            }

            // Brief pause between categories
            try? await Task.sleep(nanoseconds: 1_000_000_000)
        }

        return allNewEntries
    }

    // MARK: - Alternative Extraction Methods

    /// Extract entries from pages using .ic-block-list__item or expandable elements.
    private func extractFromBlockList(_ webView: WKWebView, personName: String, category: String) async -> [ExtractedEntry] {
        // First click any "load more" style buttons
        let loadMoreJS = """
        (function() {
            var clicked = 0;
            // Try various load-more patterns
            var selectors = [
                'button.load-more', '.load-more', 'button[class*="load-more"]',
                'a[class*="load-more"]', 'button:contains("Visa fler")', 'button:contains("Visa alla")'
            ];
            document.querySelectorAll('button, a').forEach(function(el) {
                var t = el.textContent.trim().toLowerCase();
                if ((t.includes('visa fler') || t.includes('visa alla') || t.includes('ladda fler') || t.includes('fler'))
                    && el.offsetParent !== null) {
                    el.click();
                    clicked++;
                }
            });
            return clicked;
        })();
        """
        if let clicks = try? await webView.evaluateJavaScript(loadMoreJS) as? Int, clicks > 0 {
            log("    Clicked \(clicks) load-more buttons")
            try? await Task.sleep(nanoseconds: 2_000_000_000)
        }

        // Try clicking all expand arrows/buttons, then extract content
        let js = """
            var entries = [];
            var monthMap = {
                'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'maj': '05', 'jun': '06',
                'jul': '07', 'aug': '08', 'sep': '09', 'okt': '10', 'nov': '11', 'dec': '12'
            };
            var uiNoise = ['Ladda ner', 'Stäng', 'Nytt', 'Osignerad', 'Skriv ut', 'Tillbaka'];

            // Find all clickable expand elements
            var expanders = document.querySelectorAll(
                '[aria-expanded], .icon-angle-down, [class*="expand"], [class*="arrow"], ' +
                'button[class*="toggle"], details > summary, .ic-collapsible__header, ' +
                '.nc-collapsible__header, [data-toggle]'
            );

            // Click all of them to expand
            for (var i = 0; i < expanders.length; i++) {
                try {
                    var exp = expanders[i];
                    if (exp.getAttribute('aria-expanded') === 'false' || !exp.getAttribute('aria-expanded')) {
                        exp.click();
                        await new Promise(function(r) { setTimeout(r, 150); });
                    }
                } catch(e) {}
            }

            // Also open any <details> elements
            document.querySelectorAll('details').forEach(function(d) { d.open = true; });

            await new Promise(function(r) { setTimeout(r, 500); });

            // Now extract from block list items
            var items = document.querySelectorAll(
                '.ic-block-list__item, .nc-block-list__item, ' +
                '[class*="journal-entry"], [class*="journal-item"], ' +
                '[data-cy-id], .timeline-item'
            );

            for (var i = 0; i < items.length; i++) {
                try {
                    var item = items[i];
                    var rawText = item.textContent || '';
                    var lines = rawText.split('\\n')
                        .map(function(l) { return l.replace(/[ \\t]+/g, ' ').trim(); })
                        .filter(function(l) { return l.length > 0 && uiNoise.indexOf(l) === -1; });
                    var cleanText = lines.join('\\n');

                    if (cleanText.length < 10) continue;

                    var entry = {
                        id: 'cat_' + i,
                        date: '', time: '', category: '', type: '',
                        provider: '', summary: '', details: cleanText
                    };

                    // Try data attributes
                    var dataCy = item.getAttribute('data-cy-id') || item.getAttribute('data-id');
                    if (dataCy) entry.id = dataCy;
                    var dateAttr = item.closest('[data-cy-datetime]');
                    if (dateAttr) {
                        entry.date = dateAttr.getAttribute('data-cy-datetime') || '';
                        entry.type = dateAttr.getAttribute('data-cy-journal-overview-item-type') || '';
                    }

                    // Try button with data-id
                    var btn = item.querySelector('button[data-id]');
                    if (btn) {
                        entry.id = btn.getAttribute('data-id') || entry.id;
                        var label = btn.getAttribute('aria-label') || '';
                        if (label) entry.summary = label;
                    }

                    // Parse date, time, provider from text
                    for (var li = 0; li < Math.min(lines.length, 20); li++) {
                        var line = lines[li];
                        if (!entry.date) {
                            var swDate = line.match(/(\\d{1,2})\\s+(jan|feb|mar|apr|maj|jun|jul|aug|sep|okt|nov|dec)\\s+(\\d{4})/i);
                            if (swDate) entry.date = swDate[3] + '-' + monthMap[swDate[2].toLowerCase()] + '-' + swDate[1].padStart(2, '0');
                            var iso = line.match(/(\\d{4}-\\d{2}-\\d{2})/);
                            if (iso && !entry.date) entry.date = iso[1];
                        }
                        if (!entry.time) {
                            var tm = line.match(/(?:klockan\\s+)?(\\d{1,2}:\\d{2})/);
                            if (tm) entry.time = tm[1];
                        }
                        if (!entry.provider && line.length > 5 && line.length < 150) {
                            var provWords = ['vårdcentral','sjukhus','akut','tandvård','folktandvården',
                                'slso','region','klinik','mottagning','husläkar'];
                            for (var p = 0; p < provWords.length; p++) {
                                if (line.toLowerCase().includes(provWords[p])) { entry.provider = line; break; }
                            }
                        }
                        if (!entry.summary && line.length > 5 && line.length < 100
                            && !line.match(/\\d{4}-\\d{2}-\\d{2}/)
                            && !line.match(/\\d{1,2}\\s+\\w{3}\\s+\\d{4}/)) {
                            entry.summary = line;
                        }
                    }

                    if (entry.date && entry.date.includes(' ')) {
                        var parts = entry.date.split(' ');
                        entry.date = parts[0];
                        if (!entry.time && parts[1]) entry.time = parts[1].substring(0, 5);
                    }

                    entries.push(entry);
                } catch(err) {}
            }

            return JSON.stringify(entries);
        """

        do {
            let result = try await webView.callAsyncJavaScript(js, arguments: [:], contentWorld: .page)
            if let jsonStr = result as? String,
               let data = jsonStr.data(using: .utf8),
               let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                return entries.map { e in
                    ExtractedEntry(
                        id: e["id"] as? String ?? "cat_\(entries.firstIndex(where: { ($0["id"] as? String) == (e["id"] as? String) }) ?? 0)",
                        date: e["date"] as? String,
                        time: e["time"] as? String,
                        category: (e["category"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? category,
                        type: e["type"] as? String,
                        provider: e["provider"] as? String,
                        responsiblePerson: nil,
                        responsibleRole: nil,
                        summary: e["summary"] as? String,
                        details: e["details"] as? String,
                        notes: nil,
                        person: personName
                    )
                }
            }
        } catch {
            log("    Block list extraction error: \(error.localizedDescription)")
        }
        return []
    }

    /// Extract entries from table-based category pages.
    private func extractFromTable(_ webView: WKWebView, personName: String, category: String) async -> [ExtractedEntry] {
        let js = """
        (function() {
            var entries = [];
            var tables = document.querySelectorAll('table');
            var monthMap = {
                'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'maj': '05', 'jun': '06',
                'jul': '07', 'aug': '08', 'sep': '09', 'okt': '10', 'nov': '11', 'dec': '12'
            };

            for (var t = 0; t < tables.length; t++) {
                var table = tables[t];
                var rows = table.querySelectorAll('tbody tr, tr');
                for (var r = 0; r < rows.length; r++) {
                    var row = rows[r];
                    var cells = row.querySelectorAll('td, th');
                    if (cells.length < 2) continue;

                    var text = row.textContent.trim().replace(/[ \\t]+/g, ' ');
                    if (text.length < 10) continue;

                    var entry = {
                        id: 'table_' + t + '_' + r,
                        date: '', time: '', category: '', type: '',
                        provider: '', summary: '', details: text
                    };

                    // Try to extract date from first cell
                    var firstCell = cells[0].textContent.trim();
                    var dateMatch = firstCell.match(/(\\d{4}-\\d{2}-\\d{2})/);
                    if (dateMatch) entry.date = dateMatch[1];
                    var swDate = firstCell.match(/(\\d{1,2})\\s+(jan|feb|mar|apr|maj|jun|jul|aug|sep|okt|nov|dec)\\s+(\\d{4})/i);
                    if (swDate) entry.date = swDate[3] + '-' + monthMap[swDate[2].toLowerCase()] + '-' + swDate[1].padStart(2, '0');

                    // Second cell often has the summary/title
                    if (cells.length >= 2) {
                        entry.summary = cells[1].textContent.trim().substring(0, 200);
                    }

                    entries.push(entry);
                }
            }
            return JSON.stringify(entries);
        })();
        """

        if let result = try? await webView.evaluateJavaScript(js) as? String,
           let data = result.data(using: .utf8),
           let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return entries.map { e in
                ExtractedEntry(
                    id: e["id"] as? String ?? "table_0",
                    date: e["date"] as? String,
                    time: e["time"] as? String,
                    category: (e["category"] as? String).flatMap { $0.isEmpty ? nil : $0 } ?? category,
                    type: e["type"] as? String,
                    provider: e["provider"] as? String,
                    responsiblePerson: nil,
                    responsibleRole: nil,
                    summary: e["summary"] as? String,
                    details: e["details"] as? String,
                    notes: nil,
                    person: personName
                )
            }
        }
        return []
    }

    /// Extract content from main content area when no structured elements are found.
    private func extractFromMainContent(_ webView: WKWebView, personName: String, category: String) async -> [ExtractedEntry] {
        let js = """
        (function() {
            var main = document.querySelector('#main-content, main, [role="main"], .iu-main') || document.body;
            var uiNoise = ['Ladda ner', 'Stäng', 'Nytt', 'Osignerad', 'Skriv ut', 'Tillbaka',
                           'Logga ut', 'Meny', 'Journalen', 'Intyg', 'Ändra'];
            var rawText = main.textContent || '';
            var lines = rawText.split('\\n')
                .map(function(l) { return l.replace(/[ \\t]+/g, ' ').trim(); })
                .filter(function(l) { return l.length > 0 && uiNoise.indexOf(l) === -1; });
            var cleanText = lines.join('\\n');

            if (cleanText.length < 50) return JSON.stringify([]);

            return JSON.stringify([{
                id: 'content_' + window.location.pathname.replace(/\\//g, '_'),
                date: '',
                summary: document.title || '',
                details: cleanText
            }]);
        })();
        """

        if let result = try? await webView.evaluateJavaScript(js) as? String,
           let data = result.data(using: .utf8),
           let entries = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            return entries.compactMap { e in
                let details = e["details"] as? String ?? ""
                guard details.count >= 50 else { return nil as ExtractedEntry? }
                return ExtractedEntry(
                    id: e["id"] as? String ?? "content",
                    date: e["date"] as? String,
                    time: nil,
                    category: category,
                    type: nil,
                    provider: nil,
                    responsiblePerson: nil,
                    responsibleRole: nil,
                    summary: e["summary"] as? String,
                    details: details,
                    notes: nil,
                    person: personName
                )
            }
        }
        return []
    }

    // MARK: - Patient Name

    private func getPatientName(_ webView: WKWebView) async -> String? {
        // Try "Du ser uppgifter för X" header first (shows whose journal is being viewed)
        let js = """
        (function() {
            var allText = document.body.innerText || '';
            var m = allText.match(/Du ser uppgifter f\\u00f6r\\s+([^\\n]+)/);
            if (m) return m[1].trim();
            var el = document.querySelector('.ic-avatar-box__name');
            return el ? el.textContent.trim() : null;
        })();
        """
        return try? await webView.evaluateJavaScript(js) as? String
    }

    // MARK: - CSRF Token

    private func extractCSRFToken(_ webView: WKWebView) async -> String? {
        let js = """
        (function() {
            var input = document.querySelector('input[name="__RequestVerificationToken"]');
            if (input) return input.value;
            var meta = document.querySelector('meta[name="__RequestVerificationToken"]');
            if (meta) return meta.content;
            return null;
        })();
        """

        do {
            let result = try await webView.evaluateJavaScript(js)
            if let token = result as? String, !token.isEmpty {
                return token
            }
        } catch {
            log("CSRF extraction error: \(error.localizedDescription)")
        }

        log("CSRF not found, navigating to dashboard...")
        webView.load(URLRequest(url: URL(string: "\(journalBaseURL)/Dashboard")!))
        try? await Task.sleep(nanoseconds: 3_000_000_000)

        do {
            let result = try await webView.evaluateJavaScript(js)
            if let token = result as? String, !token.isEmpty {
                return token
            }
        } catch {
            log("CSRF fallback error: \(error.localizedDescription)")
        }

        return nil
    }

    // MARK: - Family Members

    private func getFamilyMembers(_ webView: WKWebView, csrfToken: String, currentPatientName: String) async -> [FamilyMember] {
        log("Fetching family members...")

        let js = """
        try {
            const resp = await fetch('/Dashboard/GetLegalRepresentation', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json;charset=UTF-8',
                    'X-Requested-With': 'XMLHttpRequest',
                    '__RequestVerificationToken': '\(csrfToken.replacingOccurrences(of: "'", with: "\\'"))'
                },
                body: '{}'
            });
            const data = await resp.json();
            const html = data.PartialView || '';

            var parser = new DOMParser();
            var doc = parser.parseFromString(html, 'text/html');
            var members = [];

            // Find all family members — check both desktop and mobile sections
            // Only process the first list (desktop) to avoid duplicates
            var lists = doc.querySelectorAll('ul.ic-block-list, ul.nc-block-list');
            var firstList = lists.length > 0 ? lists[0] : doc;
            var listItems = firstList.querySelectorAll('li.ic-block-list__item, li.nc-block-list__item');

            listItems.forEach(function(li) {
                var badge = li.querySelector('.LegalRepresentationBadge');
                var nameEl = li.querySelector('p.nc-tooltip-ellipsis, p[data-mini-tooltip]');
                var linkEl = li.querySelector('a.iu-legal-representation--link, a[data-mini-tooltip]');

                if (badge && nameEl) {
                    // Current user (has "Visas" badge) — isSelf
                    members.push({ rawId: '__SELF__', name: nameEl.textContent.trim(), isSelf: true });
                } else if (linkEl) {
                    // Family member with link: <a id="2" ...>Name</a>
                    var id = linkEl.getAttribute('id') || '';
                    var name = '';
                    linkEl.childNodes.forEach(function(node) {
                        if (node.nodeType === 3) name += node.textContent;
                    });
                    name = name.trim();
                    if (!name) name = linkEl.textContent.trim();
                    if (id && name) {
                        members.push({ rawId: id, name: name, isSelf: false });
                    }
                } else if (nameEl) {
                    var name = nameEl.textContent.trim();
                    if (name && !members.some(function(m) { return m.name === name; })) {
                        members.push({ rawId: '__UNKNOWN__', name: name, isSelf: false });
                    }
                }
            });

            return JSON.stringify(members);
        } catch(e) {
            return JSON.stringify({error: e.message});
        }
        """

        do {
            let result = try await webView.callAsyncJavaScript(js, arguments: [:], contentWorld: .page)
            if let jsonStr = result as? String {
                log("Family members response: \(jsonStr)")

                guard let data = jsonStr.data(using: .utf8),
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
                    log("Could not parse family members JSON")
                    return [FamilyMember(rawId: "__SELF__", personId: "person_0", name: currentPatientName, isSelf: true)]
                }

                // Build members with unique personIds (for storage) but keep rawIds (for ChangeJournal)
                var seenNames = Set<String>()
                var members: [FamilyMember] = []

                for (index, dict) in arr.enumerated() {
                    guard let name = dict["name"] as? String else { continue }
                    let rawId = dict["rawId"] as? String ?? dict["id"] as? String ?? "__UNKNOWN__"
                    let isSelf = dict["isSelf"] as? Bool ?? false

                    // Deduplicate by name (desktop/mobile sections)
                    if seenNames.contains(name) { continue }
                    seenNames.insert(name)

                    members.append(FamilyMember(
                        rawId: rawId,
                        personId: "person_\(index)",
                        name: name,
                        isSelf: isSelf
                    ))
                }

                log("People found: \(members.map { "\($0.name) (rawId:\($0.rawId), self:\($0.isSelf))" }.joined(separator: ", "))")

                return members.isEmpty
                    ? [FamilyMember(rawId: "__SELF__", personId: "person_0", name: currentPatientName, isSelf: true)]
                    : members
            }
        } catch {
            log("Family members error: \(error.localizedDescription)")
        }

        return [FamilyMember(rawId: "__SELF__", personId: "person_0", name: currentPatientName, isSelf: true)]
    }

    // MARK: - Journal Switching

    private func switchJournal(_ webView: WKWebView, toId id: String) async {
        log("Switching to journal id=\(id)...")

        let js = """
        try {
            var token = document.querySelector('input[name="__RequestVerificationToken"]');
            var csrfToken = token ? token.value : '';
            const resp = await fetch('/ChangeJournal/ChangeJournal', {
                method: 'POST',
                headers: {
                    'Content-Type': 'application/json;charset=UTF-8',
                    'X-Requested-With': 'XMLHttpRequest',
                    '__RequestVerificationToken': csrfToken
                },
                body: JSON.stringify({id: '\(id)'})
            });
            return JSON.stringify({ status: resp.status });
        } catch(e) {
            return JSON.stringify({error: e.message});
        }
        """

        do {
            let result = try await webView.callAsyncJavaScript(js, arguments: [:], contentWorld: .page)
            if let jsonStr = result as? String {
                log("Journal switch response: \(jsonStr)")
            }
            // Wait generously after switch before any further operations
            try? await Task.sleep(nanoseconds: 3_000_000_000)
        } catch {
            log("Journal switch error: \(error.localizedDescription)")
        }
    }

    // MARK: - Save Results

    private func saveResults() async {
        // JSON
        let fileURL = URL(fileURLWithPath: "/tmp/eirviewer-extracted-data.json")
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(results)
            try data.write(to: fileURL)
            log("Results saved to \(fileURL.path)")
        } catch {
            log("Save error: \(error.localizedDescription)")
        }

        // Text dump
        let textURL = URL(fileURLWithPath: "/tmp/eirviewer-extracted-data.txt")
        var text = "=== Health Data Extraction ===\n"
        text += "Date: \(Date())\n\n"
        for result in results {
            text += "# \(result.personName) (id: \(result.personId))\n"
            text += "Entries: \(result.entries.count)\n\n"
            for entry in result.entries {
                text += "## [\(entry.id)] \(entry.date ?? "?") — \(entry.category ?? "?")\n"
                if let summary = entry.summary { text += "Summary: \(summary)\n" }
                if let details = entry.details, !details.isEmpty { text += "Details: \(details.prefix(500))\n" }
                text += "\n"
            }
        }
        try? text.write(to: textURL, atomically: true, encoding: .utf8)
        log("Text dump saved to \(textURL.path)")

        // .eir YAML files (one per person)
        saveAsEir()
    }

    // MARK: - Receive Plugin Data

    /// Called when the embedded chrome plugin JS sends extracted data via postMessage.
    func receivePluginData(personName: String, entries: [ExtractedEntry]) {
        let personId = personName  // Use name as ID for plugin results

        // Remove previous plugin results for this person
        results.removeAll { $0.personId == personId }

        let result = ExtractionResult(personName: personName, personId: personId, entries: entries)
        results.append(result)

        saveAsEirForResult(result)

        status = .done(entries.count)
        log("Plugin extraction: received \(entries.count) entries for \(personName)")
    }

    // MARK: - EIR Format Export

    private func saveAsEir() {
        for result in results {
            saveAsEirForResult(result)
        }
    }

    private func saveAsEirForResult(_ result: ExtractionResult) {
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let now = isoFormatter.string(from: Date())

        let sanitizedName = result.personName
            .replacingOccurrences(of: " ", with: "_")
            .replacingOccurrences(of: "/", with: "-")
        let fileURL = URL(fileURLWithPath: "/tmp/eirviewer-\(sanitizedName).eir")

        let providers = Set(result.entries.compactMap { $0.provider }).sorted()
        let dates = result.entries.compactMap { normalizeDate($0.date) }.sorted()
        let startDate = dates.first ?? "unknown"
        let endDate = dates.last ?? "unknown"

        var yaml = "metadata:\n"
        yaml += "  format_version: \"1.0\"\n"
        yaml += "  created_at: \"\(now)\"\n"
        yaml += "  source: \"EirViewer – 1177.se extraction\"\n"
        yaml += "  patient:\n"
        yaml += "    name: \"\(escapeYAML(result.personName))\"\n"
        yaml += "  export_info:\n"
        yaml += "    total_entries: \(result.entries.count)\n"
        yaml += "    date_range:\n"
        yaml += "      start: \"\(startDate)\"\n"
        yaml += "      end: \"\(endDate)\"\n"
        if !providers.isEmpty {
            yaml += "    healthcare_providers:\n"
            for p in providers {
                yaml += "      - \"\(escapeYAML(p))\"\n"
            }
        }

        yaml += "entries:\n"

        for (index, entry) in result.entries.enumerated() {
            let entryID = entry.id.isEmpty ? "entry_\(String(format: "%03d", index))" : entry.id
            let date = normalizeDate(entry.date) ?? entry.date ?? ""
            let category = entry.category ?? "Övrigt"

            yaml += "  - id: \"\(escapeYAML(entryID))\"\n"
            yaml += "    date: \"\(escapeYAML(date))\"\n"
            if let time = entry.time, !time.isEmpty {
                yaml += "    time: \"\(escapeYAML(time))\"\n"
            }
            yaml += "    category: \"\(escapeYAML(category))\"\n"
            if let type = entry.type, !type.isEmpty {
                yaml += "    type: \"\(escapeYAML(type))\"\n"
            }
            if let provider = entry.provider, !provider.isEmpty {
                yaml += "    provider:\n"
                yaml += "      name: \"\(escapeYAML(provider))\"\n"
            }
            if let person = entry.responsiblePerson, !person.isEmpty {
                yaml += "    responsible_person:\n"
                yaml += "      name: \"\(escapeYAML(person))\"\n"
                if let role = entry.responsibleRole, !role.isEmpty {
                    yaml += "      role: \"\(escapeYAML(role))\"\n"
                }
            }
            yaml += "    content:\n"
            if let summary = entry.summary, !summary.isEmpty {
                yaml += "      summary: \"\(escapeYAML(summary))\"\n"
            }
            if let details = entry.details, !details.isEmpty {
                yaml += "      details: \"\(escapeYAML(details))\"\n"
            }
            if let notes = entry.notes, !notes.isEmpty {
                yaml += "      notes:\n"
                for note in notes {
                    yaml += "        - \"\(escapeYAML(note))\"\n"
                }
            }
            yaml += "    tags: []\n"
        }

        do {
            try yaml.write(to: fileURL, atomically: true, encoding: .utf8)
            eirFilePaths[result.personId] = fileURL
            log("EIR file saved: \(fileURL.path) (\(result.entries.count) entries)")
        } catch {
            log("EIR save error for \(result.personName): \(error.localizedDescription)")
        }
    }

    /// Escape special characters for YAML double-quoted strings.
    private func escapeYAML(_ str: String) -> String {
        str.replacingOccurrences(of: "\\", with: "\\\\")
           .replacingOccurrences(of: "\"", with: "\\\"")
           .replacingOccurrences(of: "\n", with: "\\n")
           .replacingOccurrences(of: "\r", with: "")
           .replacingOccurrences(of: "\t", with: " ")
    }

    /// Try to normalize a date string to yyyy-MM-dd format.
    private func normalizeDate(_ dateStr: String?) -> String? {
        guard let dateStr = dateStr, !dateStr.isEmpty else { return nil }

        // Already in yyyy-MM-dd format
        if dateStr.count == 10, dateStr.contains("-"),
           dateStr.first?.isNumber == true {
            return dateStr
        }

        // Try common Swedish date formats
        let formatters: [(String, Locale?)] = [
            ("yyyy-MM-dd", nil),
            ("yyyy-MM-dd'T'HH:mm:ss", nil),
            ("d MMM yyyy", Locale(identifier: "sv_SE")),
            ("d MMMM yyyy", Locale(identifier: "sv_SE")),
            ("dd MMM yyyy", Locale(identifier: "sv_SE")),
            ("dd MMMM yyyy", Locale(identifier: "sv_SE")),
            ("yyyy-MM-dd HH:mm", nil),
            ("yyyy-MM-dd HH:mm:ss", nil),
        ]

        for (format, locale) in formatters {
            let f = DateFormatter()
            f.dateFormat = format
            if let loc = locale { f.locale = loc }
            if let date = f.date(from: dateStr) {
                let out = DateFormatter()
                out.dateFormat = "yyyy-MM-dd"
                return out.string(from: date)
            }
        }

        return nil
    }

    // MARK: - Logging

    private func log(_ message: String) {
        let timestamp = Self.timeFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        statusLog.append(line)

        Task {
            await NetworkLogger.shared.log(
                type: "EXTRACT",
                method: "LOG",
                url: "",
                detail: message
            )
        }

        let logURL = URL(fileURLWithPath: "/tmp/eirviewer-extraction.log")
        let data = (line + "\n").data(using: .utf8) ?? Data()
        if FileManager.default.fileExists(atPath: logURL.path) {
            if let handle = try? FileHandle(forWritingTo: logURL) {
                handle.seekToEndOfFile()
                handle.write(data)
                handle.closeFile()
            }
        } else {
            try? data.write(to: logURL)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}
