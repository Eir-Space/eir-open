---
title: "🇺🇸 US FDA Medications"
---

Comprehensive US FDA medication lookup with 81,212 medications. 99 curated common medications for instant access, drug interaction checking, CLI and JavaScript API.

**Perfect for:** US healthcare apps, drug interaction checkers, medical AI assistants.

## Quick Start

```bash
npm install -g us-medications
us-medications "lisinopril"
us-medications --search "blood pressure"
us-medications --interactions "warfarin"
```

## Database Statistics

- **81,212** total medications
- **99** curated (instant access)
- **FDA** data source

## Usage

### Command Line

```bash
us-medications "lisinopril"
us-medications --search "blood pressure"
us-medications --interactions "warfarin"
us-medications --stats
```

### JavaScript API

```javascript
const { lookupMedication, searchMedications } = require('us-medications');
const med = await lookupMedication('metformin');
```

## Links

- [GitHub Repository](https://github.com/BirgerMoell/us-medications)
- [npm Package](https://www.npmjs.com/package/us-medications)
- [Skill file (OpenClaw)](/eir-open/projects/us-medications/skill.md)
