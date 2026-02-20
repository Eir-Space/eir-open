# US Medications Skill

Look up US FDA medication information including uses, warnings, and drug interactions.

## Data Source

- **FDA Drug Labels**: Official medication information from the US Food and Drug Administration
- **81,212 medications** in the full database
- **100 curated** common medications with instant access (no download needed)

## Usage

### Command Line

```bash
# Look up a medication (uses curated data, falls back to full database)
us-medications "lisinopril"

# Search for medications (partial match)
us-medications --search "blood pressure"

# Look up drug interactions
us-medications --interactions "warfarin"

# Show database statistics
us-medications --stats

# Download full database (happens automatically on first full lookup)
us-medications --download

# List common curated medications
us-medications --list

# Help
us-medications --help
```

### JavaScript API

```javascript
const { 
  lookupMedication, 
  searchMedications,
  lookupInteractions,
  downloadDatabase,
  getDatabaseStats,
  CURATED_MEDICATIONS 
} = require('us-medications');

// Look up a specific medication
const med = await lookupMedication('metformin');
console.log(med.uses, med.warnings);

// Search for medications
const results = await searchMedications('diabetes');
results.forEach(m => console.log(m.name));

// Get drug interactions
const interactions = await lookupInteractions('lisinopril');

// Check if full database is available
const stats = await getDatabaseStats();
console.log(`${stats.totalMedications} medications available`);
```

## Installation

### npm (recommended)

```bash
npm install -g us-medications
```

The full database (~7.5MB compressed) downloads automatically on first use.

### URL-based (OpenClaw)

```
https://birgermoell.github.io/us-medications/skill.md
```

## Output Format

Each medication includes:
- **name**: Brand/generic name
- **altNames**: Alternative names
- **substances**: Active ingredients
- **form**: Dosage form (oral, injection, etc.)
- **rx**: Prescription required (true/false)
- **uses**: FDA-approved indications
- **warnings**: Safety information and contraindications
- **interactions**: Drug-drug interactions (when available)

## Data Management

The full database is stored in `~/.us-medications/`:
- `medications.json` - Main medication database
- `interactions.json` - Drug interaction data

To refresh data:
```bash
us-medications --download --force
```

## Common Medication Categories

### Cardiovascular
- Lisinopril, Metoprolol, Amlodipine, Losartan, Atorvastatin

### Diabetes
- Metformin, Insulin (various), Glipizide, Januvia

### Pain/Inflammation
- Ibuprofen, Acetaminophen, Naproxen, Tramadol

### Mental Health
- Sertraline, Escitalopram, Alprazolam, Trazodone

### Antibiotics
- Amoxicillin, Azithromycin, Ciprofloxacin, Doxycycline

## Disclaimer

This tool provides FDA label information for educational purposes. **Always consult a healthcare professional** for medical advice. Do not use this tool for self-diagnosis or treatment decisions.
