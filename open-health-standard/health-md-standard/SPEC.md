# Health.md Specification v1.0

## Overview

Health.md is a markdown-based format for structuring healthcare data that optimizes for:
1. **LLM Comprehension** - Clear semantic structure for AI processing
2. **Human Readability** - Clinicians and patients can read/edit directly  
3. **Privacy Preservation** - Built-in anonymization and security patterns
4. **Clinical Accuracy** - Preserves medical context and relationships

## File Structure

### Basic Format
```
patient-id.health.md
anonymous-001.health.md  
john-doe-2024.health.md
```

### Required YAML Frontmatter
```yaml
---
health_md_version: "1.0"
record_id: "anonymous-001"
generated: "2024-02-17T10:00:00Z"
privacy_level: "anonymous"  # anonymous, pseudonymized, identified
last_updated: "2024-02-17T10:00:00Z"
data_sources: ["epic", "manual_entry"]
---
```

## Required Sections

### 1. Demographics
Basic patient information required for clinical context.

```markdown
## Demographics
- **Age:** 34 (or Age Range: 30-39 for privacy)
- **Sex:** Female
- **Gender Identity:** Female (optional, if different from sex)
- **Occupation:** Software Engineer (or Category: Technology)
- **Location:** Stockholm, Sweden (or Region: Northern Europe)
```

**Privacy Levels:**
- `anonymous`: Age ranges, occupation categories, broad regions
- `pseudonymized`: Exact age, specific occupation, city-level location  
- `identified`: Full demographics with real identifiers

### 2. Current Medications
Active medications with clinical context.

```markdown
## Current Medications

### Metformin 500mg
- **Generic Name:** Metformin Hydrochloride
- **Brand Names:** Glucophage, Fortamet
- **Indication:** Type 2 Diabetes Mellitus (ICD-10: E11)
- **Dosage:** 500mg twice daily with meals
- **Route:** Oral
- **Started:** 2024-01-15
- **Prescriber:** Dr. Smith, Endocrinology
- **Pharmacy:** Apoteket (Stockholm)
- **Insurance Coverage:** 85% covered
- **Side Effects:** None reported
- **Adherence:** Good (90%+ compliance)
- **Clinical Notes:** Well tolerated, no GI issues

### Lisinopril 10mg  
- **Generic Name:** Lisinopril
- **Indication:** Hypertension (ICD-10: I10)
- **Dosage:** 10mg once daily
- **Started:** 2023-08-10
- **Clinical Notes:** Good BP control, monitoring K+ levels
```

### 3. Medical History
Chronological record of significant medical events.

```markdown
## Medical History

### Type 2 Diabetes Mellitus (2024-01-15)
- **ICD-10:** E11.9
- **Onset:** January 2024
- **Presentation:** Polyuria, polydipsia, fatigue
- **Diagnostic Criteria:** HbA1c 8.2%, Fasting glucose 180 mg/dL
- **Risk Factors:** Family history, obesity (BMI 32)
- **Treatment Response:** Good, HbA1c improved to 6.8%

### Hypertension (2023-08-10)
- **ICD-10:** I10
- **Onset:** August 2023
- **Presentation:** Elevated BP on routine screening
- **Highest Reading:** 158/96 mmHg
- **Current Status:** Well controlled (average 128/78)
```

### 4. Lab Results
Laboratory data with temporal context and clinical significance.

```markdown
## Lab Results

### Hemoglobin A1C
- **2024-02-10:** 6.8% (↓ from 8.2%)
- **Reference Range:** <7.0% (ADA target for diabetes)
- **Clinical Significance:** Excellent improvement in glycemic control
- **Trend:** Decreasing (8.2% → 7.4% → 6.8%)
- **Next Due:** 2024-05-10

### Basic Metabolic Panel (2024-02-10)
- **Glucose:** 125 mg/dL (Ref: 70-100, ↓ from 180)
- **Creatinine:** 0.9 mg/dL (Ref: 0.6-1.2, stable)
- **eGFR:** >60 mL/min/1.73m² (Normal)
- **Potassium:** 4.2 mEq/L (Ref: 3.5-5.0)
- **Clinical Notes:** Monitoring for metformin/ACE inhibitor effects

### Lipid Panel (2024-01-15)
- **Total Cholesterol:** 198 mg/dL (Ref: <200)
- **LDL:** 128 mg/dL (Ref: <100, elevated)
- **HDL:** 45 mg/dL (Ref: >40 male, >50 female)  
- **Triglycerides:** 156 mg/dL (Ref: <150)
- **Clinical Plan:** Recheck in 3 months, consider statin if LDL remains >100
```

