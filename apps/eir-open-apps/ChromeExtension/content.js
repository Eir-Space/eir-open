// Initialize data transfer manager
let dataTransferManager = null;

// Check if user is logged in by looking for specific elements on the page
function isUserLoggedIn() {
  // Check for common indicators that user is logged in
  // This might need adjustment based on the actual site structure
  const loginIndicators = [
    document.querySelector('[data-testid="user-menu"]'),
    document.querySelector('.user-profile'),
    document.querySelector('.logout-button'),
    document.querySelector('[href*="logout"]'),
    document.querySelector('.user-info'),
    // Add more specific selectors for 1177.se
    document.querySelector('[class*="user"]'),
    document.querySelector('[class*="login"]'),
    document.querySelector('[class*="profile"]'),
    document.querySelector('a[href*="logout"]'),
    document.querySelector('button[class*="logout"]'),
    // Check if we're on a page that requires login (not the login page itself)
    !window.location.href.includes('login') && !window.location.href.includes('auth')
  ];
  
  const isLoggedIn = loginIndicators.some(indicator => indicator !== null);
  
  // Debug logging
  console.log('1177 Extension Debug:');
  console.log('Current URL:', window.location.href);
  console.log('Login indicators found:', loginIndicators.filter(indicator => indicator !== null));
  console.log('Is logged in:', isLoggedIn);
  
  return isLoggedIn;
}

// Create the floating button
function createFloatingButton() {
  // Always show button on 1177.se domain
  if (!window.location.href.includes('1177.se')) {
    console.log('Not on 1177.se domain, button not created');
    return;
  }
  
  console.log('Creating floating button on 1177.se');

  // Check if button already exists
  if (document.getElementById('journal-downloader-btn')) {
    return;
  }

  const button = document.createElement('div');
  button.id = 'journal-downloader-btn';
  button.className = 'floating-button';
  button.innerHTML = `
    <div class="button-content">
      <svg width="24" height="24" viewBox="0 0 24 24" fill="none" xmlns="http://www.w3.org/2000/svg">
        <path d="M12 2L2 7L12 12L22 7L12 2Z" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
        <path d="M2 17L12 22L22 17" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
        <path d="M2 12L12 17L22 12" stroke="currentColor" stroke-width="2" stroke-linejoin="round"/>
      </svg>
      <span class="button-text">Download Journals</span>
    </div>
  `;

  // Add click event for main button
  button.addEventListener('click', function(e) {
    e.stopPropagation();
    downloadAllJournalContent();
  });

  // Make button draggable
  makeDraggable(button);

  // Position button on the right side
  button.style.position = 'fixed';
  button.style.right = '20px';
  button.style.top = '50%';
  button.style.transform = 'translateY(-50%)';
  button.style.zIndex = '999999';

  document.body.appendChild(button);
  console.log('1177 Extension: Button created and added to page!');
  console.log('Button position:', button.style.right, button.style.top);
}

// Make element draggable
function makeDraggable(element) {
  let isDragging = false;
  let currentX;
  let currentY;
  let initialX;
  let initialY;
  let xOffset = 0;
  let yOffset = 0;

  element.addEventListener('mousedown', dragStart);
  document.addEventListener('mousemove', drag);
  document.addEventListener('mouseup', dragEnd);

  function dragStart(e) {
    if (e.target.closest('.button-content')) {
      return; // Don't drag if clicking on the button content
    }
    
    initialX = e.clientX - xOffset;
    initialY = e.clientY - yOffset;

    if (e.target === element) {
      isDragging = true;
      element.style.cursor = 'grabbing';
    }
  }

  function drag(e) {
    if (isDragging) {
      e.preventDefault();
      currentX = e.clientX - initialX;
      currentY = e.clientY - initialY;

      xOffset = currentX;
      yOffset = currentY;

      element.style.transform = `translate(${currentX}px, ${currentY}px)`;
    }
  }

  function dragEnd(e) {
    initialX = currentX;
    initialY = currentY;
    isDragging = false;
    element.style.cursor = 'grab';
  }
}

