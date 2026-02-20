#!/usr/bin/env node

/**
 * US FDA Medication Lookup
 * 
 * Provides lookup for US medications using FDA drug label data.
 * - 99 curated common medications available instantly
 * - 81,212 medications in full database (downloaded on first use)
 */

const fs = require('fs');
const path = require('path');
const os = require('os');

// Paths
const DATA_DIR = path.join(os.homedir(), '.us-medications');
const FULL_MEDS_PATH = path.join(DATA_DIR, 'medications.json');
const INTERACTIONS_PATH = path.join(DATA_DIR, 'interactions.json');
const CURATED_PATH = path.join(__dirname, '..', 'data', 'curated-medications.json');

// GitHub release URLs for full database
const GITHUB_BASE = 'https://github.com/BirgerMoell/us-medications/releases/latest/download';
const MEDS_URL = `${GITHUB_BASE}/medications.json.gz`;
const INTERACTIONS_URL = `${GITHUB_BASE}/interactions.json.gz`;

// Load curated medications (always available)
let CURATED_MEDICATIONS = [];
try {
  CURATED_MEDICATIONS = JSON.parse(fs.readFileSync(CURATED_PATH, 'utf8'));
} catch (e) {
  // Will be empty if file not found
}

// Cache for full database
let fullMedsCache = null;
let interactionsCache = null;

/**
 * Check if full database is downloaded
 */
function isFullDatabaseAvailable() {
  return fs.existsSync(FULL_MEDS_PATH);
}

/**
 * Check if interactions database is downloaded
 */
function isInteractionsDatabaseAvailable() {
  return fs.existsSync(INTERACTIONS_PATH);
}

/**
 * Load full medications database
 */
function loadFullDatabase() {
  if (fullMedsCache) return fullMedsCache;
  if (!isFullDatabaseAvailable()) return null;
  
  try {
    fullMedsCache = JSON.parse(fs.readFileSync(FULL_MEDS_PATH, 'utf8'));
    return fullMedsCache;
  } catch (e) {
    console.error('Error loading full database:', e.message);
    return null;
  }
}

/**
 * Load interactions database
 */
function loadInteractionsDatabase() {
  if (interactionsCache) return interactionsCache;
  if (!isInteractionsDatabaseAvailable()) return null;
  
  try {
    const data = JSON.parse(fs.readFileSync(INTERACTIONS_PATH, 'utf8'));
    interactionsCache = data.interactions || data;
    return interactionsCache;
  } catch (e) {
    console.error('Error loading interactions database:', e.message);
    return null;
  }
}

/**
 * Download full database from GitHub releases
 */
async function downloadDatabase(options = {}) {
  const { silent = false, force = false } = options;
  
  if (!force && isFullDatabaseAvailable()) {
    if (!silent) console.log('Full database already downloaded. Use --force to re-download.');
    return true;
  }
  
  // Create data directory
  if (!fs.existsSync(DATA_DIR)) {
    fs.mkdirSync(DATA_DIR, { recursive: true });
  }
  
  if (!silent) console.log('Downloading full medication database...');
  
  try {
    const { execSync } = require('child_process');
    
    // Download and decompress medications
    if (!silent) console.log('  - medications.json.gz');
    execSync(`curl -sL "${MEDS_URL}" | gunzip > "${FULL_MEDS_PATH}"`, { stdio: silent ? 'ignore' : 'inherit' });
    
    // Download and decompress interactions
    if (!silent) console.log('  - interactions.json.gz');
    execSync(`curl -sL "${INTERACTIONS_URL}" | gunzip > "${INTERACTIONS_PATH}"`, { stdio: silent ? 'ignore' : 'inherit' });
    
    if (!silent) console.log('Download complete!');
    return true;
  } catch (e) {
    if (!silent) console.error('Download failed:', e.message);
    return false;
  }
}

/**
 * Look up a medication by name
 * First checks curated list, then full database
 */
