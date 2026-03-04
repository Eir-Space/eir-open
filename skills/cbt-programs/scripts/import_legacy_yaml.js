#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const { execFileSync } = require('child_process');

const ROOT = path.join(__dirname, '..');
const DEFAULT_SOURCE = '/Users/birger/Community/egen_journal/backend/content/programs';
const DEFAULT_TARGET = path.join(ROOT, 'data', 'programs');

function parseArgs(argv) {
  const positional = [];
  const options = {};

  for (let i = 0; i < argv.length; i += 1) {
    const token = argv[i];
    if (!token.startsWith('--')) {
      positional.push(token);
      continue;
    }

    const key = token.slice(2);
    const next = argv[i + 1];
    if (!next || next.startsWith('--')) {
      options[key] = true;
      continue;
    }

    options[key] = next;
    i += 1;
  }

  return { positional, options };
}

function usage() {
  console.log(`import_legacy_yaml - migrate legacy CBT YAML files into modular cbt-programs format

Usage:
  node scripts/import_legacy_yaml.js [--source <dir>] [--target <dir>] [--lang <code>] [--status draft|published] [--overwrite] [--mark-human-reviewed] [--mark-expert-verified]

Defaults:
  --source ${DEFAULT_SOURCE}
  --target ${DEFAULT_TARGET}
  --lang en
  --status draft
`);
}

