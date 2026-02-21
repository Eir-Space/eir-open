/**
 * Data Transfer Module for Chrome Plugin
 * Handles secure data transfer to eir.space using PostMessage API
 */

class DataTransferManager {
  constructor() {
    this.dataKey = null;
    this.eirData = null;
    this.eirSpaceUrl = 'https://eir.space';
    this.messageHandlers = new Map();
    
    this.init();
  }

  /**
   * Initialize the data transfer manager
   */
  init() {
    this.setupMessageListener();
    console.log('DataTransferManager initialized');
  }

  /**
   * Generate a unique key for data storage
   */
  generateDataKey() {
    const timestamp = Date.now();
    const random = Math.random().toString(36).substring(2, 15);
    return `eir_data_${timestamp}_${random}`;
  }

  /**
   * Store EIR data locally and prepare for transfer
   */
  async storeEirData(journalEntries) {
    try {
      // Generate unique key
      this.dataKey = this.generateDataKey();
      
      // Generate EIR content
      this.eirData = this.generateEIRContent(journalEntries);
      
      // Store in local storage
      localStorage.setItem(this.dataKey, JSON.stringify(this.eirData));
      
      // Set expiration (24 hours)
      const expiration = Date.now() + (24 * 60 * 60 * 1000);
      localStorage.setItem(`${this.dataKey}_expires`, expiration.toString());
      
      console.log(`EIR data stored with key: ${this.dataKey}`);
      return this.dataKey;
      
    } catch (error) {
      console.error('Error storing EIR data:', error);
      throw error;
    }
  }

  /**
   * Transfer data to eir.space using PostMessage
   */
  async transferToEirSpace() {
    if (!this.dataKey || !this.eirData) {
      throw new Error('No data available for transfer');
    }

    try {
      // Open eir.space in new tab with data key
      const eirUrl = `${this.eirSpaceUrl}/view?key=${this.dataKey}`;
      const eirTab = window.open(eirUrl, '_blank');
      
      if (!eirTab) {
        throw new Error('Failed to open eir.space tab. Please check popup blockers.');
      }

      // Wait for eir.space to load and request data
      this.waitForDataRequest(eirTab);
      
      return eirUrl;
      
    } catch (error) {
      console.error('Error transferring to eir.space:', error);
      throw error;
    }
  }

  /**
   * Wait for eir.space to request data via PostMessage
   */
  waitForDataRequest(eirTab) {
    const checkInterval = setInterval(() => {
      try {
        // Check if tab is still open
        if (eirTab.closed) {
          clearInterval(checkInterval);
          return;
        }

        // Try to send a ping to check if eir.space is ready
        eirTab.postMessage({
          type: 'EIR_PLUGIN_PING',
          key: this.dataKey
        }, this.eirSpaceUrl);
        
      } catch (error) {
        // Tab might not be ready yet, continue waiting
        console.log('Waiting for eir.space to load...');
      }
    }, 1000);

    // Stop checking after 30 seconds
    setTimeout(() => {
      clearInterval(checkInterval);
    }, 30000);
  }

  /**
   * Setup PostMessage listener for data requests
   */
  setupMessageListener() {
    window.addEventListener('message', (event) => {
      // Security: Only accept messages from eir.space
      if (event.origin !== this.eirSpaceUrl) {
        return;
      }

      this.handleMessage(event);
    });
  }

  /**
   * Handle incoming messages from eir.space
   */
  handleMessage(event) {
    const { type, key } = event.data;

    switch (type) {
      case 'REQUEST_EIR_DATA':
        this.sendEirData(event.source, key);
        break;
        
      case 'EIR_SPACE_READY':
        // eir.space is ready, send data immediately
        this.sendEirData(event.source, key);
        break;
        
      default:
        console.log('Unknown message type:', type);
    }
  }

  /**
   * Send EIR data to eir.space
   */
  sendEirData(targetWindow, requestedKey) {
    try {
      // Verify the key matches
      if (requestedKey !== this.dataKey) {
        console.error('Key mismatch:', requestedKey, 'vs', this.dataKey);
        return;
      }

      // Get data from local storage
      const storedData = localStorage.getItem(this.dataKey);
      
      if (!storedData) {
        console.error('No data found for key:', this.dataKey);
        return;
      }

      // Send data to eir.space
      targetWindow.postMessage({
        type: 'EIR_DATA_RESPONSE',
        key: this.dataKey,
        data: storedData,
        timestamp: Date.now()
      }, this.eirSpaceUrl);

      console.log('EIR data sent to eir.space successfully');
      
      // Clean up after successful transfer (optional)
      // this.cleanupData();
      
    } catch (error) {
      console.error('Error sending EIR data:', error);
    }
  }

  /**
   * Clean up stored data
   */
  cleanupData() {
    if (this.dataKey) {
      localStorage.removeItem(this.dataKey);
      localStorage.removeItem(`${this.dataKey}_expires`);
      console.log('Data cleaned up for key:', this.dataKey);
    }
  }

