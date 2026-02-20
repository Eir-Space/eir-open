# EIR Format Specification v1.0

**EIR (Electronic health Information Record)** - Open Standard for LLM-Optimized Healthcare Data

*Named after Eir, the Norse goddess of healing and medicine*

## Overview

The EIR format is a YAML-based open standard for structuring healthcare data optimized for:
1. **LLM/AI Processing** - Structured format perfect for AI analysis
2. **Human Readability** - YAML is both machine and human readable
3. **Privacy Preservation** - Built-in anonymization and security patterns
4. **Clinical Accuracy** - Preserves medical context and relationships
5. **Extensibility** - Easy to add new sections and fields

## File Structure

### Basic Format
```
patient-id.eir
anonymous-001.eir  
john-doe-2024.eir
```

### Required Metadata Section
```yaml
metadata:
  format_version: "1.0"
  created_at: "2024-02-17T10:00:00Z"
  source: "epic_ehr"  # Source system
  privacy_level: "anonymous"  # anonymous, pseudonymized, identified
  last_updated: "2024-02-17T10:00:00Z"
  record_id: "anonymous-001"
```

## Core Schema

### Patient Demographics
```yaml
patient:
  # Basic demographics (privacy-aware)
  name: "Anonymous Patient 001"  # Or real name if privacy_level: identified
  age: 34  # Or age_range: "30-39" for anonymous
  sex: "female"
  gender_identity: "female"  # Optional if different from sex
  
  # Contact (privacy-filtered)
  location:
    country: "Sweden"
    region: "Northern Europe"  # For anonymous
    city: "Stockholm"  # For pseudonymized/identified
  
  # Demographics
  occupation:
    category: "Technology"  # For anonymous
    specific: "Software Engineer"  # For identified
  
  # Languages and accessibility
  languages: ["Swedish", "English"]
  accessibility_needs: []  # hearing, vision, mobility, cognitive
```

### Medical History
```yaml
medical_history:
  - condition: "Type 2 Diabetes Mellitus"
    icd_10: "E11.9"
    snomed_ct: "44054006"
    onset_date: "2024-01-15"
    status: "active"  # active, resolved, chronic, acute
    severity: "moderate"
    
    # Clinical context
    presentation:
      - "Polyuria, polydipsia, fatigue"
      - "Unintentional weight loss"
    
    diagnostic_criteria:
      - test: "HbA1c"
        value: "8.2%"
        threshold: ">6.5%"
        result: "diagnostic"
      - test: "Fasting Plasma Glucose"
        value: "180 mg/dL"
        threshold: ">126 mg/dL"  
        result: "diagnostic"
    
    risk_factors:
      - "Family history of diabetes"
      - "Overweight (BMI 31-32)"
      - "Previous gestational diabetes"
    
    complications: []  # None identified to date
    
  - condition: "Essential Hypertension"
    icd_10: "I10"
    onset_date: "2023-08-10"
    status: "active"
    severity: "mild"
    current_status: "well_controlled"
```

### Current Medications
```yaml
current_medications:
  - name: "Metformin"
    generic_name: "Metformin Hydrochloride"
    brand_names: ["Glucophage", "Fortamet"]
    
    # Prescription details
    strength: "500mg"
    dosage: "500mg twice daily"
    route: "oral"
    frequency: "BID"  # twice daily
    timing: "with meals"
    
    # Clinical context
    indication:
      condition: "Type 2 Diabetes Mellitus"
      icd_10: "E11.9"
    
    # Treatment history
    started: "2024-01-15"
    duration_months: 1
    
    # Provider information
    prescriber:
      name: "Dr. Smith"  # Or anonymized based on privacy level
      specialty: "Endocrinology"
      facility: "University Hospital"
    
    # Patient response
    adherence: 
      rate: 90  # percentage
      assessment: "excellent"
    
    side_effects: []  # None reported
    
    clinical_notes: "Well tolerated, no gastrointestinal issues"
    
  - name: "Lisinopril"
    strength: "10mg"
    dosage: "10mg once daily"
    route: "oral"
    frequency: "daily"
    timing: "morning"
    
    indication:
      condition: "Essential Hypertension"
      icd_10: "I10"
    
    started: "2023-08-10"
    duration_months: 6
    
    clinical_response: "Good blood pressure control"
    monitoring: "Electrolyte levels checked regularly"
```