function slugify(value) {
  return String(value || '')
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

function ensureArray(value) {
  return Array.isArray(value) ? value : [];
}

function unique(values) {
  const out = [];
  const seen = new Set();
  for (const value of values) {
    const text = String(value || '').trim();
    if (!text) continue;
    const key = text.toLowerCase();
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(text);
  }
  return out;
}

function normalizeOverview(overview) {
  if (Array.isArray(overview)) {
    return overview
      .map((line) => String(line).trim())
      .filter(Boolean)
      .join(' ');
  }
  return String(overview || '').trim();
}

function parseLegacyFile(filePath) {
  const parserCode = `
import json, sys
try:
    import yaml
except Exception:
    sys.stderr.write("PyYAML is required (pip install PyYAML)\\n")
    sys.exit(2)
with open(sys.argv[1], "r", encoding="utf-8") as f:
    data = yaml.safe_load(f) or {}
print(json.dumps(data))
`;

  const pythonCandidates = ['python3', 'python'];
  for (const bin of pythonCandidates) {
    try {
      const raw = execFileSync(bin, ['-c', parserCode, filePath], {
        encoding: 'utf8',
        stdio: ['ignore', 'pipe', 'pipe'],
      });
      return JSON.parse(raw || '{}');
    } catch (error) {
      const stderr = String(error?.stderr || '').trim();
      if (stderr.includes('PyYAML is required')) {
        throw new Error('PyYAML is required for migration. Install with: pip install PyYAML');
      }
      continue;
    }
  }
  throw new Error('Python 3 is required for migration parsing (python3 not found).');
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function ensureDir(dirPath) {
  fs.mkdirSync(dirPath, { recursive: true });
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function mapModule(module, index) {
  return {
    id: `module-${index + 1}`,
    title: String(module?.title || `Module ${index + 1}`).trim(),
    overview: normalizeOverview(module?.overview),
    takeaways: ensureArray(module?.takeaways)
      .map((item) => String(item))
      .filter(Boolean),
    exercises: ensureArray(module?.exercises)
      .map((item) => String(item))
      .filter(Boolean),
    homework: ensureArray(module?.homework)
      .map((item) => String(item))
      .filter(Boolean),
  };
}

function buildImportedProgram(legacy, sourceFileName, config) {
  const lang = config.lang;
  const legacyId = String(legacy.id || sourceFileName.replace(/\.ya?ml$/i, '')).trim();
  const id = legacyId.startsWith('cbt-') ? legacyId : `cbt-${slugify(legacyId)}`;
  const conditionName = String(legacy.condition || 'General CBT').trim();
  const conditionKey = slugify(conditionName) || 'general-cbt';

  const modules = ensureArray(legacy.modules).map((module, index) => mapModule(module, index));
  const focusAreas = unique(ensureArray(legacy.focusAreas));
  const derivedProblems = unique([conditionName, ...focusAreas]);
  const derivedTags = unique([
    'cbt',
    conditionKey,
    ...focusAreas.map((value) => slugify(value)).filter(Boolean),
  ]);

  let humanReviewed = Boolean(config.markHumanReviewed);
  let expertVerified = Boolean(config.markExpertVerified);
  if (config.status === 'published' && !humanReviewed && !expertVerified) {
    humanReviewed = true;
  }

  const translationStatus = expertVerified
    ? 'expert-verified'
    : humanReviewed
      ? 'human-reviewed'
      : config.status === 'published'
        ? 'human-reviewed'
        : 'draft';

  const program = {
    $schema: '../../../schemas/program.schema.json',
    id,
    version: config.status === 'published' ? '1.0.0' : '0.1.0',
    status: config.status,
    condition: {
      key: conditionKey,
      name: conditionName,
    },
    tags: derivedTags.length > 0 ? derivedTags : ['cbt'],
    defaultLanguage: lang,
    lineage: {
      aiCreated: true,
      humanCreated: false,
      humanReviewed,
      healthcareExpertVerified: expertVerified,
      notes: `Imported from legacy YAML: ${sourceFileName}`,
    },
    provenance: {
      authors: [
        {
          name: 'Legacy CBT Importer',
          role: 'ai-migration',
        },
      ],
      reviewers: [],
      experts: [],
    },
    translations: [
      {
        lang,
        status: translationStatus,
        completion: 100,
        path: `locales/${lang}.json`,
      },
    ],
    content: {
      moduleCount: modules.length || 1,
      estimatedWeeks: String(legacy.duration || `${Math.max(1, modules.length)} weeks`).trim(),
    },
    recommendationSignals: {
      problems: derivedProblems.length > 0 ? derivedProblems : [conditionName],
      contraindications: [],
      severity: 'unknown',
    },
    safety: {
      intendedUse: 'psychoeducation and structured self-help',
      medicalDisclaimer:
        'This program is educational support and does not replace diagnosis or treatment planning.',
      crisisAdvice: 'If there is immediate danger, call local emergency services now.',
    },
    changeLog: 'changelog.md',
    progressDir: 'progress',
  };

  const locale = {
    language: lang,
    title: String(legacy.title || id).trim(),
    summary: String(legacy.summary || '').trim(),
    modules,
    resources: ensureArray(legacy.resources),
    aiSupport: {
      coachingTone: 'supportive, practical, non-judgmental',
      systemPrompt:
        'Help the user apply one concrete module step at a time. Do not diagnose. Escalate urgent safety concerns to emergency care.',
    },
  };

  return { id, program, locale };
}

function migrateOneFile(filePath, targetRoot, config) {
  const sourceFileName = path.basename(filePath);
  const legacy = parseLegacyFile(filePath);
  const { id, program, locale } = buildImportedProgram(legacy, sourceFileName, config);

  const programDir = path.join(targetRoot, id);
  if (fs.existsSync(programDir) && !config.overwrite) {
    return { status: 'skipped', id, reason: 'already exists' };
  }

  ensureDir(path.join(programDir, 'locales'));
  ensureDir(path.join(programDir, 'progress'));

  writeJson(path.join(programDir, 'program.json'), program);
  writeJson(path.join(programDir, 'locales', `${config.lang}.json`), locale);

  fs.writeFileSync(
    path.join(programDir, 'changelog.md'),
    `# Changelog\n\n## ${program.version} - ${today()}\n\n- Imported from legacy YAML source: ${sourceFileName}\n`,
  );

  fs.writeFileSync(
    path.join(programDir, 'progress', `${today()}-imported-from-legacy-yaml.md`),
    `# Imported from legacy YAML\n\nDate: ${today()}\nProgram: ${id}\nAuthor: Migration script\n\n## What changed\n\n- Created modular program package from ${sourceFileName}.\n- Added machine-readable metadata and locale content.\n\n## Why this change\n\n- Enable open-source reuse, translation workflows, and provenance tracking.\n`,
  );

  return { status: 'imported', id };
}

function main() {
  const { options } = parseArgs(process.argv.slice(2));
  if (options.help) {
    usage();
    return;
  }

  const source = options.source || DEFAULT_SOURCE;
  const target = options.target || DEFAULT_TARGET;
  const lang = options.lang || 'en';
  const status = options.status || 'draft';

  if (status !== 'draft' && status !== 'published') {
    throw new Error('status must be draft or published');
  }

  if (!fs.existsSync(source)) {
    throw new Error(`source directory not found: ${source}`);
  }

  ensureDir(target);

  const config = {
    lang,
    status,
    overwrite: Boolean(options.overwrite),
    markHumanReviewed: Boolean(options['mark-human-reviewed']),
    markExpertVerified: Boolean(options['mark-expert-verified']),
  };

  const yamlFiles = fs
    .readdirSync(source)
    .filter((name) => name.endsWith('.yaml') || name.endsWith('.yml'))
    .sort();

  let imported = 0;
  let skipped = 0;
  let failed = 0;

  for (const fileName of yamlFiles) {
    const filePath = path.join(source, fileName);
    try {
      const result = migrateOneFile(filePath, target, config);
      if (result.status === 'imported') {
        imported += 1;
        console.log(`imported: ${result.id}`);
      } else {
        skipped += 1;
        console.log(`skipped: ${result.id} (${result.reason})`);
      }
    } catch (error) {
      failed += 1;
      console.error(`failed: ${fileName} (${error.message})`);
    }
  }

  console.log(`\nMigration summary`);
  console.log(`- source: ${source}`);
  console.log(`- target: ${target}`);
  console.log(`- imported: ${imported}`);
  console.log(`- skipped: ${skipped}`);
  console.log(`- failed: ${failed}`);

  if (failed > 0) {
    process.exitCode = 1;
  }
}

try {
  main();
} catch (error) {
  console.error(`Error: ${error.message}`);
  process.exitCode = 1;
}