// Initialize the extension
function init() {
  // Wait for page to be fully loaded
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', createFloatingButton);
  } else {
    createFloatingButton();
  }

  // Also check periodically in case the page loads dynamically
  setTimeout(createFloatingButton, 2000);
}

// Function to download all journal content
async function downloadAllJournalContent() {
  console.log('Starting journal content download...');
  
  // Show loading state
  const button = document.getElementById('journal-downloader-btn');
  if (button) {
    button.style.opacity = '0.7';
    button.querySelector('.button-text').textContent = 'Downloading...';
  }

  try {
    // Wait for journal data to load
    await waitForJournalData();
    
    // Load all available journal entries first
    await loadAllJournalEntries();
    
    // Get all journal entries
    const journalEntries = await getAllJournalEntries();
    
    // Initialize data transfer manager if not already done
    if (!dataTransferManager) {
      dataTransferManager = new DataTransferManager();
    }
    
    // Store EIR data for transfer
    await dataTransferManager.storeEirData(journalEntries);
    
    // Format the content
    const formattedContent = formatJournalContent(journalEntries);
    
    // Generate EIR format
    const eirData = generateEIRContent(journalEntries);
    const eirYAML = convertToYAML(eirData);
    
    // Generate README
    const readmeContent = generateReadme();

    // Download all files
    downloadTextFile(formattedContent, 'journal-content.txt');
    downloadTextFile(eirYAML, 'journal-content.eir');
    downloadTextFile(readmeContent, 'README.md');

    // Download EirViewer app
    downloadExternalFile(
      'https://github.com/BirgerMoell/eir-chrome-plugin/raw/main/releases/EirViewer-macOS.dmg',
      'EirViewer-macOS.dmg'
    );

    console.log('Journal download completed successfully!');

    // Reset button state
    if (button) {
      button.style.opacity = '1';
      button.querySelector('.button-text').textContent = 'Downloaded!';
      setTimeout(() => {
        button.querySelector('.button-text').textContent = 'Download Journals';
      }, 3000);
    }
    
  } catch (error) {
    console.error('Error downloading journal content:', error);
    alert('Error downloading journal content. Please try again.');
    
    // Reset button state
    if (button) {
      button.style.opacity = '1';
      button.querySelector('.button-text').textContent = 'Download Journals';
    }
  }
}

// Wait for journal data to load
function waitForJournalData() {
  return new Promise((resolve) => {
    const checkForData = () => {
      const timelineView = document.getElementById('timeline-view');
      if (timelineView && timelineView.children.length > 0) {
        console.log('Journal data loaded');
        resolve();
      } else {
        console.log('Waiting for journal data...');
        setTimeout(checkForData, 1000);
      }
    };
    
    // Start checking immediately
    checkForData();
    
    // Also check after a delay in case data loads later
    setTimeout(() => {
      console.log('Timeout reached, proceeding with available data');
      resolve();
    }, 10000);
  });
}

// Load all available journal entries by clicking "Load More" button
async function loadAllJournalEntries() {
  console.log('Loading all available journal entries...');
  
  let loadMoreClicks = 0;
  const maxClicks = 50; // Safety limit to prevent infinite loops
  
  while (loadMoreClicks < maxClicks) {
    // Find the load more button
    const loadMoreButtons = document.getElementsByClassName("load-more ic-button ic-button--secondary iu-px-xxl");
    
    if (loadMoreButtons.length === 0) {
      console.log('No more "Load More" button found - all entries loaded');
      break;
    }
    
    const loadMoreButton = loadMoreButtons[0];
    
    // Check if button is visible and not disabled
    if (loadMoreButton.offsetParent === null || loadMoreButton.disabled) {
      console.log('Load More button is hidden or disabled - all entries loaded');
      break;
    }
    
    try {
      console.log(`Clicking "Load More" button (click ${loadMoreClicks + 1})`);
      loadMoreButton.click();
      loadMoreClicks++;
      
      // Wait for new content to load
      await new Promise(resolve => setTimeout(resolve, 2000));
      
      // Check if new entries were loaded by counting current entries
      const currentEntries = document.getElementsByClassName("icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview");
      console.log(`Currently have ${currentEntries.length} journal entries loaded`);
      
    } catch (error) {
      console.log('Error clicking Load More button:', error);
      break;
    }
  }
  
  if (loadMoreClicks >= maxClicks) {
    console.log('Reached maximum load more clicks limit');
  }
  
  console.log(`Finished loading entries after ${loadMoreClicks} clicks`);
}

