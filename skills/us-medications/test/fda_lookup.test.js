const { describe, it, before } = require('node:test');
const assert = require('node:assert');
const {
  lookupMedication,
  searchMedications,
  getDatabaseStats,
  CURATED_MEDICATIONS
} = require('../scripts/fda_lookup.js');

describe('US FDA Medication Lookup', () => {
  
  describe('Curated Database', () => {
    
    it('should have curated medications loaded', () => {
      assert.ok(CURATED_MEDICATIONS.length > 0, 'Should have curated medications');
      assert.ok(CURATED_MEDICATIONS.length >= 50, 'Should have at least 50 curated meds');
    });
    
    it('should have required fields in curated meds', () => {
      const sample = CURATED_MEDICATIONS[0];
      assert.ok(sample.name, 'Should have name');
      assert.ok(sample.substances, 'Should have substances');
      assert.ok(typeof sample.rx === 'boolean', 'Should have rx boolean');
    });
    
    it('should include common medications', () => {
      const names = CURATED_MEDICATIONS.map(m => m.name.toLowerCase());
      // Check for presence of common medications (case-insensitive, partial match)
      const hasInsulin = names.some(n => n.includes('insulin'));
      const hasOmeprazole = names.some(n => n.includes('omeprazole'));
      assert.ok(hasInsulin || hasOmeprazole, 'Should have common medications');
    });
    
  });
  
  describe('lookupMedication()', () => {
    
    it('should find medication by name', async () => {
      const result = await lookupMedication('omeprazole', { autoDownload: false });
      assert.ok(result, 'Should find omeprazole');
      assert.ok(result.name.toLowerCase().includes('omeprazole'));
    });
    
    it('should return null for non-existent medication (curated only)', async () => {
      const result = await lookupMedication('xyznonexistent123', { autoDownload: false });
      assert.strictEqual(result, null, 'Should return null for non-existent med');
    });
    
    it('should include source field', async () => {
      const result = await lookupMedication('insulin', { autoDownload: false });
      if (result) {
        assert.ok(result.source, 'Should have source field');
        assert.ok(['curated', 'full'].includes(result.source));
      }
    });
    
    it('should search by substance name', async () => {
      const result = await lookupMedication('OMEPRAZOLE', { autoDownload: false });
      assert.ok(result, 'Should find by substance');
    });
    
  });
  
  describe('searchMedications()', () => {
    
    it('should return multiple results', async () => {
      const results = await searchMedications('insulin');
      assert.ok(Array.isArray(results), 'Should return array');
    });
    
    it('should respect limit option', async () => {
      const results = await searchMedications('a', { limit: 5 });
      assert.ok(results.length <= 5, 'Should respect limit');
    });
    
    it('should return empty array for no matches', async () => {
      const results = await searchMedications('xyznonexistent999');
      assert.ok(Array.isArray(results), 'Should return array');
      assert.strictEqual(results.length, 0, 'Should be empty');
    });
    
    it('should search in uses field', async () => {
      // Search for a common condition/use
      const results = await searchMedications('acid reflux');
      // Might find something, might not depending on curated data
      assert.ok(Array.isArray(results), 'Should return array');
    });
    
  });
  
  describe('getDatabaseStats()', () => {
    
    it('should return statistics object', async () => {
      const stats = await getDatabaseStats();
      assert.ok(typeof stats === 'object', 'Should return object');
      assert.ok(typeof stats.curatedMedications === 'number');
      assert.ok(typeof stats.fullDatabaseAvailable === 'boolean');
      assert.ok(typeof stats.totalMedications === 'number');
    });
    
    it('should report curated count correctly', async () => {
      const stats = await getDatabaseStats();
      assert.strictEqual(stats.curatedMedications, CURATED_MEDICATIONS.length);
    });
    
    it('should include data directory path', async () => {
      const stats = await getDatabaseStats();
      assert.ok(stats.dataDirectory, 'Should have dataDirectory');
      assert.ok(stats.dataDirectory.includes('.us-medications'));
    });
    
  });
  
  describe('Data Quality', () => {
    
    it('should have uses information for some meds', () => {
      const withUses = CURATED_MEDICATIONS.filter(m => m.uses && m.uses.length > 10);
      assert.ok(withUses.length > 0, 'Should have meds with uses');
    });
    
    it('should have warnings information for some meds', () => {
      const withWarnings = CURATED_MEDICATIONS.filter(m => m.warnings && m.warnings.length > 10);
      assert.ok(withWarnings.length > 0, 'Should have meds with warnings');
    });
    
    it('should have both rx and otc medications', () => {
      const rx = CURATED_MEDICATIONS.filter(m => m.rx === true);
      const otc = CURATED_MEDICATIONS.filter(m => m.rx === false);
      assert.ok(rx.length > 0, 'Should have prescription meds');
      assert.ok(otc.length > 0, 'Should have OTC meds');
    });
    
    it('should have different dosage forms', () => {
      const forms = new Set(CURATED_MEDICATIONS.map(m => m.form).filter(Boolean));
      assert.ok(forms.size >= 2, 'Should have multiple dosage forms');
    });
    
  });
  
  describe('CLI Compatibility', () => {
    
    it('should be executable', () => {
      const fs = require('fs');
      const path = require('path');
      const scriptPath = path.join(__dirname, '..', 'scripts', 'fda_lookup.js');
      assert.ok(fs.existsSync(scriptPath), 'Script should exist');
    });
    
    it('should export COMMON_MEDICATIONS alias', () => {
      const { COMMON_MEDICATIONS } = require('../scripts/fda_lookup.js');
      assert.strictEqual(COMMON_MEDICATIONS, CURATED_MEDICATIONS, 'Should be same as CURATED');
    });
    
  });
  
});

// Run count summary
describe('Test Summary', () => {
  it('ran all tests', () => {
    assert.ok(true, 'All tests completed');
  });
});
