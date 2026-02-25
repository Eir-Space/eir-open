---
title: "🇸🇪 Swedish Medications"
---

A comprehensive medication lookup tool for Swedish pharmaceuticals based on the FASS database. 9,064 medications with brand-to-substance mapping, dosages, side effects, and OTC status.

**Perfect for:** AI agents, healthcare apps, OpenClaw skills, Swedish market applications.

## Quick Start

```bash
npm install -g swedish-medications
fass-lookup paracetamol
fass-lookup Alvedon
```

## Features

- **9,064 medications** — Complete Swedish pharmaceutical database
- **Smart search** — By brand name, substance, or partial match
- **Rich details** — Dosage, warnings, OTC status, ATC codes
- **AI-agent ready** — OpenClaw, LangChain, and custom agent frameworks

## API Reference

- `lookupMedication(query)` — Formatted markdown with medication info
- `findMedication(query)` — Raw medication data object
- `searchMedications(query, limit?)` — Multiple matching medications
- `getDatabaseStats()` — Database statistics

## Links

- [View on npm](https://www.npmjs.com/package/swedish-medications)
- [GitHub Repository](https://github.com/BirgerMoell/swedish-medications)
- [Skill file (OpenClaw)](/eir-open/projects/swedish-medications/skill.md)
