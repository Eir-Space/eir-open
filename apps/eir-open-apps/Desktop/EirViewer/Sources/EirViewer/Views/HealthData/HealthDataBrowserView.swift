import SwiftUI
import WebKit

// MARK: - Main View

struct HealthDataBrowserView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @StateObject private var viewModel = HealthDataBrowserViewModel()
    @StateObject private var extractor = HealthDataExtractor()
    @State private var showingLog = true
    @State private var showingExtractorLog = false
    @State private var importedPersonIds: Set<String> = []
    @State private var importError: String?

    var body: some View {
        VStack(spacing: 0) {
            browserToolbar
            Divider()

            // Extraction progress bar
            if extractor.isExtracting {
                extractionProgressBar
            }

            // Main content
            if showingExtractorLog {
                HSplitView {
                    HealthDataWebView(viewModel: viewModel, extractor: extractor)
                        .frame(minWidth: 400)
                    extractionLogPanel
                        .frame(minWidth: 300, idealWidth: 400)
                }
            } else if showingLog {
                HSplitView {
                    HealthDataWebView(viewModel: viewModel, extractor: extractor)
                        .frame(minWidth: 400)
                    NetworkLogPanel(viewModel: viewModel)
                        .frame(minWidth: 300, idealWidth: 400)
                }
            } else {
                HealthDataWebView(viewModel: viewModel, extractor: extractor)
            }
        }
        // Auto-show extraction log when plugin sends data
        .onChange(of: extractor.results.count) { _, newCount in
            if newCount > 0 && !extractor.isExtracting {
                showingExtractorLog = true
                showingLog = false
            }
        }
    }

    private var browserToolbar: some View {
        HStack(spacing: 12) {
            // Navigation buttons
            HStack(spacing: 4) {
                Button { viewModel.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(!viewModel.canGoBack)
                Button { viewModel.goForward() } label: { Image(systemName: "chevron.right") }
                    .disabled(!viewModel.canGoForward)
                Button { viewModel.reload() } label: { Image(systemName: "arrow.clockwise") }
            }
            .buttonStyle(.borderless)

            // URL bar
            Text(viewModel.currentURL)
                .font(.caption)
                .foregroundColor(AppColors.textSecondary)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.divider)
                .cornerRadius(6)

            if viewModel.isLoading {
                ProgressView().scaleEffect(0.6)
            }

            // Extract button
            extractButton

            Divider().frame(height: 20)

            // Panel toggles
            Button {
                showingExtractorLog = false
                showingLog.toggle()
            } label: {
                Image(systemName: "network")
                    .foregroundColor(showingLog && !showingExtractorLog ? AppColors.primary : AppColors.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Network log")

            Button {
                showingLog = false
                showingExtractorLog.toggle()
            } label: {
                Image(systemName: "text.alignleft")
                    .foregroundColor(showingExtractorLog ? AppColors.primary : AppColors.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Extraction log")

            Button { viewModel.clearLog() } label: {
                Image(systemName: "trash").foregroundColor(AppColors.textSecondary)
            }
            .buttonStyle(.borderless)
            .help("Clear logs")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(AppColors.divider)
    }

    @ViewBuilder
    private var extractButton: some View {
        if extractor.isExtracting {
            Button {
                extractor.cancelExtraction()
            } label: {
                HStack(spacing: 4) {
                    ProgressView().scaleEffect(0.5)
                    Text("Cancel")
                        .font(.caption)
                }
            }
            .buttonStyle(.borderless)
        } else {
            // API extraction (fast, recommended)
            Button {
                showingExtractorLog = true
                showingLog = false
                Task {
                    await extractor.startAPIExtraction()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.white)
                        .font(.caption2)
                    Text("Download (API)")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(AppColors.primary)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Fast extraction via API calls")

            // DOM scraping fallback
            Button {
                showingExtractorLog = true
                showingLog = false
                Task {
                    await extractor.startExtraction()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption2)
                    Text("DOM")
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(AppColors.divider)
                .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Fallback: extract by clicking through the page")

            // Session indicator
            if extractor.hasActiveSession {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
                    .help("Session active — keep-alive running")
            }
        }
    }

    private var extractionProgressBar: some View {
        VStack(spacing: 2) {
            ProgressView(value: extractor.progress)
                .tint(AppColors.primary)
            HStack {
                statusText
                Spacer()
                Text("\(Int(extractor.progress * 100))%")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var statusText: some View {
        switch extractor.status {
        case .idle:
            Text("Ready").font(.caption2).foregroundColor(AppColors.textSecondary)
        case .navigating:
            Text("Navigating to journalen...").font(.caption2).foregroundColor(AppColors.primary)
        case .extractingToken:
            Text("Getting session token...").font(.caption2).foregroundColor(AppColors.primary)
        case .loadingMore(let clicks):
            Text("Loading more entries (\(clicks))...").font(.caption2).foregroundColor(AppColors.primary)
        case .expandingEntries(let current, let total):
            Text("Expanding entries \(current)/\(total)...").font(.caption2).foregroundColor(AppColors.primary)
        case .switchingJournal(let name):
            Text("Switching to \(name)...").font(.caption2).foregroundColor(AppColors.primary)
        case .extractingCategory(let name):
            Text("Extracting \(name)...").font(.caption2).foregroundColor(AppColors.primary)
        case .fetchingTimeline(let fetched, let total):
            Text("Fetching timeline \(fetched)/\(total)...").font(.caption2).foregroundColor(AppColors.primary)
        case .fetchingDetails(let current, let total):
            Text("Fetching details \(current)/\(total)...").font(.caption2).foregroundColor(AppColors.primary)
        case .parsingData:
            Text("Parsing data...").font(.caption2).foregroundColor(AppColors.primary)
        case .done(let count):
            Text("Done — \(count) entries extracted").font(.caption2).foregroundColor(AppColors.green)
        case .error(let msg):
            Text("Error: \(msg)").font(.caption2).foregroundColor(AppColors.red)
        }
    }

    private var extractionLogPanel: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Extraction Log")
                    .font(.caption)
                    .fontWeight(.semibold)
                Spacer()
                if case .done(let count) = extractor.status {
                    Text("\(count) entries")
                        .font(.caption2)
                        .foregroundColor(AppColors.green)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(AppColors.divider)

            Divider()

            // Log entries
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 2) {
                        ForEach(Array(extractor.statusLog.enumerated()), id: \.offset) { index, line in
                            Text(line)
                                .font(.system(size: 10, design: .monospaced))
                                .foregroundColor(logLineColor(line))
                                .textSelection(.enabled)
                                .id(index)
                        }
                    }
                    .padding(8)
                }
                .onChange(of: extractor.statusLog.count) {
                    if let last = extractor.statusLog.indices.last {
                        proxy.scrollTo(last, anchor: .bottom)
                    }
                }
            }

            // Results summary
            if !extractor.results.isEmpty {
                Divider()
                resultsSummary
            }
        }
    }

    private func logLineColor(_ line: String) -> Color {
        if line.contains("ERROR") { return AppColors.red }
        if line.contains("WARNING") { return AppColors.orange }
        if line.contains("===") { return AppColors.primary }
        if line.contains("→") { return AppColors.green }
        return AppColors.text
    }

    private var resultsSummary: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Results")
                .font(.caption)
                .fontWeight(.semibold)

            ForEach(extractor.results, id: \.personId) { result in
                resultRow(for: result)
            }

            HStack(spacing: 8) {
                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp/eirviewer-extracted-data.json"))
                } label: {
                    Text("JSON")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp/eirviewer-extracted-data.txt"))
                } label: {
                    Text("Text")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)

                Button {
                    NSWorkspace.shared.open(URL(fileURLWithPath: "/tmp/eirviewer-extraction.log"))
                } label: {
                    Text("Log")
                        .font(.caption2)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(8)
        .background(AppColors.divider)
    }

    @ViewBuilder
    private func resultRow(for result: HealthDataExtractor.ExtractionResult) -> some View {
        let matchingProfile = profileStore.findMatchingProfile(name: result.personName)
        let eirURL = extractor.eirFilePaths[result.personId]
        let alreadyImported = importedPersonIds.contains(result.personId)

        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(result.personName)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                Text("\(result.entries.count) entries")
                    .font(.caption2)
                    .foregroundColor(AppColors.textSecondary)
            }

            if alreadyImported {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                    Text("Imported")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
            } else if let eirURL = eirURL {
                HStack(spacing: 6) {
                    if let profile = matchingProfile {
                        // Existing profile found — offer to update
                        Button {
                            if profileStore.replaceFile(profile.id, with: eirURL) {
                                importedPersonIds.insert(result.personId)
                            }
                        } label: {
                            Label("Update \(profile.displayName)", systemImage: "arrow.triangle.2.circlepath")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    } else {
                        // No matching profile — offer to add new
                        Button {
                            if profileStore.addProfile(displayName: result.personName, fileURL: eirURL) != nil {
                                importedPersonIds.insert(result.personId)
                                importError = nil
                            } else {
                                importError = profileStore.errorMessage ?? "Failed to add \(result.personName)"
                            }
                        } label: {
                            Label("Add as New", systemImage: "person.badge.plus")
                                .font(.caption2)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                    }

                    Button {
                        saveEirFile(sourceURL: eirURL, personName: result.personName)
                    } label: {
                        Label("Save", systemImage: "square.and.arrow.down")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)

                    Button {
                        NSWorkspace.shared.open(eirURL)
                    } label: {
                        Text(".eir")
                            .font(.caption2)
                    }
                    .buttonStyle(.borderless)
                }
            }

            if let error = importError {
                Text(error)
                    .font(.caption2)
                    .foregroundColor(.red)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }

    private func saveEirFile(sourceURL: URL, personName: String) {
        let panel = NSSavePanel()
        panel.title = "Save Health Data"
        panel.nameFieldStringValue = "\(personName).eir"
        panel.allowedContentTypes = [.data]
        panel.allowsOtherFileTypes = true
        panel.canCreateDirectories = true

        if panel.runModal() == .OK, let destURL = panel.url {
            do {
                if FileManager.default.fileExists(atPath: destURL.path) {
                    try FileManager.default.removeItem(at: destURL)
                }
                try FileManager.default.copyItem(at: sourceURL, to: destURL)
            } catch {
                importError = "Save failed: \(error.localizedDescription)"
            }
        }
    }
}

// MARK: - Network Log Panel

struct NetworkLogPanel: View {
    @ObservedObject var viewModel: HealthDataBrowserViewModel
    @State private var selectedEntry: NetworkLogger.LogEntry?
    @State private var filterText = ""
    @State private var filterType: String? = nil

    private var filteredEntries: [NetworkLogger.LogEntry] {
        var result = viewModel.logEntries
        if let filterType {
            result = result.filter { $0.type == filterType }
        }
        if !filterText.isEmpty {
            result = result.filter {
                $0.url.localizedCaseInsensitiveContains(filterText) ||
                ($0.body?.localizedCaseInsensitiveContains(filterText) ?? false) ||
                ($0.detail?.localizedCaseInsensitiveContains(filterText) ?? false)
            }
        }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            filterBar
            Divider()
            logList
            if let entry = selectedEntry {
                Divider()
                NetworkLogDetail(entry: entry)
                    .frame(height: 200)
            }
        }
    }

    private var filterBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(AppColors.textSecondary)
                .font(.caption)

            TextField("Filter...", text: $filterText)
                .textFieldStyle(.plain)
                .font(.caption)

            filterChips

            Text("\(filteredEntries.count)")
                .font(.caption2)
                .foregroundColor(AppColors.textSecondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(AppColors.divider)
    }

    private var filterChips: some View {
        ForEach(["NAV", "XHR", "FETCH", "API"], id: \.self) { type in
            Button {
                filterType = filterType == type ? nil : type
            } label: {
                Text(type)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(filterType == type ? AppColors.primary : AppColors.divider)
                    .foregroundColor(filterType == type ? .white : AppColors.textSecondary)
                    .cornerRadius(4)
            }
            .buttonStyle(.plain)
        }
    }

    private var logList: some View {
        List(filteredEntries) { entry in
            NetworkLogRow(entry: entry, isSelected: selectedEntry?.id == entry.id)
                .onTapGesture {
                    selectedEntry = selectedEntry?.id == entry.id ? nil : entry
                }
        }
        .listStyle(.plain)
        .font(.system(size: 11, design: .monospaced))
    }
}

// MARK: - Log Row

struct NetworkLogRow: View {
    let entry: NetworkLogger.LogEntry
    let isSelected: Bool

    private var typeColor: Color {
        switch entry.type {
        case "NAV": return .blue
        case "XHR": return .orange
        case "FETCH": return .purple
        case "API": return .green
        case "REDIRECT": return .yellow
        case "COOKIE": return .gray
        case "RESPONSE": return .cyan
        default: return AppColors.textSecondary
        }
    }

    private var statusColor: Color {
        guard let status = entry.status else { return AppColors.textSecondary }
        switch status {
        case 200..<300: return .green
        case 300..<400: return .yellow
        case 400..<500: return .orange
        case 500...: return .red
        default: return AppColors.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Text(entry.type)
                .font(.system(size: 9, design: .monospaced))
                .fontWeight(.bold)
                .foregroundColor(typeColor)
                .frame(width: 45, alignment: .leading)

            Text(entry.method)
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(AppColors.textSecondary)
                .frame(width: 35, alignment: .leading)

            if let status = entry.status {
                Text("\(status)")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(statusColor)
                    .frame(width: 25)
            }

            Text(shortenURL(entry.url))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(isSelected ? AppColors.primary : AppColors.text)
                .lineLimit(1)
        }
        .padding(.vertical, 1)
        .background(isSelected ? AppColors.primarySoft : Color.clear)
    }

    private func shortenURL(_ url: String) -> String {
        guard let parsed = URL(string: url) else { return url }
        let path = parsed.path
        let query = parsed.query.map { "?\($0.prefix(80))" } ?? ""
        return "\(parsed.host ?? "")\(path)\(query)"
    }
}

// MARK: - Log Detail

struct NetworkLogDetail: View {
    let entry: NetworkLogger.LogEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Group {
                    Text("URL: \(entry.url)")
                    Text("Method: \(entry.method)")
                    if let status = entry.status {
                        Text("Status: \(status)")
                    }
                    if let detail = entry.detail {
                        Text("Detail: \(detail)")
                    }
                }
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(AppColors.text)
                .textSelection(.enabled)

                if let headers = entry.headers, !headers.isEmpty {
                    Text("Headers:")
                        .font(.system(size: 11, design: .monospaced))
                        .fontWeight(.bold)
                    ForEach(headers.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        Text("  \(key): \(value)")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(AppColors.textSecondary)
                            .textSelection(.enabled)
                    }
                }

                if let body = entry.body, !body.isEmpty {
                    Text("Body:")
                        .font(.system(size: 11, design: .monospaced))
                        .fontWeight(.bold)
                    Text(body.prefix(5000))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundColor(AppColors.textSecondary)
                        .textSelection(.enabled)
                }
            }
            .padding(8)
        }
        .background(AppColors.divider)
    }
}

// MARK: - ViewModel

@MainActor
class HealthDataBrowserViewModel: ObservableObject {
    @Published var currentURL: String = "https://e-tjanster.1177.se/mvk/login/login.xhtml"
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var logEntries: [NetworkLogger.LogEntry] = []

    weak var webView: WKWebView?
    private var refreshTimer: Timer?

    let startURL = URL(string: "https://e-tjanster.1177.se/mvk/login/login.xhtml")!

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }

    func clearLog() {
        logEntries.removeAll()
        Task { await NetworkLogger.shared.clear() }
    }

    func startLogRefresh() {
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                let entries = await NetworkLogger.shared.getEntries()
                if entries.count != self.logEntries.count {
                    self.logEntries = entries
                }
            }
        }
    }

    func stopLogRefresh() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    deinit {
        refreshTimer?.invalidate()
    }
}

