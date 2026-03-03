#!/usr/bin/env node

/**
 * Process Swedish healthcare data from eir-chrome-plugin into standardized format
 * Usage: node scripts/process-swedish-data.js
 */

const fs = require('fs');
const path = require('path');

// Paths to source data
const sourcePath = '/Users/birger/Community/eir-chrome-plugin';
const mainClinicFile = path.join(sourcePath, 'healthcare-clinics.json');
const specialistFile = path.join(sourcePath, 'EgenRemiss/targets-specialist.json');
const vardcentralFile = path.join(sourcePath, 'EgenRemiss/targets-vardcentral.json');
const hospitalFile = path.join(sourcePath, 'EgenRemiss/targets-hospital.json');

// Output paths
const outputDir = './public/data';
const outputFile = path.join(outputDir, 'providers-sweden.json');

console.log('🏥 Processing Swedish Healthcare Data...');

// Ensure output directory exists
if (!fs.existsSync(outputDir)) {
  fs.mkdirSync(outputDir, { recursive: true });
}

// Load source data
let allClinics = [];
let specialistClinics = [];
let vardcentralClinics = [];
let hospitalClinics = [];

try {
  console.log('📊 Loading source data...');
  
  if (fs.existsSync(mainClinicFile)) {
    allClinics = JSON.parse(fs.readFileSync(mainClinicFile, 'utf8'));
    console.log(`   • Loaded ${allClinics.length} total clinics`);
  }
  
  if (fs.existsSync(specialistFile)) {
    specialistClinics = JSON.parse(fs.readFileSync(specialistFile, 'utf8'));
    console.log(`   • Loaded ${specialistClinics.length} specialist clinics`);
  }
  
  if (fs.existsSync(vardcentralFile)) {
    vardcentralClinics = JSON.parse(fs.readFileSync(vardcentralFile, 'utf8'));
    console.log(`   • Loaded ${vardcentralClinics.length} vårdcentraler`);
  }
  
  if (fs.existsSync(hospitalFile)) {
    hospitalClinics = JSON.parse(fs.readFileSync(hospitalFile, 'utf8'));
    console.log(`   • Loaded ${hospitalClinics.length} hospitals`);
  }
} catch (error) {
  console.error('❌ Error loading source data:', error.message);
  process.exit(1);
}

// Create lookup sets for efficient categorization
const specialistIds = new Set(specialistClinics.map(c => c.hsaId));
const vardcentralIds = new Set(vardcentralClinics.map(c => c.hsaId));
const hospitalIds = new Set(hospitalClinics.map(c => c.hsaId));

function categorizeClinic(clinic) {
  const name = clinic.name.toLowerCase();
  
  // Use explicit categorization first
  if (specialistIds.has(clinic.hsaId)) return 'specialist';
  if (vardcentralIds.has(clinic.hsaId)) return 'primary_care';
  if (hospitalIds.has(clinic.hsaId)) return 'hospital';
  
  // Fallback to name-based categorization
  if (name.includes('vårdcentral') || name.includes('hälsocentral')) return 'primary_care';
  if (name.includes('sjukhus') || name.includes('hospital')) return 'hospital';
  if (name.includes('tandvård') || name.includes('folktandvård')) return 'dental';
  if (name.includes('mottagning') && !name.includes('ungdomsmottagning')) return 'specialist';
  if (name.includes('akutmottagning') || name.includes('akuten')) return 'emergency';
  if (name.includes('psykiatri') || name.includes('bup')) return 'mental_health';
  if (name.includes('barnavård') || name.includes('bvc')) return 'pediatric';
  if (name.includes('mödravård') || name.includes('förlossning')) return 'maternity';
  
  return 'other';
}