## Optional Sections

### 5. Allergies and Intolerances
```markdown
## Allergies & Intolerances

### Drug Allergies
- **Penicillin:** Severe (anaphylaxis) - documented 2010
- **Codeine:** Moderate (nausea, vomiting)

### Environmental Allergies  
- **Pollen:** Seasonal rhinitis (Spring/Summer)
- **Shellfish:** Mild (oral itching)

### Food Intolerances
- **Lactose:** Moderate (bloating, diarrhea)
```

### 6. Vital Signs
```markdown
## Vital Signs

### Blood Pressure (2024-02-10)
- **Reading:** 128/78 mmHg
- **Position:** Seated
- **Arm:** Left
- **Cuff Size:** Standard adult
- **Trend:** Improved from 158/96 (2023-08-10)

### Anthropometrics (2024-02-10)
- **Weight:** 78 kg (↓ from 85 kg)
- **Height:** 165 cm  
- **BMI:** 28.7 (↓ from 31.2, target <25)
- **Waist Circumference:** 92 cm (↓ from 98 cm)
```

### 7. Clinical Timeline
```markdown
## Clinical Timeline

### 2024-02-10: Diabetes Follow-up
- **Provider:** Dr. Smith (Endocrinology)
- **Chief Complaint:** Routine diabetes management
- **Assessment:** Excellent glycemic control, continue current therapy
- **Plan:** 
  - Continue Metformin 500mg BID
  - Recheck HbA1c in 3 months
  - Nutrition counseling referral
- **Next Appointment:** 2024-05-10

### 2024-01-15: Initial Diabetes Diagnosis  
- **Provider:** Dr. Johnson (Family Medicine)
- **Chief Complaint:** Increased thirst, frequent urination
- **Labs:** HbA1c 8.2%, Fasting glucose 180 mg/dL
- **Assessment:** Type 2 Diabetes Mellitus, newly diagnosed
- **Plan:**
  - Start Metformin 500mg BID
  - Diabetes education class
  - Endocrinology referral
  - Lifestyle modifications (diet, exercise)
```

### 8. Care Team
```markdown
## Care Team

### Primary Care
- **Dr. Sarah Johnson, MD** - Family Medicine
- **Practice:** Stockholm Family Health Center  
- **Contact:** +46-8-123-4567
- **Relationship:** Primary Care Provider (2020-present)

### Specialists
- **Dr. Michael Smith, MD** - Endocrinology
- **Practice:** Karolinska Diabetes Center
- **Contact:** +46-8-987-6543  
- **Relationship:** Diabetes management (2024-present)

### Pharmacy
- **Apoteket Centralstation**
- **Pharmacist:** Anna Lindberg, PharmD
- **Contact:** +46-8-555-0123
```

## Data Types and Formats

### Dates
- **ISO 8601 format:** `2024-02-17` or `2024-02-17T10:00:00Z`
- **Partial dates:** `2024-02` (month precision), `2024` (year precision)

### Measurements
- **Include units:** `500mg`, `10 mL/min`, `78 kg`
- **Reference ranges:** `(Ref: 70-100)` or `(Normal: <7.0%)`
- **Trends:** `↑`, `↓`, `→`, `stable`, `improving`, `worsening`

### Clinical Codes
- **ICD-10:** `E11.9` (Type 2 diabetes)
- **SNOMED CT:** `44054006` (Type 2 diabetes)  
- **LOINC:** `4548-4` (Hemoglobin A1c)
- **RxNorm:** `6809` (Metformin)