// MARK: - WKWebView Wrapper

struct HealthDataWebView: NSViewRepresentable {
    @ObservedObject var viewModel: HealthDataBrowserViewModel
    @ObservedObject var extractor: HealthDataExtractor

    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // Enable JavaScript
        config.defaultWebpagePreferences.allowsContentJavaScript = true

        // Add script message handlers for intercepted network calls and plugin data
        let contentController = WKUserContentController()
        contentController.add(context.coordinator, name: "networkLogger")
        contentController.add(context.coordinator, name: "consoleLog")
        contentController.add(context.coordinator, name: "eirExtracted")

        // Inject XHR/fetch interceptor BEFORE page loads
        let interceptScript = WKUserScript(
            source: Self.networkInterceptorJS,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        )
        contentController.addUserScript(interceptScript)

        // Inject page content extractor
        let extractScript = WKUserScript(
            source: Self.pageContentExtractorJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        )
        contentController.addUserScript(extractScript)

        // Inject chrome plugin (floating download button) on journalen.1177.se pages
        let pluginScript = WKUserScript(
            source: Self.chromePluginJS,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: true
        )
        contentController.addUserScript(pluginScript)

        config.userContentController = contentController

        // Allow all cookies for BankID auth
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Custom user agent to appear as a real browser
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        viewModel.webView = webView
        extractor.setWebView(webView)
        viewModel.startLogRefresh()