async function lookupMedication(query, options = {}) {
  const queryLower = query.toLowerCase();
  
  // First check curated medications
  const curated = CURATED_MEDICATIONS.find(m => 
    m.name.toLowerCase().includes(queryLower) ||
    (m.altNames && m.altNames.some(a => a.toLowerCase().includes(queryLower))) ||
    (m.substances && m.substances.some(s => s.toLowerCase().includes(queryLower)))
  );
  
  if (curated) {
    return { ...curated, source: 'curated' };
  }
  
  // Try full database
  const fullDb = loadFullDatabase();
  if (!fullDb) {
    // Offer to download
    if (options.autoDownload !== false) {
      console.log(`"${query}" not found in curated list. Full database not available.`);
      console.log('Run: us-medications --download');
    }
    return null;
  }
  
  const full = fullDb.find(m =>
    m.name.toLowerCase().includes(queryLower) ||
    (m.altNames && m.altNames.some(a => a.toLowerCase().includes(queryLower))) ||
    (m.substances && m.substances.some(s => s.toLowerCase().includes(queryLower)))
  );
  
  if (full) {
    return { ...full, source: 'full' };
  }
  
  return null;
}

/**
 * Search medications (returns multiple results)
 */
async function searchMedications(query, options = {}) {
  const { limit = 10 } = options;
  const queryLower = query.toLowerCase();
  const results = [];
  
  // Search curated first
  for (const m of CURATED_MEDICATIONS) {
    if (
      m.name.toLowerCase().includes(queryLower) ||
      (m.altNames && m.altNames.some(a => a.toLowerCase().includes(queryLower))) ||
      (m.substances && m.substances.some(s => s.toLowerCase().includes(queryLower))) ||
      (m.uses && m.uses.toLowerCase().includes(queryLower))
    ) {
      results.push({ ...m, source: 'curated' });
    }
  }
  
  // Search full database if available
  const fullDb = loadFullDatabase();
  if (fullDb) {
    for (const m of fullDb) {
      // Skip if already in results
      if (results.some(r => r.id === m.id)) continue;
      
      if (
        m.name.toLowerCase().includes(queryLower) ||
        (m.altNames && m.altNames.some(a => a.toLowerCase().includes(queryLower))) ||
        (m.substances && m.substances.some(s => s.toLowerCase().includes(queryLower))) ||
        (m.uses && m.uses.toLowerCase().includes(queryLower))
      ) {
        results.push({ ...m, source: 'full' });
      }
      
      if (results.length >= limit) break;
    }
  }
  
  return results.slice(0, limit);
}

/**
 * Look up drug interactions for a medication
 */
async function lookupInteractions(query) {
  const queryLower = query.toLowerCase();
  
  const interactions = loadInteractionsDatabase();
  if (!interactions) {
    console.log('Interactions database not available. Run: us-medications --download');
    return null;
  }
  
  const found = interactions.find(i =>
    i.medicationName.toLowerCase().includes(queryLower) ||
    (i.activeSubstances && i.activeSubstances.some(s => s.toLowerCase().includes(queryLower)))
  );
  
  return found || null;
}

/**
 * Get database statistics
 */
async function getDatabaseStats() {
  const fullDb = loadFullDatabase();
  const interactions = loadInteractionsDatabase();
  
  return {
    curatedMedications: CURATED_MEDICATIONS.length,
    fullDatabaseAvailable: isFullDatabaseAvailable(),
    totalMedications: fullDb ? fullDb.length : CURATED_MEDICATIONS.length,
    interactionsAvailable: isInteractionsDatabaseAvailable(),
    totalInteractions: interactions ? interactions.length : 0,
    dataDirectory: DATA_DIR
  };
}

/**
 * Format medication for display
 */
function formatMedication(med) {
  const lines = [];
  lines.push(`\n📋 ${med.name}`);
  lines.push(`${'─'.repeat(50)}`);
  
  if (med.altNames && med.altNames.length > 0) {
    lines.push(`Also known as: ${med.altNames.join(', ')}`);
  }
  
  if (med.substances && med.substances.length > 0) {
    const cleaned = med.substances.filter(s => !s.includes('Active ingredient'));
    if (cleaned.length > 0) {
      lines.push(`Active ingredients: ${cleaned.join(', ')}`);
    }
  }
  
  if (med.form) {
    lines.push(`Form: ${med.form.trim()}`);
  }
  
  lines.push(`Prescription required: ${med.rx ? 'Yes' : 'No (OTC)'}`);
  
  if (med.uses) {
    lines.push(`\n📖 Uses:\n${med.uses.slice(0, 500)}${med.uses.length > 500 ? '...' : ''}`);
  }
  
  if (med.warnings) {
    lines.push(`\n⚠️ Warnings:\n${med.warnings.slice(0, 500)}${med.warnings.length > 500 ? '...' : ''}`);
  }
  
  if (med.interactions) {
    lines.push(`\n💊 Interactions:\n${med.interactions.slice(0, 300)}${med.interactions.length > 300 ? '...' : ''}`);
  }
  
  lines.push(`\nSource: ${med.source === 'curated' ? 'Curated database' : 'FDA full database'}`);
  
  return lines.join('\n');
}

