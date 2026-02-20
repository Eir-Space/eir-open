#!/usr/bin/env python3
"""
Health.md Parser Script for OpenClaw

Parse and analyze Health.md files, extracting structured healthcare data
and generating LLM-optimized summaries for AI analysis.

Usage:
    python parse_health.py patient.health.md
    python parse_health.py patient.health.md --summary --medications
    python parse_health.py patient.health.md --validate --anonymize
"""

import argparse
import json
import sys
from pathlib import Path
from typing import Dict, Any, Optional

# Import the health_md parser (assumes it's installed or in path)
try:
    from health_md import HealthRecord, validate_health_md, HealthMdValidationError
except ImportError:
    print("Error: health-md library not found. Install with: pip install health-md")
    sys.exit(1)


class HealthMdParser:
    """
    OpenClaw skill for parsing and analyzing Health.md files.
    """
    
    def __init__(self, filepath: str):
        self.filepath = Path(filepath)
        self.record: Optional[HealthRecord] = None
        
        if not self.filepath.exists():
            raise FileNotFoundError(f"Health.md file not found: {filepath}")
    
    def parse(self) -> HealthRecord:
        """Parse the Health.md file and return a HealthRecord object."""
        try:
            self.record = HealthRecord.from_file(self.filepath)
            return self.record
        except HealthMdValidationError as e:
            raise ValueError(f"Invalid Health.md format: {e}")
    
    def validate(self) -> Dict[str, Any]:
        """Validate the Health.md file format and return validation results."""
        try:
            with open(self.filepath, 'r', encoding='utf-8') as f:
                content = f.read()
            
            validation_result = validate_health_md(content)
            return {
                'valid': True,
                'file': str(self.filepath),
                'version': validation_result.get('version', 'unknown'),
                'privacy_level': validation_result.get('privacy_level', 'unknown'),
                'warnings': validation_result.get('warnings', []),
                'sections_found': validation_result.get('sections', [])
            }
        except Exception as e:
            return {
                'valid': False,
                'file': str(self.filepath),
                'error': str(e)
            }
    
    def get_summary(self) -> str:
        """Generate an LLM-optimized summary of the health record."""
        if not self.record:
            self.parse()
        
        return self.record.to_llm_context()
    
    def get_medications(self) -> Dict[str, Any]:
        """Extract current medications information."""
        if not self.record:
            self.parse()
        
        medications = []
        for med in self.record.get_current_medications():
            medications.append({
                'name': med.name,
                'generic_name': med.generic_name,
                'indication': med.indication,
                'dosage': med.dosage,
                'started': med.started.isoformat() if med.started else None,
                'prescriber': med.prescriber,
                'notes': med.notes,
                'icd_codes': med.icd_codes
            })
        
        return {
            'medication_count': len(medications),
            'medications': medications
        }
    
    def get_lab_results(self, days: int = 90) -> Dict[str, Any]:
        """Extract recent lab results."""
        if not self.record:
            self.parse()
        
        recent_labs = self.record.get_recent_labs(days)
        
        labs = []
        for lab in recent_labs:
            labs.append({
                'name': lab.name,
                'date': lab.date.isoformat() if lab.date else None,
                'value': lab.value,
                'reference_range': lab.reference_range,
                'trend': lab.trend,
                'clinical_significance': lab.clinical_significance
            })
        
        return {
            'lab_count': len(labs),
            'timeframe_days': days,
            'labs': labs
        }
    
    def get_conditions(self) -> Dict[str, Any]:
        """Extract medical conditions and history."""
        if not self.record:
            self.parse()
        
        conditions = []
        for condition in self.record.medical_history:
            conditions.append({
                'condition': condition['condition'],
                'onset': condition['onset'].isoformat() if condition['onset'] else None,
                'icd_code': condition.get('icd_code', 'Unknown')
            })
        
        return {
            'condition_count': len(conditions),
            'conditions': conditions
        }
    
    def get_clinical_timeline(self, days: int = 365) -> Dict[str, Any]:
        """Extract clinical timeline events."""
        if not self.record:
            self.parse()
        
        timeline = self.record.get_clinical_timeline(days)
        
        events = []
        for event in timeline:
            events.append({
                'date': event.date.isoformat() if event.date else None,
                'title': event.title,
                'provider_type': event.provider_type,
                'visit_type': event.visit_type,
                'chief_complaint': event.chief_complaint,
                'assessment': event.assessment,
                'plan': event.plan
            })
        
        return {
            'event_count': len(events),
            'timeframe_days': days,
            'events': events
        }
    
    def anonymize_record(self) -> Dict[str, Any]:
        """Generate an anonymized version of the record."""
        if not self.record:
            self.parse()
        
        # This would use the anonymization functions from health_md
        # For now, return basic anonymization info
        privacy_level = self.record.get_privacy_level()
        
        return {
            'original_privacy_level': privacy_level,
            'anonymization_available': privacy_level != 'anonymous',
            'message': 'Anonymization feature coming soon in health-md v1.1'
        }
    
    def generate_insights(self) -> Dict[str, Any]:
        """Generate clinical insights and observations."""
        if not self.record:
            self.parse()
        
        insights = {
            'medication_insights': [],
            'lab_trends': [],
            'care_gaps': [],
            'risk_factors': []
        }
        
        # Medication insights
        medications = self.record.get_current_medications()
        if medications:
            diabetes_meds = [m for m in medications if 'diabetes' in (m.indication or '').lower()]
            if diabetes_meds:
                insights['medication_insights'].append(
                    f"Patient is on {len(diabetes_meds)} diabetes medication(s)"
                )
        
        # Lab trends
        recent_labs = self.record.get_recent_labs(180)
        a1c_labs = [l for l in recent_labs if 'a1c' in l.name.lower() or 'hemoglobin a1c' in l.name.lower()]
        if len(a1c_labs) >= 2:
            trends = [l.trend for l in a1c_labs if l.trend]
            if '↓' in trends:
                insights['lab_trends'].append("HbA1c trending downward - good glycemic control")
        
        # Care gaps (basic heuristics)
        if medications and not recent_labs:
            insights['care_gaps'].append("Patient on medications but no recent lab monitoring")
        
        # Risk factors from demographics and conditions
        if self.record.demographics.get('age', '').startswith('5') or 'diabetes' in str(self.record.medical_history).lower():
            insights['risk_factors'].append("Increased cardiovascular risk - consider lipid monitoring")
        
        return insights
    
    def to_json(self) -> str:
        """Convert the entire health record to JSON format."""
        if not self.record:
            self.parse()
        
        return json.dumps(self.record.to_dict(), indent=2, default=str)