        // Clear log and start fresh
        Task { await NetworkLogger.shared.clear() }

        // Load 1177 login page
        webView.load(URLRequest(url: viewModel.startURL))

        return webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, extractor: extractor)
    }

    // MARK: - JavaScript Interceptors

    /// Intercepts XMLHttpRequest and fetch() calls, posting details to Swift
    static let networkInterceptorJS = """
    (function() {
        // === XMLHttpRequest Interceptor ===
        const origXHROpen = XMLHttpRequest.prototype.open;
        const origXHRSend = XMLHttpRequest.prototype.send;
        const origXHRSetHeader = XMLHttpRequest.prototype.setRequestHeader;

        XMLHttpRequest.prototype.open = function(method, url, async, user, pass) {
            this._eir_method = method;
            this._eir_url = url;
            this._eir_headers = {};
            this._eir_async = async;
            return origXHROpen.apply(this, arguments);
        };

        XMLHttpRequest.prototype.setRequestHeader = function(name, value) {
            if (this._eir_headers) {
                this._eir_headers[name] = value;
            }
            return origXHRSetHeader.apply(this, arguments);
        };

        XMLHttpRequest.prototype.send = function(body) {
            const self = this;
            const startTime = Date.now();

            // Log the request
            try {
                window.webkit.messageHandlers.networkLogger.postMessage({
                    type: 'XHR',
                    phase: 'request',
                    method: self._eir_method || 'GET',
                    url: self._eir_url || '',
                    headers: self._eir_headers || {},
                    body: typeof body === 'string' ? body : (body ? '[binary]' : null)
                });
            } catch(e) {}

            // Listen for response
            self.addEventListener('load', function() {
                try {
                    const responseHeaders = {};
                    const headerStr = self.getAllResponseHeaders();
                    if (headerStr) {
                        headerStr.split('\\r\\n').forEach(function(line) {
                            const parts = line.split(': ');
                            if (parts.length >= 2) {
                                responseHeaders[parts[0]] = parts.slice(1).join(': ');
                            }
                        });
                    }

                    let responseBody = null;
                    try {
                        responseBody = self.responseText;
                    } catch(e) {
                        responseBody = '[unable to read response]';
                    }

                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'XHR',
                        phase: 'response',
                        method: self._eir_method || 'GET',
                        url: self._eir_url || '',
                        status: self.status,
                        headers: responseHeaders,
                        body: responseBody ? responseBody.substring(0, 10000) : null,
                        duration: Date.now() - startTime
                    });
                } catch(e) {}
            });

            self.addEventListener('error', function() {
                try {
                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'XHR',
                        phase: 'error',
                        method: self._eir_method || 'GET',
                        url: self._eir_url || '',
                        duration: Date.now() - startTime
                    });
                } catch(e) {}
            });

            return origXHRSend.apply(this, arguments);
        };

        // === Fetch Interceptor ===
        const origFetch = window.fetch;
        window.fetch = function(input, init) {
            const method = (init && init.method) || 'GET';
            const url = typeof input === 'string' ? input : (input.url || String(input));
            const headers = {};
            const startTime = Date.now();

            if (init && init.headers) {
                if (init.headers instanceof Headers) {
                    init.headers.forEach(function(value, key) { headers[key] = value; });
                } else if (typeof init.headers === 'object') {
                    Object.assign(headers, init.headers);
                }
            }

            let bodyStr = null;
            if (init && init.body) {
                if (typeof init.body === 'string') {
                    bodyStr = init.body;
                } else {
                    bodyStr = '[binary/FormData]';
                }
            }

            try {
                window.webkit.messageHandlers.networkLogger.postMessage({
                    type: 'FETCH',
                    phase: 'request',
                    method: method,
                    url: url,
                    headers: headers,
                    body: bodyStr
                });
            } catch(e) {}

            return origFetch.apply(this, arguments).then(function(response) {
                const cloned = response.clone();
                cloned.text().then(function(text) {
                    try {
                        const respHeaders = {};
                        response.headers.forEach(function(value, key) { respHeaders[key] = value; });

                        window.webkit.messageHandlers.networkLogger.postMessage({
                            type: 'FETCH',
                            phase: 'response',
                            method: method,
                            url: url,
                            status: response.status,
                            headers: respHeaders,
                            body: text ? text.substring(0, 10000) : null,
                            duration: Date.now() - startTime
                        });
                    } catch(e) {}
                });
                return response;
            }).catch(function(err) {
                try {
                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'FETCH',
                        phase: 'error',
                        method: method,
                        url: url,
                        detail: err.message || String(err),
                        duration: Date.now() - startTime
                    });
                } catch(e) {}
                throw err;
            });
        };

        // === Console.log interceptor ===
        const origLog = console.log;
        const origWarn = console.warn;
        const origError = console.error;

        console.log = function() {
            try {
                const msg = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({level: 'log', message: msg});
            } catch(e) {}
            origLog.apply(console, arguments);
        };
        console.warn = function() {
            try {
                const msg = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({level: 'warn', message: msg});
            } catch(e) {}
            origWarn.apply(console, arguments);
        };
        console.error = function() {
            try {
                const msg = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({level: 'error', message: msg});
            } catch(e) {}
            origError.apply(console, arguments);
        };
    })();
    """

    /// Extracts page content after load for analysis
    static let pageContentExtractorJS = """
    (function() {
        try {
            // Log page metadata
            const meta = {
                title: document.title,
                url: window.location.href,
                cookies: document.cookie ? document.cookie.substring(0, 2000) : '',
                forms: [],
                links: [],
                scripts: []
            };

            // Capture forms
            document.querySelectorAll('form').forEach(function(form) {
                meta.forms.push({
                    action: form.action,
                    method: form.method,
                    id: form.id,
                    fields: Array.from(form.elements).map(function(el) {
                        return {name: el.name, type: el.type, id: el.id};
                    }).filter(function(f) { return f.name; })
                });
            });

            // Capture interesting links (API-related)
            document.querySelectorAll('a[href]').forEach(function(a) {
                const href = a.href;
                if (href.includes('api') || href.includes('journal') || href.includes('mvk') ||
                    href.includes('health') || href.includes('record')) {
                    meta.links.push(href);
                }
            });

            // Capture script sources
            document.querySelectorAll('script[src]').forEach(function(s) {
                meta.scripts.push(s.src);
            });

            window.webkit.messageHandlers.networkLogger.postMessage({
                type: 'PAGE',
                phase: 'content',
                method: 'LOAD',
                url: window.location.href,
                body: JSON.stringify(meta, null, 2)
            });
        } catch(e) {}
    })();
    """

    /// Embedded chrome plugin: floating download button on journalen.1177.se pages.
    /// Extracts journal entries from the DOM and sends structured data to Swift via postMessage.
    static let chromePluginJS = """
    (function() {
        if (!window.location.href.includes('journalen.1177.se')) return;
        if (window.location.href.includes('login') || window.location.href.includes('Login')) return;
        if (window.__eirPluginInjected) return;
        window.__eirPluginInjected = true;

        function createButton() {
            if (document.getElementById('eir-plugin-btn')) return;
            var btn = document.createElement('div');
            btn.id = 'eir-plugin-btn';
            btn.innerHTML = '<div style="display:flex;align-items:center;gap:8px;cursor:pointer;">'
                + '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">'
                + '<path d="M21 15v4a2 2 0 01-2 2H5a2 2 0 01-2-2v-4"/>'
                + '<polyline points="7 10 12 15 17 10"/>'
                + '<line x1="12" y1="15" x2="12" y2="3"/>'
                + '</svg>'
                + '<span id="eir-btn-text">Download Journals</span>'
                + '</div>';
            btn.style.cssText = 'position:fixed;right:20px;bottom:20px;z-index:999999;'
                + 'background:#6366F1;color:white;padding:12px 20px;border-radius:12px;'
                + 'font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:14px;font-weight:600;'
                + 'box-shadow:0 4px 12px rgba(99,102,241,0.4);cursor:pointer;'
                + 'transition:transform 0.2s,box-shadow 0.2s;user-select:none;';
            btn.onmouseenter = function() {
                btn.style.transform = 'scale(1.05)';
                btn.style.boxShadow = '0 6px 16px rgba(99,102,241,0.5)';
            };
            btn.onmouseleave = function() {
                btn.style.transform = 'scale(1)';
                btn.style.boxShadow = '0 4px 12px rgba(99,102,241,0.4)';
            };
            btn.onclick = function(e) { e.stopPropagation(); extractAndSend(); };
            document.body.appendChild(btn);
        }

        function setBtnText(t) {
            var e = document.getElementById('eir-btn-text');
            if (e) e.textContent = t;
        }
        function setBtnEnabled(on) {
            var b = document.getElementById('eir-plugin-btn');
            if (b) {
                b.style.opacity = on ? '1' : '0.7';
                b.style.pointerEvents = on ? 'auto' : 'none';
            }
        }

        function waitForTimeline() {
            return new Promise(function(resolve) {
                var attempts = 0;
                (function check() {
                    var tv = document.getElementById('timeline-view');
                    if (tv && tv.children.length > 0) return resolve(true);
                    if (++attempts > 15) return resolve(false);
                    setTimeout(check, 1000);
                })();
            });
        }

        async function loadAllEntries() {
            var clicks = 0;
            while (clicks < 50) {
                var btns = document.getElementsByClassName('load-more ic-button ic-button--secondary iu-px-xxl');
                if (!btns.length) break;
                var b = btns[0];
                if (b.offsetParent === null || b.disabled) break;
                b.click();
                clicks++;
                setBtnText('Loading more... (' + clicks + ')');
                await new Promise(function(r) { setTimeout(r, 2000); });
            }
            return clicks;
        }

        async function expandAndExtract() {
            var arrows = document.getElementsByClassName('icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview');
            var entries = [];
            var monthMap = {
                jan:'01', feb:'02', mar:'03', apr:'04', maj:'05', jun:'06',
                jul:'07', aug:'08', sep:'09', okt:'10', nov:'11', dec:'12'
            };
            var cats = ['V\\u00e5rdkontakter','Anteckningar','Diagnoser','Vaccinationer',
                'L\\u00e4kemedel','Provsvar','Remisser','Tillv\\u00e4xt',
                'Uppm\\u00e4rksamhetsinformation','V\\u00e5rdplaner'];
            var provWords = ['v\\u00e5rdcentral','sjukhus','akut','tandv\\u00e5rd','folktandv\\u00e5rden',
                'slso','region','klinik','mottagning','husl\\u00e4kar'];

            for (var i = 0; i < arrows.length; i++) {
                try {
                    arrows[i].click();
                    await new Promise(function(r) { setTimeout(r, 100); });

                    var cont = arrows[i].closest('.ic-block-list__item, .journal-entry, .timeline-item, [data-cy-id]')
                        || arrows[i].parentElement;
                    if (!cont) continue;

                    var rawText = cont.textContent || cont.innerText || '';
                    var uiNoise = ['Ladda ner', 'St\\u00e4ng', 'Nytt', 'Osignerad'];
                    var lines = rawText.split('\\n')
                        .map(function(l) { return l.replace(/[ \\t]+/g, ' ').trim(); })
                        .filter(function(l) { return l.length > 0 && uiNoise.indexOf(l) === -1; });
                    var cleanText = lines.join('\\n');

                    var e = {
                        id: 'entry_' + String(i).padStart(3, '0'),
                        date: '', time: '', category: '', type: '',
                        provider: '', summary: '', details: cleanText
                    };

                    var dp = arrows[i].closest('[data-cy-datetime]');
                    if (dp) {
                        e.date = dp.getAttribute('data-cy-datetime') || '';
                        e.type = dp.getAttribute('data-cy-journal-overview-item-type') || '';
                    }
                    var db = cont.querySelector('button[data-id]');
                    if (db) {
                        e.id = db.getAttribute('data-id') || e.id;
                        var lbl = db.getAttribute('aria-label') || '';
                        if (lbl) e.summary = lbl;
                    }

                    for (var li = 0; li < lines.length; li++) {
                        var ln = lines[li];
                        if (!e.date) {
                            var dm = ln.match(/(\\d{1,2})\\s+(jan|feb|mar|apr|maj|jun|jul|aug|sep|okt|nov|dec)\\s+(\\d{4})/i);
                            if (dm) e.date = dm[3] + '-' + monthMap[dm[2].toLowerCase()] + '-' + dm[1].padStart(2, '0');
                            var iso = ln.match(/(\\d{4}-\\d{2}-\\d{2})/);
                            if (iso && !e.date) e.date = iso[1];
                        }
                        if (!e.time) {
                            var tm = ln.match(/(?:klockan\\s+)?(\\d{1,2}:\\d{2})/);
                            if (tm) e.time = tm[1];
                        }
                        if (!e.category) {
                            for (var c = 0; c < cats.length; c++) {
                                if (ln.includes(cats[c])) { e.category = cats[c]; break; }
                            }
                        }
                        if (!e.provider) {
                            for (var p = 0; p < provWords.length; p++) {
                                if (ln.toLowerCase().includes(provWords[p])) { e.provider = ln; break; }
                            }
                        }
                        if (!e.summary && ln.length > 5 && ln.length < 100
                            && !ln.match(/\\d{4}-\\d{2}-\\d{2}/)
                            && !ln.match(/\\d{1,2}\\s+\\w{3}\\s+\\d{4}/)) {
                            e.summary = ln;
                        }
                    }

                    if (e.date && e.date.includes(' ')) {
                        var parts = e.date.split(' ');
                        e.date = parts[0];
                        if (!e.time && parts[1]) e.time = parts[1].substring(0, 5);
                    }

                    entries.push(e);
                } catch(err) {}

                if (i > 0 && i % 20 === 0) {
                    setBtnText('Reading ' + i + '/' + arrows.length + '...');
                }
            }
            return entries;
        }

        async function extractAndSend() {
            setBtnEnabled(false);
            setBtnText('Waiting for data...');
            try {
                var ready = await waitForTimeline();
                if (!ready) {
                    setBtnText('No timeline found');
                    setTimeout(function() { setBtnText('Download Journals'); setBtnEnabled(true); }, 3000);
                    return;
                }

                setBtnText('Loading entries...');
                await loadAllEntries();

                var count = document.getElementsByClassName(
                    'icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview').length;
                setBtnText('Extracting ' + count + ' entries...');
                var entries = await expandAndExtract();

                // Try "Du ser uppgifter för X" header first (shows whose journal is viewed)
                var name = '';
                var allText = document.body.innerText || '';
                var viewingMatch = allText.match(/Du ser uppgifter f\\u00f6r\\s+([^\\n]+)/);
                if (viewingMatch) {
                    name = viewingMatch[1].trim();
                }
                // Fall back to avatar name (logged-in user)
                if (!name) {
                    name = (document.querySelector('.ic-avatar-box__name') || {}).textContent || 'Unknown';
                    name = name.trim();
                }

                window.webkit.messageHandlers.eirExtracted.postMessage({
                    personName: name,
                    entryCount: entries.length,
                    entries: entries
                });

                setBtnText('Sent ' + entries.length + ' entries!');
                setTimeout(function() { setBtnText('Download Journals'); setBtnEnabled(true); }, 3000);
            } catch(err) {
                console.error('EIR plugin error:', err);
                setBtnText('Error - Try Again');
                setTimeout(function() { setBtnEnabled(true); }, 1000);
            }
        }

        if (document.readyState === 'loading') {
            document.addEventListener('DOMContentLoaded', createButton);
        } else {
            createButton();
        }
        setTimeout(createButton, 2000);

        var lastURL = window.location.href;
        setInterval(function() {
            if (window.location.href !== lastURL) {
                lastURL = window.location.href;
                if (lastURL.includes('journalen.1177.se') && !lastURL.includes('login') && !lastURL.includes('Login')) {
                    setTimeout(createButton, 1000);
                } else {
                    var existing = document.getElementById('eir-plugin-btn');
                    if (existing) existing.remove();
                }
            }
        }, 1000);
    })();
    """
}