// Get all journal entries by expanding them and extracting content
async function getAllJournalEntries() {
  const entries = [];
  
  // Find all clickable journal entry elements using the correct selector
  const clickableElements = document.getElementsByClassName("icon-angle-down nu-list-nav-icon nu-list-nav-icon--journal-overview");
  
  console.log(`Found ${clickableElements.length} journal entries to expand`);
  
  // Click each entry to expand it
  for (let i = 0; i < clickableElements.length; i++) {
    const element = clickableElements[i];
    
    try {
      console.log(`Expanding entry ${i + 1}/${clickableElements.length}`);
      
      // Click to expand the entry
      element.click();
      
      // Wait for content to load after clicking (very fast since it's just DOM manipulation)
      await new Promise(resolve => setTimeout(resolve, 100));
      
      // Find the parent container of this entry to extract content
      const parentContainer = element.closest('.ic-block-list__item, .journal-entry, .timeline-item, [data-cy-id]') || element.parentElement;
      
      if (parentContainer) {
        const entryContent = extractEntryContent(parentContainer);
        if (entryContent) {
          entries.push(entryContent);
          console.log(`Extracted content from entry ${i + 1}`);
        }
      }
      
    } catch (error) {
      console.log(`Error processing entry ${i + 1}:`, error);
    }
  }
  
  // Also try to get any visible content that might not need clicking
  const timelineView = document.getElementById('timeline-view');
  if (timelineView) {
    const visibleEntries = timelineView.querySelectorAll('.ic-block-list__item, .journal-entry, .timeline-item');
    for (const entry of visibleEntries) {
      const content = extractEntryContent(entry);
      if (content && !entries.some(e => e.text === content.text)) {
        entries.push(content);
      }
    }
  }
  
  console.log(`Total extracted ${entries.length} journal entries`);
  return entries;
}

// Download files only (without transferring to eir.space)
async function downloadFilesOnly() {
  console.log('Downloading files only...');
  
  const button = document.getElementById('journal-downloader-btn');
  if (button) {
    button.style.opacity = '0.7';
    button.querySelector('.button-text').textContent = 'Downloading...';
  }

  try {
    // Wait for journal data to load
    await waitForJournalData();
    
    // Load all available journal entries first
    await loadAllJournalEntries();
    
    // Get all journal entries
    const journalEntries = await getAllJournalEntries();
    
    // Format the content
    const formattedContent = formatJournalContent(journalEntries);
    
    // Generate EIR format
    const eirData = generateEIRContent(journalEntries);
    const eirYAML = convertToYAML(eirData);
    
    // Download both files
    downloadTextFile(formattedContent, 'journal-content.txt');
    downloadTextFile(eirYAML, 'journal-content.eir');
    
    console.log('Files downloaded successfully!');
    
    // Reset button state
    if (button) {
      button.style.opacity = '1';
      button.querySelector('.button-text').textContent = 'Files Downloaded!';
      setTimeout(() => {
        button.querySelector('.button-text').textContent = 'Download Journals';
      }, 3000);
    }
    
  } catch (error) {
    console.error('Error downloading files:', error);
    alert('Error downloading files. Please try again.');
    
    // Reset button state
    if (button) {
      button.style.opacity = '1';
      button.querySelector('.button-text').textContent = 'Download Journals';
    }
  }
}

