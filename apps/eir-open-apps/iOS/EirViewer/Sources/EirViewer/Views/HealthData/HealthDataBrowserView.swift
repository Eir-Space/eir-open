import SwiftUI
import WebKit

// MARK: - Main View

struct HealthDataBrowserView: View {
    @EnvironmentObject var profileStore: ProfileStore
    @StateObject private var viewModel = HealthDataBrowserViewModel()
    @StateObject private var extractor = HealthDataExtractor()
    @State private var showingExtractionSheet = false
    @State private var importedPersonIds: Set<String> = []
    @State private var importError: String?

    var body: some View {
        ZStack(alignment: .bottom) {
            HealthDataWebView(viewModel: viewModel, extractor: extractor)
                .ignoresSafeArea(edges: .bottom)

            // Floating extraction progress pill
            if extractor.isExtracting {
                extractionPill
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .navigationTitle("Health Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button { viewModel.goBack() } label: { Image(systemName: "chevron.left") }
                    .disabled(!viewModel.canGoBack)
                Button { viewModel.goForward() } label: { Image(systemName: "chevron.right") }
                    .disabled(!viewModel.canGoForward)
                Button { viewModel.reload() } label: { Image(systemName: "arrow.clockwise") }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                if extractor.isExtracting {
                    Button {
                        extractor.cancelExtraction()
                    } label: {
                        HStack(spacing: 4) {
                            ProgressView().scaleEffect(0.6)
                            Text("Cancel")
                                .font(.caption)
                        }
                    }
                } else {
                    Button {
                        Task {
                            await extractor.startAPIExtraction()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "bolt.fill")
                                .font(.caption2)
                            Text("Download")
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppColors.primary)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)

                    if extractor.hasActiveSession {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExtractionSheet) {
            extractionResultsSheet
        }
        .onChange(of: extractor.results.count) { _, newCount in
            if newCount > 0 && !extractor.isExtracting {
                showingExtractionSheet = true
            }
        }
    }

    // MARK: - Extraction Progress Pill

    private var extractionPill: some View {
        Button {
            showingExtractionSheet = true
        } label: {
            VStack(spacing: 4) {
                ProgressView(value: extractor.progress)
                    .tint(.white)
                HStack {
                    statusText
                    Spacer()
                    Text("\(Int(extractor.progress * 100))%")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.8))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(AppColors.primary)
            .cornerRadius(12)
            .shadow(radius: 8)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 20)
    }

    @ViewBuilder
    private var statusText: some View {
        let color = Color.white
        switch extractor.status {
        case .idle:
            Text("Ready").font(.caption2).foregroundColor(color.opacity(0.8))
        case .navigating:
            Text("Navigating to journalen...").font(.caption2).foregroundColor(color)
        case .extractingToken:
            Text("Getting session token...").font(.caption2).foregroundColor(color)
        case .loadingMore(let clicks):
            Text("Loading more entries (\(clicks))...").font(.caption2).foregroundColor(color)
        case .expandingEntries(let current, let total):
            Text("Expanding entries \(current)/\(total)...").font(.caption2).foregroundColor(color)
        case .switchingJournal(let name):
            Text("Switching to \(name)...").font(.caption2).foregroundColor(color)
        case .extractingCategory(let name):
            Text("Extracting \(name)...").font(.caption2).foregroundColor(color)
        case .fetchingTimeline(let fetched, let total):
            Text("Fetching timeline \(fetched)/\(total)...").font(.caption2).foregroundColor(color)
        case .fetchingDetails(let current, let total):
            Text("Fetching details \(current)/\(total)...").font(.caption2).foregroundColor(color)
        case .parsingData:
            Text("Parsing data...").font(.caption2).foregroundColor(color)
        case .done(let count):
            Text("Done — \(count) entries").font(.caption2).foregroundColor(color)
        case .error(let msg):
            Text("Error: \(msg)").font(.caption2).foregroundColor(.red)
        }
    }

    // MARK: - Extraction Results Sheet

    private var extractionResultsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Progress section
                    if extractor.isExtracting {
                        VStack(spacing: 4) {
                            ProgressView(value: extractor.progress)
                                .tint(AppColors.primary)
                            HStack {
                                statusTextDark
                                Spacer()
                                Text("\(Int(extractor.progress * 100))%")
                                    .font(.caption2)
                                    .foregroundColor(AppColors.textSecondary)
                            }
                        }
                        .padding()
                        .background(AppColors.divider)
                        .cornerRadius(12)
                    }

                    // Results
                    if !extractor.results.isEmpty {
                        ForEach(extractor.results, id: \.personId) { result in
                            resultCard(for: result)
                        }
                    }

                    // Log (collapsible)
                    if !extractor.statusLog.isEmpty {
                        DisclosureGroup("Extraction Log") {
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 1) {
                                    ForEach(Array(extractor.statusLog.enumerated()), id: \.offset) { _, line in
                                        Text(line)
                                            .font(.system(size: 9, design: .monospaced))
                                            .foregroundColor(logLineColor(line))
                                    }
                                }
                            }
                            .frame(maxHeight: 300)
                        }
                        .font(.caption)
                        .padding()
                        .background(AppColors.divider)
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("Extraction Results")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { showingExtractionSheet = false }
                }
            }
        }
    }

    @ViewBuilder
    private var statusTextDark: some View {
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

    private func logLineColor(_ line: String) -> Color {
        if line.contains("ERROR") { return AppColors.red }
        if line.contains("WARNING") { return AppColors.orange }
        if line.contains("===") { return AppColors.primary }
        return AppColors.text
    }

    @ViewBuilder
    private func resultCard(for result: HealthDataExtractor.ExtractionResult) -> some View {
        let matchingProfile = profileStore.findMatchingProfile(name: result.personName)
        let eirURL = extractor.eirFilePaths[result.personId]
        let alreadyImported = importedPersonIds.contains(result.personId)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.fill")
                    .foregroundColor(AppColors.primary)
                Text(result.personName)
                    .font(.headline)
                Spacer()
                Text("\(result.entries.count) entries")
                    .font(.caption)
                    .foregroundColor(AppColors.textSecondary)
            }

            if alreadyImported {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("Imported successfully")
                        .foregroundColor(.green)
                }
                .font(.subheadline)
            } else if let eirURL {
                VStack(spacing: 8) {
                    if let profile = matchingProfile {
                        Button {
                            profileStore.replaceFile(profile.id, with: eirURL)
                            importedPersonIds.insert(result.personId)
                        } label: {
                            Label("Update \(profile.displayName)", systemImage: "arrow.triangle.2.circlepath")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            if profileStore.addProfile(displayName: result.personName, fileURL: eirURL) != nil {
                                importedPersonIds.insert(result.personId)
                                importError = nil
                            } else {
                                importError = profileStore.errorMessage ?? "Failed to add \(result.personName)"
                            }
                        } label: {
                            Label("Add as New Profile", systemImage: "person.badge.plus")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    }

                    if let error = importError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }
        }
        .padding()
        .background(AppColors.divider)
        .cornerRadius(12)
    }
}

