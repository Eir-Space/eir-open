#!/usr/bin/env node
const fs = require('fs');
const path = require('path');
const https = require('https');

const ROOT = path.join(__dirname, '..', '..');
const SWEDISH_MEDICATIONS_DIR = path.join(ROOT, 'swedish-medications');
const { findMedication } = require(path.join(SWEDISH_MEDICATIONS_DIR, 'scripts', 'fass_lookup.js'));
const allMedications = require(path.join(SWEDISH_MEDICATIONS_DIR, 'data', 'medications.json'));

const SITEMAP_URL = 'https://www.apotea.se/Sitemap/SMPViewAACC';
const DEFAULT_JSON_OUTPUT = path.join(__dirname, '..', 'references', 'apotea-otc-medications.json');
const DEFAULT_MD_OUTPUT = path.join(__dirname, '..', 'references', 'apotea-otc-medications.md');

const OTC_BRAND_QUERIES = [
  'alvedon',
  'panodil',
  'pamol',
  'ipren',
  'ibumetin',
  'brufen',
  'voltaren',
  'pronaxen',
  'clarityn',
  'zyrtec',
  'aerius',
  'losec',
  'imodium',
  'nicorette',
  'otrivin',
  'nasoferm',
  'canesten',
  'lamisil',
  'dimor',
  'treo',
  'bamyl',
  'nexium',
  'gaviscon',
  'postafen',
  'rinexin',
  'bisolvon',
];

function fetchText(url) {
  return new Promise((resolve, reject) => {
    https
      .get(
        url,
        {
          headers: {
            'User-Agent': 'Mozilla/5.0 (compatible; Codex buy-medication skill builder)',
            Accept: 'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
          },
        },
        (res) => {
          if (res.statusCode >= 300 && res.statusCode < 400 && res.headers.location) {
            fetchText(res.headers.location).then(resolve, reject);
            return;
          }
          if (res.statusCode !== 200) {
            reject(new Error(`Request failed for ${url}: ${res.statusCode}`));
            return;
          }
          let data = '';
          res.on('data', (chunk) => {
            data += chunk;
          });
          res.on('end', () => resolve(data));
        }
      )
      .on('error', reject);
  });
}

function stripTags(value) {
  return value.replace(/<[^>]+>/g, ' ');
}