// Transfer data to eir.space
async function viewOnEirSpace() {
  console.log('Transferring data to eir.space...');
  
  const button = document.getElementById('journal-downloader-btn');
  if (button) {
    button.style.opacity = '0.7';
    button.querySelector('.button-text').textContent = 'Opening eir.space...';
  }

  try {
    // Check if data transfer manager is available
    if (!dataTransferManager) {
      throw new Error('No data available. Please download journals first.');
    }

    // Transfer data to eir.space
    const eirUrl = await dataTransferManager.transferToEirSpace();
    
    console.log('Data transferred to eir.space successfully!');
    console.log('eir.space URL:', eirUrl);
    
    // Reset button state
    if (button) {
      button.style.opacity = '1';
      button.querySelector('.button-text').textContent = 'Opened eir.space!';
      setTimeout(() => {
        button.querySelector('.button-text').textContent = 'Download Journals';
      }, 3000);
    }
    
  } catch (error) {
    console.error('Error transferring to eir.space:', error);
    alert(`Error opening eir.space: ${error.message}`);
    
    // Reset button state
    if (button) {
      button.style.opacity = '1';
      button.querySelector('.button-text').textContent = 'Download Journals';
    }
  }
}

// Extract content from a journal entry element
function extractEntryContent(element) {
  const content = {
    date: '',
    title: '',
    text: '',
    category: '',
    source: '',
    details: ''
  };
  
  // Get all text content first
  const textContent = element.textContent || element.innerText || '';
  content.text = textContent.trim();
  
  // Try to parse the content more intelligently
  const lines = textContent.split('\n').map(line => line.trim()).filter(line => line);
  
  // Look for date patterns in the text
  for (const line of lines) {
    // Look for Swedish date patterns like "17 mar 2025", "11 jun 2024"
    const dateMatch = line.match(/(\d{1,2})\s+(jan|feb|mar|apr|maj|jun|jul|aug|sep|okt|nov|dec)\s+(\d{4})/i);
    if (dateMatch && !content.date) {
      content.date = line;
      break;
    }
    
    // Look for ISO date patterns
    const isoDateMatch = line.match(/(\d{4}-\d{2}-\d{2})/);
    if (isoDateMatch && !content.date) {
      content.date = line;
      break;
    }
  }
  
  // Try to find title - look for common patterns
  const titleElement = element.querySelector('.title, .journal-title, .entry-title, h3, h4, .ic-block-list__title, .nc-journal-title');
  if (titleElement) {
    content.title = titleElement.textContent.trim();
  } else {
    // Try to extract title from text content
    for (const line of lines) {
      if (line.length > 5 && line.length < 100 && !line.match(/\d{4}-\d{2}-\d{2}/) && !line.match(/\d{1,2}\s+\w{3}\s+\d{4}/)) {
        content.title = line;
        break;
      }
    }
  }
  
  // Try to find category - look for common patterns
  const categoryElement = element.querySelector('.category, .journal-category, .entry-category, .ic-badge, .nc-category');
  if (categoryElement) {
    content.category = categoryElement.textContent.trim();
  } else {
    // Try to extract category from text content
    const categoryKeywords = ['Vårdkontakter', 'Anteckningar', 'Diagnoser', 'Vaccinationer', 'Läkemedel', 'Provsvar', 'Remisser', 'Tillväxt', 'Uppmärksamhetsinformation', 'Vaccinationer', 'Vårdplaner'];
    for (const line of lines) {
      for (const keyword of categoryKeywords) {
        if (line.includes(keyword)) {
          content.category = keyword;
          break;
        }
      }
      if (content.category) break;
    }
  }
  
  // Try to find source/provider
  const sourceElement = element.querySelector('.source, .provider, .journal-source, .nc-source');
  if (sourceElement) {
    content.source = sourceElement.textContent.trim();
  } else {
    // Try to extract provider from text content
    const providerKeywords = ['vårdcentral', 'sjukhus', 'akut', 'tandvård', 'folktandvården', 'SLSO', 'region', 'stockholm', 'uppsala', 'danderyd'];
    for (const line of lines) {
      for (const keyword of providerKeywords) {
        if (line.toLowerCase().includes(keyword)) {
          content.source = line;
          break;
        }
      }
      if (content.source) break;
    }
  }
  
  // Look for detailed content that appears after expansion
  const detailsElement = element.querySelector('.journal-details, .entry-details, .nc-details, .ic-block-list__content');
  if (detailsElement) {
    content.details = detailsElement.textContent.trim();
  }
  
  // Clean up the text content to remove navigation elements
  const cleanText = content.text
    .replace(/\s+/g, ' ') // Replace multiple spaces with single space
    .replace(/\n\s*\n/g, '\n') // Remove empty lines
    .trim();
  
  content.text = cleanText;
  
  // Only return if we have some meaningful content
  if (content.text && content.text.length > 20) {
    return content;
  }
  
  return null;
}

