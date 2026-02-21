# Eir Open Apps

Open-source tools for accessing, viewing, and understanding your Swedish medical records from [1177.se](https://journalen.1177.se).

**Your data never leaves your device.**

## Apps

### [Desktop — Eir Viewer](Desktop/EirViewer/)

A native macOS app (Swift/SwiftUI) for viewing `.eir` medical record files with AI-powered health insights.

**[Download latest release](https://github.com/BirgerMoell/eir-open-apps/releases/latest)**

- **Timeline view** — entries grouped by month with colored category badges
- **AI chat** — ask questions about your records using OpenAI, Anthropic, Groq, or any OpenAI-compatible provider
- **Agent with tools** — the AI can search records, drill into entries, find clinics, and remember you across sessions
- **Smart context** — handles 400+ entries by automatically summarizing records and letting the AI fetch details on demand
- **Multi-profile** — manage records for multiple family members, each with their own chat history
- **Health data browser** — embedded 1177.se browser with API-based extraction and session keep-alive
- **Find Care** — interactive map with 17,800+ Swedish healthcare clinics
- **Local vector search** — on-device embeddings for semantic search across records
- **Explain with AI** — one-click button on each journal entry to get a plain-language explanation
- **Privacy-first** — everything runs locally, no cloud storage

### [Chrome Extension — 1177 Journal Downloader](ChromeExtension/)

A Chrome extension that downloads your medical records from 1177.se into portable, structured files.

- **One-click download** — floating button on 1177.se exports all your journal entries
- **Structured EIR format** — exports to both plain text (.txt) and the open EIR format (.eir/YAML)
- **Complete history** — automatically loads all available entries by expanding the full timeline
- **Privacy-first** — all processing happens locally in your browser
- **Transfer to Eir.Space** — optionally view your records in the [Eir.Space](https://eir.space) viewer

## Repository Structure

```
├── Desktop/              # macOS desktop app
│   └── EirViewer/        # Swift/SwiftUI app with AI agent, tools, and memory
├── ChromeExtension/      # Chrome browser extension
│   ├── manifest.json     # Manifest V3 configuration
│   ├── content.js        # Journal scraping and EIR generation
│   ├── data-transfer.js  # Secure data transfer to Eir.Space
│   └── popup.html        # Extension popup UI
├── docs/                 # GitHub Pages (privacy policy)
├── eir-format-specification.md   # Full EIR format spec
├── eir-format-simple.yaml        # Example EIR file
└── EIR-FORMAT-OVERVIEW.md        # Format overview
```

## The EIR Format

The `.eir` file is a YAML-based format designed for medical records:

```yaml
metadata:
  format_version: "1.0"
  source: "1177.se Journal"
  patient:
    name: "Your Name"
  export_info:
    total_entries: 25
    date_range:
      start: "2001-02-26"
      end: "2025-03-17"

entries:
  - id: "entry_001"
    date: "2025-03-17"
    category: "Vaccinationer"
    provider:
      name: "Your Healthcare Provider"
      region: "Region Uppsala"
    content:
      summary: "TBE-vaccination"
      notes:
        - "Dos: 0.5 ml"
```

See [eir-format-specification.md](eir-format-specification.md) for the full specification.

## Quick Start

### Desktop App

1. Download `EirViewer-macOS.dmg` from [Releases](https://github.com/BirgerMoell/eir-open-apps/releases/latest)
2. Open the DMG and drag **Eir Viewer** to Applications
3. On first launch, right-click → Open to bypass Gatekeeper (unsigned app)
4. Import your `.eir` medical record files

Or build from source:

```bash
cd Desktop/EirViewer
swift build -c release
```

Requires macOS 14+ and Xcode Command Line Tools.

### Chrome Extension

1. Clone this repo or download the [latest release](https://github.com/BirgerMoell/eir-open-apps/releases/latest)
2. Open Chrome → `chrome://extensions/` → enable **Developer mode**
3. Click **"Load unpacked"** and select the `ChromeExtension/` folder
4. Navigate to [journalen.1177.se](https://journalen.1177.se), log in with BankID, and click "Download Journals"

Works with Chrome, Edge, Brave, Arc, and other Chromium-based browsers.

## Privacy

- All data processing happens locally on your device
- No data is sent to external servers (AI providers process queries temporarily, nothing is stored)
- No cookies, analytics, or tracking
- API keys stored in macOS Keychain (desktop app)
- GDPR compliant

## Contributing

Contributions are welcome! Feel free to open issues or submit pull requests.

## License

MIT
