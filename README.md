# eir-open

Open Source Eir Space code — focused on AI for empowering people in their health journey.

## Quick Install (Mac)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/eir-space/eir-open/main/install.sh)
```

Interactive menu installs medication skills, CBT programs module, Health.md, Eir Apps, and OpenClaw integration. See the [Quickstart guide](https://eir-space.github.io/eir-open/docs/quickstart/) for individual installs and OpenClaw setup.

## Open Source Projects

### 🇸🇪 Swedish Medications

**Location**: [`skills/swedish-medications/`](skills/swedish-medications/)

A comprehensive medication lookup tool for Swedish pharmaceuticals based on the FASS database. Built as an OpenClaw skill for AI agents, this tool provides quick access to medication information including brand to substance mapping, dosage information, side effects, and official FASS links.

**Key Features:**

- Quick lookup of common Swedish medications
- Brand → substance mapping (e.g., Alvedon → paracetamol)
- Dosage information, side effects, and warnings
- OTC (over-the-counter) status indicators
- Direct links to official FASS documentation
- AI-agent ready for integration with OpenClaw, LangChain, and other frameworks

Perfect for healthcare applications, AI assistants helping with Swedish healthcare queries, and developers building health-focused applications in the Swedish market.

### 🇺🇸 US FDA Medications

**Location**: [`skills/us-medications/`](skills/us-medications/)

A comprehensive US FDA medication lookup tool with access to over 81,000 medications in the full database. Features 99 curated common medications for instant access and includes drug interaction checking capabilities.

**Key Features:**

- **81,212 FDA medications** in the full database
- **99 curated** common medications with instant access (no download needed)
- **Drug interactions** lookup functionality
- CLI and JavaScript API
- OpenClaw skill compatible
- Automatic database download on first use
- Comprehensive medication information including uses, warnings, and interactions

Ideal for US healthcare applications, medical AI assistants, drug interaction checkers, and developers building healthcare applications for the American market.

### 🧠 CBT Programs Registry

**Location**: [`skills/cbt-programs/`](skills/cbt-programs/)

A modular open-source CBT registry for different health problems with multilingual support, provenance labels, and agent-ready workflows.

**Key Features:**

- **Modular structure**: one folder per program with machine-readable metadata + locale content
- **Multilingual by design**: language packs under `locales/<lang>.json` with translation review status
- **Trust labels**: explicit flags for AI-created, human-created, human-reviewed, and healthcare-expert-verified
- **Change tracking**: markdown `progress/*.md` logs and `changelog.md` per program
- **CLI included**: `cbt-programs` for list/search/recommend/validate/scaffold workflows
- **Agent skill included**: `SKILL.md` for integration in agent systems

Ideal for teams publishing transparent, auditable CBT programs and for agents that need safe recommendation and guided-support workflows.

**Why this matters:**

- Anyone can inspect exactly who authored and reviewed a program.
- Programs are easy to localize without touching core metadata.
- Teams can collaborate safely with traceable markdown updates.

**How to contribute quickly:**

1. Scaffold or import a program.
2. Add or improve `locales/<lang>.json`.
3. Mark review/verification status in `program.json`.
4. Run `cbt-programs validate`.
5. Open a PR with your `progress/` note and changelog update.

See detailed docs in [`site/src/content/docs/docs/cbt-programs.mdx`](site/src/content/docs/docs/cbt-programs.mdx).

### 🏥 EIR Health Data Standard

**Location**: [`open-health-standard/health-md-standard/`](open-health-standard/health-md-standard/)

An open YAML-based standard for structuring healthcare information optimized for Large Language Models. Named after Eir, the Norse goddess of healing and medicine, this format enables privacy-preserving, clinically-accurate health data exchange.

**Key Features:**

- **LLM-Optimized**: Structured for perfect AI comprehension and reasoning
- **Privacy-First**: Built-in anonymization and data protection patterns
- **Clinical-Accurate**: Preserves medical context and relationships
- **Human-Readable**: Markdown format accessible to clinicians and patients
- **Interoperable**: Works across systems, platforms, and use cases
- **MCP Compatible**: Includes Model Context Protocol server implementation
- **Comprehensive Specification**: Detailed EIR-SPEC.md with examples and guidelines

Perfect for healthcare AI applications, EHR systems, telemedicine platforms, and any application requiring standardized, privacy-aware health data formatting. Enables seamless integration between healthcare systems and AI models while maintaining clinical accuracy and patient privacy.

## Applications

App directory index: [`apps/README.md`](apps/README.md)

### 📱 Eir Open Apps

**Location**: [`apps/eir-open-apps/`](apps/eir-open-apps/)

Open-source applications for accessing, viewing, and understanding Swedish medical records from 1177.se with complete privacy - your data never leaves your device.

**Desktop App - Eir Viewer (macOS):**

- **Timeline view** with AI-powered health insights using OpenAI, Anthropic, or Groq
- **Agent with tools** for intelligent record search and analysis
- **Multi-profile support** for managing family health records
- **Local vector search** with on-device embeddings
- **Health data browser** with embedded 1177.se integration
- **Find Care** interactive map with 17,800+ Swedish healthcare clinics
- **Privacy-first** - everything runs locally, no cloud storage

**Chrome Extension - 1177 Journal Downloader:**

- **One-click download** of complete medical records from 1177.se
- **Structured EIR format** exports (.eir/YAML and .txt)
- **Complete history** with automatic timeline expansion
- **Privacy-first** - all processing happens locally in browser
- **Transfer to Eir.Space** for viewing in web interface

Ideal for patients wanting full control over their health data, healthcare developers building patient-centric applications, and anyone requiring privacy-preserving medical record management with AI assistance.

### Open Medical Scribe

**Location**: [`apps/open-medical-scribe/`](apps/open-medical-scribe/)

An open-source AI medical scribe that transcribes clinical encounters in real-time and generates structured medical notes. Runs fully local for maximum privacy — no patient data ever leaves your machine.

**Key Features:**

- **Real-time transcription** with Whisper ONNX running locally (Swedish-optimized KB Whisper model)
- **Structured note generation** via Ollama (local), OpenAI, Anthropic Claude, or Google Gemini
- **Six note formats**: SOAP, H&P, Progress, DAP, Procedure, and Swedish Journalanteckning
- **Privacy-first**: entire pipeline runs on your own hardware in local mode
- **Electron desktop app** with light build (~1 GB) and full offline build (~1.9 GB with bundled models)
- **CLI tools**: `scribe-transcribe` and `scribe-note` for scripting and batch workflows
- **Web UI** with settings page for all providers and configuration
- **Pluggable providers**: swap transcription and LLM backends with a single config change

**Supported Providers:**

| Transcription          | Note Generation  |
| ---------------------- | ---------------- |
| Whisper ONNX (local)   | Ollama (local)   |
| faster-whisper (local) | OpenAI           |
| whisper.cpp (local)    | Anthropic Claude |
| OpenAI Whisper         | Google Gemini    |
| Deepgram               |                  |
| Google Cloud Speech    |                  |
| Berget AI (EU)         |                  |

**Quick Start:**

```bash
cd apps/open-medical-scribe
npm install
npm start
# Open http://localhost:8787
```

**Downloads**: [Desktop app for macOS](https://github.com/BirgerMoell/open-medical-scribe/releases/tag/v0.1.0) | [Documentation](https://birgermoell.github.io/open-medical-scribe/)

Ideal for clinicians who want AI-assisted documentation without sending patient data to the cloud, healthtech developers building documentation tools, and researchers exploring medical NLP pipelines.

### 🏥 EIR Provider Directory

**Location**: [`apps/eir-provider-directory/`](apps/eir-provider-directory/)

Production-grade healthcare provider discovery app for Sweden with map + list browsing, verified service capabilities, and Cloudflare-native data infrastructure.

**Key Features:**

- **Nationwide provider search** with map and list views
- **Verified self-referral data** from 1177 clinic pages
- **Detailed care metadata** including e-services and action capabilities
- **Location-aware discovery** with "My position" centering and nearby filtering
- **Digital-only clinic support** separated from physical-address listings
- **Cloudflare deployment** with D1 (query layer) + R2 (snapshot storage) + Workers Assets
- **Automated enrichment pipeline** for keeping provider capabilities current

Built to support care discovery flows in EIR products and as a standalone public care-finder foundation for future multi-country expansion.

## GitHub Pages

The documentation is built with [Astro](https://astro.build/) using [Starlight](https://starlight.astro.build/) and [shadcn/ui](https://ui.shadcn.com/) styling, deployed via GitHub Actions.

**🌐 https://eir-space.github.io/eir-open/**

### Deployment

The site deploys automatically when you push to `main` or `cursor/root-docs-consolidation-3cc0`. To enable:

1. Go to **Settings** → **Pages**
2. Under **Source**, choose **GitHub Actions**
3. The workflow in `.github/workflows/deploy-docs.yml` will build and deploy on each push

### Local development

```bash
cd site
pnpm install
pnpm dev
```

Then open http://localhost:4321/eir-open/
