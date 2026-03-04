# Health.md Specification v1.1 (Draft)

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
health_md_version: "1.1"
record_id: "anonymous-001"
generated: "2024-02-17T10:00:00Z"
privacy_level: "anonymous"  # anonymous, pseudonymized, identified
last_updated: "2024-02-17T10:00:00Z"
data_sources: ["epic", "manual_entry"]
# Optional agent interoperability fields
agent_compatible: true
provenance_policy: "required_for_agent_added_facts"
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

### 9. Active Health Contexts (Agent-Facing)
Use this section for conditions or states that should influence how an agent responds right now, including non-disease contexts such as pregnancy or breastfeeding.

```markdown
## Active Health Contexts

### Pregnancy
- **Status:** Active
- **Type:** Physiologic state
- **Source:** user_reported
- **Confidence:** High
- **Last Confirmed:** 2026-02-26
- **Notes:** Use pregnancy-safe guidance and medication caution checks

### Type 2 Diabetes Mellitus
- **Status:** Active
- **Type:** Chronic condition
- **Source:** ehr_export
- **Confidence:** High
- **Last Confirmed:** 2024-02-10
```

**Recommended values:**
- `Status:` `active`, `resolved`, `unknown`
- `Source:` `user_reported`, `ehr`, `ehr_export`, `journal_inferred`, `clinician_verified`, `manual_entry`
- `Confidence:` `low`, `medium`, `high`

### 10. Unconfirmed Findings (Agent Safety)
Use this section for inferred findings from journals, chat, or uploads that require confirmation before being treated as confirmed conditions or contexts.

```markdown
## Unconfirmed Findings

### Possible Pregnancy (journal mention, 2026-02-26)
- **Type:** Potential health context
- **Source:** journal_inferred
- **Confidence:** Medium
- **Evidence:** "Missed period and positive home test" in journal entry
- **Action Needed:** Confirm with user before adding to Active Health Contexts
- **Do Not Treat As Confirmed:** Yes
```

### 11. Skill Attachments (Agent Interoperability)
Use this section to track which health skills are suggested or active for this record so any compatible agent can load the same context and behavior.

```markdown
## Skill Attachments

### health
- **Status:** Active
- **Reason:** Base health record management and follow-up questions
- **Added By:** user
- **Last Reviewed:** 2026-02-26

### diabetes
- **Status:** Active
- **Reason:** Active Type 2 Diabetes Mellitus in Medical History
- **Added By:** agent
- **Last Reviewed:** 2026-02-26

### pregnancy
- **Status:** Suggested
- **Reason:** Unconfirmed finding indicates possible pregnancy
- **Added By:** agent
```

**Recommended values:**
- `Status:` `suggested`, `active`, `disabled`
- `Added By:` `user`, `agent`, `clinician`, `system`

### 12. Linked Health Files (Condition/Event Records)
Use this section to list focused companion files for specific conditions or health events (for example `pregnancy.md`, `diabetes.md`). This keeps `health.md` as the master index while allowing richer condition-specific tracking in separate files.

```markdown
## Linked Health Files

### pregnancy.md
- **Type:** Condition/Event record
- **Skill:** pregnancy
- **Status:** Active
- **Reason:** Active pregnancy context with trimester-specific follow-up
- **Created:** 2026-02-26
- **Last Updated:** 2026-02-26

### diabetes.md
- **Type:** Condition/Event record
- **Skill:** diabetes
- **Status:** Active
- **Reason:** Detailed glucose tracking and diabetes-specific goals
- **Created:** 2026-02-26
- **Last Updated:** 2026-02-26
```

**Naming convention (recommended):**
- Use simple canonical skill-aligned filenames: `pregnancy.md`, `diabetes.md`, `ms.md`
- For multiple concurrent records of the same type, append a disambiguator: `pregnancy-2026.md`, `cancer-breast.md`

**Recommended values:**
- `Status:` `active`, `archived`, `planned`

### 13. Active Programs (Optional)
Use this section for structured monitoring or coaching workflows linked to a condition skill.

```markdown
## Active Programs

### diabetes-monitoring
- **Status:** Active
- **Linked Skill:** diabetes
- **Inputs Requested:** Glucose readings, meals, symptoms, medication adherence
- **Frequency:** Up to 5x/day (user-configurable)
- **Started:** 2026-02-26
- **Safety Notes:** Escalate urgent symptoms or severe hypo/hyperglycemia concerns to emergency care guidance
```

