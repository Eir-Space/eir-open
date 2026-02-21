# EIR File Format - Clinical Notes Explorer

## 🎯 **What is EIR?**

EIR (Electronic Health Record) is a structured YAML format designed for storing and exploring clinical notes. It's both human and machine readable, making it perfect for clinical note exploration tools.

## 📋 **File Format Structure**

### **Metadata Section**
```yaml
metadata:
  format_version: "1.0"
  created_at: "2025-01-16T17:17:03Z"
  source: "1177.se Journal"
  patient:
    name: "Birger Moell"
    birth_date: "1986-02-28"
    personal_number: "19860228-0250"
  export_info:
    total_entries: 25
    date_range:
      start: "2001-02-26"
      end: "2025-03-17"
    healthcare_providers: ["Östervåla vårdcentral", "Folktandvården Östervåla"]
```

### **Entry Structure**
Each journal entry contains:
```yaml
- id: "entry_001"
  date: "2025-03-17"
  time: "10:52"
  category: "Vårdkontakter"
  type: "Annan"
  provider:
    name: "Östervåla vårdcentral"
    region: "Region Uppsala"
    location: "Östervåla vårdcentral"
  status: "Nytt"
  responsible_person:
    name: "Therese Karlberg"
    role: "Distriktssköterska"
  content:
    summary: "Vårdkontakt - Annan typ"
    details: "Dag & tid: måndag 17 mars 2025 klockan 10:52"
    notes: []
  attachments: []
  tags: ["vårdkontakt", "allmänmedicin"]
```

## 🔧 **Chrome Extension Features**

### **Dual Download System**
The extension now downloads **TWO files**:

1. **`journal-content.txt`** - Human-readable text format
2. **`journal-content.eir`** - Structured YAML format for clinical tools

### **Smart Data Extraction**
- **Date parsing**: Converts "17 mar 2025" → "2025-03-17"
- **Time extraction**: Finds "klockan 10:52" → "10:52"
- **Provider parsing**: Extracts region, location, name
- **Person extraction**: Finds responsible healthcare staff
- **Role detection**: Identifies "Distriktssköterska", "Läkare", etc.
- **Tag generation**: Auto-generates relevant tags

### **Clinical Data Structure**
Each entry includes:
- **Unique ID**: `entry_001`, `entry_002`, etc.
- **Temporal data**: Date, time, status
- **Categorization**: Category, type, tags
- **Provider info**: Name, region, location
- **Responsibility**: Person, role
- **Content**: Summary, details, notes
- **Metadata**: Attachments, tags

## 🏥 **Eir Clinical Notes Viewer**

### **What Eir Can Do**
Eir (or any clinical notes viewer) can:

1. **Parse EIR files** and display structured data
2. **Filter by categories**: Vårdkontakter, Diagnoser, Vaccinationer
3. **Search by tags**: akut, vaccination, tandvård
4. **Timeline view**: Chronological display
5. **Provider filtering**: Show entries by healthcare provider
6. **Status filtering**: Nytt, Osignerad, Signerad
7. **Export capabilities**: PDF, other formats

### **Example Eir Features**
```yaml
# Filter by category
entries:
  - category: "Diagnoser"
    tags: ["akut", "ortopedi"]

# Search by provider
entries:
  - provider:
      name: "Östervåla vårdcentral"
      region: "Region Uppsala"

# Timeline view
entries:
  - date: "2025-03-17"
    time: "10:52"
```

## 📊 **Data Quality Features**

### **Intelligent Parsing**
- **Date normalization**: Multiple formats → ISO format
- **Time extraction**: Swedish time patterns
- **Provider mapping**: Region detection
- **Role classification**: Healthcare staff roles
- **Content summarization**: Auto-generated summaries

### **Tag System**
Auto-generated tags include:
- **Categories**: vårdkontakt, diagnos, vaccination
- **Content**: akut, tandvård, osignerad
- **Roles**: distriktssköterska, tandläkare, läkare
- **Status**: nytt, osignerad, signerad

## 🚀 **Usage Workflow**

1. **Install Chrome Extension**
2. **Visit 1177.se Journal**
3. **Click Download Button**
4. **Get Two Files**:
   - `journal-content.txt` (human readable)
   - `journal-content.eir` (structured data)
5. **Import EIR into Eir** (clinical notes viewer)
6. **Explore structured data**

## 🔮 **Future Possibilities**

### **Eir Viewer Features**
- **Timeline visualization**
- **Provider network mapping**
- **Diagnosis tracking**
- **Medication history**
- **Appointment scheduling**
- **Data export to other systems**

### **Advanced Analytics**
- **Health trend analysis**
- **Provider performance metrics**
- **Diagnosis pattern recognition**
- **Treatment effectiveness tracking**

## 📁 **File Examples**

### **Simple Entry**
```yaml
- id: "entry_001"
  date: "2025-03-17"
  category: "Vaccinationer"
  type: "FSME-IMMUN Vuxen"
  provider:
    name: "Östervåla vårdcentral"
  content:
    summary: "TBE-vaccination utförd"
  tags: ["vaccination", "TBE"]
```

### **Complex Entry**
```yaml
- id: "entry_009"
  date: "2021-11-02"
  category: "Anteckningar"
  type: "Besöksanteckning"
  provider:
    name: "SLSO- Närakut Danderyd"
    region: "Stockholm"
  status: "Osignerad"
  responsible_person:
    name: "Andreas Fredholm"
    role: "Läkare"
  content:
    summary: "Tåskada - luxation"
    notes:
      - "Kontakttyp: Oplanerat mottagningsbesök"
      - "Bedömning: DIP-led subluxation lateralt"
  tags: ["akut", "ortopedi", "tåskada", "luxation", "osignerad"]
```

## ✅ **Benefits**

1. **Structured Data**: Easy to parse and process
2. **Human Readable**: YAML is easy to read and edit
3. **Machine Processable**: Perfect for clinical tools
4. **Extensible**: Easy to add new fields
5. **Standardized**: Consistent format across entries
6. **Searchable**: Tags and categories enable filtering
7. **Timeline Ready**: Chronological data structure

The EIR format transforms raw journal data into a powerful, structured format that clinical tools like Eir can use to provide beautiful, interactive views of medical records! 🏥✨