function decodeHtml(value) {
  const named = {
    amp: '&',
    quot: '"',
    apos: "'",
    lt: '<',
    gt: '>',
    nbsp: ' ',
    aring: 'å',
    Aring: 'Å',
    auml: 'ä',
    Auml: 'Ä',
    ouml: 'ö',
    Ouml: 'Ö',
    eacute: 'é',
    Eacute: 'É',
    frac12: '1/2',
  };

  return value
    .replace(/&#(\d+);/g, (_, code) => String.fromCharCode(Number(code)))
    .replace(/&#x([0-9a-f]+);/gi, (_, code) => String.fromCharCode(parseInt(code, 16)))
    .replace(/&([a-zA-Z]+);/g, (match, name) => named[name] || match)
    .replace(/\s+/g, ' ')
    .trim();
}

function getOtcIndex() {
  const index = new Map();

  for (const medication of allMedications) {
    if (!medication.prescriptionRequired && medication.nameNormalized) {
      index.set(medication.nameNormalized.toLowerCase(), medication.name);
    }
  }

  for (const query of OTC_BRAND_QUERIES) {
    const hit = findMedication(query);
    if (hit && hit.otc !== false) {
      index.set(query, hit.name);
    }
  }

  return index;
}

function getCandidateQueriesFromSlug(url, otcIndex) {
  const slug = url.replace('https://www.apotea.se/', '').replace(/\/$/, '');
  if (!slug || slug.includes('/')) {
    return null;
  }

  const parts = slug.split('-').filter(Boolean);
  for (let n = Math.min(parts.length, 5); n >= 1; n -= 1) {
    const query = parts.slice(0, n).join(' ').toLowerCase();
    if (otcIndex.has(query)) {
      return { query, matchedMedicationName: otcIndex.get(query) };
    }
  }

  return null;
}

function extractJsonLd(html) {
  const match = html.match(/<script type="application\/ld\+json">\s*({[\s\S]*?})\s*<\/script>/i);
  if (!match) {
    return null;
  }
  try {
    return JSON.parse(match[1]);
  } catch {
    return null;
  }
}

function extractFact(html, label) {
  const escaped = label.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  const regex = new RegExp(
    `<dt[^>]*class="product-fact-key"[^>]*>${escaped}:<\\/dt>\\s*<dd[^>]*class="product-fact-value"[^>]*>([\\s\\S]*?)<\\/dd>`,
    'i'
  );
  const match = html.match(regex);
  if (!match) {
    return null;
  }
  return decodeHtml(stripTags(match[1]));
}

function extractClassification(html) {
  const headingMatch = html.match(/<div id="product-classification-full"[\s\S]*?<h2>([\s\S]*?)<\/h2>/i);
  if (headingMatch) {
    return decodeHtml(stripTags(headingMatch[1]));
  }
  return extractFact(html, 'Klassificering');
}

function isAllowedClassification(classification) {
  const normalized = classification.toLowerCase();
  return normalized.includes('receptfritt läkemedel') || normalized.includes('nikotinläkemedel');
}

function parseProductPage(candidate, html) {
  const jsonLd = extractJsonLd(html);
  const productName = decodeHtml(
    stripTags((html.match(/<h1 id="product-name">([\s\S]*?)<\/h1>/i) || [null, ''])[1] || '')
  );
  const classification = extractClassification(html);
  if (!classification || !isAllowedClassification(classification)) {
    return null;
  }

  const medication = findMedication(candidate.query) || findMedication(candidate.matchedMedicationName);
  if (!medication) {
    return null;
  }

  const availability = jsonLd && jsonLd.offers ? jsonLd.offers.availability : null;
  const category = extractFact(html, 'Kategori');
  const packageSize = extractFact(html, 'Förpackningsstorlek');
  const price = jsonLd && jsonLd.offers ? jsonLd.offers.price : null;

  return {
    productName,
    url: candidate.url,
    matchedQuery: candidate.query,
    medicationName: medication.name,
    medicationOtc: medication.otc,
    atcCode: medication.atc || '',
    activeSubstances: medication.substances || [],
    classification,
    category,
    packageSize,
    brand: jsonLd && jsonLd.brand ? jsonLd.brand.name : null,
    priceSek: price !== null ? Number(price) : null,
    availability,
    inStock: availability === 'https://schema.org/InStock',
  };
}

async function mapLimit(items, limit, mapper) {
  const results = new Array(items.length);
  let nextIndex = 0;

  async function worker() {
    while (true) {
      const current = nextIndex;
      nextIndex += 1;
      if (current >= items.length) {
        return;
      }
      results[current] = await mapper(items[current], current);
    }
  }

  await Promise.all(Array.from({ length: Math.min(limit, items.length) }, worker));
  return results;
}

function buildMarkdown(snapshot) {
  const lines = [];
  lines.push('# Apotea OTC medication snapshot');
  lines.push('');
  lines.push(`Generated: ${snapshot.generatedAt}`);
  lines.push(`Source: ${snapshot.source}`);
  lines.push(`Matched products: ${snapshot.totalProducts}`);
  lines.push(`Unique medications: ${snapshot.uniqueMedicationCount}`);
  lines.push('');
  lines.push('This file is generated from live Apotea product pages and filtered through the local `swedish-medications` skill data.');
  lines.push('');

  for (const entry of snapshot.medications) {
    lines.push(`## ${entry.medicationName}`);
    lines.push('');
    lines.push(`- Products: ${entry.productCount}`);
    lines.push(`- ATC: ${entry.atcCode || 'Unknown'}`);
    lines.push(`- Active substances: ${entry.activeSubstances.length ? entry.activeSubstances.join(', ') : 'Unknown'}`);
    lines.push(`- Examples: ${entry.products.slice(0, 5).map((product) => product.productName).join(' | ')}`);
    lines.push('');
  }

  return `${lines.join('\n')}\n`;
}

async function main() {
  const jsonOutput = process.argv[2] || DEFAULT_JSON_OUTPUT;
  const mdOutput = process.argv[3] || DEFAULT_MD_OUTPUT;
  const otcIndex = getOtcIndex();

  const sitemapXml = await fetchText(SITEMAP_URL);
  const urls = [...sitemapXml.matchAll(/<loc>(https:\/\/www\.apotea\.se[^<]*)<\/loc>/g)].map((match) => match[1]);

  const candidates = [];
  for (const url of urls) {
    const match = getCandidateQueriesFromSlug(url, otcIndex);
    if (match) {
      candidates.push({ url, ...match });
    }
  }

  const dedupedCandidates = Array.from(new Map(candidates.map((candidate) => [candidate.url, candidate])).values());

  const parsed = await mapLimit(dedupedCandidates, 8, async (candidate) => {
    try {
      const html = await fetchText(candidate.url);
      return parseProductPage(candidate, html);
    } catch {
      return null;
    }
  });

  const products = parsed
    .filter(Boolean)
    .sort((a, b) => a.medicationName.localeCompare(b.medicationName, 'sv') || a.productName.localeCompare(b.productName, 'sv'));

  const byMedication = new Map();
  for (const product of products) {
    const key = product.medicationName;
    if (!byMedication.has(key)) {
      byMedication.set(key, {
        medicationName: product.medicationName,
        atcCode: product.atcCode,
        activeSubstances: product.activeSubstances,
        productCount: 0,
        products: [],
      });
    }
    const entry = byMedication.get(key);
    entry.productCount += 1;
    entry.products.push(product);
  }

  const snapshot = {
    generatedAt: new Date().toISOString(),
    source: SITEMAP_URL,
    totalCandidateUrls: dedupedCandidates.length,
    totalProducts: products.length,
    uniqueMedicationCount: byMedication.size,
    medications: Array.from(byMedication.values()).sort((a, b) =>
      a.medicationName.localeCompare(b.medicationName, 'sv')
    ),
  };

  fs.mkdirSync(path.dirname(jsonOutput), { recursive: true });
  fs.writeFileSync(jsonOutput, JSON.stringify(snapshot, null, 2));
  fs.writeFileSync(mdOutput, buildMarkdown(snapshot));

  console.log(
    JSON.stringify(
      {
        jsonOutput,
        mdOutput,
        totalCandidateUrls: snapshot.totalCandidateUrls,
        totalProducts: snapshot.totalProducts,
        uniqueMedicationCount: snapshot.uniqueMedicationCount,
      },
      null,
      2
    )
  );
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exit(1);
});