### 14. Information Gaps & Follow-up Questions (Agent Workflow)
Use this section to persist unanswered questions so agents can continue collecting missing health information over time.

```markdown
## Information Gaps & Follow-up Questions

### Diabetes Monitoring Baseline
- **Question:** Does the patient currently check glucose at home?
- **Why It Matters:** Determines whether a monitoring program should be suggested
- **Status:** Open
- **Created By:** agent
- **Created:** 2026-02-26

### Pregnancy Confirmation
- **Question:** Has a clinician confirmed the pregnancy?
- **Why It Matters:** Determines whether to move pregnancy from Unconfirmed Findings to Active Health Contexts
- **Status:** Open
- **Created By:** agent
```

**Recommended values:**
- `Status:` `open`, `answered`, `deferred`

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

### Provenance and Confidence (Recommended for Agent-Added Data)
- **Source values:** `user_reported`, `ehr`, `ehr_export`, `journal_inferred`, `manual_entry`, `clinician_verified`
- **Confidence values:** `low`, `medium`, `high`
- **Confirmation rule:** Inferred findings should be stored in `Unconfirmed Findings` until user or clinician confirmation

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

### Agent Interoperability Validation (Recommended)
1. **Agent-added facts include provenance:** Any new condition/context added by an agent should include `Source`
2. **Inferred findings are not silently promoted:** `journal_inferred` findings should remain unconfirmed until confirmed
3. **Skill names are simple and portable:** Prefer canonical names like `health`, `pregnancy`, `diabetes`
4. **Follow-up questions are explicit:** Missing critical information should be captured in `Information Gaps & Follow-up Questions`
5. **Linked files are indexed in `health.md`:** Condition/event files (for example `pregnancy.md`) should be listed in `Linked Health Files`

## Agent Interoperability Profile (`health` Skill)

The `health.md` format is designed to support a portable `health` skill that can be used across agents.

### Expected `health` Skill Behavior
1. **Read and update `health.md`:** Use the file as the source of truth for longitudinal health context
2. **Ask follow-up questions:** When key information is missing, ask the user and store open questions in `Information Gaps & Follow-up Questions`
3. **Store provenance:** Mark whether information came from user report, EHR export, journal inference, or clinician verification
4. **Separate inferred from confirmed facts:** Store uncertain findings in `Unconfirmed Findings` until confirmed
5. **Attach relevant health skills:** Use `Skill Attachments` to record suggested/active skills like `pregnancy` or `diabetes`
6. **Maintain linked condition/event files:** Record focused files like `pregnancy.md` in `Linked Health Files` when created
7. **Activate optional programs:** Use `Active Programs` for monitoring workflows only when relevant and user-approved

### Canonical Skill Naming (Recommended)
- Base skill: `health`
- Condition/context skills: `pregnancy`, `diabetes`, `ms`, `hypertension`
- Discovery skill: `health-skill-finder`

### Condition/Event File Pattern (Recommended)
- `health.md` is the master record and index
- Condition/event skills may create focused companion files (for example `pregnancy.md`)
- The focused file stores detailed tracking and condition-specific notes
- `health.md` must list those files in `Linked Health Files`

### Agent Prompting Guidance (Recommended)
- Prefer asking short, high-value clarifying questions before writing uncertain diagnoses
- Confirm sensitive or high-impact facts (pregnancy, cancer, acute diagnoses, medication changes) before marking as confirmed
- Preserve user wording in notes when useful, but normalize key facts into structured bullets
- Update `last_updated` when the file changes

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

- **v1.1 (Draft):** Added agent interoperability sections (`Active Health Contexts`, `Unconfirmed Findings`, `Skill Attachments`, `Linked Health Files`, `Active Programs`, `Information Gaps & Follow-up Questions`) and `health` skill profile
- **v1.0 (2024-02-17):** Initial specification release
- **v0.9 (2024-02-10):** Beta release for community feedback
- **v0.5 (2024-01-15):** Alpha specification draft

---

**Specification Maintained By:** [Birger Moëll](https://github.com/BirgerMoell), Uppsala University  
**Last Updated:** 2026-02-26  
**License:** MIT