// MARK: - Coordinator (WKNavigationDelegate + ScriptMessageHandler)

extension HealthDataWebView {
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        let viewModel: HealthDataBrowserViewModel
        let extractor: HealthDataExtractor

        init(viewModel: HealthDataBrowserViewModel, extractor: HealthDataExtractor) {
            self.viewModel = viewModel
            self.extractor = extractor
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(
            _ userContentController: WKUserContentController,
            didReceive message: WKScriptMessage
        ) {
            guard let body = message.body as? [String: Any] else { return }

            if message.name == "consoleLog" {
                let level = body["level"] as? String ?? "log"
                let msg = body["message"] as? String ?? ""
                Task {
                    await NetworkLogger.shared.log(
                        type: "CONSOLE",
                        method: level.uppercased(),
                        url: "",
                        detail: msg
                    )
                }
                return
            }

            // Handle extracted data from embedded chrome plugin
            if message.name == "eirExtracted" {
                handlePluginExtraction(body)
                return
            }

            // networkLogger messages
            let type = body["type"] as? String ?? "UNKNOWN"
            let phase = body["phase"] as? String ?? ""
            let method = body["method"] as? String ?? "GET"
            let url = body["url"] as? String ?? ""
            let status = body["status"] as? Int
            let headers = body["headers"] as? [String: String]
            let bodyStr = body["body"] as? String
            let duration = body["duration"] as? Int
            let detail = body["detail"] as? String

            let typeLabel = phase == "response" ? "\(type)_RESP" : type
            let durationStr = duration.map { " (\($0)ms)" } ?? ""

            Task {
                await NetworkLogger.shared.log(
                    type: typeLabel,
                    method: method,
                    url: url,
                    status: status,
                    headers: headers,
                    body: bodyStr,
                    detail: (detail ?? "") + durationStr
                )
            }
        }

        // MARK: - Plugin Extraction Handler

        private func handlePluginExtraction(_ body: [String: Any]) {
            guard let personName = body["personName"] as? String,
                  let entriesArray = body["entries"] as? [[String: Any]] else {
                Task {
                    await NetworkLogger.shared.log(
                        type: "PLUGIN",
                        method: "ERROR",
                        url: "",
                        detail: "Invalid plugin data format"
                    )
                }
                return
            }

            let entries = entriesArray.map { e in
                HealthDataExtractor.ExtractedEntry(
                    id: e["id"] as? String ?? "entry_\(entriesArray.firstIndex(where: { ($0["id"] as? String) == (e["id"] as? String) }) ?? 0)",
                    date: e["date"] as? String,
                    time: e["time"] as? String,
                    category: e["category"] as? String,
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

            Task { @MainActor in
                extractor.receivePluginData(personName: personName, entries: entries)
            }
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            Task { @MainActor in
                viewModel.isLoading = true
                viewModel.currentURL = webView.url?.absoluteString ?? ""
                viewModel.canGoBack = webView.canGoBack
                viewModel.canGoForward = webView.canGoForward
            }

            if let url = webView.url {
                Task {
                    await NetworkLogger.shared.log(
                        type: "NAV",
                        method: "START",
                        url: url.absoluteString
                    )
                }
            }
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                viewModel.isLoading = false
                viewModel.currentURL = webView.url?.absoluteString ?? ""
                viewModel.canGoBack = webView.canGoBack
                viewModel.canGoForward = webView.canGoForward
            }

            if let url = webView.url {
                Task {
                    await NetworkLogger.shared.log(
                        type: "NAV",
                        method: "FINISH",
                        url: url.absoluteString
                    )
                }

                // Log cookies for this domain
                WKWebsiteDataStore.default().httpCookieStore.getAllCookies { cookies in
                    let relevantCookies = cookies.filter { cookie in
                        url.host?.contains(cookie.domain.replacingOccurrences(of: ".", with: "", options: .anchored)) ?? false
                    }
                    if !relevantCookies.isEmpty {
                        let cookieStr = relevantCookies.map { "\($0.name)=\($0.value.prefix(50))" }.joined(separator: "; ")
                        Task {
                            await NetworkLogger.shared.log(
                                type: "COOKIE",
                                method: "GET",
                                url: url.absoluteString,
                                detail: "\(relevantCookies.count) cookies: \(cookieStr.prefix(500))"
                            )
                        }
                    }
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.isLoading = false
            }
            Task {
                await NetworkLogger.shared.log(
                    type: "NAV",
                    method: "ERROR",
                    url: webView.url?.absoluteString ?? "",
                    detail: error.localizedDescription
                )
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.isLoading = false
            }
            Task {
                await NetworkLogger.shared.log(
                    type: "NAV",
                    method: "PROV_ERROR",
                    url: webView.url?.absoluteString ?? "",
                    detail: error.localizedDescription
                )
            }
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url {
                let method = navigationAction.request.httpMethod ?? "GET"
                let headers = navigationAction.request.allHTTPHeaderFields

                Task {
                    await NetworkLogger.shared.log(
                        type: "NAV",
                        method: method,
                        url: url.absoluteString,
                        headers: headers,
                        detail: "navigationType=\(navigationAction.navigationType.rawValue)"
                    )
                }
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            if let httpResponse = navigationResponse.response as? HTTPURLResponse {
                let url = httpResponse.url?.absoluteString ?? ""
                let headers = httpResponse.allHeaderFields as? [String: String]

                Task {
                    await NetworkLogger.shared.log(
                        type: "RESPONSE",
                        method: "RESP",
                        url: url,
                        status: httpResponse.statusCode,
                        headers: headers,
                        detail: "mimeType=\(navigationResponse.response.mimeType ?? "?")"
                    )
                }
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!
        ) {
            if let url = webView.url {
                Task {
                    await NetworkLogger.shared.log(
                        type: "REDIRECT",
                        method: "302",
                        url: url.absoluteString
                    )
                }
            }
        }

        // Handle HTTPS certificate challenges (needed for BankID/SITHS)
        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            Task {
                await NetworkLogger.shared.log(
                    type: "AUTH",
                    method: "CHALLENGE",
                    url: challenge.protectionSpace.host,
                    detail: "authMethod=\(challenge.protectionSpace.authenticationMethod)"
                )
            }
            // Accept all server certificates for 1177
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
}