  /**
   * Check if stored data has expired
   */
  isDataExpired(key) {
    const expiration = localStorage.getItem(`${key}_expires`);
    if (!expiration) return true;
    
    return Date.now() > parseInt(expiration);
  }

  /**
   * Generate EIR content from journal entries
   * This is a simplified version - you might want to move this to a separate module
   */
  generateEIRContent(entries) {
    const patientName = document.querySelector('.ic-avatar-box__name')?.textContent || 'Unknown';
    const currentDate = new Date().toISOString();
    
    // Extract and clean date range
    const validDates = entries
      .map(entry => this.formatDate(entry.date))
      .filter(date => date && date !== 'Unknown' && date.match(/^\d{4}-\d{2}-\d{2}$/))
      .sort();
    
    const dateRange = {
      start: validDates[0] || 'Unknown',
      end: validDates[validDates.length - 1] || 'Unknown'
    };
    
    // Extract unique healthcare providers
    const providers = [...new Set(entries
      .map(entry => entry.source)
      .filter(source => source && source.trim() && source !== 'Unknown')
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
        date: this.formatDate(entry.date),
        time: this.extractTime(entry.text),
        category: entry.category || 'Unknown',
        type: entry.title || 'Unknown',
        provider: {
          name: entry.source || 'Unknown',
          region: this.extractRegion(entry.source),
          location: entry.source || 'Unknown'
        },
        status: this.extractStatus(entry.text),
        responsible_person: {
          name: this.extractResponsiblePerson(entry.text),
          role: this.extractRole(entry.text)
        },
        content: {
          summary: this.generateSummary(entry),
          details: entry.text.substring(0, 200) + (entry.text.length > 200 ? '...' : ''),
          notes: this.extractNotes(entry.text)
        },
        attachments: [],
        tags: this.generateTags(entry)
      }))
    };
    
    return eirData;
  }

  /**
   * Format date string to ISO format
   */
  formatDate(dateString) {
    if (!dateString) return 'Unknown';
    
    const cleanDate = dateString.replace(/\s+/g, ' ').trim();
    
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
    
    const isoMatch = cleanDate.match(/(\d{4}-\d{2}-\d{2})/);
    if (isoMatch) {
      return isoMatch[1];
    }
    
    return 'Unknown';
  }

  /**
   * Extract time from text
   */
  extractTime(text) {
    if (!text) return 'Unknown';
    
    const timeMatch = text.match(/(?:klockan\s+)?(\d{1,2}:\d{2})/);
    if (timeMatch) {
      return timeMatch[1];
    }
    
    return 'Unknown';
  }

  /**
   * Extract region from source
   */
  extractRegion(source) {
    if (!source) return 'Unknown';
    
    if (source.includes('Region Uppsala')) return 'Region Uppsala';
    if (source.includes('Stockholm')) return 'Stockholm';
    if (source.includes('Danderyd')) return 'Danderyd';
    if (source.includes('Västerbotten')) return 'Västerbotten';
    
    return 'Unknown';
  }

  /**
   * Extract status from text
   */
  extractStatus(text) {
    if (!text) return 'Unknown';
    
    if (text.includes('Nytt')) return 'Nytt';
    if (text.includes('Osignerad')) return 'Osignerad';
    if (text.includes('Signerad')) return 'Signerad';
    
    return 'Unknown';
  }

  /**
   * Extract responsible person from text
   */
  extractResponsiblePerson(text) {
    if (!text) return 'Unknown';
    
    const personMatch = text.match(/Antecknad av ([^(]+)\s*\(/);
    if (personMatch) {
      return personMatch[1].trim();
    }
    
    const otherMatch = text.match(/(?:Vaccinerad av|Ordinatör|Ansvarig för kontakten)\s+([^(]+)/);
    if (otherMatch) {
      return otherMatch[1].trim();
    }
    
    return 'Unknown';
  }

  /**
   * Extract role from text
   */
  extractRole(text) {
    if (!text) return 'Unknown';
    
    const roleMatch = text.match(/\(([^)]+)\)/);
    if (roleMatch) {
      return roleMatch[1].trim();
    }
    
    return 'Unknown';
  }

  /**
   * Generate summary for entry
   */
  generateSummary(entry) {
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

  /**
   * Extract notes from text
   */
  extractNotes(text) {
    if (!text) return [];
    
    const notes = [];
    const lines = text.split('\n').map(line => line.trim()).filter(line => line);
    
    for (const line of lines) {
      if (line.includes(':') && !line.includes('http') && line.length > 10) {
        notes.push(line);
      }
    }
    
    return notes.slice(0, 10);
  }

  /**
   * Generate tags for entry
   */
  generateTags(entry) {
    const tags = [];
    
    if (entry.category) {
      tags.push(entry.category.toLowerCase());
    }
    
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
    
    return [...new Set(tags)];
  }
}

// Export for use in other modules
if (typeof module !== 'undefined' && module.exports) {
  module.exports = DataTransferManager;
} else {
  window.DataTransferManager = DataTransferManager;
}
