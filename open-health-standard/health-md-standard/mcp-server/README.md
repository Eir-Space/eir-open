# EIR Healthcare Viewer MCP Server

Model Context Protocol (MCP) server for viewing and analyzing EIR (Electronic health Information Record) files in AI conversations.

## Overview

This MCP server allows users to load `.eir` healthcare files directly into any MCP-compatible AI application (Claude Desktop, ChatGPT, etc.) and have natural conversations about their health data.

## Features

- **📁 File Loading** - Load any `.eir` file into AI context
- **🔍 Data Exploration** - Query medications, lab results, conditions, timeline
- **📊 Analysis** - Generate insights, trends, and clinical summaries
- **🔒 Privacy-Aware** - Respects privacy levels in EIR files
- **✅ Validation** - Validates EIR format and provides helpful error messages
- **🌐 Multi-Language** - Supports Swedish healthcare terminology

## Quick Start

### Installation
```bash
npm install -g eir-mcp-server
# or
pip install eir-mcp-server
```

### Configuration
Add to your MCP client (Claude Desktop, etc.):

```json
{
  "mcpServers": {
    "eir-healthcare": {
      "command": "eir-mcp-server",
      "args": []
    }
  }
}
```

### Usage
1. **Load EIR file**: "Load my healthcare data from patient-2024.eir"
2. **Query data**: "What medications am I currently taking?"
3. **Analyze trends**: "How has my HbA1c changed over time?"
4. **Get insights**: "What are my main health risks?"

## MCP Tools

### `load_eir_file`
Load an EIR healthcare file into the conversation context.

**Parameters:**
- `file_path` (string): Path to the .eir file
- `privacy_check` (boolean): Verify privacy level before loading

**Returns:**
- Structured healthcare data ready for AI analysis
- Patient summary and key metrics
- Validation status and warnings

### `query_medications` 
Get current medications and treatment details.

**Parameters:**
- `active_only` (boolean): Show only active medications
- `include_history` (boolean): Include medication history

### `query_lab_results`
Retrieve lab results with filtering options.

**Parameters:**
- `test_name` (string, optional): Filter by specific test
- `days_back` (number): How many days back to include
- `include_trends` (boolean): Calculate trends and changes

### `query_conditions`
Get medical conditions and diagnoses.

**Parameters:**  
- `status` (enum): active, resolved, chronic, all
- `include_icd_codes` (boolean): Include ICD-10/SNOMED codes

### `analyze_timeline`
Generate clinical timeline and care journey analysis.

**Parameters:**
- `days_back` (number): Time period to analyze
- `event_types` (array): Filter by visit types
- `include_outcomes` (boolean): Include treatment outcomes

### `validate_eir_file`
Validate EIR file format and content.

**Parameters:**
- `file_path` (string): Path to file to validate
- `strict_mode` (boolean): Enable strict validation rules

### `generate_summary`
Create comprehensive health summary for AI analysis.

**Parameters:**
- `summary_type` (enum): brief, detailed, clinical, patient_friendly
- `focus_areas` (array): Specific areas to emphasize

## Example Conversations

### Loading and Basic Queries
```
User: Load my healthcare data from ~/health/birger-2024.eir

AI: I've loaded your healthcare data (privacy level: pseudonymized). I can see:
- 2 active medical conditions (Type 2 Diabetes, Hypertension) 
- 2 current medications (Metformin, Lisinopril)
- Recent lab results showing excellent diabetes control (HbA1c: 6.8%)
- 15 clinical events over the past year

What would you like to know about your health data?

User: How is my diabetes management going?

AI: Your diabetes management is going exceptionally well! Here's what I see:

**Blood Sugar Control:**
- HbA1c improved dramatically: 8.2% → 6.8% (now at target <7%)
- Latest fasting glucose: 118 mg/dL (near normal range)
- Trend: Consistently decreasing since starting metformin

**Treatment Response:**
- Metformin 500mg twice daily - excellent adherence (90%+)
- No reported side effects
- 7kg weight loss since diagnosis (78kg current)

**Key Achievements:**
✅ Met HbA1c target in just 4 weeks
✅ Sustainable weight loss
✅ No hypoglycemic episodes
✅ Good blood pressure control

Your endocrinologist Dr. Smith noted "excellent response to lifestyle and metformin" at your last visit. Keep up the great work!
```