def main():
    """Main CLI interface for the Health.md parser skill."""
    parser = argparse.ArgumentParser(
        description="Parse and analyze Health.md files",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python parse_health.py patient.health.md
  python parse_health.py patient.health.md --summary
  python parse_health.py patient.health.md --medications --labs
  python parse_health.py patient.health.md --validate --json
  python parse_health.py patient.health.md --insights --timeline
        """
    )
    
    parser.add_argument('file', help='Path to Health.md file')
    
    # Output options
    parser.add_argument('--summary', action='store_true', 
                       help='Generate LLM-optimized summary')
    parser.add_argument('--medications', action='store_true',
                       help='Extract medication information')
    parser.add_argument('--labs', action='store_true',
                       help='Extract lab results (last 90 days)')
    parser.add_argument('--conditions', action='store_true',
                       help='Extract medical conditions')
    parser.add_argument('--timeline', action='store_true',
                       help='Extract clinical timeline (last 365 days)')
    parser.add_argument('--insights', action='store_true',
                       help='Generate clinical insights')
    parser.add_argument('--validate', action='store_true',
                       help='Validate file format')
    parser.add_argument('--anonymize', action='store_true',
                       help='Generate anonymized version')
    parser.add_argument('--json', action='store_true',
                       help='Output full record as JSON')
    
    # Options
    parser.add_argument('--lab-days', type=int, default=90,
                       help='Days back to include lab results (default: 90)')
    parser.add_argument('--timeline-days', type=int, default=365,
                       help='Days back to include timeline events (default: 365)')
    
    args = parser.parse_args()
    
    try:
        # Create parser instance
        health_parser = HealthMdParser(args.file)
        
        # If no specific output requested, show summary
        if not any([args.summary, args.medications, args.labs, args.conditions, 
                   args.timeline, args.insights, args.validate, args.anonymize, args.json]):
            args.summary = True
        
        output = {}
        
        # Validation
        if args.validate:
            validation = health_parser.validate()
            output['validation'] = validation
            
            if not validation['valid']:
                print("❌ Validation failed:", validation['error'])
                return 1
            else:
                print("✅ Health.md file is valid")
                print(f"   Version: {validation['version']}")
                print(f"   Privacy Level: {validation['privacy_level']}")
                if validation['warnings']:
                    print(f"   Warnings: {len(validation['warnings'])}")
        
        # Parse the file (if not already done by validation)
        health_parser.parse()
        
        # Generate requested outputs
        if args.summary:
            output['summary'] = health_parser.get_summary()
            print("📋 LLM-Optimized Summary:")
            print("=" * 50)
            print(output['summary'])
            print("=" * 50)
        
        if args.medications:
            output['medications'] = health_parser.get_medications()
            meds = output['medications']
            print(f"\n💊 Current Medications ({meds['medication_count']}):")
            for med in meds['medications']:
                print(f"  • {med['name']}")
                if med['dosage']:
                    print(f"    Dosage: {med['dosage']}")
                if med['indication']:
                    print(f"    For: {med['indication']}")
        
        if args.labs:
            output['labs'] = health_parser.get_lab_results(args.lab_days)
            labs = output['labs']
            print(f"\n🔬 Recent Lab Results ({labs['lab_count']} in last {labs['timeframe_days']} days):")
            for lab in labs['labs']:
                trend_symbol = f" {lab['trend']}" if lab['trend'] else ""
                print(f"  • {lab['name']}: {lab['value']}{trend_symbol}")
                if lab['date']:
                    print(f"    Date: {lab['date']}")
        
        if args.conditions:
            output['conditions'] = health_parser.get_conditions()
            conditions = output['conditions']
            print(f"\n🏥 Medical Conditions ({conditions['condition_count']}):")
            for condition in conditions['conditions']:
                onset = f" (since {condition['onset'][:10]})" if condition['onset'] else ""
                print(f"  • {condition['condition']}{onset}")
                if condition['icd_code'] != 'Unknown':
                    print(f"    ICD-10: {condition['icd_code']}")
        
        if args.timeline:
            output['timeline'] = health_parser.get_clinical_timeline(args.timeline_days)
            timeline = output['timeline']
            print(f"\n📅 Clinical Timeline ({timeline['event_count']} events in last {timeline['timeframe_days']} days):")
            for event in timeline['events']:
                date = event['date'][:10] if event['date'] else 'Unknown date'
                print(f"  • {date}: {event['title']}")
                if event['assessment']:
                    print(f"    Assessment: {event['assessment']}")
        
        if args.insights:
            output['insights'] = health_parser.generate_insights()
            insights = output['insights']
            print(f"\n💡 Clinical Insights:")
            
            for category, items in insights.items():
                if items:
                    category_name = category.replace('_', ' ').title()
                    print(f"  {category_name}:")
                    for item in items:
                        print(f"    • {item}")
        
        if args.anonymize:
            output['anonymization'] = health_parser.anonymize_record()
            anon = output['anonymization']
            print(f"\n🔒 Anonymization Info:")
            print(f"  Current Privacy Level: {anon['original_privacy_level']}")
            print(f"  Can Anonymize: {anon['anonymization_available']}")
            print(f"  Status: {anon['message']}")
        
        if args.json:
            print(f"\n📄 Full JSON Export:")
            print(health_parser.to_json())
        
        return 0
        
    except Exception as e:
        print(f"❌ Error processing Health.md file: {e}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())