### Identifiers
- **Record ID:** Unique identifier for the health record
- **Provider NPI:** National Provider Identifier (US) or equivalent
- **Facility ID:** Clinic/hospital identifier

## Privacy Guidelines

### Anonymization Levels

#### Anonymous (`privacy_level: anonymous`)
- **Demographics:** Age ranges, occupation categories, regions
- **Identifiers:** Removed or replaced with anonymous IDs
- **Dates:** Year only or relative dates ("6 months ago")
- **Providers:** Role only ("Endocrinologist")
- **Use Case:** Research, training data, public examples

#### Pseudonymized (`privacy_level: pseudonymized`)
- **Demographics:** Exact age, specific occupation, city
- **Identifiers:** Consistent pseudonyms across records
- **Dates:** Full dates preserved
- **Providers:** Named but pseudonymized
- **Use Case:** Clinical research with IRB approval

#### Identified (`privacy_level: identified`)  
- **Demographics:** Complete real information
- **Identifiers:** Real names, SSNs, MRNs as appropriate
- **Dates:** Full precision
- **Providers:** Real names and contact information
- **Use Case:** Clinical care, patient-controlled sharing

### Sensitive Data Markers
```markdown
## Mental Health History
<!-- SENSITIVE: Mental health information -->
### Major Depressive Disorder (2022-03-15)  
<!-- END SENSITIVE -->

## Substance Use History
<!-- SENSITIVE: Substance use -->
- **Alcohol:** Social use, 2-3 drinks/week
- **Tobacco:** Former smoker, quit 2020
- **Illicit Drugs:** None reported
<!-- END SENSITIVE -->
```

## Validation Rules

### File Structure Validation
1. **YAML Frontmatter:** Must be valid YAML with required fields
2. **Section Headers:** Must use proper markdown heading levels
3. **Required Sections:** Demographics, Current Medications must be present
4. **Date Formats:** Must follow ISO 8601 or specified alternatives

### Clinical Validation
1. **Drug Names:** Must match standard drug databases (RxNorm, SNOMED)
2. **ICD Codes:** Must be valid ICD-10 or ICD-11 codes
3. **Lab Values:** Should include units and reference ranges
4. **Date Consistency:** Dates should be logically consistent (start < end)

### Privacy Validation
1. **Privacy Level:** Must match actual data anonymization level
2. **Sensitive Markers:** Mental health, substance use should be marked
3. **Identifier Consistency:** Pseudonymized IDs should be consistent

## Extensions and Customizations

### Specialty Extensions
```markdown  
<!-- EXTENSION: cardiology-v1.0 -->
## Cardiac Function
### Echocardiogram (2024-02-15)
- **EF:** 65% (Normal: >55%)
- **Wall Motion:** Normal
- **Valve Function:** Mild mitral regurgitation
<!-- END EXTENSION -->
```

### Device Data
```markdown
## Device Data
### Continuous Glucose Monitor
- **Device:** Freestyle Libre 2
- **Period:** 2024-02-01 to 2024-02-14
- **Average Glucose:** 135 mg/dL
- **Time in Range:** 78% (70-180 mg/dL)
- **Time Below Range:** 2% (<70 mg/dL)
```

### Genomics
```markdown
## Genomic Information  
<!-- SENSITIVE: Genetic data -->
### Pharmacogenomics
- **CYP2D6:** *1/*4 (Intermediate Metabolizer)
- **Clinical Relevance:** May need adjusted dosing for codeine, metoprolol
- **Testing Date:** 2024-01-20
- **Laboratory:** GeneDx
<!-- END SENSITIVE -->
```

## Version History

- **v1.0 (2024-02-17):** Initial specification release
- **v0.9 (2024-02-10):** Beta release for community feedback
- **v0.5 (2024-01-15):** Alpha specification draft

---

**Specification Maintained By:** [Birger Moëll](https://github.com/BirgerMoell), Uppsala University  
**Last Updated:** 2024-02-17  
**License:** MIT