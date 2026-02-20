"""
Health.md Parser - Core parsing functionality for Health.md files
"""

import yaml
import re
from datetime import datetime, timedelta
from typing import Dict, List, Optional, Any, Union
from dataclasses import dataclass
from pathlib import Path
import markdown
from bs4 import BeautifulSoup


@dataclass
class Medication:
    """Represents a medication entry from a Health.md file."""
    name: str
    generic_name: Optional[str] = None
    indication: Optional[str] = None
    dosage: Optional[str] = None
    route: Optional[str] = None
    frequency: Optional[str] = None
    started: Optional[datetime] = None
    prescriber: Optional[str] = None
    notes: Optional[str] = None
    icd_codes: List[str] = None
    
    def __post_init__(self):
        if self.icd_codes is None:
            self.icd_codes = []


@dataclass  
class LabResult:
    """Represents a lab result from a Health.md file."""
    name: str
    date: datetime
    value: str
    reference_range: Optional[str] = None
    units: Optional[str] = None
    clinical_significance: Optional[str] = None
    trend: Optional[str] = None  # ↑, ↓, →, etc.
    
    
@dataclass
class VitalSign:
    """Represents a vital sign measurement."""
    name: str
    date: datetime
    value: str
    units: Optional[str] = None
    notes: Optional[str] = None


@dataclass
class ClinicalEvent:
    """Represents an event in the clinical timeline."""
    date: datetime
    title: str
    provider_type: Optional[str] = None
    visit_type: Optional[str] = None
    chief_complaint: Optional[str] = None
    assessment: Optional[str] = None
    plan: Optional[str] = None
    notes: Optional[str] = None