### Trend Analysis
```
User: Show me how my lab values have changed over time

AI: Here's your lab trend analysis:

**Hemoglobin A1C (Diabetes Control):**
📉 Dec 2023: 8.2% (diagnostic)
📉 Jan 2024: 7.4% (improving) 
📉 Feb 2024: 6.8% (target achieved!)
Trend: -1.4% in 2 months (excellent improvement)

**Blood Pressure:**
📉 Aug 2023: 158/96 (high, pre-treatment)
📉 Dec 2023: 145/88 (improving)
📉 Feb 2024: 126/78 (well controlled)
Trend: 32/18 mmHg reduction (great response to lisinopril)

**Weight Management:**
📉 Oct 2023: 85kg (BMI 31.2)
📉 Feb 2024: 78kg (BMI 28.7)
Trend: -7kg in 4 months (sustainable pace)

**Clinical Insight:** Your multi-faceted approach (medication + lifestyle) is working excellently. All major health metrics trending in the right direction!
```

### Risk Assessment
```
User: What should I be watching out for health-wise?

AI: Based on your health data, here are key areas to monitor:

**Immediate Priorities:**
1. **Cardiovascular Risk** - You have diabetes + controlled hypertension
   - Current LDL: 128 mg/dL (target <100 for diabetics)
   - Consider statin discussion with your doctor
   - Keep up excellent BP control (current: 126/78)

2. **Diabetes Complications Prevention**
   - Annual diabetic eye exam (scheduled ✅)
   - Foot exams (last exam normal ✅)
   - Kidney function monitoring (current eGFR >60 ✅)

**Positive Factors:**
✅ Excellent diabetes control (HbA1c 6.8%)
✅ No medication side effects
✅ Strong healthcare team (endocrinologist + primary care)
✅ Good medication adherence

**Recommended Actions:**
- Continue current diabetes management
- Discuss cholesterol treatment at next visit
- Maintain weight loss momentum (goal BMI <25)
- Keep up regular monitoring schedule

**Red Flags to Watch For:**
- Frequent hypoglycemia episodes
- Rapid weight gain/loss
- Vision changes
- Foot injuries or numbness

Your proactive approach and excellent clinical response suggest low risk for complications. Keep doing what you're doing!
```

## Privacy and Security

### Privacy Levels
- **Anonymous**: No personal identifiers displayed
- **Pseudonymized**: Consistent fake names, full clinical data
- **Identified**: Real names and contact information (use carefully)

### Security Features
- **Local processing**: EIR files processed locally, not sent to servers
- **Validation**: Schema validation prevents malformed data processing
- **Access control**: Respects file permissions and privacy settings
- **Audit trail**: Logs all data access for compliance

### GDPR/HIPAA Compliance
- **Data minimization**: Only loads requested data sections  
- **Retention limits**: Data cleared after conversation ends
- **Consent tracking**: Records user consent for data processing
- **Right to erasure**: Complete data deletion on request

## Swedish Healthcare Integration

### 1177 Vårdguiden Support
- **Native terminology**: Understands Swedish medical terms
- **Provider mapping**: Maps Swedish healthcare providers
- **ICD-10-SE**: Supports Swedish ICD-10 extensions
- **Referral system**: Understands Swedish referral patterns

### Regional Integration
- **Uppsala Region**: Enhanced support for local providers
- **Folktandvården**: Dental care integration
- **Vaccination records**: Integration with Swedish vaccination system

## Development

### Contributing
```bash
git clone https://github.com/BirgerMoell/eir-mcp-server
cd eir-mcp-server
npm install
npm run dev
```

### Testing
```bash
# Run tests
npm test

# Test with sample EIR file
npm run test:sample

# Validate EIR files
npm run validate examples/*.eir
```

### API Documentation
Full API documentation available at: https://docs.eir.space/mcp-server

## Roadmap

### Version 1.1 (Q2 2024)
- **Real-time sync** with Swedish healthcare systems
- **Family sharing** for caregiver access  
- **Predictive analytics** for health risk assessment
- **Integration** with Apple Health, Google Fit

### Version 2.0 (Q3 2024)
- **Multi-patient** support for healthcare providers
- **Clinical decision support** with evidence-based recommendations  
- **Population health** analytics for research
- **Blockchain integration** for data provenance

## Support

- **Documentation**: https://docs.eir.space/
- **Issues**: https://github.com/BirgerMoell/eir-mcp-server/issues
- **Discord**: https://discord.gg/eir-format
- **Email**: support@eir.space

---

**EIR MCP Server - Healthcare data that actually works with AI.** 🏥🤖💙