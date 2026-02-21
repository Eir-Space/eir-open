// EIR File Generator for 1177 Journal Data
// Converts journal entries into structured YAML format for clinical notes exploration

function generateEIRContent(entries) {
  const patientName = document.querySelector('.ic-avatar-box__name')?.textContent || 'Unknown';
  const currentDate = new Date().toISOString();
  
  // Extract date range
  const dates = entries
    .map(entry => entry.date)
    .filter(date => date && date.trim())
    .sort();
  
  const dateRange = {
    start: dates[0] || 'Unknown',
    end: dates[dates.length - 1] || 'Unknown'
  };
  
  // Extract unique healthcare providers
  const providers = [...new Set(entries
    .map(entry => entry.source)
    .filter(source => source && source.trim())
  )];
  
  // Generate EIR structure
  const eirData = {
    metadata: {
      format_version: "1.0",
      created_at: currentDate,
      source: "1177.se Journal",
      patient: {
        name: patientName,
        birth_date: "1986-02-28", // This would need to be extracted from the page
        personal_number: "19860228-0250" // This would need to be extracted from the page
      },
      export_info: {
        total_entries: entries.length,
        date_range: dateRange,
        healthcare_providers: providers
      }
    },
    entries: entries.map((entry, index) => ({
      id: `entry_${String(index + 1).padStart(3, '0')}`,
      date: formatDate(entry.date),
      time: extractTime(entry.text),
      category: entry.category || 'Unknown',
      type: entry.title || 'Unknown',
      provider: {
        name: entry.source || 'Unknown',
        region: extractRegion(entry.source),
        location: entry.source || 'Unknown'
      },
      status: extractStatus(entry.text),
      responsible_person: {
        name: extractResponsiblePerson(entry.text),
        role: extractRole(entry.text)
      },
      content: {
        summary: generateSummary(entry),
        details: entry.text.substring(0, 200) + (entry.text.length > 200 ? '...' : ''),
        notes: extractNotes(entry.text)
      },
      attachments: [],
      tags: generateTags(entry)
    }))
  };
  
  return eirData;
}

function formatDate(dateString) {
  if (!dateString) return 'Unknown';
  
  // Try to parse various date formats
  const cleanDate = dateString.replace(/\s+/g, ' ').trim();
  
  // Look for patterns like "17 mar 2025", "11 jun 2024", etc.
  const monthMap = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'maj': '05', 'jun': '06',
    'jul': '07', 'aug': '08', 'sep': '09', 'okt': '10', 'nov': '11', 'dec': '12'
  };
  
  const dateMatch = cleanDate.match(/(\d{1,2})\s+(\w{3})\s+(\d{4})/);
  if (dateMatch) {
    const [, day, month, year] = dateMatch;
    const monthNum = monthMap[month.toLowerCase()];
    if (monthNum) {
      return `${year}-${monthNum}-${day.padStart(2, '0')}`;
    }
  }
  
  // Look for YYYY-MM-DD format
  const isoMatch = cleanDate.match(/(\d{4}-\d{2}-\d{2})/);
  if (isoMatch) {
    return isoMatch[1];
  }
  
  return cleanDate;
}

function extractTime(text) {
  if (!text) return 'Unknown';
  
  // Look for time patterns like "klockan 10:52", "10:52", etc.
  const timeMatch = text.match(/(?:klockan\s+)?(\d{1,2}:\d{2})/);
  if (timeMatch) {
    return timeMatch[1];
  }
  
  return 'Unknown';
}

function extractRegion(source) {
  if (!source) return 'Unknown';
  
  // Look for region patterns
  if (source.includes('Region Uppsala')) return 'Region Uppsala';
  if (source.includes('Stockholm')) return 'Stockholm';
  if (source.includes('Danderyd')) return 'Danderyd';
  if (source.includes('Västerbotten')) return 'Västerbotten';
  
  return 'Unknown';
}