// Format all journal content into a readable text format
function formatJournalContent(entries) {
  const header = `
=== 1177 JOURNAL DOWNLOAD ===
Downloaded: ${new Date().toLocaleString('sv-SE')}
Patient: ${document.querySelector('.ic-avatar-box__name')?.textContent || 'Unknown'}
Total Entries: ${entries.length}

========================================

`;

  let content = header;
  
  entries.forEach((entry, index) => {
    content += `\n--- ENTRY ${index + 1} ---\n`;
    
    if (entry.date) {
      content += `Date: ${entry.date}\n`;
    }
    
    if (entry.title) {
      content += `Title: ${entry.title}\n`;
    }
    
    if (entry.category) {
      content += `Category: ${entry.category}\n`;
    }
    
    if (entry.source) {
      content += `Source: ${entry.source}\n`;
    }
    
    if (entry.details) {
      content += `\nDetails:\n${entry.details}\n`;
    }
    
    content += `\nFull Content:\n${entry.text}\n`;
    content += `\n${'='.repeat(50)}\n`;
  });
  
  // Add page metadata
  content += `\n\n=== PAGE METADATA ===\n`;
  content += `URL: ${window.location.href}\n`;
  content += `Download Time: ${new Date().toISOString()}\n`;
  content += `User Agent: ${navigator.userAgent}\n`;
  
  return content;
}

// Generate README explaining eir.space
function generateReadme() {
  return `# Your Medical Records from 1177.se

These files were downloaded from your Swedish medical journal at journalen.1177.se
using the Eir Chrome Extension.

## What's in this download

- **journal-content.txt** - A plain text version of your medical records, easy to read
- **journal-content.eir** - Your records in the structured EIR format (YAML), designed for
  import into health apps
- **EirViewer-macOS.dmg** - The Eir Viewer desktop app for macOS (unzip and run)
- **README.md** - This file

## View your records with Eir Viewer (Recommended)

Eir Viewer is included in this download! To get started:

1. Open **EirViewer-macOS.dmg**
2. Drag **EirViewer** to the **Applications** folder
3. Open **EirViewer** from Applications, then open the \`journal-content.eir\` file
4. If macOS says the app is "damaged", open Terminal and run:
   \`\`\`
   xattr -cr /path/to/EirViewer.app
   \`\`\`

### What Eir Viewer offers
- **Timeline view** with search and filters
- **"Explain with AI"** button on each entry — understand medical terms instantly
- **Chat threads** — ask follow-up questions, conversations are saved per person
- **Markdown rendering** — AI responses are nicely formatted
- **100% local** — your records never leave your computer

## View your records on Eir.Space

You can also upload your \`.eir\` file to **https://eir.space** to view records in your browser.

1. Go to **https://eir.space**
2. Click **"Load EIR File"** and select the \`journal-content.eir\` file
3. Your records will be loaded locally in your browser - no data is uploaded to any server

## Privacy

Your health data is yours. Both Eir Viewer and Eir.Space process everything locally.
No medical data is stored on any server. The AI chat sends only the specific context
you're asking about, and nothing is retained after your session.

## Learn more

- Source code: https://github.com/BirgerMoell/eir-chrome-plugin
- Eir.Space: https://eir.space
`;
}

// Download content as text file
function downloadTextFile(content, filename) {
  const blob = new Blob([content], { type: 'text/plain;charset=utf-8' });
  const url = URL.createObjectURL(blob);
  
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.style.display = 'none';
  
  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);
  
  URL.revokeObjectURL(url);
  
  console.log(`Downloaded ${filename} (${content.length} characters)`);
}

