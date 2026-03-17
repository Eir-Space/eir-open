#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);
const DATA_PATH = path.resolve(__dirname, '../data/self-referral-clinics-sweden.json');

function loadData() {
  const raw = fs.readFileSync(DATA_PATH, 'utf8');
  return JSON.parse(raw);
}

function normalize(value) {
  return String(value || '')
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .trim();
}

function parseArgs(argv) {
  const options = {
    limit: 10,
    format: 'json',
    radiusKm: null,
  };

  for (let index = 0; index < argv.length; index += 1) {
    const token = argv[index];
    if (!token.startsWith('--')) continue;

    const key = token.slice(2);
    const value = argv[index + 1] && !argv[index + 1].startsWith('--') ? argv[index + 1] : true;
    if (value !== true) index += 1;

    if (key === 'limit') options.limit = Number(value);
    else if (key === 'radius-km') options.radiusKm = Number(value);
    else options[toCamelCase(key)] = value;
  }

  return options;
}

function toCamelCase(value) {
  return String(value).replace(/-([a-z])/g, (_, char) => char.toUpperCase());
}

function haversineKm(lat1, lng1, lat2, lng2) {
  const toRad = (degrees) => (degrees * Math.PI) / 180;
  const dLat = toRad(lat2 - lat1);
  const dLng = toRad(lng2 - lng1);
  const a =
    Math.sin(dLat / 2) ** 2 +
    Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
  return 6371 * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
}

function parseNear(value) {
  if (!value || value === true) return null;
  const [lat, lng] = String(value)
    .split(',')
    .map((part) => Number(part.trim()));
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng };
}

function includesMatch(haystack, needle) {
  return normalize(haystack).includes(normalize(needle));
}

function scoreClinic(clinic, options, near) {
  let score = 0;
  const query = options.query && options.query !== true ? String(options.query) : '';
  const county = options.county && options.county !== true ? String(options.county) : '';
  const municipality =
    options.municipality && options.municipality !== true ? String(options.municipality) : '';
  const specialty = options.specialty && options.specialty !== true ? String(options.specialty) : '';
  const tag = options.tag && options.tag !== true ? String(options.tag) : '';

  if (county) {
    if (normalize(clinic.location.county) === normalize(county)) score += 40;
    else if (includesMatch(clinic.location.county, county)) score += 18;
    else return null;
  }

  if (municipality) {
    if (normalize(clinic.location.municipality) === normalize(municipality)) score += 60;
    else if (includesMatch(clinic.location.municipality, municipality)) score += 24;
    else return null;
  }

  if (specialty) {
    const exact = clinic.specialties.some((item) => normalize(item) === normalize(specialty));
    const partial = clinic.specialties.some((item) => includesMatch(item, specialty));
    if (exact) score += 50;
    else if (partial) score += 20;
    else if (!includesMatch(clinic.summary, specialty) && !clinic.tags.some((item) => includesMatch(item, specialty))) {
      return null;
    }
  }

  if (tag) {
    const matched = clinic.tags.some((item) => normalize(item) === normalize(tag) || includesMatch(item, tag));
    if (!matched) return null;
    score += 15;
  }

  if (query) {
    if (includesMatch(clinic.name, query)) score += 70;
    if (includesMatch(clinic.summary, query)) score += 20;
    if (clinic.specialties.some((item) => includesMatch(item, query))) score += 25;
    if (clinic.tags.some((item) => includesMatch(item, query))) score += 18;
    if (includesMatch(clinic.location.municipality, query)) score += 15;
    if (includesMatch(clinic.location.county, query)) score += 12;
    if (score === 0) return null;
  }

  let distanceKm = null;
  if (near && clinic.location.lat != null && clinic.location.lng != null) {
    distanceKm = haversineKm(near.lat, near.lng, clinic.location.lat, clinic.location.lng);
    if (Number.isFinite(options.radiusKm) && distanceKm > options.radiusKm) {
      return null;
    }
    score += Math.max(0, 30 - Math.min(distanceKm, 30));
  } else if (Number.isFinite(options.radiusKm) && near) {
    return null;
  }

  return { score, distanceKm };
}

function searchClinics(data, options) {
  const near = parseNear(options.near);
  const ranked = [];

  for (const clinic of data.clinics) {
    const result = scoreClinic(clinic, options, near);
    if (!result) continue;
    ranked.push({
      ...clinic,
      score: Number(result.score.toFixed(2)),
      distance_km:
        result.distanceKm == null ? null : Number(result.distanceKm.toFixed(1)),
    });
  }

  ranked.sort((left, right) => {
    if (right.score !== left.score) return right.score - left.score;
    if (left.distance_km != null && right.distance_km != null && left.distance_km !== right.distance_km) {
      return left.distance_km - right.distance_km;
    }
    return String(left.name).localeCompare(String(right.name), 'sv');
  });

  return ranked.slice(0, Number.isFinite(options.limit) ? options.limit : 10);
}

function formatMarkdown(results, metadata) {
  const lines = [];
  lines.push(`# Verified Swedish self-referral clinics`);
  lines.push('');
  lines.push(`Matches: ${results.length}`);
  lines.push(`Source generated: ${metadata.source_generated || metadata.generated || 'unknown'}`);
  lines.push('');

  for (const clinic of results) {
    lines.push(`## ${clinic.name}`);
    lines.push(`- Location: ${[clinic.location.address, clinic.location.municipality, clinic.location.county].filter(Boolean).join(', ') || 'Not specified'}`);
    lines.push(`- Type: ${clinic.type || 'unknown'}`);
    lines.push(`- Specialties: ${clinic.specialties.join(', ') || 'None listed'}`);
    lines.push(`- Phone: ${clinic.contact.phone || 'Not listed'}`);
    lines.push(`- 1177: ${clinic.links.profile_1177 || 'Not listed'}`);
    lines.push(`- Self-referral actions: ${clinic.self_referral.actions.join(', ') || 'Verified, action name unavailable'}`);
    if (clinic.distance_km != null) {
      lines.push(`- Distance: ${clinic.distance_km} km`);
    }
    if (clinic.access.booking_actions.length) {
      lines.push(`- Booking/contact signals: ${clinic.access.booking_actions.join(', ')}`);
    }
    lines.push(`- Summary: ${clinic.summary || 'No summary available'}`);
    const evidence = clinic.self_referral.evidence[0];
    if (evidence) {
      lines.push(`- Evidence: ${evidence.excerpt || evidence.text}`);
    }
    lines.push('');
  }

  return `${lines.join('\n').trim()}\n`;
}

function main() {
  const options = parseArgs(process.argv.slice(2));
  const data = loadData();
  const results = searchClinics(data, options);

  if (options.format === 'markdown') {
    process.stdout.write(formatMarkdown(results, data.metadata));
    return;
  }

  if (options.format === 'ndjson') {
    for (const clinic of results) {
      process.stdout.write(`${JSON.stringify(clinic)}\n`);
    }
    return;
  }

  process.stdout.write(
    `${JSON.stringify(
      {
        metadata: data.metadata,
        query: options,
        results,
      },
      null,
      2,
    )}\n`,
  );
}

main();