function extractStatus(text) {
  if (!text) return 'Unknown';
  
  if (text.includes('Nytt')) return 'Nytt';
  if (text.includes('Osignerad')) return 'Osignerad';
  if (text.includes('Signerad')) return 'Signerad';
  
  return 'Unknown';
}

function extractResponsiblePerson(text) {
  if (!text) return 'Unknown';
  
  // Look for patterns like "Antecknad av Therese Karlberg (Distriktssköterska)"
  const personMatch = text.match(/Antecknad av ([^(]+)\s*\(/);
  if (personMatch) {
    return personMatch[1].trim();
  }
  
  // Look for other patterns
  const otherMatch = text.match(/(?:Vaccinerad av|Ordinatör|Ansvarig för kontakten)\s+([^(]+)/);
  if (otherMatch) {
    return otherMatch[1].trim();
  }
  
  return 'Unknown';
}

function extractRole(text) {
  if (!text) return 'Unknown';
  
  // Look for role patterns in parentheses
  const roleMatch = text.match(/\(([^)]+)\)/);
  if (roleMatch) {
    return roleMatch[1].trim();
  }
  
  return 'Unknown';
}

function generateSummary(entry) {
  const category = entry.category || '';
  const type = entry.title || '';
  
  if (category && type) {
    return `${category} - ${type}`;
  } else if (category) {
    return category;
  } else if (type) {
    return type;
  }
  
  return 'Journal Entry';
}

function extractNotes(text) {
  if (!text) return [];
  
  const notes = [];
  const lines = text.split('\n').map(line => line.trim()).filter(line => line);
  
  // Look for specific note patterns
  for (const line of lines) {
    if (line.includes(':') && !line.includes('http') && line.length > 10) {
      notes.push(line);
    }
  }
  
  return notes.slice(0, 10); // Limit to 10 notes per entry
}

function generateTags(entry) {
  const tags = [];
  
  // Category-based tags
  if (entry.category) {
    tags.push(entry.category.toLowerCase());
  }
  
  // Content-based tags
  const text = entry.text || '';
  
  if (text.includes('akut') || text.includes('Akut')) tags.push('akut');
  if (text.includes('vaccination') || text.includes('Vaccination')) tags.push('vaccination');
  if (text.includes('tandvård') || text.includes('Tandvård')) tags.push('tandvård');
  if (text.includes('diagnos') || text.includes('Diagnos')) tags.push('diagnos');
  if (text.includes('besök') || text.includes('Besök')) tags.push('besök');
  if (text.includes('osignerad') || text.includes('Osignerad')) tags.push('osignerad');
  if (text.includes('distriktssköterska')) tags.push('distriktssköterska');
  if (text.includes('tandläkare')) tags.push('tandläkare');
  if (text.includes('läkare')) tags.push('läkare');
  
  // Remove duplicates and return
  return [...new Set(tags)];
}

function convertToYAML(obj) {
  // Simple YAML conversion - in production, use a proper YAML library
  function yamlify(obj, indent = 0) {
    const spaces = '  '.repeat(indent);
    
    if (Array.isArray(obj)) {
      if (obj.length === 0) return '[]';
      return obj.map(item => `${spaces}- ${yamlify(item, indent + 1)}`).join('\n');
    }
    
    if (typeof obj === 'object' && obj !== null) {
      const entries = Object.entries(obj);
      if (entries.length === 0) return '{}';
      
      return entries.map(([key, value]) => {
        if (typeof value === 'object' && value !== null) {
          return `${spaces}${key}:\n${yamlify(value, indent + 1)}`;
        } else {
          const valueStr = typeof value === 'string' ? `"${value}"` : value;
          return `${spaces}${key}: ${valueStr}`;
        }
      }).join('\n');
    }
    
    return typeof obj === 'string' ? `"${obj}"` : obj;
  }
  
  return yamlify(obj);
}

// Export functions for use in content.js
window.EIRGenerator = {
  generateEIRContent,
  convertToYAML
};
