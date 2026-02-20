# US FDA Medication Lookup 🇺🇸💊

Look up US FDA medication information including uses, warnings, and drug interactions.

[![npm version](https://badge.fury.io/js/us-medications.svg)](https://www.npmjs.com/package/us-medications)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

## Features

- **81,212 FDA medications** in the full database
- **99 curated** common medications with instant access (no download needed)
- **Drug interactions** lookup
- **CLI and JavaScript API**
- **OpenClaw skill** compatible

## Installation

```bash
npm install -g us-medications
```

The full database (~45MB compressed) downloads automatically on first use.

## Quick Start

### CLI

```bash
# Look up a medication
us-medications "lisinopril"

# Search for medications
us-medications --search "blood pressure"

# Look up drug interactions
us-medications --interactions "warfarin"

# Show database statistics
us-medications --stats

# List curated medications
us-medications --list
```

### JavaScript API

```javascript
const { 
  lookupMedication, 
  searchMedications,
  lookupInteractions,
  getDatabaseStats 
} = require('us-medications');

// Look up a specific medication
const med = await lookupMedication('metformin');
console.log(med.uses, med.warnings);

// Search for medications
const results = await searchMedications('diabetes');
results.forEach(m => console.log(m.name));

// Get drug interactions
const interactions = await lookupInteractions('lisinopril');
```

## Data Source

All medication data comes from the **US Food and Drug Administration (FDA)** drug labels database.

## Output Fields

Each medication includes:
- `name` - Brand/generic name
- `altNames` - Alternative names
- `substances` - Active ingredients
- `form` - Dosage form (oral, injection, etc.)
- `rx` - Prescription required (true/false)
- `uses` - FDA-approved indications
- `warnings` - Safety information and contraindications
- `interactions` - Drug-drug interactions (when available)

## OpenClaw Skill

Install as an OpenClaw skill:

```bash
# From npm
openclaw skill add us-medications

# Or from URL
openclaw skill add https://birgermoell.github.io/us-medications/skill.md
```

## Database Management

```bash
# Download full database
us-medications --download

# Force re-download
us-medications --download --force

# Check status
us-medications --stats
```

Data is stored in `~/.us-medications/`.

## Disclaimer

⚠️ This tool provides FDA label information for **educational purposes only**. **Always consult a healthcare professional** for medical advice. Do not use this tool for self-diagnosis or treatment decisions.

## Related Projects

- [swedish-medications](https://github.com/BirgerMoell/swedish-medications) - Swedish FASS medication lookup

## License

MIT © Birger Moëll

## Contributing

Issues and PRs welcome at [GitHub](https://github.com/BirgerMoell/us-medications).
