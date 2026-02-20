# EIR Format - Open Standard for LLM-Optimized Healthcare Data

<img src="assets/logo.svg" alt="EIR Format Logo" width="400">

[![GitHub](https://img.shields.io/badge/GitHub-eir--format--standard-blue?logo=github)](https://github.com/BirgerMoell/health-md-standard)
[![Website](https://img.shields.io/badge/Website-Live-green)](https://birgermoell.github.io/health-md-standard/)
[![License](https://img.shields.io/badge/License-MIT-yellow)](LICENSE)
[![MCP](https://img.shields.io/badge/MCP-Compatible-purple)](mcp-server/)

**Version 1.0** | [Website](https://birgermoell.github.io/health-md-standard/) | [Specification](EIR-SPEC.md) | [Examples](examples/) | [MCP Server](mcp-server/)

*Named after Eir, the Norse goddess of healing and medicine*

## 🎯 Mission

Healthcare data is complex, sensitive, and crucial. **EIR Format** defines an open YAML-based standard for structuring healthcare information optimized for Large Language Models while preserving privacy, accuracy, and clinical context.

## 🚀 Why Health.md?

- **LLM-Optimized:** Structured for perfect AI comprehension and reasoning
- **Privacy-First:** Built-in anonymization and data protection patterns
- **Clinical-Accurate:** Preserves medical context and relationships
- **Human-Readable:** Markdown format that clinicians and patients can read
- **Interoperable:** Works across systems, platforms, and use cases

## 📋 Quick Example

```markdown
# Health Record - Anonymous Patient 001

## Demographics
- Age: 34
- Sex: Female  
- Occupation: Software Engineer

## Current Medications
### Metformin 500mg
- **Indication:** Type 2 Diabetes Mellitus
- **Dosage:** 500mg twice daily with meals
- **Started:** 2024-01-15
- **Prescriber:** Dr. Smith (Endocrinology)
- **Notes:** Well tolerated, no gastrointestinal issues

## Lab Results
### Hemoglobin A1C
- **Date:** 2024-02-10
- **Value:** 6.8%
- **Reference:** <7.0% (target for diabetes)
- **Trend:** ↓ from 8.2% (2023-12-01)
- **Clinical Significance:** Improving glycemic control

## Clinical Timeline
### 2024-01-15: Initial Diabetes Diagnosis
- **HbA1c:** 8.2%
- **Fasting Glucose:** 180 mg/dL  
- **Action:** Started Metformin 500mg BID
- **Goals:** HbA1c <7%, weight loss 5-10%
```

## 🛠️ Features

- **Semantic Structure:** Clear sections for demographics, medications, labs, timeline
- **Temporal Context:** Built-in date tracking and trend analysis
- **Clinical Relationships:** Links between conditions, medications, and outcomes
- **Privacy Controls:** Anonymization patterns and data sensitivity markers
- **Validation:** Schema validation and clinical accuracy checks
- **LLM Integration:** Parser library for seamless AI integration

## 📖 Specification

The complete specification is available in [SPEC.md](SPEC.md). Key sections include:

- [File Structure](SPEC.md#file-structure)
- [Required Sections](SPEC.md#required-sections)  
- [Optional Extensions](SPEC.md#optional-extensions)
- [Privacy Guidelines](SPEC.md#privacy-guidelines)
- [Validation Rules](SPEC.md#validation-rules)

## 🔧 Parser & Tools

```python
pip install health-md

from health_md import HealthRecord

# Parse a health.md file
record = HealthRecord.from_file('patient-001.health.md')

# Extract key information
medications = record.get_current_medications()
recent_labs = record.get_labs(days=30)
timeline = record.get_clinical_timeline()

# Generate LLM-optimized summary
summary = record.to_llm_context()
```

## 🌍 Use Cases

- **Clinical Decision Support:** Structured data for AI diagnostic tools
- **Patient Portals:** Human-readable health records
- **Research:** Standardized datasets for health AI training  
- **Health Apps:** Interoperable data format across platforms
- **Telemedicine:** Efficient information sharing between providers

## 🤝 Contributing

We welcome contributions from:
- **Clinicians:** Medical accuracy and workflow insights
- **Developers:** Parser improvements and tooling
- **Researchers:** Validation studies and use cases
- **Patients:** Usability feedback and privacy requirements

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## 📊 Adoption

Organizations using Health.md:

- [EIR Space](https://eir.space/) - Health literacy platform
- *Your organization here - submit a PR!*

## 📄 License

MIT License - See [LICENSE](LICENSE)

## 🏆 Team

**Created by:**
- [Birger Moëll](https://github.com/BirgerMoell) - AI/NLP Researcher, Clinical Psychologist
- Uppsala University, Department of Linguistics and Philology

**Special Thanks:**
- Healthcare professionals who provided clinical input
- Privacy advocates who shaped our anonymization guidelines
- LLM researchers who validated our structured approach

---

*Healthcare data deserves better standards. Let's build them together.* 🏥💙