#!/usr/bin/env node

import fs from 'fs';
import path from 'path';
import { fileURLToPath } from 'url';

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const inputPath = path.resolve(__dirname, '../public/data/providers-sweden-verified.json');
const outputDir = path.resolve(__dirname, '../public/data/agent');
const outputPath = path.join(outputDir, 'self-referral-clinics-sweden.json');

const MAX_SUMMARY_LENGTH = 320;
const MAX_EVIDENCE_LENGTH = 220;

function normalizeWhitespace(value) {
  return String(value || '')
    .replace(/\s+/g, ' ')
    .replace(/\s([,.;:!?])/g, '$1')
    .trim();
}

function truncateText(value, maxLength) {
  const text = normalizeWhitespace(value);
  if (!text || text.length <= maxLength) return text;
  return `${text.slice(0, maxLength - 1).trimEnd()}…`;
}

function unique(values) {
  return [...new Set(values.filter(Boolean))];
}

function slugify(value) {
  return normalizeWhitespace(value)
    .toLowerCase()
    .normalize('NFD')
    .replace(/[\u0300-\u036f]/g, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function getPrimaryPhone(provider) {
  const phoneGroups = provider.profile_1177?.phone ?? [];
  for (const group of phoneGroups) {
    const number = group?.numbers?.[0]?.national;
    if (number) return number;
  }
  return provider.contact?.phone || null;
}

function deriveActionTags(actions, provider) {
  const tags = [];
  const actionTexts = actions.map((action) => normalizeWhitespace(action?.text));

  if (provider.services?.mvk_services) tags.push('1177-e-services');
  if (provider.services?.video_consultation) tags.push('video-consultation');
  if (provider.services?.has_listing) tags.push('listning');

  for (const text of actionTexts) {
    const lower = text.toLowerCase();
    if (lower.includes('egen vårdbegäran') || lower.includes('egenvardbegaran')) {
      tags.push('self-referral');
    }
    if (lower.includes('adhd') || lower.includes('add')) {
      tags.push('adhd-add');
    }
    if (lower.includes('boka tid') || lower.includes('beställ tid') || lower.includes('bestall tid')) {
      tags.push('booking');
    }
    if (lower.includes('omboka') || lower.includes('av- eller omboka')) {
      tags.push('rescheduling');
    }
    if (lower.includes('förnya recept') || lower.includes('fornya recept')) {
      tags.push('prescription-renewal');
    }
    if (lower.includes('kontakta') || lower.includes('fråga') || lower.includes('fraga')) {
      tags.push('contact');
    }
    if (lower.includes('journalkopia')) {
      tags.push('records');
    }
  }

  return unique(tags);
}

function pickSummary(provider) {
  return truncateText(
    provider.profile_1177?.description ||
      provider.description ||
      provider.profile_1177?.about_us?.description?.join(' ') ||
      '',
    MAX_SUMMARY_LENGTH,
  );
}

function buildEvidence(actions) {
  return actions.slice(0, 3).map((action) => ({
    text: normalizeWhitespace(action.text),
    action_code: action.action_code || null,
    excerpt: truncateText(action.description_text || action.heading || '', MAX_EVIDENCE_LENGTH),
    url: action.url || null,
  }));
}

function buildClinic(provider) {
  const actions =
    provider.services?.e_services_structured ||
    provider.profile_1177?.actions ||
    [];

  const selfReferralActions = actions.filter((action) => {
    const text = normalizeWhitespace(action?.text).toLowerCase();
    return action?.action_code === 'EGREM' || text.includes('egen vårdbegäran');
  });

  const bookingActions = actions
    .filter((action) => {
      const code = action?.action_code || '';
      const text = normalizeWhitespace(action?.text).toLowerCase();
      return (
        ['BOKATID', 'OBT', 'VISATID', 'FORMSCHEDULING', 'FORMESERVICES'].includes(code) ||
        text.includes('boka tid') ||
        text.includes('beställ tid') ||
        text.includes('bestall tid') ||
        text.includes('omboka')
      );
    })
    .map((action) => normalizeWhitespace(action.text))
    .slice(0, 6);

  const typeTags = provider.type ? [provider.type] : [];
  const specialtyTags = Array.isArray(provider.specialty) ? provider.specialty : [];
  const actionTags = deriveActionTags(actions, provider);
  const tags = unique([...typeTags, ...specialtyTags, ...actionTags]).sort();

  return {
    id: provider.id,
    hsa_id: provider.profile_1177?.hsa_id || provider.id,
    name: provider.profile_1177?.display_name || provider.name,
    type: provider.type || null,
    specialties: specialtyTags,
    tags,
    location: {
      address: provider.profile_1177?.address || provider.location?.address || null,
      municipality: provider.profile_1177?.municipality || null,
      county: provider.profile_1177?.county || null,
      lat: provider.profile_1177?.location?.latitude ?? provider.location?.coordinates?.lat ?? null,
      lng: provider.profile_1177?.location?.longitude ?? provider.location?.coordinates?.lng ?? null,
    },
    contact: {
      phone: getPrimaryPhone(provider),
    },
    links: {
      profile_1177: provider.profile_1177?.source_url || null,
      website: provider.profile_1177?.website_url || provider.contact?.website || null,
    },
    self_referral: {
      verified: true,
      verification_status: provider.services?.self_referral_verification_status || 'verified',
      actions: selfReferralActions.map((action) => normalizeWhitespace(action.text)),
      evidence: buildEvidence(selfReferralActions),
    },
    access: {
      has_1177_e_services: Boolean(provider.services?.mvk_services),
      video_consultation: Boolean(provider.services?.video_consultation),
      booking_actions: bookingActions,
    },
    summary: pickSummary(provider),
  };
}

function main() {
  if (!fs.existsSync(inputPath)) {
    throw new Error(`Input dataset not found: ${inputPath}`);
  }

  const source = JSON.parse(fs.readFileSync(inputPath, 'utf8'));
  const providers = Array.isArray(source.providers) ? source.providers : [];

  const clinics = providers
    .filter((provider) => provider.services?.self_referral_verified === true)
    .map(buildClinic)
    .sort((left, right) => {
      const leftKey = [
        left.location.county || '',
        left.location.municipality || '',
        left.name || '',
      ].join('|');
      const rightKey = [
        right.location.county || '',
        right.location.municipality || '',
        right.name || '',
      ].join('|');
      return leftKey.localeCompare(rightKey, 'sv');
    });

  const counties = unique(clinics.map((clinic) => clinic.location.county)).sort((a, b) =>
    a.localeCompare(b, 'sv'),
  );
  const specialties = unique(clinics.flatMap((clinic) => clinic.specialties)).sort();

  const output = {
    metadata: {
      generated: new Date().toISOString(),
      schema_version: '1.0',
      country: 'Sweden',
      source_dataset: 'providers-sweden-verified.json',
      source_generated: source.metadata?.generated || null,
      self_referral_verification_generated:
        source.metadata?.self_referral_verification?.generated || null,
      clinic_count: clinics.length,
      counties,
      specialty_tags: specialties,
      description:
        'Compact agent-oriented index of Swedish clinics with verified 1177 self-referral capability.',
    },
    clinics,
  };

  fs.mkdirSync(outputDir, { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(output, null, 2));

  const byteSize = fs.statSync(outputPath).size;
  console.log(`Wrote ${clinics.length} clinics to ${outputPath}`);
  console.log(`Size: ${(byteSize / 1024 / 1024).toFixed(2)} MB`);
}

main();