### Lab Results
```yaml
lab_results:
  # Grouped by test type for better organization
  glucose_metabolism:
    - test_name: "Hemoglobin A1C"
      loinc_code: "4548-4"
      
      results:
        - date: "2024-02-10"
          value: 6.8
          unit: "%"
          reference_range: "<7.0"
          status: "target_met"
          trend: "decreasing"
          
        - date: "2024-01-15"
          value: 7.4
          unit: "%"
          reference_range: "<7.0"
          trend: "decreasing"
          
        - date: "2023-12-15"
          value: 8.2
          unit: "%"
          reference_range: "<7.0"
          status: "elevated"
          clinical_significance: "Initial diagnostic value"
      
      interpretation:
        current: "Excellent glycemic control achieved"
        trend_analysis: "Rapid improvement with metformin therapy"
        clinical_target: "Maintain HbA1c <7.0%"
        next_due: "2024-05-10"
  
  basic_metabolic:
    - test_name: "Basic Metabolic Panel"
      date: "2024-02-10"
      
      components:
        - analyte: "Glucose (fasting)"
          value: 118
          unit: "mg/dL"
          reference_range: "70-100"
          status: "slightly_elevated"
          
        - analyte: "Creatinine"
          value: 0.8
          unit: "mg/dL"
          reference_range: "0.6-1.2"
          status: "normal"
          
        - analyte: "eGFR"
          value: ">60"
          unit: "mL/min/1.73m²"
          status: "normal"
          clinical_note: "Normal kidney function"
```

### Vital Signs
```yaml
vital_signs:
  blood_pressure:
    - date: "2024-02-10"
      time: "10:30"
      systolic: 126
      diastolic: 78
      unit: "mmHg"
      position: "seated"
      arm: "left"
      cuff_size: "standard_adult"
      
      clinical_context:
        status: "well_controlled"
        target: "<130/80"
        trend: "improved"
        
    - date: "2024-01-15"
      systolic: 132
      diastolic: 82
      status: "improving"
      
    - date: "2023-12-15"
      systolic: 145
      diastolic: 88
      status: "elevated"
      clinical_note: "Pre-treatment baseline"
  
  anthropometrics:
    - date: "2024-02-10"
      weight:
        value: 78
        unit: "kg"
        change_from_baseline: -7  # kg lost
        
      height:
        value: 165
        unit: "cm"
        
      bmi:
        value: 28.7
        category: "overweight"
        change: -2.5
        target: "<25"
        
      waist_circumference:
        value: 92
        unit: "cm"
        change: -6
        clinical_significance: "Reduced cardiovascular risk"
```

### Clinical Timeline
```yaml
clinical_timeline:
  - date: "2024-02-10"
    time: "14:30"
    event_type: "follow_up_visit"
    title: "Diabetes Follow-up"
    
    provider:
      name: "Dr. Smith"
      type: "endocrinologist"
      facility: "University Diabetes Center"
      
    visit_details:
      visit_type: "scheduled_follow_up"
      duration_minutes: 30
      
    clinical_assessment:
      chief_complaint: "Routine diabetes management"
      
      review_of_systems:
        - system: "endocrine"
          status: "negative"
          details: "No hypoglycemic episodes"
        - system: "cardiovascular"
          status: "stable"
          details: "Blood pressure well controlled"
          
      physical_exam:
        general: "Well-appearing, comfortable"
        vital_signs: "BP 126/78, Weight 78kg (7kg loss)"
        diabetic_foot_exam: "No ulcers, good pulses, normal sensation"
        
      assessment:
        primary: "Type 2 diabetes with excellent glycemic control"
        secondary: "Essential hypertension, well controlled"
        progress: "Excellent response to lifestyle and metformin"
        
      plan:
        medications:
          - continue: "Metformin 500mg BID"
          - continue: "Lisinopril 10mg daily"
        monitoring:
          - "HbA1c in 3 months (May 2024)"
          - "Basic metabolic panel in 3 months"
        lifestyle:
          - "Continue current diet and exercise"
          - "Nutrition counseling referral"
        follow_up:
          - "Return in 3 months"
          - "Annual diabetic eye exam scheduled"
    
    patient_education:
      topics_discussed:
        - "Excellent progress with diabetes management"
        - "Importance of continued medication adherence"
        - "Signs and symptoms of hypoglycemia"
      materials_provided:
        - "Diabetes self-management handout"
```

### Allergies and Intolerances  
```yaml
allergies:
  drug_allergies:
    - allergen: "Penicillin"
      type: "drug"
      reaction_type: "severe"
      
      reactions:
        - "Anaphylaxis"
        - "Throat swelling"
        - "Hives"
        - "Hypotension"
        
      onset: "immediate"
      documented_date: "2015-03-20"
      
      emergency_treatment:
        - "Epinephrine auto-injector"
        - "IV corticosteroids"
        
      precautions:
        - "Wears medical alert bracelet"
        - "Carries epinephrine auto-injector"
        
  environmental_allergies:
    - allergen: "Tree pollen"
      severity: "mild"
      season: "spring"
      symptoms: ["rhinitis", "watery eyes"]
      treatment: "Antihistamines as needed"
      
  food_intolerances:
    - food: "Lactose"
      severity: "moderate"
      symptoms: ["bloating", "diarrhea"]
      threshold: "More than 1 cup of milk"
      management: ["Lactase supplements", "Lactose-free products"]
```

