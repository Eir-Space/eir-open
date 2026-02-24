# US Medications Skill

Look up US FDA medication information including uses, warnings, and drug interactions.

## Data Source

- **FDA Drug Labels**: Official medication information from the US Food and Drug Administration
- **81,212 medications** in the full database
- **99 curated** common medications with instant access (no download needed)

## Usage

### Command Line

```bash
# Look up a medication
us-medications "lisinopril"

# Search for medications
us-medications --search "blood pressure"

# Look up drug interactions
us-medications --interactions "warfarin"

# Show database statistics
us-medications --stats
```

### JavaScript API

```javascript
const { lookupMedication, searchMedications } = require('us-medications');

const med = await lookupMedication('metformin');
console.log(med.uses, med.warnings);
```

## Installation

```bash
npm install -g us-medications
```

## Disclaimer

This tool provides FDA label information for educational purposes. Always consult a healthcare professional for medical advice.