class HealthRecord:
    """
    Main class for parsing and working with Health.md files.
    
    Provides methods to extract structured data and generate
    LLM-optimized summaries.
    """
    
    def __init__(self, content: str):
        self.raw_content = content
        self._parse_content()
    
    @classmethod
    def from_file(cls, filepath: Union[str, Path]) -> 'HealthRecord':
        """Load a Health.md file and create a HealthRecord instance."""
        with open(filepath, 'r', encoding='utf-8') as f:
            content = f.read()
        return cls(content)
    
    def _parse_content(self):
        """Parse the raw markdown content into structured data."""
        # Split frontmatter and content
        parts = self.raw_content.split('---', 2)
        if len(parts) >= 3:
            self.frontmatter = yaml.safe_load(parts[1])
            self.markdown_content = parts[2].strip()
        else:
            self.frontmatter = {}
            self.markdown_content = self.raw_content
        
        # Parse markdown into sections
        self.sections = self._parse_sections()
        
        # Extract structured data
        self.demographics = self._parse_demographics()
        self.medications = self._parse_medications()
        self.lab_results = self._parse_lab_results()
        self.vital_signs = self._parse_vital_signs()
        self.clinical_timeline = self._parse_clinical_timeline()
        self.allergies = self._parse_allergies()
        self.medical_history = self._parse_medical_history()
    
    def _parse_sections(self) -> Dict[str, str]:
        """Split markdown content into sections based on headers."""
        sections = {}
        current_section = None
        current_content = []
        
        for line in self.markdown_content.split('\n'):
            header_match = re.match(r'^(#{1,6})\s+(.+)$', line)
            if header_match:
                # Save previous section
                if current_section:
                    sections[current_section] = '\n'.join(current_content)
                
                # Start new section
                level = len(header_match.group(1))
                title = header_match.group(2)
                current_section = title.lower().replace(' ', '_')
                current_content = []
            else:
                current_content.append(line)
        
        # Save last section
        if current_section:
            sections[current_section] = '\n'.join(current_content)
            
        return sections
    
    def _parse_demographics(self) -> Dict[str, Any]:
        """Extract demographics information."""
        demographics_section = self.sections.get('demographics', '')
        demographics = {}
        
        patterns = {
            'age': r'[*\-]\s*\*?Age\*?:?\s*(.+)',
            'age_range': r'[*\-]\s*\*?Age Range\*?:?\s*(.+)',
            'sex': r'[*\-]\s*\*?Sex\*?:?\s*(.+)',
            'gender_identity': r'[*\-]\s*\*?Gender Identity\*?:?\s*(.+)',
            'occupation': r'[*\-]\s*\*?Occupation\*?:?\s*(.+)',
            'location': r'[*\-]\s*\*?Location\*?:?\s*(.+)',
        }
        
        for key, pattern in patterns.items():
            match = re.search(pattern, demographics_section, re.IGNORECASE)
            if match:
                demographics[key] = match.group(1).strip()
        
        return demographics
    
    def _parse_medications(self) -> List[Medication]:
        """Extract current medications."""
        medications_section = self.sections.get('current_medications', '')
        medications = []
        
        # Split into individual medication blocks
        med_blocks = re.split(r'\n### (.+)\n', medications_section)[1:]
        
        for i in range(0, len(med_blocks), 2):
            if i + 1 < len(med_blocks):
                med_name = med_blocks[i].strip()
                med_content = med_blocks[i + 1]
                
                med = self._parse_single_medication(med_name, med_content)
                medications.append(med)
        
        return medications
    
    def _parse_single_medication(self, name: str, content: str) -> Medication:
        """Parse a single medication block."""
        med = Medication(name=name)
        
        patterns = {
            'generic_name': r'[*\-]\s*\*?Generic Name\*?:?\s*(.+)',
            'indication': r'[*\-]\s*\*?Indication\*?:?\s*(.+)',
            'dosage': r'[*\-]\s*\*?Dosage\*?:?\s*(.+)',
            'route': r'[*\-]\s*\*?Route\*?:?\s*(.+)',
            'prescriber': r'[*\-]\s*\*?Prescriber\*?:?\s*(.+)',
            'notes': r'[*\-]\s*\*?Clinical Notes\*?:?\s*(.+)',
        }
        
        for field, pattern in patterns.items():
            match = re.search(pattern, content, re.IGNORECASE)
            if match:
                setattr(med, field, match.group(1).strip())
        
        # Parse started date
        started_match = re.search(r'[*\-]\s*\*?Started\*?:?\s*(.+)', content, re.IGNORECASE)
        if started_match:
            date_str = started_match.group(1).strip()
            med.started = self._parse_date(date_str)
        
        # Extract ICD codes
        icd_matches = re.findall(r'ICD-10:\s*([A-Z]\d{2}(?:\.\d+)?)', content)
        med.icd_codes = icd_matches
        
        return med
    
    def _parse_lab_results(self) -> List[LabResult]:
        """Extract lab results from the file."""
        lab_section = self.sections.get('lab_results', '')
        lab_results = []
        
        # Parse individual lab tests
        test_blocks = re.split(r'\n### (.+)\n', lab_section)[1:]
        
        for i in range(0, len(test_blocks), 2):
            if i + 1 < len(test_blocks):
                test_name = test_blocks[i].strip()
                test_content = test_blocks[i + 1]
                
                results = self._parse_single_lab_test(test_name, test_content)
                lab_results.extend(results)
        
        return lab_results
    
    def _parse_single_lab_test(self, test_name: str, content: str) -> List[LabResult]:
        """Parse a single lab test section."""
        results = []
        
        # Look for date-value pairs
        date_value_pattern = r'[*\-]\s*\*?(\d{4}-\d{2}-\d{2})\*?:?\s*(.+)'
        matches = re.findall(date_value_pattern, content)
        
        for date_str, value_info in matches:
            result = LabResult(
                name=test_name,
                date=self._parse_date(date_str),
                value=value_info.strip()
            )
            
            # Extract reference range if present
            ref_match = re.search(r'\(Ref:\s*([^)]+)\)', value_info)
            if ref_match:
                result.reference_range = ref_match.group(1)
            
            # Extract trend if present  
            trend_match = re.search(r'[↑↓→]', value_info)
            if trend_match:
                result.trend = trend_match.group(0)
            
            results.append(result)
        
        return results
    
    def _parse_vital_signs(self) -> List[VitalSign]:
        """Extract vital signs from the file."""
        vitals_section = self.sections.get('vital_signs', '')
        vital_signs = []
        
        # Look for vital sign entries
        vital_blocks = re.split(r'\n### (.+)\s*\(([^)]+)\)', vitals_section)[1:]
        
        for i in range(0, len(vital_blocks), 3):
            if i + 2 < len(vital_blocks):
                vital_name = vital_blocks[i].strip()
                date_str = vital_blocks[i + 1].strip()
                content = vital_blocks[i + 2]
                
                # Parse the main reading
                reading_match = re.search(r'[*\-]\s*\*?Reading\*?:?\s*(.+)', content)
                if reading_match:
                    vital = VitalSign(
                        name=vital_name,
                        date=self._parse_date(date_str),
                        value=reading_match.group(1).strip()
                    )
                    vital_signs.append(vital)
        
        return vital_signs
    
    def _parse_clinical_timeline(self) -> List[ClinicalEvent]:
        """Extract clinical timeline events."""
        timeline_section = self.sections.get('clinical_timeline', '')
        events = []
        
        # Parse timeline entries
        event_blocks = re.split(r'\n### ([^:]+):\s*(.+)\n', timeline_section)[1:]
        
        for i in range(0, len(event_blocks), 3):
            if i + 2 < len(event_blocks):
                date_str = event_blocks[i].strip()
                title = event_blocks[i + 1].strip()
                content = event_blocks[i + 2]
                
                event = ClinicalEvent(
                    date=self._parse_date(date_str),
                    title=title
                )
                
                # Parse additional fields
                patterns = {
                    'provider_type': r'[*\-]\s*\*?Provider Type\*?:?\s*(.+)',
                    'visit_type': r'[*\-]\s*\*?Visit Type\*?:?\s*(.+)',
                    'chief_complaint': r'[*\-]\s*\*?Chief Complaint\*?:?\s*(.+)',
                    'assessment': r'[*\-]\s*\*?Assessment\*?:?\s*(.+)',
                    'plan': r'[*\-]\s*\*?Plan\*?:?\s*(.+)',
                }
                
                for field, pattern in patterns.items():
                    match = re.search(pattern, content, re.IGNORECASE)
                    if match:
                        setattr(event, field, match.group(1).strip())
                
                events.append(event)
        
        return events
    
    def _parse_allergies(self) -> Dict[str, List[str]]:
        """Extract allergy information."""
        allergies_section = self.sections.get('allergies_&_intolerances', '')
        allergies = {
            'drug_allergies': [],
            'environmental_allergies': [],
            'food_intolerances': []
        }
        
        # Parse drug allergies
        drug_section = re.search(r'### Drug Allergies\n(.*?)(?=\n###|\Z)', allergies_section, re.DOTALL)
        if drug_section:
            drug_matches = re.findall(r'[*\-]\s*\*?([^:]+)\*?:?\s*(.+)', drug_section.group(1))
            allergies['drug_allergies'] = [f"{drug.strip()}: {reaction.strip()}" for drug, reaction in drug_matches]
        
        return allergies
    
    def _parse_medical_history(self) -> List[Dict[str, Any]]:
        """Extract medical history."""
        history_section = self.sections.get('medical_history', '')
        history = []
        
        # Parse condition blocks
        condition_blocks = re.split(r'\n### (.+)\s*\(([^)]+)\)', history_section)[1:]
        
        for i in range(0, len(condition_blocks), 3):
            if i + 2 < len(condition_blocks):
                condition_name = condition_blocks[i].strip()
                date_str = condition_blocks[i + 1].strip()
                content = condition_blocks[i + 2]
                
                condition = {
                    'condition': condition_name,
                    'onset': self._parse_date(date_str),
                    'content': content
                }
                
                # Extract ICD codes
                icd_match = re.search(r'ICD-10:\*?\s*([A-Z]\d{2}(?:\.\d+)?)', content)
                if icd_match:
                    condition['icd_code'] = icd_match.group(1)
                
                history.append(condition)
        
        return history
    
    def _parse_date(self, date_str: str) -> Optional[datetime]:
        """Parse various date formats into datetime objects."""
        date_str = date_str.strip()
        
        # Common date formats
        formats = [
            '%Y-%m-%d',
            '%Y-%m-%dT%H:%M:%SZ',
            '%Y-%m-%dT%H:%M:%S%z',
            '%B %Y',  # January 2024
            '%Y'      # 2024
        ]
        
        for fmt in formats:
            try:
                return datetime.strptime(date_str, fmt)
            except ValueError:
                continue
        
        # Handle relative dates like "1 month ago"
        relative_match = re.search(r'(\d+)\s+(day|week|month|year)s?\s+ago', date_str.lower())
        if relative_match:
            num = int(relative_match.group(1))
            unit = relative_match.group(2)
            
            now = datetime.now()
            if unit == 'day':
                return now - timedelta(days=num)
            elif unit == 'week':
                return now - timedelta(weeks=num)
            elif unit == 'month':
                return now - timedelta(days=num * 30)  # Approximate
            elif unit == 'year':
                return now - timedelta(days=num * 365)  # Approximate
        
        return None
    
    # Public API methods
    
    def get_current_medications(self) -> List[Medication]:
        """Get list of current medications."""
        return self.medications
    
    def get_recent_labs(self, days: int = 30) -> List[LabResult]:
        """Get lab results from the last N days."""
        cutoff_date = datetime.now() - timedelta(days=days)
        return [lab for lab in self.lab_results if lab.date and lab.date >= cutoff_date]
    
    def get_clinical_timeline(self, days: Optional[int] = None) -> List[ClinicalEvent]:
        """Get clinical timeline events, optionally filtered by days."""
        if days is None:
            return self.clinical_timeline
        
        cutoff_date = datetime.now() - timedelta(days=days)
        return [event for event in self.clinical_timeline if event.date >= cutoff_date]
    
    def get_conditions(self) -> List[str]:
        """Get list of medical conditions."""
        return [condition['condition'] for condition in self.medical_history]
    
    def get_privacy_level(self) -> str:
        """Get the privacy level of this record."""
        return self.frontmatter.get('privacy_level', 'unknown')
    
    def to_llm_context(self, max_length: int = 4000) -> str:
        """
        Generate a concise, LLM-optimized summary of the health record.
        
        Args:
            max_length: Maximum character length of the summary
            
        Returns:
            String summary optimized for LLM consumption
        """
        context_parts = []
        
        # Demographics
        if self.demographics:
            demo_parts = []
            for key, value in self.demographics.items():
                if value:
                    demo_parts.append(f"{key.replace('_', ' ').title()}: {value}")
            if demo_parts:
                context_parts.append(f"PATIENT: {', '.join(demo_parts)}")
        
        # Current conditions
        if self.medical_history:
            conditions = [f"{cond['condition']} ({cond.get('icd_code', 'unknown onset')})" 
                         for cond in self.medical_history]
            context_parts.append(f"CONDITIONS: {'; '.join(conditions)}")
        
        # Current medications
        if self.medications:
            meds = []
            for med in self.medications:
                med_str = f"{med.name}"
                if med.dosage:
                    med_str += f" {med.dosage}"
                if med.indication:
                    med_str += f" for {med.indication}"
                meds.append(med_str)
            context_parts.append(f"MEDICATIONS: {'; '.join(meds)}")
        
        # Recent lab results (last 90 days)
        recent_labs = self.get_recent_labs(90)
        if recent_labs:
            labs = []
            for lab in recent_labs[-5:]:  # Last 5 results
                lab_str = f"{lab.name}: {lab.value}"
                if lab.date:
                    lab_str += f" ({lab.date.strftime('%Y-%m-%d')})"
                labs.append(lab_str)
            context_parts.append(f"RECENT LABS: {'; '.join(labs)}")
        
        # Allergies
        if self.allergies.get('drug_allergies'):
            context_parts.append(f"ALLERGIES: {'; '.join(self.allergies['drug_allergies'])}")
        
        # Recent clinical events
        recent_events = self.get_clinical_timeline(90)
        if recent_events:
            events = []
            for event in recent_events[-3:]:  # Last 3 events
                event_str = f"{event.date.strftime('%Y-%m-%d')}: {event.title}"
                if event.assessment:
                    event_str += f" - {event.assessment}"
                events.append(event_str)
            context_parts.append(f"RECENT VISITS: {'; '.join(events)}")
        
        # Join and truncate if needed
        full_context = '\n\n'.join(context_parts)
        
        if len(full_context) > max_length:
            full_context = full_context[:max_length - 3] + "..."
        
        return full_context
    
    def to_dict(self) -> Dict[str, Any]:
        """Convert the health record to a dictionary representation."""
        return {
            'frontmatter': self.frontmatter,
            'demographics': self.demographics,
            'medications': [
                {
                    'name': med.name,
                    'generic_name': med.generic_name,
                    'indication': med.indication,
                    'dosage': med.dosage,
                    'route': med.route,
                    'started': med.started.isoformat() if med.started else None,
                    'prescriber': med.prescriber,
                    'notes': med.notes,
                    'icd_codes': med.icd_codes
                } for med in self.medications
            ],
            'lab_results': [
                {
                    'name': lab.name,
                    'date': lab.date.isoformat() if lab.date else None,
                    'value': lab.value,
                    'reference_range': lab.reference_range,
                    'units': lab.units,
                    'clinical_significance': lab.clinical_significance,
                    'trend': lab.trend
                } for lab in self.lab_results
            ],
            'medical_history': self.medical_history,
            'allergies': self.allergies,
            'clinical_timeline': [
                {
                    'date': event.date.isoformat() if event.date else None,
                    'title': event.title,
                    'provider_type': event.provider_type,
                    'visit_type': event.visit_type,
                    'chief_complaint': event.chief_complaint,
                    'assessment': event.assessment,
                    'plan': event.plan,
                    'notes': event.notes
                } for event in self.clinical_timeline
            ]
        }