// MARK: - ViewModel

@MainActor
class HealthDataBrowserViewModel: ObservableObject {
    @Published var currentURL: String = ""
    @Published var isLoading: Bool = false
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false

    weak var webView: WKWebView?
    let startURL = URL(string: "https://e-tjanster.1177.se/mvk/login/login.xhtml")!

    func goBack() { webView?.goBack() }
    func goForward() { webView?.goForward() }
    func reload() { webView?.reload() }
}

// MARK: - WKWebView Wrapper (UIViewRepresentable)

struct HealthDataWebView: UIViewRepresentable {
    @ObservedObject var viewModel: HealthDataBrowserViewModel
    @ObservedObject var extractor: HealthDataExtractor

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true

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
        config.websiteDataStore = .default()

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // iPhone Safari user agent
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1"

        viewModel.webView = webView
        extractor.setWebView(webView)

        webView.load(URLRequest(url: viewModel.startURL))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(viewModel: viewModel, extractor: extractor)
    }

    // MARK: - JavaScript Scripts (verbatim from Desktop)

    static let networkInterceptorJS = """
    (function() {
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

            try {
                window.webkit.messageHandlers.networkLogger.postMessage({
                    type: 'XHR', phase: 'request',
                    method: self._eir_method || 'GET',
                    url: self._eir_url || '',
                    headers: self._eir_headers || {},
                    body: typeof body === 'string' ? body : (body ? '[binary]' : null)
                });
            } catch(e) {}

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
                    try { responseBody = self.responseText; } catch(e) { responseBody = '[unable to read]'; }

                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'XHR', phase: 'response',
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
                        type: 'XHR', phase: 'error',
                        method: self._eir_method || 'GET',
                        url: self._eir_url || '',
                        duration: Date.now() - startTime
                    });
                } catch(e) {}
            });

            return origXHRSend.apply(this, arguments);
        };

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
                bodyStr = typeof init.body === 'string' ? init.body : '[binary/FormData]';
            }

            try {
                window.webkit.messageHandlers.networkLogger.postMessage({
                    type: 'FETCH', phase: 'request', method: method, url: url,
                    headers: headers, body: bodyStr
                });
            } catch(e) {}

            return origFetch.apply(this, arguments).then(function(response) {
                const cloned = response.clone();
                cloned.text().then(function(text) {
                    try {
                        const respHeaders = {};
                        response.headers.forEach(function(value, key) { respHeaders[key] = value; });
                        window.webkit.messageHandlers.networkLogger.postMessage({
                            type: 'FETCH', phase: 'response', method: method, url: url,
                            status: response.status, headers: respHeaders,
                            body: text ? text.substring(0, 10000) : null,
                            duration: Date.now() - startTime
                        });
                    } catch(e) {}
                });
                return response;
            }).catch(function(err) {
                try {
                    window.webkit.messageHandlers.networkLogger.postMessage({
                        type: 'FETCH', phase: 'error', method: method, url: url,
                        detail: err.message || String(err), duration: Date.now() - startTime
                    });
                } catch(e) {}
                throw err;
            });
        };

        const origLog = console.log;
        const origWarn = console.warn;
        const origError = console.error;
        console.log = function() {
            try { const msg = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({level: 'log', message: msg}); } catch(e) {}
            origLog.apply(console, arguments);
        };
        console.warn = function() {
            try { const msg = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({level: 'warn', message: msg}); } catch(e) {}
            origWarn.apply(console, arguments);
        };
        console.error = function() {
            try { const msg = Array.from(arguments).map(a => typeof a === 'object' ? JSON.stringify(a) : String(a)).join(' ');
                window.webkit.messageHandlers.consoleLog.postMessage({level: 'error', message: msg}); } catch(e) {}
            origError.apply(console, arguments);
        };
    })();
    """

    static let pageContentExtractorJS = """
    (function() {
        try {
            const meta = {
                title: document.title, url: window.location.href,
                cookies: document.cookie ? document.cookie.substring(0, 2000) : '',
                forms: [], links: [], scripts: []
            };
            document.querySelectorAll('form').forEach(function(form) {
                meta.forms.push({ action: form.action, method: form.method, id: form.id,
                    fields: Array.from(form.elements).map(function(el) {
                        return {name: el.name, type: el.type, id: el.id};
                    }).filter(function(f) { return f.name; })
                });
            });
            document.querySelectorAll('a[href]').forEach(function(a) {
                const href = a.href;
                if (href.includes('api') || href.includes('journal') || href.includes('mvk') || href.includes('health') || href.includes('record')) {
                    meta.links.push(href);
                }
            });
            document.querySelectorAll('script[src]').forEach(function(s) { meta.scripts.push(s.src); });
            window.webkit.messageHandlers.networkLogger.postMessage({
                type: 'PAGE', phase: 'content', method: 'LOAD', url: window.location.href,
                body: JSON.stringify(meta, null, 2)
            });
        } catch(e) {}
    })();
    """

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
            btn.style.cssText = 'position:fixed;right:16px;bottom:80px;z-index:999999;'
                + 'background:#6366F1;color:white;padding:12px 20px;border-radius:12px;'
                + 'font-family:-apple-system,BlinkMacSystemFont,sans-serif;font-size:14px;font-weight:600;'
                + 'box-shadow:0 4px 12px rgba(99,102,241,0.4);cursor:pointer;'
                + 'transition:transform 0.2s,box-shadow 0.2s;user-select:none;-webkit-tap-highlight-color:transparent;';
            btn.ontouchstart = function() { btn.style.transform = 'scale(0.95)'; };
            btn.ontouchend = function() { btn.style.transform = 'scale(1)'; };
            btn.onclick = function(e) { e.stopPropagation(); extractAndSend(); };
            document.body.appendChild(btn);
        }

        function setBtnText(t) { var e = document.getElementById('eir-btn-text'); if (e) e.textContent = t; }
        function setBtnEnabled(on) {
            var b = document.getElementById('eir-plugin-btn');
            if (b) { b.style.opacity = on ? '1' : '0.7'; b.style.pointerEvents = on ? 'auto' : 'none'; }
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
                b.click(); clicks++;
                setBtnText('Loading more... (' + clicks + ')');
                await new Promise(function(r) { setTimeout(r, 2000); });
            }
            return clicks;
        }

        async function expandAndExtract() {
            var arrows = document.getElementsByClassName('icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview');
            var entries = [];
            var monthMap = { jan:'01', feb:'02', mar:'03', apr:'04', maj:'05', jun:'06',
                jul:'07', aug:'08', sep:'09', okt:'10', nov:'11', dec:'12' };
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

                    var e = { id: 'entry_' + String(i).padStart(3, '0'),
                        date: '', time: '', category: '', type: '',
                        provider: '', summary: '', details: cleanText };

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
                        if (!e.time) { var tm = ln.match(/(?:klockan\\s+)?(\\d{1,2}:\\d{2})/); if (tm) e.time = tm[1]; }
                        if (!e.category) { for (var c = 0; c < cats.length; c++) { if (ln.includes(cats[c])) { e.category = cats[c]; break; } } }
                        if (!e.provider) { for (var p = 0; p < provWords.length; p++) { if (ln.toLowerCase().includes(provWords[p])) { e.provider = ln; break; } } }
                        if (!e.summary && ln.length > 5 && ln.length < 100
                            && !ln.match(/\\d{4}-\\d{2}-\\d{2}/) && !ln.match(/\\d{1,2}\\s+\\w{3}\\s+\\d{4}/)) { e.summary = ln; }
                    }

                    if (e.date && e.date.includes(' ')) {
                        var parts = e.date.split(' ');
                        e.date = parts[0];
                        if (!e.time && parts[1]) e.time = parts[1].substring(0, 5);
                    }

                    entries.push(e);
                } catch(err) {}

                if (i > 0 && i % 20 === 0) { setBtnText('Reading ' + i + '/' + arrows.length + '...'); }
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
                var count = document.getElementsByClassName('icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview').length;
                setBtnText('Extracting ' + count + ' entries...');
                var entries = await expandAndExtract();

                var name = '';
                var allText = document.body.innerText || '';
                var viewingMatch = allText.match(/Du ser uppgifter f\\u00f6r\\s+([^\\n]+)/);
                if (viewingMatch) { name = viewingMatch[1].trim(); }
                if (!name) { name = (document.querySelector('.ic-avatar-box__name') || {}).textContent || 'Unknown'; name = name.trim(); }

                window.webkit.messageHandlers.eirExtracted.postMessage({
                    personName: name, entryCount: entries.length, entries: entries
                });

                setBtnText('Sent ' + entries.length + ' entries!');
                setTimeout(function() { setBtnText('Download Journals'); setBtnEnabled(true); }, 3000);
            } catch(err) {
                console.error('EIR plugin error:', err);
                setBtnText('Error - Try Again');
                setTimeout(function() { setBtnEnabled(true); }, 1000);
            }
        }

        if (document.readyState === 'loading') { document.addEventListener('DOMContentLoaded', createButton); }
        else { createButton(); }
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

            // Handle extracted data from embedded chrome plugin
            if message.name == "eirExtracted" {
                handlePluginExtraction(body)
                return
            }

            // networkLogger and consoleLog messages are silently consumed on iOS
            // (no network log panel — the data is used only by HealthDataExtractor)
        }

        private func handlePluginExtraction(_ body: [String: Any]) {
            guard let personName = body["personName"] as? String,
                  let entriesArray = body["entries"] as? [[String: Any]] else {
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
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            Task { @MainActor in
                viewModel.isLoading = false
                viewModel.currentURL = webView.url?.absoluteString ?? ""
                viewModel.canGoBack = webView.canGoBack
                viewModel.canGoForward = webView.canGoForward
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.isLoading = false
            }
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            Task { @MainActor in
                viewModel.isLoading = false
            }
        }

        // BankID URL scheme interception + general navigation policy
        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            if let url = navigationAction.request.url {
                // Handle BankID URL scheme for same-device authentication
                if url.scheme == "bankid" {
                    UIApplication.shared.open(url) { _ in }
                    decisionHandler(.cancel)
                    return
                }
            }
            decisionHandler(.allow)
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationResponse: WKNavigationResponse,
            decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
        ) {
            decisionHandler(.allow)
        }

        // Handle HTTPS certificate challenges
        func webView(
            _ webView: WKWebView,
            didReceive challenge: URLAuthenticationChallenge,
            completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void
        ) {
            if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
               let serverTrust = challenge.protectionSpace.serverTrust {
                completionHandler(.useCredential, URLCredential(trust: serverTrust))
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
}