### Care Team
```yaml
care_team:
  primary_care:
    - provider:
        name: "Dr. Sarah Johnson"  # Anonymized based on privacy level
        credentials: "MD"
        specialty: "Family Medicine"
        
      practice:
        name: "Stockholm Family Health Center"
        type: "community_health_center"
        address:
          city: "Stockholm"
          country: "Sweden"
        contact:
          phone: "+46-8-123-4567"  # Anonymized for privacy
          
      relationship:
        role: "primary_care_provider"
        duration: "4 years"
        since: "2020-01-01"
        
  specialists:
    - provider:
        name: "Dr. Michael Smith"
        credentials: "MD"
        specialty: "Endocrinology"
        
      practice:
        name: "University Diabetes Center"
        type: "specialty_clinic"
        
      relationship:
        role: "diabetes_management"
        since: "2024-01-15"
        referral_reason: "New diabetes diagnosis"
```

## Privacy Levels

### Anonymous (privacy_level: "anonymous")
```yaml
patient:
  name: "Anonymous Patient 001"
  age_range: "30-39"  # Instead of exact age
  occupation_category: "Technology"  # Instead of specific job
  location:
    region: "Northern Europe"  # Instead of city/address

care_team:
  - provider:
      name: "Endocrinologist"  # Role only
      specialty: "Endocrinology"
    # No names, addresses, or contact info
```

### Pseudonymized (privacy_level: "pseudonymized")  
```yaml
patient:
  name: "Patient Smith-001"  # Consistent pseudonym
  age: 34  # Exact age OK
  occupation: "Software Engineer"  # Specific occupation OK
  location:
    city: "Stockholm"  # City-level location OK

care_team:
  - provider:
      name: "Dr. Johnson-A"  # Consistent pseudonym
      # Full clinical details but anonymized identifiers
```

### Identified (privacy_level: "identified")
```yaml
patient:
  name: "Birger Moëll"  # Real name
  # All real identifying information
```

## Extensions and Customizations

### Specialty Extensions
The format supports specialty-specific sections:

```yaml
# Cardiology extension
cardiology:
  format_version: "cardiology-1.0"
  
  echocardiograms:
    - date: "2024-02-15"
      ejection_fraction: 65
      wall_motion: "normal"
      valve_function:
        mitral: "mild regurgitation"
        aortic: "normal"
        
# Mental health extension  
mental_health:
  format_version: "mental-health-1.0"
  
  assessments:
    - date: "2024-02-10"
      instrument: "PHQ-9"
      score: 8
      interpretation: "Mild depression"
      
# Pediatric extension
pediatrics:
  format_version: "pediatrics-1.0"
  
  growth_charts:
    - date: "2024-02-10"
      height_percentile: 75
      weight_percentile: 50
      head_circumference_percentile: 60
```

### Device Data Extensions
```yaml
device_data:
  continuous_glucose_monitor:
    device: "FreeStyle Libre 2"
    period:
      start: "2024-02-01"
      end: "2024-02-14"
      
    metrics:
      average_glucose: 135  # mg/dL
      time_in_range: 78  # percent (70-180 mg/dL)
      time_below_range: 2  # percent (<70 mg/dL)
      time_above_range: 20  # percent (>180 mg/dL)
      
  wearable_fitness:
    device: "Apple Watch Series 8"
    
    daily_averages:
      steps: 8500
      heart_rate_resting: 65
      sleep_hours: 7.5
```

## Validation Schema

The EIR format includes JSON Schema validation:

```yaml
# Schema validation markers
$schema: "https://eir.space/schemas/eir-format-v1.0.json"

# Required validation
metadata:
  format_version: "1.0"  # Required
  privacy_level: "anonymous"  # Required, must be enum
  created_at: "2024-02-17T10:00:00Z"  # Required, must be ISO datetime
```

## File Size and Performance

- **Typical file size:** 50-500 KB for comprehensive record
- **Large datasets:** Use compression (.eir.gz) for archives
- **Streaming:** YAML supports streaming for real-time data
- **Validation:** Schema validation in <10ms for typical files

## Version History

- **v1.0 (2024-02-17):** Initial specification release
- **v0.9 (2024-02-10):** Beta release for community feedback  
- **v0.5 (2024-01-15):** Alpha specification draft

---

**Specification Maintained By:** [Birger Moëll](https://github.com/BirgerMoell), Uppsala University  
**Last Updated:** 2024-02-17  
**License:** MIT

**EIR Format - Because healthcare data deserves better standards.** 🏥💙