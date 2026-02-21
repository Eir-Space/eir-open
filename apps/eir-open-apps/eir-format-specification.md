# EIR File Format Specification

## Overview
The `.eir` file format is a YAML-based structure designed for storing and exchanging clinical notes and medical records. It's optimized for both human readability and machine processing, making it ideal for clinical note exploration tools like Eir.

## File Structure

```yaml
# EIR File Format v1.0
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
    healthcare_providers: ["Östervåla vårdcentral", "Folktandvården Östervåla", "SLSO- Närakut Danderyd"]

entries:
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

  - id: "entry_002"
    date: "2025-03-17"
    time: "10:52"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "Östervåla vårdcentral"
      region: "Region Uppsala"
      location: "Östervåla vårdcentral"
    status: "Nytt"
    responsible_person:
      name: "Therese Karlberg"
      role: "Distriktssköterska"
    content:
      summary: "Besöksanteckning"
      details: "Anteckning från besök"
      notes: []
    attachments: []
    tags: ["anteckning", "besök"]

  - id: "entry_003"
    date: "2025-03-17"
    time: "10:52"
    category: "Diagnoser"
    type: "Vaccination avseende artropodöverförd virusencefalit"
    provider:
      name: "Östervåla vårdcentral"
      region: "Region Uppsala"
      location: "Östervåla vårdcentral"
    status: "Nytt"
    responsible_person:
      name: "Therese Karlberg"
      role: "Distriktssköterska"
    content:
      summary: "TBE-vaccination diagnos"
      details: "Diagnos: Vaccination avseende artropodöverförd virusencefalit 2025-03-17 10:52"
      notes: []
    attachments: []
    tags: ["diagnos", "vaccination", "TBE"]

  - id: "entry_004"
    date: "2025-03-17"
    time: "10:52"
    category: "Vaccinationer"
    type: "FSME-IMMUN Vuxen"
    provider:
      name: "Östervåla vårdcentral"
      region: "Region Uppsala"
      location: "Östervåla vårdcentral"
    status: "Nytt"
    responsible_person:
      name: "Karlberg, Anne"
      role: "Sjuksköterska"
    content:
      summary: "TBE-vaccination utförd"
      details: "FSME-IMMUN Vuxen 2025-03-17"
      notes:
        - "Dos: 0.5 ml, intramuskulär"
        - "Typ av vaccin: Läs mer om ditt läkemedel i FASS"
        - "Tillverkare: Pfizer Innovations AB (batch KC8559)"
        - "Ordinatör: Drochtert, Sarah, distriktsläkare, drs003"
        - "Vaccinerad av: Karlberg, Therese, kat025"
    attachments: []
    tags: ["vaccination", "TBE", "FSME-IMMUN"]

  - id: "entry_005"
    date: "2024-06-11"
    time: "09:01"
    category: "Anteckningar"
    type: "Åtgärd/behandling"
    provider:
      name: "Folktandvården Östervåla"
      region: "Region Uppsala"
      location: "Östervåla"
    status: "Nytt"
    responsible_person:
      name: "Ban Rabi"
      role: "Tandläkare"
    content:
      summary: "Tandvårdsbehandling"
      details: "Åtgärd/behandling 2024-06-11 09:01"
      notes:
        - "Behandling: Allmänt tandvårdsbidrag : Utförd"
        - "Undersökning - Kompletterande undersökning eller utredning, enstaka tand - (FK tillstånd 1301) : Utförd"
        - "Tandvård - Sjukdomsbehandlande åtgärder mindre omfattning - (FK tillstånd 4772) : Utförd"
    attachments: []
    tags: ["tandvård", "behandling", "tandläkare"]

  - id: "entry_006"
    date: "2024-06-11"
    time: "08:55"
    category: "Anteckningar"
    type: "Utredning"
    provider:
      name: "Folktandvården Östervåla"
      region: "Region Uppsala"
      location: "Östervåla"
    status: "Nytt"
    responsible_person:
      name: "Ban Rabi"
      role: "Tandläkare"
    content:
      summary: "Tandutredning"
      details: "Utredning 2024-06-11 08:55"
      notes:
        - "Status 11 - Fyllning - MP - Komposit - U.A. : Registrerad"
        - "Status 11 - Kusp/Ytfraktur - M : Registrerad"
    attachments: []
    tags: ["tandvård", "utredning", "tandläkare"]

  - id: "entry_007"
    date: "2024-06-11"
    time: "08:55"
    category: "Vårdkontakter"
    type: "Mottagningsbesök"
    provider:
      name: "Folktandvården Östervåla"
      region: "Region Uppsala"
      location: "Östervåla"
    status: "Nytt"
    responsible_person:
      name: "Ban Rabi"
      role: "Tandläkare"
    content:
      summary: "Mottagningsbesök tandvård"
      details: "Mottagningsbesök - Dag & tid: tisdag 11 juni 2024 klockan 08:55 - 09:35"
      notes: []
    attachments: []
    tags: ["tandvård", "mottagning", "besök"]

  - id: "entry_008"
    date: "2024-06-05"
    time: "08:02"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "Folktandvården Östervåla"
      region: "Region Uppsala"
      location: "Östervåla"
    status: "Nytt"
    responsible_person:
      name: "Linda Gullevin"
      role: "Tandsköterska"
    content:
      summary: "Tandfraktur - akutbesök"
      details: "Besöksanteckning 2024-06-05 08:02"
      notes:
        - "Daganteckning: Pat ringer med fraktur, en flisa av en framtand har lossnat när han åt."
        - "Han har lagat samma framtand för tre år sedan."
        - "Får tid 11/6 muntligen samt via sms."
    attachments: []
    tags: ["tandvård", "fraktur", "akut", "tandsköterska"]

  - id: "entry_009"
    date: "2021-11-02"
    time: "21:37"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "SLSO- Närakut Danderyd"
      region: "Stockholm"
      location: "Danderyd"
    status: "Osignerad"
    responsible_person:
      name: "Andreas Fredholm"
      role: "Läkare"
    content:
      summary: "Tåskada - luxation"
      details: "Besöksanteckning 2021-11-02 21:37"
      notes:
        - "Kontakttyp: Oplanerat mottagningsbesök"
        - "Kontaktorsak: Smärta vänster dig 2. Olycksfall."
        - "Aktuellt: Man som sparkat in i någon betongvägg. Dig 2 vänster pekar lite snett."
        - "Status: Lokalstatus Dig 2 vänster inspekteras lite sned i DIP-leden. Palpöm där."
        - "Bedömning: DIP-led subluxation lateralt. Drar den rakt och därefter är tån rak. Inga hematom eller svullnader. Således luxation, ingen misstanke om fraktur."
    attachments: []
    tags: ["akut", "ortopedi", "tåskada", "luxation", "osignerad"]

  - id: "entry_010"
    date: "2021-11-02"
    time: "20:18"
    category: "Vårdkontakter"
    type: "Mottagningsbesök"
    provider:
      name: "SLSO- Närakut Danderyd"
      region: "Stockholm"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "SLSO- Närakut Danderyd"
      role: "Akutvård"
    content:
      summary: "Akutbesök tåskada"
      details: "Mottagningsbesök - Dag & tid: tisdag 2 november 2021 klockan 20:18"
      notes: []
    attachments: []
    tags: ["akut", "ortopedi", "tåskada"]

  - id: "entry_011"
    date: "2021-11-02"
    time: "21:37"
    category: "Diagnoser"
    type: "Luxation i tå"
    provider:
      name: "SLSO- Närakut Danderyd"
      region: "Stockholm"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "Andreas Fredholm"
      role: "Läkare"
    content:
      summary: "Diagnos: Luxation i tå"
      details: "Diagnos: Luxation i tå 2021-11-02 00:00"
      notes:
        - "Huvuddiagnos: Luxation i tå"
    attachments: []
    tags: ["diagnos", "ortopedi", "luxation", "tå"]

  - id: "entry_012"
    date: "2021-07-10"
    time: "17:21"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "Folktandvården Fridhemsplan Akuten"
      region: "Stockholm"
      location: "Fridhemsplan"
    status: "Nytt"
    responsible_person:
      name: "Juni Liu"
      role: "Leg. Tandläkare"
    content:
      summary: "Akut tandvård - perikoronit"
      details: "Besöksanteckning 2021-07-10 17:21"
      notes:
        - "Behandling: Akut us: Patienten behandlad på AKUTEN"
        - "ID kontroll: Pat söker akut pga värk regio 38 i två dagar, har tagit Alvedon och Ipren kombination"
        - "Info att endast akutbehandling ges."
        - "Allmäntillstånd: ua"
        - "Hälsodeklaration: updd"
        - "Klinisk us: Tand 38 erupterad ua. operculum. svulen gingiva. 1apikalrtg, visar: ej ind"
        - "Diagnos: 38 perikoronit"
        - "Terapiförslag: spoln"
        - "Kostnadsförslag: 1060 kr"
        - "Pat samtycker till föreslagen behandlingoch kostnad"
        - "Behandling: spoln 38 koksalt fys, corsodyl gel + tuss. info om status, förklaring för pat hur han ska hålla rent."
        - "rek Alvedon + Ipren och Corsodyl"
        - "Pat ombedes kontakta ordinare tandläkare för fortsatt terapiplanering och behandling."
        - "Info pat ev besvär från tanden kan kvarstå till dess att tanden är fullständigt behandlad."
        - "Rekommenderar receptfria smärtstillande vid behov."
        - "Undersökning - Kompletterande eller akut undersökning utförd av tandläkare - (FK tillstånd 1301) : Utförd"
        - "Tandvård - Tillägg obekväm arbetstid : Utförd"
        - "Tandvård - Sjukdoms- eller smärtbehandling, mindre omfattande - (FK tillstånd 3045) : Utförd"
        - "Allmänt tandvårdsbidrag : Utförd"
    attachments: []
    tags: ["tandvård", "akut", "perikoronit", "tandläkare"]

  - id: "entry_013"
    date: "2021-07-10"
    time: "17:10"
    category: "Vårdkontakter"
    type: "Mottagningsbesök"
    provider:
      name: "Folktandvården Fridhemsplan Akuten"
      region: "Stockholm"
      location: "Fridhemsplan"
    status: "Nytt"
    responsible_person:
      name: "Juni Liu"
      role: "Leg. Tandläkare"
    content:
      summary: "Akut tandvård besök"
      details: "Mottagningsbesök - Dag & tid: lördag 10 juli 2021 klockan 17:10 - 17:30"
      notes: []
    attachments: []
    tags: ["tandvård", "akut", "besök"]

  - id: "entry_014"
    date: "2021-04-21"
    time: "09:23"
    category: "Anteckningar"
    type: "Anteckning"
    provider:
      name: "SLSO-Smittspårningsenhet"
      region: "Stockholm"
      location: "Smittspårningsenhet"
    status: "Nytt"
    responsible_person:
      name: "Anna Svelander"
      role: "Administrativ personal"
    content:
      summary: "COVID-19 smittspårning"
      details: "Anteckning 2021-04-21 09:23"
      notes:
        - "Smittspårning"
        - "Kontakttyp: Telefonkontakt med patient"
        - "Information till patienten, provsvar virus SARS-CoV-2"
        - "Informationsblad från Vårdgivarguiden."
        - "Positivt provsvar, virus påvisat"
        - "Muntlig information och förhållningsregler.Positivt provsvar, virus påvisat"
        - "Anmälan SML Anmälan enligt Smittskyddslagen gjord"
        - "Anteckning Smittspårning utförd av patienten själv"
    attachments: []
    tags: ["covid-19", "smittspårning", "provsvar", "administrativ"]

  - id: "entry_015"
    date: "2020-12-28"
    time: "12:53"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "SLSO- Danderyds VC"
      region: "Danderyd"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "Kristina Sund"
      role: "Läkare"
    content:
      summary: "Handskada efter fall"
      details: "Besöksanteckning 2020-12-28 12:53"
      notes:
        - "Besök"
        - "Kontakttyp: Planerat mottagningsbesök"
        - "Kontaktorsak: Önskar bedömning av finger efter ett fall 23/12"
        - "Aktuellt: Pat som föll i en trappa 23/12 och tog emot sig med båda händerna, dorsalsidan av höger hand. Sedan dess haft lite ont i ffa hö långfinger och önskar en bedömning varför bokat tid idag. Upplever ingen rörelseinskränkning, känselnedsättning eller nedsatt kraft. Tar även upp ont till vä i halsen sedan igår."
        - "Status: Allmäntillstånd Gott, opåverkat. Munhåla och svalg Inspekteras med normalfuktade slemhinnor, oretade förhållanden. Tonsiller insp u.a. Ytliga lymfkörtlar Palp u.a. huvud, hals."
        - "Lokalstatus: Hö hand: ingen felställning, svullnad, hematom eller sår. God rörlighet. Ingen extensions- eller flektionsdefekt. God kapillär återfyllnad samtliga fingrar. God känsel och grov kraft. Diskret palpationsömhet diffust över lång- och ringfinger. Skelettet palperas utan hak eller asymmetri. Ingen svullnad eller värk över MCP- eller IP-leder. 2PD 4mm u.a. samtliga fingrar."
        - "Bedömning: Trauma mot höger hand för 5d sedan. Status väs u.a. Ingen misstanke om allvarlig skada. Ger lugnande besked. Ont i halsen sedan igår vid en specifik punkt. Inget avvikande i status. Råder till expektans."
        - "Uppföljning: Ingen planerad. Åter vid behov."
    attachments: []
    tags: ["handskada", "trauma", "fall", "allmänmedicin"]

  - id: "entry_016"
    date: "2020-12-28"
    time: "12:52"
    category: "Vårdkontakter"
    type: "Mottagningsbesök"
    provider:
      name: "SLSO- Danderyds VC"
      region: "Danderyd"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "Kristina Sund"
      role: "Läkare"
    content:
      summary: "Kontrollbesök handskada"
      details: "Mottagningsbesök - Dag & tid: måndag 28 december 2020 klockan 12:52"
      notes: []
    attachments: []
    tags: ["handskada", "kontroll", "allmänmedicin"]

  - id: "entry_017"
    date: "2020-12-28"
    time: "10:18"
    category: "Anteckningar"
    type: "Anteckning utan fysiskt möte"
    provider:
      name: "SLSO- Danderyds VC"
      region: "Danderyd"
      location: "Danderyd"
    status: "Osignerad"
    responsible_person:
      name: "Britt Hulding Nyström"
      role: "Distriktssköterska"
    content:
      summary: "Telefonkontakt om handskada"
      details: "Anteckning utan fysiskt möte 2020-12-28 10:18"
      notes:
        - "Telefonkontakt"
        - "Kontakttyp: Telefonkontakt med patient"
        - "Kontaktorsak: Patient ringer, ramlat i trappa den 23/12, skadat fingrar. Önskar kontroll"
        - "Åtgärd: Bokar tid idag."
    attachments: []
    tags: ["telefonkontakt", "handskada", "osignerad", "distriktssköterska"]

  - id: "entry_018"
    date: "2020-12-28"
    time: "12:53"
    category: "Diagnoser"
    type: "Smärta, ospecifik i hand"
    provider:
      name: "SLSO- Danderyds VC"
      region: "Danderyd"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "Kristina Sund"
      role: "Läkare"
    content:
      summary: "Diagnos: Smärta, ospecifik i hand"
      details: "Diagnos: Smärta, ospecifik i hand 2020-12-28 00:00"
      notes:
        - "Huvuddiagnos: Smärta, ospecifik i hand"
    attachments: []
    tags: ["diagnos", "smärta", "hand", "allmänmedicin"]

  - id: "entry_019"
    date: "2018-03-26"
    time: "16:45"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "SLSO- Närakut Danderyd"
      region: "Stockholm"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "Maria Sjödahl"
      role: "Läkare"
    content:
      summary: "Feber och miktionssveda"
      details: "Besöksanteckning 2018-03-26 16:45"
      notes:
        - "Besök"
        - "Kontakttyp: Oplanerat mottagningsbesök"
        - "Aktuellt: Feber och miktionssveda sedan två dagar. Kraktes idag, temp 39 vid inkomst hit."
        - "Status: Allmäntillstånd Gott. Opåverkat. Fått Alvedon, afebril"
        - "Buk: Oöm"
        - "Mätvärden: Urinsticka nitritpositiv."
        - "Åtgärd: Skickar urinodling, kontakt vid behov."
        - "recept: Ciprofloxacin i tio dagar."
    attachments: []
    tags: ["feber", "miktionssveda", "akut", "urologi"]

  - id: "entry_020"
    date: "2018-03-26"
    time: "13:38"
    category: "Anteckningar"
    type: "Anteckning"
    provider:
      name: "SLSO- Danderyds VC"
      region: "Danderyd"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "Birgitta Björkå Dahlberg"
      role: "Distriktssköterska"
    content:
      summary: "Återbud läkarbesök"
      details: "Anteckning 2018-03-26 13:38"
      notes:
        - "Återbud"
        - "Anteckning: Avbokar läkarbesök 26/3"
    attachments: []
    tags: ["återbud", "distriktssköterska"]

  - id: "entry_021"
    date: "2018-03-26"
    time: "12:32"
    category: "Vårdkontakter"
    type: "Mottagningsbesök"
    provider:
      name: "SLSO- Närakut Danderyd"
      region: "Stockholm"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "SLSO- Närakut Danderyd"
      role: "Akutvård"
    content:
      summary: "Akutbesök feber"
      details: "Mottagningsbesök - Dag & tid: måndag 26 mars 2018 klockan 12:32"
      notes: []
    attachments: []
    tags: ["akut", "feber", "besök"]

  - id: "entry_022"
    date: "2018-03-26"
    time: "16:45"
    category: "Diagnoser"
    type: "Akut tubulo-interstitiell nefrit"
    provider:
      name: "SLSO- Närakut Danderyd"
      region: "Stockholm"
      location: "Danderyd"
    status: "Nytt"
    responsible_person:
      name: "Maria Sjödahl"
      role: "Läkare"
    content:
      summary: "Diagnos: Akut tubulo-interstitiell nefrit"
      details: "Diagnos: Akut tubulo-interstitiell nefrit 2018-03-26 00:00"
      notes:
        - "Huvuddiagnos: Akut tubulo-interstitiell nefrit"
    attachments: []
    tags: ["diagnos", "nefrit", "urologi", "akut"]

  - id: "entry_023"
    date: "2001-02-26"
    time: "18:00"
    category: "Diagnoser"
    type: "DISTORSION (PV10-T03-P)?Handled??"
    provider:
      name: "MeDict journal, Tärnaby"
      region: "Västerbotten"
      location: "Tärnaby"
    status: "Osignerad"
    responsible_person:
      name: "Lars Carle"
      role: "läkare"
    content:
      summary: "Diagnos: DISTORSION (PV10-T03-P)?Handled??"
      details: "Diagnos: DISTORSION (PV10-T03-P)?Handled?? 2001-02-26 18:00"
      notes:
        - "Bidiagnos: DISTORSION (PV10-T03-P)?Handled??"
    attachments: []
    tags: ["diagnos", "distorsion", "handled", "osignerad", "gammal"]

  - id: "entry_024"
    date: "2025-03-17"
    time: "10:52"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "Östervåla vårdcentral"
      region: "Region Uppsala"
      location: "Östervåla vårdcentral"
    status: "Nytt"
    responsible_person:
      name: "Therese Karlberg"
      role: "Distriktssköterska"
    content:
      summary: "TBE-vaccination besöksanteckning"
      details: "Besöksanteckning 2025-03-17 10:52"
      notes:
        - "Allmänna uppgifter"
        - "ID-kontroll: Utförd mot giltig ID-handling"
        - "Kontaktorsak: Vaccination TBE"
        - "Egenbetalande: Ja"
        - "Bedömning: Hälsodeklaration: Inga kontraindikationer mot vaccination"
        - "Åtgärd: Ordinerad av FSME-IMMUN: Drochtert, Sarah, distriktsläkare, drs003"
        - "Vaccinerad av: Karlberg, Therese, kat025"
        - "Diagnos & åtgärdskod: Z241-Vaccination avseende artropodöverförd virusencefalit-HuvuddiagnosDT030-Vaccination (i)-ÅtgärdJ07BA01-Vaccin mot fästingburen encefalit, inaktiverat helvirusvaccin-"
    attachments: []
    tags: ["vaccination", "TBE", "besök", "distriktssköterska"]

  - id: "entry_025"
    date: "2021-07-10"
    time: "17:21"
    category: "Anteckningar"
    type: "Besöksanteckning"
    provider:
      name: "Folktandvården Fridhemsplan Akuten"
      region: "Stockholm"
      location: "Fridhemsplan"
    status: "Nytt"
    responsible_person:
      name: "Juni Liu"
      role: "Leg. Tandläkare"
    content:
      summary: "Akut tandvård - perikoronit (duplikat)"
      details: "Besöksanteckning 2021-07-10 17:21"
      notes:
        - "Behandling: Akut us: Patienten behandlad på AKUTEN"
        - "ID kontroll: Pat söker akut pga värk regio 38 i två dagar, har tagit Alvedon och Ipren kombination"
        - "Info att endast akutbehandling ges."
        - "Allmäntillstånd: ua"
        - "Hälsodeklaration: updd"
        - "Klinisk us: Tand 38 erupterad ua. operculum. svulen gingiva. 1apikalrtg, visar: ej ind"
        - "Diagnos: 38 perikoronit"
        - "Terapiförslag: spoln"
        - "Kostnadsförslag: 1060 kr"
        - "Pat samtycker till föreslagen behandlingoch kostnad"
        - "Behandling: spoln 38 koksalt fys, corsodyl gel + tuss. info om status, förklaring för pat hur han ska hålla rent."
        - "rek Alvedon + Ipren och Corsodyl"
        - "Pat ombedes kontakta ordinare tandläkare för fortsatt terapiplanering och behandling."
        - "Info pat ev besvär från tanden kan kvarstå till dess att tanden är fullständigt behandlad."
        - "Rekommenderar receptfria smärtstillande vid behov."
        - "Undersökning - Kompletterande eller akut undersökning utförd av tandläkare - (FK tillstånd 1301) : Utförd"
        - "Tandvård - Tillägg obekväm arbetstid : Utförd"
        - "Tandvård - Sjukdoms- eller smärtbehandling, mindre omfattande - (FK tillstånd 3045) : Utförd"
        - "Allmänt tandvårdsbidrag : Utförd"
    attachments: []
    tags: ["tandvård", "akut", "perikoronit", "tandläkare", "duplikat"]

# End of EIR file