function extractSpecialty(clinic) {
  const name = clinic.name.toLowerCase();
  const specialties = [];
  
  if (name.includes('dermatologi')) specialties.push('dermatology');
  if (name.includes('ortopedi')) specialties.push('orthopedics');
  if (name.includes('kardiologi')) specialties.push('cardiology');
  if (name.includes('neurologi')) specialties.push('neurology');
  if (name.includes('gastro')) specialties.push('gastroenterology');
  if (name.includes('urologi')) specialties.push('urology');
  if (name.includes('gynekologi')) specialties.push('gynecology');
  if (name.includes('onkologi')) specialties.push('oncology');
  if (name.includes('endokrin')) specialties.push('endocrinology');
  if (name.includes('reumatologi')) specialties.push('rheumatology');
  if (name.includes('önh') || name.includes('öron')) specialties.push('ent');
  if (name.includes('ögon')) specialties.push('ophthalmology');
  if (name.includes('psykiatri')) specialties.push('psychiatry');
  if (name.includes('röntgen') || name.includes('radiologi')) specialties.push('radiology');
  if (name.includes('patologi')) specialties.push('pathology');
  
  return specialties;
}

// Process all clinics into standardized format
console.log('🔄 Converting to standardized format...');

const standardizedClinics = allClinics.map(clinic => {
  const type = categorizeClinic(clinic);
  const specialties = extractSpecialty(clinic);
  
  return {
    id: clinic.hsaId,
    name: clinic.name,
    type: type,
    specialty: specialties,
    
    contact: {
      phone: clinic.phone || null,
      internationalPhone: clinic.internationalPhone || null,
      email: null, // TODO: Email acquisition
      website: clinic.url || null
    },
    
    location: {
      address: clinic.address || null,
      coordinates: {
        lat: clinic.lat,
        lng: clinic.lng
      }
    },
    
    services: {
      self_referral: specialistIds.has(clinic.hsaId) || vardcentralIds.has(clinic.hsaId),
      video_consultation: clinic.videoOrChat || false,
      mvk_services: clinic.hasMvkServices || false,
      has_listing: clinic.hasListing || false
    },
    
    metadata: {
      country: 'SE',
      source: '1177.se',
      updated: new Date().toISOString(),
      eigen_remiss_research: specialistIds.has(clinic.hsaId) || vardcentralIds.has(clinic.hsaId)
    }
  };
});

// Generate summary statistics
const stats = {
  total: standardizedClinics.length,
  by_type: {},
  with_coordinates: standardizedClinics.filter(c => c.location.coordinates.lat && c.location.coordinates.lng).length,
  with_phone: standardizedClinics.filter(c => c.contact.phone).length,
  with_address: standardizedClinics.filter(c => c.location.address).length,
  self_referral_eligible: standardizedClinics.filter(c => c.services.self_referral).length
};

// Count by type
standardizedClinics.forEach(clinic => {
  stats.by_type[clinic.type] = (stats.by_type[clinic.type] || 0) + 1;
});

// Save processed data
const output = {
  metadata: {
    generated: new Date().toISOString(),
    source: 'eir-chrome-plugin + EgenRemiss research',
    country: 'Sweden',
    total_providers: standardizedClinics.length,
    data_version: '1.0'
  },
  statistics: stats,
  providers: standardizedClinics
};

fs.writeFileSync(outputFile, JSON.stringify(output, null, 2));

// Also create a smaller sample for testing
const sampleOutput = {
  ...output,
  providers: standardizedClinics.slice(0, 500)
};
fs.writeFileSync(path.join(outputDir, 'providers-sweden-sample.json'), JSON.stringify(sampleOutput, null, 2));

console.log('\n✅ Processing complete!');
console.log(`📄 Full dataset: ${outputFile}`);
console.log(`📄 Sample dataset: ${path.join(outputDir, 'providers-sweden-sample.json')}`);

console.log('\n📊 Statistics:');
console.log(`   Total providers: ${stats.total}`);
console.log(`   With coordinates: ${stats.with_coordinates} (${(stats.with_coordinates/stats.total*100).toFixed(1)}%)`);
console.log(`   With phone: ${stats.with_phone} (${(stats.with_phone/stats.total*100).toFixed(1)}%)`);
console.log(`   With address: ${stats.with_address} (${(stats.with_address/stats.total*100).toFixed(1)}%)`);
console.log(`   Self-referral eligible: ${stats.self_referral_eligible} (${(stats.self_referral_eligible/stats.total*100).toFixed(1)}%)`);

console.log('\n📈 By Type:');
Object.entries(stats.by_type)
  .sort(([,a], [,b]) => b - a)
  .forEach(([type, count]) => {
    console.log(`   ${type}: ${count}`);
  });

console.log('\n🚀 Ready to launch EIR Provider Directory!');