// Download a file from an external URL
function downloadExternalFile(url, filename) {
  const link = document.createElement('a');
  link.href = url;
  link.download = filename;
  link.style.display = 'none';

  document.body.appendChild(link);
  link.click();
  document.body.removeChild(link);

  console.log(`Initiated download of ${filename} from ${url}`);
}

// EIR File Generator Functions
function generateEIRContent(entries) {
  const patientName = document.querySelector('.ic-avatar-box__name')?.textContent || 'Unknown';
  const currentDate = new Date().toISOString();
  
  // Extract and clean date range
  const validDates = entries
    .map(entry => formatDate(entry.date))
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
  
  // Clean the date string
  const cleanDate = dateString.replace(/\s+/g, ' ').trim();
  
  // Look for patterns like "17 mar 2025", "11 jun 2024", etc.
  const monthMap = {
    'jan': '01', 'feb': '02', 'mar': '03', 'apr': '04', 'maj': '05', 'jun': '06',
    'jul': '07', 'aug': '08', 'sep': '09', 'okt': '10', 'nov': '11', 'dec': '12'
  };
  
  // First try to find a clean date pattern
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
  
  // Look for YYYY-MM-DD in the beginning of the string
  const isoStartMatch = cleanDate.match(/^(\d{4}-\d{2}-\d{2})/);
  if (isoStartMatch) {
    return isoStartMatch[1];
  }
  
  // If the date string contains a lot of text, try to extract just the date part
  if (cleanDate.length > 20) {
    // Look for date patterns within longer strings
    const embeddedDateMatch = cleanDate.match(/(\d{1,2})\s+(\w{3})\s+(\d{4})/);
    if (embeddedDateMatch) {
      const [, day, month, year] = embeddedDateMatch;
      const monthNum = monthMap[month.toLowerCase()];
      if (monthNum) {
        return `${year}-${monthNum}-${day.padStart(2, '0')}`;
      }
    }
  }
  
  // If we can't parse it, return Unknown
  return 'Unknown';
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
  function escapeYaml(str) {
    if (str === null || str === undefined) return '""';
    str = String(str);
    if (str.includes('"') || str.includes('\n') || str.includes(':') || str.includes('#')) {
      return `"${str.replace(/\\/g, '\\\\').replace(/"/g, '\\"')}"`;
    }
    return `"${str}"`;
  }

  function yamlify(obj, indent = 0) {
    const spaces = '  '.repeat(indent);

    if (Array.isArray(obj)) {
      if (obj.length === 0) return '[]';
      return obj.map(item => {
        if (typeof item === 'object' && item !== null) {
          const inner = Object.entries(item);
          if (inner.length === 0) return `${spaces}- {}`;
          const [firstKey, firstVal] = inner[0];
          let result = `${spaces}- ${firstKey}: ${formatValue(firstVal, indent + 2)}`;
          for (let i = 1; i < inner.length; i++) {
            const [key, val] = inner[i];
            result += `\n${spaces}  ${key}: ${formatValue(val, indent + 2)}`;
          }
          return result;
        } else {
          return `${spaces}- ${escapeYaml(item)}`;
        }
      }).join('\n');
    }

    if (typeof obj === 'object' && obj !== null) {
      const entries = Object.entries(obj);
      if (entries.length === 0) return '{}';
      return entries.map(([key, value]) => {
        return `${spaces}${key}: ${formatValue(value, indent + 1)}`;
      }).join('\n');
    }

    return escapeYaml(obj);
  }

  function formatValue(value, indent) {
    const spaces = '  '.repeat(indent);
    if (value === null || value === undefined) return '""';
    if (Array.isArray(value)) {
      if (value.length === 0) return '[]';
      return '\n' + yamlify(value, indent);
    }
    if (typeof value === 'object') {
      return '\n' + yamlify(value, indent);
    }
    return escapeYaml(value);
  }

  return yamlify(obj);
}

// Start the extension
init();
