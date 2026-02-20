#!/usr/bin/env node

/**
 * Download full US medications database from GitHub releases
 * This script runs automatically on postinstall (silently, optional failure)
 */

const { downloadDatabase } = require('./fda_lookup.js');

const args = process.argv.slice(2);
const silent = args.includes('--silent');
const force = args.includes('--force');

downloadDatabase({ silent, force })
  .then(success => {
    if (!success && !silent) {
      console.log('\nNote: You can download the full database later with:');
      console.log('  us-medications --download\n');
    }
    process.exit(success ? 0 : 1);
  })
  .catch(err => {
    if (!silent) console.error('Download error:', err.message);
    process.exit(1);
  });
