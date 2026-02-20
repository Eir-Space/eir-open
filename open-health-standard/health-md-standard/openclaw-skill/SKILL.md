---
name: health-md-parser
description: Parse and work with Health.md files - the open standard for LLM-optimized healthcare data. Extract patient information, generate summaries, and analyze healthcare records while preserving privacy.
---

# Health.md Parser Skill

Parse and analyze Health.md files - the open standard for LLM-optimized healthcare data.

## What This Skill Does

- **Parse Health.md files** into structured data
- **Extract key information** (medications, lab results, conditions)
- **Generate LLM-optimized summaries** for AI analysis
- **Validate file format** and clinical data
- **Anonymize sensitive information** based on privacy levels
- **Create patient timelines** and clinical insights

## Setup

### Install Dependencies
```bash
pip install health-md pyyaml beautifulsoup4
```

### Usage Examples

```bash
# Parse a health.md file
python scripts/parse_health.py patient-001.health.md

# Generate LLM summary
python scripts/parse_health.py patient-001.health.md --summary

# Extract specific information
python scripts/parse_health.py patient-001.health.md --medications --labs

# Validate file format
python scripts/parse_health.py patient-001.health.md --validate

# Anonymize a record
python scripts/parse_health.py patient-001.health.md --anonymize
```

## OpenClaw Integration

This skill integrates seamlessly with OpenClaw agents:

```python
# In your OpenClaw agent
from skills.health_md_parser.scripts.parse_health import HealthMdParser

# Parse a health record
parser = HealthMdParser("patient.health.md")
record = parser.parse()

# Generate AI-optimized context
context = record.to_llm_context()

# Use in agent conversation
response = agent.process(f"""
Patient context: {context}

Question: What are the key health concerns for this patient?
""")
```

## Clinical Use Cases

### **1. Clinical Decision Support**
```python
# Extract current medications and conditions
medications = record.get_current_medications()
conditions = record.get_conditions()

# Check for drug interactions or contraindications
analysis = analyze_clinical_context(medications, conditions)
```

### **2. Patient Education**
```python
# Generate patient-friendly summaries
summary = record.to_patient_summary()

# Create educational content based on conditions
education = generate_patient_education(record.get_conditions())
```

### **3. Research & Analytics**
```python
# Extract de-identified data for research
if record.get_privacy_level() == 'anonymous':
    research_data = record.to_research_dataset()
```

## Privacy & Security

This skill respects Health.md privacy levels:

- **Anonymous**: No identifiable information processed
- **Pseudonymized**: Consistent fake identifiers maintained  
- **Identified**: Full access (requires appropriate permissions)

All processing follows HIPAA/GDPR principles and the Health.md privacy specification.

## File Format Support

Supports all Health.md specification features:

- ✅ **Demographics** with privacy-aware handling
- ✅ **Current Medications** with clinical context
- ✅ **Lab Results** with trend analysis
- ✅ **Medical History** with ICD coding
- ✅ **Clinical Timeline** with provider context
- ✅ **Vital Signs** with temporal tracking
- ✅ **Allergies & Intolerances** 
- ✅ **Care Team** information

## Examples

The `examples/` directory contains sample Health.md files:

- `anonymous-diabetes-patient.health.md` - Comprehensive diabetes case
- `cardiac-patient.health.md` - Cardiovascular conditions
- `mental-health-patient.health.md` - Mental health considerations
- `pediatric-patient.health.md` - Pediatric healthcare data

## Integration with EIR Space

This skill is designed to work with [EIR Space](https://eir.space/) health literacy platform:

```python
# Convert Health.md to EIR-compatible format
eir_data = record.to_eir_format()

# Generate health literacy explanations
explanations = generate_health_explanations(record)
```

## Error Handling

Robust error handling for clinical data:

```python
try:
    record = HealthRecord.from_file('patient.health.md')
except HealthMdValidationError as e:
    # Handle validation errors (missing sections, invalid dates, etc.)
    print(f"Validation error: {e}")
except HealthMdPrivacyError as e:  
    # Handle privacy violations
    print(f"Privacy error: {e}")
```

## Advanced Features

### **Clinical Reasoning**
```python
# Generate clinical insights
insights = record.generate_clinical_insights()
# Returns: medication adherence, lab trends, care gaps, etc.
```

### **Timeline Analysis** 
```python
# Analyze patient journey over time
timeline = record.get_clinical_timeline(days=365)
events = analyze_clinical_progression(timeline)
```

### **Risk Assessment**
```python
# Calculate health risks based on available data
risks = calculate_health_risks(record)
# Returns: diabetes complications, cardiovascular risk, etc.
```

## Contributing

This skill is part of the open-source Health.md standard. Contributions welcome:

- **Clinical validation** - Review medical accuracy
- **Parser improvements** - Handle edge cases better
- **New features** - Additional analysis capabilities
- **Privacy enhancements** - Stronger anonymization

See [CONTRIBUTING.md](../CONTRIBUTING.md) in the main repository.

---

**Healthcare data deserves better standards. This skill helps make it reality.** 🏥💙