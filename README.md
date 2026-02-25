# eir-open

Open Source Eir Space code — focused on AI for empowering people in their health journey.

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

## GitHub Pages

The documentation is built with [Hugo](https://gohugo.io/) using the [Geekdoc](https://github.com/thegeeklab/hugo-geekdoc) theme and deployed via GitHub Actions.

**🌐 https://eir-space.github.io/eir-open/**

### Deployment

The site deploys automatically when you push to `main` or `cursor/root-docs-consolidation-3cc0`. To enable:

1. Go to **Settings** → **Pages**
2. Under **Source**, choose **GitHub Actions**
3. The workflow in `.github/workflows/hugo.yml` will build and deploy on each push

### Local development

```bash
cd hugo
hugo server
```

Then open http://localhost:1313/eir-open/