/**
 * CLI handler
 */
async function main() {
  const args = process.argv.slice(2);
  
  // Help
  if (args.includes('--help') || args.includes('-h') || args.length === 0) {
    console.log(`
US FDA Medication Lookup

Usage: us-medications [options] <medication-name>

Options:
  --search, -s      Search for medications (returns multiple results)
  --interactions    Look up drug interactions for a medication
  --list            List curated medications
  --stats           Show database statistics
  --download        Download full database (~45MB compressed)
  --force           Force re-download of database
  --help, -h        Show this help

Examples:
  us-medications "lisinopril"
  us-medications --search "blood pressure"
  us-medications --interactions "warfarin"
  us-medications --stats
`);
    return;
  }
  
  // Stats
  if (args.includes('--stats')) {
    const stats = await getDatabaseStats();
    console.log('\n📊 Database Statistics');
    console.log('─'.repeat(40));
    console.log(`Curated medications: ${stats.curatedMedications}`);
    console.log(`Full database available: ${stats.fullDatabaseAvailable ? 'Yes' : 'No'}`);
    console.log(`Total medications: ${stats.totalMedications.toLocaleString()}`);
    console.log(`Interactions database: ${stats.interactionsAvailable ? 'Yes' : 'No'}`);
    console.log(`Total interactions: ${stats.totalInteractions.toLocaleString()}`);
    console.log(`Data directory: ${stats.dataDirectory}`);
    return;
  }
  
  // Download
  if (args.includes('--download')) {
    const force = args.includes('--force');
    await downloadDatabase({ force });
    return;
  }
  
  // List curated
  if (args.includes('--list')) {
    console.log('\n📋 Curated US Medications\n');
    CURATED_MEDICATIONS.forEach(m => {
      const rx = m.rx ? '💊' : '🟢';
      console.log(`${rx} ${m.name}`);
    });
    console.log(`\nTotal: ${CURATED_MEDICATIONS.length} medications`);
    return;
  }
  
  // Get query (everything that's not a flag)
  const query = args.filter(a => !a.startsWith('-')).join(' ');
  
  if (!query) {
    console.log('Please provide a medication name to look up.');
    return;
  }
  
  // Search mode
  if (args.includes('--search') || args.includes('-s')) {
    const results = await searchMedications(query, { limit: 10 });
    if (results.length === 0) {
      console.log(`No medications found matching "${query}"`);
      return;
    }
    console.log(`\n🔍 Search results for "${query}":\n`);
    results.forEach((m, i) => {
      const rx = m.rx ? '💊' : '🟢';
      const src = m.source === 'curated' ? '★' : '';
      console.log(`${i + 1}. ${rx} ${m.name} ${src}`);
    });
    return;
  }
  
  // Interactions mode
  if (args.includes('--interactions')) {
    const interaction = await lookupInteractions(query);
    if (!interaction) {
      console.log(`No interaction data found for "${query}"`);
      return;
    }
    console.log(`\n💊 Drug Interactions: ${interaction.medicationName}`);
    console.log('─'.repeat(50));
    console.log(interaction.interactionText.slice(0, 2000));
    return;
  }
  
  // Default: lookup single medication
  const med = await lookupMedication(query);
  if (!med) {
    console.log(`Medication "${query}" not found.`);
    if (!isFullDatabaseAvailable()) {
      console.log('Tip: Run "us-medications --download" to access 81,000+ medications.');
    }
    return;
  }
  
  console.log(formatMedication(med));
}

// Export for use as module
module.exports = {
  lookupMedication,
  searchMedications,
  lookupInteractions,
  downloadDatabase,
  getDatabaseStats,
  isFullDatabaseAvailable,
  CURATED_MEDICATIONS,
  COMMON_MEDICATIONS: CURATED_MEDICATIONS  // Alias for compatibility
};

// Run CLI if called directly
if (require.main === module) {
  main().catch(console.error);
}
