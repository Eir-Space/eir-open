"""
Health.md Parser Library

A Python library for parsing and working with Health.md files - 
the open standard for LLM-optimized healthcare data.

Example usage:
    from health_md import HealthRecord
    
    # Load and parse a health.md file
    record = HealthRecord.from_file('patient.health.md')
    
    # Extract key information
    medications = record.get_current_medications()
    recent_labs = record.get_recent_labs(days=30)
    
    # Generate LLM-optimized context
    context = record.to_llm_context()
"""

from .parser import HealthRecord
from .validators import validate_health_md, HealthMdValidationError
from .privacy import anonymize_record, PrivacyLevel
from .exporters import export_to_fhir, export_to_json

__version__ = "1.0.0"
__author__ = "Birger Moëll"
__email__ = "birger.moell@uu.se"

__all__ = [
    'HealthRecord',
    'validate_health_md',
    'HealthMdValidationError',
    'anonymize_record',
    'PrivacyLevel',
    'export_to_fhir',
    'export_to_json'
]