#!/usr/bin/env node

const fs = require('fs');
const path = require('path');
const readlinePromises = require('readline/promises');

const ROOT = path.join(__dirname, '..');
const DATA_ROOT = path.join(ROOT, 'data', 'programs');
const TEMPLATE_PROGRAM = path.join(ROOT, 'templates', 'program-template.json');
const TEMPLATE_LOCALE = path.join(ROOT, 'templates', 'locale-template.json');

function usage() {
  console.log(`cbt-programs - open CBT registry CLI

Usage:
  cbt-programs list [--lang <code>] [--status <status>]
  cbt-programs show <program-id> [--lang <code>]
  cbt-programs search <query> [--lang <code>]
  cbt-programs recommend --problem "<text>" [--lang <code>] [--limit <n>]
  cbt-programs validate [program-id]
  cbt-programs scaffold <program-id> --title "<title>" --condition "<condition>" [--creator ai|human|ai-assisted]
  cbt-programs improve <program-id> [--interactive] [--dry-run] [--llm --llm-plan "<json>" | --llm-plan-file <path> | --goal "<goal>"] [--lang <code>] [--title "<title>"] [--program-summary "<text>"] [--add-tags "a,b"] [--add-problems "a,b"] [--new-module-title "<title>"] [--new-module-overview "<text>"] [--translation-status <status>] [--completion <0-100>] [--mark-human-reviewed] [--mark-expert-verified] [--note "<text>"]
  cbt-programs progress <program-id> --title "<entry title>" [--summary "text"]
  cbt-programs agent-prompt <program-id> [--lang <code>] [--goal "<goal>"]
`);
}

function slugify(value) {
  return String(value)
    .toLowerCase()
    .trim()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '');
}

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

function readJson(filePath) {
  return JSON.parse(fs.readFileSync(filePath, 'utf8'));
}

function writeJson(filePath, value) {
  fs.writeFileSync(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function sanitizeProgramForWrite(program) {
  const cleaned = { ...program };
  delete cleaned._id;
  delete cleaned._dir;
  return cleaned;
}

function writeProgram(program) {
  const id = program.id || program._id;
  if (!id) {
    throw new Error('Program ID missing while writing program.json');
  }
  writeJson(getProgramFile(id), sanitizeProgramForWrite(program));
}

function isDirectory(pathLike) {
  try {
    return fs.statSync(pathLike).isDirectory();
  } catch {
    return false;
  }
}

function ensureDir(pathLike) {
  fs.mkdirSync(pathLike, { recursive: true });
}

function getProgramDir(id) {
  return path.join(DATA_ROOT, id);
}

function getProgramFile(id) {
  return path.join(getProgramDir(id), 'program.json');
}

function getProgramIds() {
  if (!isDirectory(DATA_ROOT)) return [];
  return fs
    .readdirSync(DATA_ROOT)
    .filter((name) => isDirectory(path.join(DATA_ROOT, name)))
    .sort();
}

function loadProgram(id) {
  const filePath = getProgramFile(id);
  if (!fs.existsSync(filePath)) {
    throw new Error(`Program not found: ${id}`);
  }

  const data = readJson(filePath);
  data._id = id;
  data._dir = path.dirname(filePath);
  return data;
}

function loadAllPrograms() {
  return getProgramIds().map((id) => loadProgram(id));
}

function findTranslation(program, lang) {
  if (!Array.isArray(program.translations) || program.translations.length === 0) return null;

  if (lang) {
    const direct = program.translations.find((entry) => entry.lang === lang);
    if (direct) return direct;
  }

  const fallback = program.translations.find((entry) => entry.lang === program.defaultLanguage);
  return fallback || program.translations[0];
}

function loadLocale(program, lang) {
  const entry = findTranslation(program, lang);
  if (!entry) return { entry: null, locale: null };

  const localePath = path.join(program._dir, entry.path);
  if (!fs.existsSync(localePath)) return { entry, locale: null };

  return { entry, locale: readJson(localePath) };
}

function lineageBadges(lineage) {
  if (!lineage || typeof lineage !== 'object') return ['UNKNOWN'];

  const badges = [];
  if (lineage.aiCreated) badges.push('AI-CREATED');
  if (lineage.humanCreated) badges.push('HUMAN-CREATED');
  if (lineage.humanReviewed) badges.push('HUMAN-REVIEWED');
  if (lineage.healthcareExpertVerified) badges.push('EXPERT-VERIFIED');

  return badges.length > 0 ? badges : ['UNKNOWN'];
}

function translationSummary(program) {
  if (!Array.isArray(program.translations) || program.translations.length === 0) return 'none';
  return program.translations
    .map((entry) => `${entry.lang}:${entry.status}:${entry.completion ?? '?'}%`)
    .join(', ');
}

function filterPrograms(programs, options) {
  return programs.filter((program) => {
    if (options.status && program.status !== options.status) return false;
    if (options.lang && !program.translations.some((entry) => entry.lang === options.lang))
      return false;
    return true;
  });
}

function cmdList(options) {
  const programs = filterPrograms(loadAllPrograms(), options);
  if (programs.length === 0) {
    console.log('No programs found.');
    return;
  }

  for (const program of programs) {
    const badges = lineageBadges(program.lineage).join(', ');
    const condition = program.condition?.name || 'Unknown condition';
    const versions = program.version || '0.0.0';
    const languageLine = translationSummary(program);

    console.log(`${program.id} (${versions})`);
    console.log(`  Condition: ${condition}`);
    console.log(`  Status: ${program.status}`);
    console.log(`  Badges: ${badges}`);
    console.log(`  Languages: ${languageLine}`);
  }
}

function normalizeText(value) {
  return String(value || '').toLowerCase();
}

function includesToken(value, token) {
  return normalizeText(value).includes(token);
}

function tokenize(input) {
  return normalizeText(input)
    .split(/[^a-z0-9]+/)
    .filter(Boolean);
}

function parseCsv(input) {
  if (!input) return [];
  return String(input)
    .split(',')
    .map((item) => item.trim())
    .filter(Boolean);
}

function uniquePush(target, entries) {
  const seen = new Set((target || []).map((item) => normalizeText(item)));
  for (const entry of entries) {
    const key = normalizeText(entry);
    if (!seen.has(key)) {
      target.push(entry);
      seen.add(key);
    }
  }
}

function ensureArray(value) {
  return Array.isArray(value) ? value : [];
}

function uniqueValues(values) {
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

function bumpPatchVersion(value) {
  const parts = String(value || '0.1.0')
    .split('.')
    .map((part) => Number.parseInt(part, 10));
  const major = Number.isFinite(parts[0]) ? parts[0] : 0;
  const minor = Number.isFinite(parts[1]) ? parts[1] : 1;
  const patch = Number.isFinite(parts[2]) ? parts[2] : 0;
  return `${major}.${minor}.${patch + 1}`;
}

function ensureTranslation(program, lang) {
  if (!Array.isArray(program.translations)) {
    program.translations = [];
  }
  let entry = program.translations.find((item) => item.lang === lang);
  if (!entry) {
    entry = {
      lang,
      status: 'draft',
      completion: 0,
      path: `locales/${lang}.json`,
    };
    program.translations.push(entry);
  }
  return entry;
}

function ensureLocale(program, lang) {
  const entry = ensureTranslation(program, lang);
  const localePath = path.join(program._dir, entry.path);
  let locale = null;

  if (fs.existsSync(localePath)) {
    locale = readJson(localePath);
  } else {
    locale = {
      language: lang,
      title: '',
      summary: '',
      modules: [],
      aiSupport: {
        coachingTone: 'supportive, practical, non-judgmental',
        systemPrompt:
          'Help the user apply one concrete module step at a time and stay within psychoeducation support.',
      },
    };
  }

  locale.modules = ensureArray(locale.modules);
  return { entry, locale, localePath };
}

async function askText(rl, label, defaultValue = '') {
  const suffix = defaultValue ? ` [${defaultValue}]` : '';
  const answer = (await rl.question(`${label}${suffix}: `)).trim();
  return answer || defaultValue;
}

async function askOptionalText(rl, label) {
  return (await rl.question(`${label} (leave blank to skip): `)).trim();
}

async function askYesNo(rl, label, defaultValue = false) {
  const suffix = defaultValue ? ' [Y/n]' : ' [y/N]';
  const answer = (await rl.question(`${label}${suffix}: `)).trim().toLowerCase();
  if (!answer) return defaultValue;
  if (answer === 'y' || answer === 'yes') return true;
  if (answer === 'n' || answer === 'no') return false;
  return defaultValue;
}

async function collectImproveOptionsInteractive(program, options) {
  if (!options.interactive) return options;
  if (!process.stdin.isTTY) {
    throw new Error(
      'Interactive mode requires a TTY. Re-run without --interactive or use a terminal.',
    );
  }

  const rl = readlinePromises.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  try {
    const merged = { ...options };
    const defaultLang = merged.lang || program.defaultLanguage || 'en';
    merged.lang = await askText(rl, 'Language code', defaultLang);

    if (merged.llm) {
      if (merged['llm-plan'] === undefined) {
        merged['llm-plan'] = await askOptionalText(rl, 'LLM plan JSON (single line)');
      }
      if (merged['llm-plan-file'] === undefined) {
        merged['llm-plan-file'] = await askOptionalText(rl, 'LLM plan file path');
      }
      if (merged.goal === undefined) {
        merged.goal = await askOptionalText(rl, 'Improvement goal for LLM');
      }
      if (merged['dry-run'] === undefined) {
        merged['dry-run'] = await askYesNo(rl, 'Preview only (dry-run)', true);
      }
      if (merged.note === undefined) {
        merged.note = await askOptionalText(rl, 'Change note (optional)');
      }
    } else {
      if (merged.title === undefined) {
        merged.title = await askOptionalText(rl, 'New title');
      }
      if (merged['program-summary'] === undefined) {
        merged['program-summary'] = await askOptionalText(rl, 'New summary');
      }
      if (merged['add-tags'] === undefined) {
        merged['add-tags'] = await askOptionalText(rl, 'Tags to add (comma-separated)');
      }
      if (merged['add-problems'] === undefined) {
        merged['add-problems'] = await askOptionalText(
          rl,
          'Recommendation problems to add (comma-separated)',
        );
      }
      if (merged['new-module-title'] === undefined) {
        merged['new-module-title'] = await askOptionalText(rl, 'New module title');
      }
      if (merged['new-module-title'] && merged['new-module-overview'] === undefined) {
        merged['new-module-overview'] = await askOptionalText(rl, 'New module overview');
      }
      if (merged['new-module-title'] && merged['new-module-takeaways'] === undefined) {
        merged['new-module-takeaways'] = await askOptionalText(
          rl,
          'New module takeaways (comma-separated)',
        );
      }
      if (merged['new-module-title'] && merged['new-module-exercises'] === undefined) {
        merged['new-module-exercises'] = await askOptionalText(
          rl,
          'New module exercises (comma-separated)',
        );
      }
      if (merged['new-module-title'] && merged['new-module-homework'] === undefined) {
        merged['new-module-homework'] = await askOptionalText(
          rl,
          'New module homework (comma-separated)',
        );
      }
      if (merged['translation-status'] === undefined) {
        merged['translation-status'] = await askOptionalText(
          rl,
          'Translation status (source|draft|human-reviewed|expert-verified)',
        );
      }
      if (merged.completion === undefined) {
        merged.completion = await askOptionalText(rl, 'Translation completion (0-100)');
      }

      if (merged['mark-ai-created'] === undefined) {
        merged['mark-ai-created'] = await askYesNo(rl, 'Mark as AI-created', false);
      }
      if (merged['mark-human-created'] === undefined) {
        merged['mark-human-created'] = await askYesNo(rl, 'Mark as human-created', false);
      }
      if (merged['mark-human-reviewed'] === undefined) {
        merged['mark-human-reviewed'] = await askYesNo(rl, 'Mark as human-reviewed', false);
      }
      if (merged['mark-expert-verified'] === undefined) {
        merged['mark-expert-verified'] = await askYesNo(
          rl,
          'Mark as healthcare expert verified',
          false,
        );
      }
      if (merged.note === undefined) {
        merged.note = await askOptionalText(rl, 'Change note');
      }
    }
    return merged;
  } finally {
    rl.close();
  }
}

function extractFirstJsonObject(text) {
  try {
    return JSON.parse(text);
  } catch {
    /* continue */
  }

  const start = text.indexOf('{');
  const end = text.lastIndexOf('}');
  if (start === -1 || end === -1 || end <= start) {
    throw new Error('LLM did not return JSON.');
  }
  return JSON.parse(text.slice(start, end + 1));
}

function normalizeLlmPlan(plan) {
  if (!plan || typeof plan !== 'object') {
    throw new Error('LLM plan must be an object.');
  }

  return {
    title: typeof plan.title === 'string' ? plan.title.trim() : '',
    programSummary: typeof plan.programSummary === 'string' ? plan.programSummary.trim() : '',
    addTags: ensureArray(plan.addTags)
      .map((item) => String(item))
      .filter(Boolean),
    addProblems: ensureArray(plan.addProblems)
      .map((item) => String(item))
      .filter(Boolean),
    newModule:
      plan.newModule && typeof plan.newModule === 'object'
        ? {
            title: String(plan.newModule.title || '').trim(),
            overview: String(plan.newModule.overview || '').trim(),
            takeaways: ensureArray(plan.newModule.takeaways)
              .map((item) => String(item))
              .filter(Boolean),
            exercises: ensureArray(plan.newModule.exercises)
              .map((item) => String(item))
              .filter(Boolean),
            homework: ensureArray(plan.newModule.homework)
              .map((item) => String(item))
              .filter(Boolean),
          }
        : null,
    translationStatus:
      typeof plan.translationStatus === 'string' ? plan.translationStatus.trim() : '',
    completion:
      typeof plan.completion === 'number' && Number.isFinite(plan.completion)
        ? Math.max(0, Math.min(100, Math.round(plan.completion)))
        : null,
    markAiCreated: Boolean(plan.markAiCreated),
    markHumanCreated: Boolean(plan.markHumanCreated),
    markHumanReviewed: Boolean(plan.markHumanReviewed),
    markExpertVerified: Boolean(plan.markExpertVerified),
    note: typeof plan.note === 'string' ? plan.note.trim() : '',
  };
}

function mergeLlmPlanIntoOptions(options, llmPlan) {
  const merged = { ...options };
  const setIfEmpty = (key, value) => {
    if (value === undefined || value === null || value === '') return;
    if (merged[key] === undefined || merged[key] === '') {
      merged[key] = value;
    }
  };

  setIfEmpty('title', llmPlan.title);
  setIfEmpty('program-summary', llmPlan.programSummary);
  setIfEmpty('add-tags', llmPlan.addTags.join(','));
  setIfEmpty('add-problems', llmPlan.addProblems.join(','));
  if (llmPlan.newModule && llmPlan.newModule.title) {
    setIfEmpty('new-module-title', llmPlan.newModule.title);
    setIfEmpty('new-module-overview', llmPlan.newModule.overview);
    setIfEmpty('new-module-takeaways', llmPlan.newModule.takeaways.join(','));
    setIfEmpty('new-module-exercises', llmPlan.newModule.exercises.join(','));
    setIfEmpty('new-module-homework', llmPlan.newModule.homework.join(','));
  }
  setIfEmpty('translation-status', llmPlan.translationStatus);
  if (
    llmPlan.completion !== null &&
    (merged.completion === undefined || merged.completion === '')
  ) {
    merged.completion = String(llmPlan.completion);
  }
  if (llmPlan.markAiCreated && merged['mark-ai-created'] === undefined) {
    merged['mark-ai-created'] = true;
  }
  if (llmPlan.markHumanCreated && merged['mark-human-created'] === undefined) {
    merged['mark-human-created'] = true;
  }
  if (llmPlan.markHumanReviewed && merged['mark-human-reviewed'] === undefined) {
    merged['mark-human-reviewed'] = true;
  }
  if (llmPlan.markExpertVerified && merged['mark-expert-verified'] === undefined) {
    merged['mark-expert-verified'] = true;
  }
  setIfEmpty('note', llmPlan.note);
  return merged;
}

function readLlmPlanPayload(options) {
  if (options['llm-plan-file']) {
    const planPath = path.resolve(String(options['llm-plan-file']));
    if (!fs.existsSync(planPath)) {
      throw new Error(`llm plan file not found: ${planPath}`);
    }
    return fs.readFileSync(planPath, 'utf8');
  }
  if (options['llm-plan']) {
    return String(options['llm-plan']);
  }
  return '';
}

function tokenizeGoal(goal) {
  return String(goal || '')
    .toLowerCase()
    .split(/[^a-z0-9]+/)
    .map((token) => token.trim())
    .filter((token) => token.length >= 4);
}

function buildFallbackPlanFromGoal(goal) {
  const tokenPhrases = uniqueValues(tokenizeGoal(goal)).slice(0, 4);
  return {
    addTags: tokenPhrases.map((token) => token.replace(/\s+/g, '-')),
    addProblems: tokenPhrases,
    note: `LLM-guided update goal: ${goal}`,
  };
}

async function generateLlmImprovePlan(options) {
  const planPayload = readLlmPlanPayload(options);
  if (planPayload) {
    const rawPlan = extractFirstJsonObject(planPayload);
    return normalizeLlmPlan(rawPlan);
  }

  const goal = String(options.goal || '').trim();
  if (!goal) {
    throw new Error(
      'LLM mode requires --llm-plan "<json>" or --llm-plan-file <path>. Optionally add --goal for traceability.',
    );
  }

  const fallbackPlan = buildFallbackPlanFromGoal(goal);
  return normalizeLlmPlan(fallbackPlan);
}

function searchPrograms(query, options) {
  const q = normalizeText(query);
  const programs = filterPrograms(loadAllPrograms(), options);
  const matches = programs.filter((program) => {
    const tagText = (program.tags || []).join(' ');
    const condition = program.condition?.name || '';
    const signalText = (program.recommendationSignals?.problems || []).join(' ');
    const { locale } = loadLocale(program, options.lang);
    const title = locale?.title || '';
    const summary = locale?.summary || '';

    return (
      includesToken(program.id, q) ||
      includesToken(condition, q) ||
      includesToken(tagText, q) ||
      includesToken(signalText, q) ||
      includesToken(title, q) ||
      includesToken(summary, q)
    );
  });

  if (matches.length === 0) {
    console.log(`No programs matched "${query}".`);
    return;
  }

  for (const program of matches) {
    const { locale } = loadLocale(program, options.lang);
    console.log(`${program.id}: ${locale?.title || program.id}`);
  }
}

function scoreProgram(program, problem, lang) {
  const problemLower = normalizeText(problem);
  const tokens = tokenize(problem);
  let score = 0;

  const conditionText = normalizeText(program.condition?.name);
  const tagsText = normalizeText((program.tags || []).join(' '));
  const signalText = normalizeText((program.recommendationSignals?.problems || []).join(' '));

  if (signalText.includes(problemLower)) score += 6;
  if (conditionText.includes(problemLower)) score += 4;

  for (const token of tokens) {
    if (conditionText.includes(token)) score += 2;
    if (tagsText.includes(token)) score += 1;
    if (signalText.includes(token)) score += 2;
  }

  const { entry, locale } = loadLocale(program, lang);
  if (locale?.title && includesToken(locale.title, problemLower)) score += 2;
  if (locale?.summary && includesToken(locale.summary, problemLower)) score += 1;

  if (program.lineage?.humanReviewed) score += 1;
  if (program.lineage?.healthcareExpertVerified) score += 2;
  if (entry?.status === 'expert-verified') score += 1;

  return score;
}

function cmdRecommend(options) {
  const problem = options.problem;
  if (!problem) {
    throw new Error('Missing required option: --problem "<text>"');
  }

  const limit = Number(options.limit || 5);
  const lang = options.lang;

  const ranked = loadAllPrograms()
    .map((program) => ({
      program,
      score: scoreProgram(program, problem, lang),
    }))
    .filter((item) => item.score > 0)
    .sort((a, b) => b.score - a.score)
    .slice(0, limit);

  if (ranked.length === 0) {
    console.log(`No recommendations found for "${problem}".`);
    return;
  }

  for (const item of ranked) {
    const { program, score } = item;
    const { entry, locale } = loadLocale(program, lang);
    const translationInfo = entry ? `${entry.lang} (${entry.status})` : 'none';
    const badges = lineageBadges(program.lineage).join(', ');
    console.log(`${program.id} [score=${score}]`);
    console.log(`  Title: ${locale?.title || program.id}`);
    console.log(`  Condition: ${program.condition?.name || 'Unknown'}`);
    console.log(`  Translation: ${translationInfo}`);
    console.log(`  Badges: ${badges}`);
  }
}

function cmdShow(id, options) {
  const program = loadProgram(id);
  const { entry, locale } = loadLocale(program, options.lang);

  console.log(`${program.id} (${program.version})`);
  console.log(`Status: ${program.status}`);
  console.log(`Condition: ${program.condition?.name || 'Unknown'}`);
  console.log(`Badges: ${lineageBadges(program.lineage).join(', ')}`);
  console.log(`Languages: ${translationSummary(program)}`);

  if (!locale) {
    console.log('Locale content unavailable.');
    return;
  }

  console.log(`Locale: ${entry?.lang || locale.language}`);
  console.log(`Title: ${locale.title}`);
  console.log(`Summary: ${locale.summary}`);

  if (Array.isArray(locale.modules)) {
    console.log('Modules:');
    for (const module of locale.modules) {
      console.log(`  - ${module.id}: ${module.title}`);
    }
  }
}

function validateProgram(program) {
  const errors = [];

  if (!program.id || !/^cbt-[a-z0-9-]+$/.test(program.id)) {
    errors.push('id must match pattern: cbt-<slug>');
  }

  if (!program.version || !/^[0-9]+\.[0-9]+\.[0-9]+$/.test(program.version)) {
    errors.push('version must be semantic version x.y.z');
  }

  if (!program.condition || !program.condition.key || !program.condition.name) {
    errors.push('condition.key and condition.name are required');
  }

  if (!Array.isArray(program.tags) || program.tags.length === 0) {
    errors.push('at least one tag is required');
  }

  if (!program.lineage) {
    errors.push('lineage is required');
  } else {
    const neededFlags = ['aiCreated', 'humanCreated', 'humanReviewed', 'healthcareExpertVerified'];
    for (const flag of neededFlags) {
      if (typeof program.lineage[flag] !== 'boolean') {
        errors.push(`lineage.${flag} must be a boolean`);
      }
    }
  }

  if (!Array.isArray(program.translations) || program.translations.length === 0) {
    errors.push('at least one translation is required');
  } else {
    let qualityTranslationCount = 0;
    for (const entry of program.translations) {
      if (!entry.lang || !entry.path || !entry.status) {
        errors.push('translation entries require lang, status, and path');
        continue;
      }

      if (entry.status === 'human-reviewed' || entry.status === 'expert-verified') {
        qualityTranslationCount += 1;
      }

      const localePath = path.join(program._dir, entry.path);
      if (!fs.existsSync(localePath)) {
        errors.push(`missing locale file: ${entry.path}`);
        continue;
      }

      try {
        const locale = readJson(localePath);
        if (!locale.title || !locale.summary) {
          errors.push(`locale missing title/summary: ${entry.path}`);
        }
      } catch (error) {
        errors.push(`invalid locale JSON: ${entry.path} (${error.message})`);
      }
    }

    if (program.status === 'published' && qualityTranslationCount === 0) {
      errors.push('published programs require a human-reviewed or expert-verified translation');
    }
  }

  if (!program.recommendationSignals || !Array.isArray(program.recommendationSignals.problems)) {
    errors.push('recommendationSignals.problems is required');
  }

  if (!program.safety || !program.safety.medicalDisclaimer) {
    errors.push('safety.medicalDisclaimer is required');
  }

  const progressDir = path.join(program._dir, program.progressDir || 'progress');
  if (!isDirectory(progressDir) || fs.readdirSync(progressDir).length === 0) {
    errors.push('progress directory must contain at least one markdown entry');
  }

  return errors;
}

function cmdValidate(id) {
  const programs = id ? [loadProgram(id)] : loadAllPrograms();
  let failed = false;

  for (const program of programs) {
    const errors = validateProgram(program);
    if (errors.length === 0) {
      console.log(`${program.id}: OK`);
      continue;
    }

    failed = true;
    console.log(`${program.id}: FAILED`);
    for (const error of errors) {
      console.log(`  - ${error}`);
    }
  }

  if (failed) {
    process.exitCode = 1;
  }
}

function today() {
  return new Date().toISOString().slice(0, 10);
}

function cmdScaffold(id, options) {
  if (!id) {
    throw new Error('Missing required argument: <program-id>');
  }
  if (!options.title) {
    throw new Error('Missing required option: --title "<title>"');
  }
  if (!options.condition) {
    throw new Error('Missing required option: --condition "<condition>"');
  }

  const normalizedId = id.startsWith('cbt-') ? id : `cbt-${slugify(id)}`;
  const programDir = getProgramDir(normalizedId);
  if (fs.existsSync(programDir)) {
    throw new Error(`Program already exists: ${normalizedId}`);
  }

  const creator = options.creator || 'ai-assisted';

  const programTemplate = readJson(TEMPLATE_PROGRAM);
  const localeTemplate = readJson(TEMPLATE_LOCALE);

  programTemplate.id = normalizedId;
  programTemplate.condition = {
    key: slugify(options.condition),
    name: options.condition,
  };

  if (creator === 'human') {
    programTemplate.lineage.aiCreated = false;
    programTemplate.lineage.humanCreated = true;
  } else if (creator === 'ai') {
    programTemplate.lineage.aiCreated = true;
    programTemplate.lineage.humanCreated = false;
  } else {
    programTemplate.lineage.aiCreated = true;
    programTemplate.lineage.humanCreated = true;
  }

  localeTemplate.title = options.title;

  const localesDir = path.join(programDir, 'locales');
  const progressDir = path.join(programDir, 'progress');
  ensureDir(localesDir);
  ensureDir(progressDir);

  writeJson(path.join(programDir, 'program.json'), programTemplate);
  writeJson(path.join(localesDir, 'en.json'), localeTemplate);

  fs.writeFileSync(
    path.join(programDir, 'changelog.md'),
    `# Changelog\n\n## 0.1.0 - ${today()}\n\n- Scaffolded ${normalizedId} with cbt-programs CLI.\n`,
  );

  fs.writeFileSync(
    path.join(progressDir, `${today()}-scaffold-created.md`),
    `# Scaffold created\n\nDate: ${today()}\nProgram: ${normalizedId}\nAuthor: ${creator}\n\n## What changed\n\n- Generated metadata and English locale template.\n\n## Why this change\n\n- Initialize open-source program package for collaborative authoring.\n`,
  );

  console.log(`Created ${normalizedId}`);
  console.log(`- ${path.join(programDir, 'program.json')}`);
  console.log(`- ${path.join(programDir, 'locales', 'en.json')}`);
  console.log(`- ${path.join(programDir, 'progress', `${today()}-scaffold-created.md`)}`);
}

async function cmdImprove(id, options) {
  if (!id) {
    throw new Error('Missing required argument: <program-id>');
  }

  const program = loadProgram(id);
  let mergedOptions = await collectImproveOptionsInteractive(program, options);
  const lang = mergedOptions.lang || program.defaultLanguage || 'en';
  const { entry, locale, localePath } = ensureLocale(program, lang);

  let llmPlan = null;
  if (mergedOptions.llm) {
    llmPlan = await generateLlmImprovePlan(mergedOptions);
    mergedOptions = mergeLlmPlanIntoOptions(mergedOptions, llmPlan);
  }

  const changes = [];

  if (mergedOptions.title) {
    locale.title = mergedOptions.title;
    changes.push(`updated locale title (${lang})`);
  }

  if (mergedOptions['program-summary']) {
    locale.summary = mergedOptions['program-summary'];
    changes.push(`updated locale summary (${lang})`);
  }

  const addTags = parseCsv(mergedOptions['add-tags']);
  if (addTags.length > 0) {
    program.tags = ensureArray(program.tags);
    const before = program.tags.length;
    uniquePush(program.tags, addTags);
    if (program.tags.length > before) {
      changes.push(`added tags: ${addTags.join(', ')}`);
    }
  }

  const addProblems = parseCsv(mergedOptions['add-problems']);
  if (addProblems.length > 0) {
    if (!program.recommendationSignals || typeof program.recommendationSignals !== 'object') {
      program.recommendationSignals = { problems: [] };
    }
    program.recommendationSignals.problems = ensureArray(program.recommendationSignals.problems);
    const before = program.recommendationSignals.problems.length;
    uniquePush(program.recommendationSignals.problems, addProblems);
    if (program.recommendationSignals.problems.length > before) {
      changes.push(`added recommendation signals: ${addProblems.join(', ')}`);
    }
  }

  if (mergedOptions['new-module-title']) {
    locale.modules = ensureArray(locale.modules);
    const newModule = {
      id: `module-${locale.modules.length + 1}`,
      title: mergedOptions['new-module-title'],
      overview: mergedOptions['new-module-overview'] || 'Add module overview.',
      takeaways: parseCsv(mergedOptions['new-module-takeaways']),
      exercises: parseCsv(mergedOptions['new-module-exercises']),
      homework: parseCsv(mergedOptions['new-module-homework']),
    };
    locale.modules.push(newModule);
    changes.push(`added module: ${newModule.title}`);

    if (!program.content || typeof program.content !== 'object') {
      program.content = {};
    }
    program.content.moduleCount = locale.modules.length;
  }

  if (mergedOptions['translation-status']) {
    const allowed = new Set(['source', 'draft', 'human-reviewed', 'expert-verified']);
    if (!allowed.has(mergedOptions['translation-status'])) {
      throw new Error(
        'translation status must be one of: source, draft, human-reviewed, expert-verified',
      );
    }
    entry.status = mergedOptions['translation-status'];
    changes.push(`set translation status (${lang}) to ${entry.status}`);
  }

  if (mergedOptions.completion !== undefined && mergedOptions.completion !== '') {
    const completion = Number.parseInt(mergedOptions.completion, 10);
    if (!Number.isFinite(completion) || completion < 0 || completion > 100) {
      throw new Error('completion must be an integer between 0 and 100');
    }
    entry.completion = completion;
    changes.push(`set translation completion (${lang}) to ${completion}%`);
  }

  if (!program.lineage || typeof program.lineage !== 'object') {
    program.lineage = {
      aiCreated: false,
      humanCreated: false,
      humanReviewed: false,
      healthcareExpertVerified: false,
    };
  }

  if (mergedOptions['mark-ai-created']) {
    program.lineage.aiCreated = true;
    changes.push('marked AI-created');
  }
  if (mergedOptions['mark-human-created']) {
    program.lineage.humanCreated = true;
    changes.push('marked human-created');
  }
  if (mergedOptions['mark-human-reviewed']) {
    program.lineage.humanReviewed = true;
    if (entry.status === 'source' || entry.status === 'draft') {
      entry.status = 'human-reviewed';
    }
    changes.push('marked human-reviewed');
  }
  if (mergedOptions['mark-expert-verified']) {
    program.lineage.healthcareExpertVerified = true;
    entry.status = 'expert-verified';
    changes.push('marked healthcare expert verified');
  }

  if (changes.length === 0) {
    throw new Error(
      'No changes provided. Use flags like --title, --add-tags, --new-module-title, or --mark-human-reviewed',
    );
  }

  const oldVersion = program.version || '0.1.0';
  const newVersion = bumpPatchVersion(oldVersion);
  program.version = newVersion;

  const note = mergedOptions.note || `Improved ${program.id}`;

  if (mergedOptions['dry-run']) {
    console.log(`[dry-run] Would improve ${program.id} (${oldVersion} -> ${newVersion})`);
    if (llmPlan) {
      console.log('[dry-run] LLM plan:');
      console.log(JSON.stringify(llmPlan, null, 2));
    }
    console.log('[dry-run] Planned changes:');
    for (const change of changes) {
      console.log(`- ${change}`);
    }
    console.log(`[dry-run] Would update locale: ${localePath}`);
    console.log(`[dry-run] Would update program: ${getProgramFile(program.id || program._id)}`);
    console.log(
      `[dry-run] Would append changelog: ${path.join(program._dir, program.changeLog || 'changelog.md')}`,
    );
    console.log(
      `[dry-run] Would create progress note in: ${path.join(program._dir, program.progressDir || 'progress')}`,
    );
    return;
  }

  ensureDir(path.dirname(localePath));
  writeJson(localePath, locale);
  writeProgram(program);

  const changelogPath = path.join(program._dir, program.changeLog || 'changelog.md');
  if (!fs.existsSync(changelogPath)) {
    fs.writeFileSync(changelogPath, '# Changelog\n');
  }
  fs.appendFileSync(
    changelogPath,
    `\n## ${newVersion} - ${today()}\n\n- ${note}\n- Changes: ${changes.join('; ')}\n`,
  );

  const progressDir = path.join(program._dir, program.progressDir || 'progress');
  ensureDir(progressDir);
  const progressFile = path.join(
    progressDir,
    `${today()}-improve-${slugify(note).slice(0, 40) || 'update'}.md`,
  );
  const progressBody = `# ${note}\n\nDate: ${today()}\nProgram: ${program.id}\nAuthor: AI or Human contributor\n\n## What changed\n\n${changes
    .map((item) => `- ${item}`)
    .join(
      '\n',
    )}\n\n## Why this change\n\n- Improve quality, usability, and recommendation fit.\n\n## Validation\n\n- [ ] Metadata validated with \`cbt-programs validate ${program.id}\`\n- [ ] Translation status reviewed\n- [ ] Safety disclaimer retained\n`;
  fs.writeFileSync(progressFile, progressBody);

  console.log(`Improved ${program.id} (${oldVersion} -> ${newVersion})`);
  console.log(`Locale updated: ${localePath}`);
  console.log(`Program updated: ${getProgramFile(program.id || program._id)}`);
  console.log(`Changelog updated: ${changelogPath}`);
  console.log(`Progress note: ${progressFile}`);
}

function cmdProgress(id, options) {
  if (!id) {
    throw new Error('Missing required argument: <program-id>');
  }

  if (!options.title) {
    throw new Error('Missing required option: --title "<entry title>"');
  }

  const program = loadProgram(id);
  const progressDir = path.join(program._dir, program.progressDir || 'progress');
  ensureDir(progressDir);

  const fileName = `${today()}-${slugify(options.title)}.md`;
  const filePath = path.join(progressDir, fileName);
  const summary = options.summary || 'No summary provided.';

  const body = `# ${options.title}\n\nDate: ${today()}\nProgram: ${program.id}\nAuthor: AI or Human contributor\n\n## What changed\n\n- ${summary}\n\n## Why this change\n\n- Explain the rationale and expected impact.\n\n## Validation\n\n- [ ] Metadata updated\n- [ ] Translation status reviewed\n- [ ] Safety disclaimer retained\n`;

  fs.writeFileSync(filePath, body);

  const changelogPath = path.join(program._dir, program.changeLog || 'changelog.md');
  const changelogEntry = `\n## ${today()}\n\n- ${options.title}: ${summary}\n`;
  fs.appendFileSync(changelogPath, changelogEntry);

  console.log(`Created progress note: ${filePath}`);
  console.log(`Updated changelog: ${changelogPath}`);
}

function cmdAgentPrompt(id, options) {
  const program = loadProgram(id);
  const { entry, locale } = loadLocale(program, options.lang);
  if (!locale) {
    throw new Error(`Locale not found for ${id}${options.lang ? ` (${options.lang})` : ''}`);
  }

  const goal = options.goal || 'Help the user start and complete the next module safely.';
  const moduleList = (locale.modules || [])
    .map((module) => `- ${module.id}: ${module.title}`)
    .join('\n');

  const prompt = [
    `You are a CBT support assistant for program ${program.id}.`,
    `Title: ${locale.title}`,
    `Language: ${entry?.lang || locale.language}`,
    `Condition: ${program.condition?.name || 'unknown'}`,
    `Goal: ${goal}`,
    '',
    'Safety rules:',
    '- Do not diagnose or replace emergency care.',
    '- If user reports immediate risk, direct them to local emergency services now.',
    '- Stay within psychoeducation and behavior-change support.',
    '',
    'Program lineage labels:',
    `- ${lineageBadges(program.lineage).join(', ')}`,
    '',
    'Modules:',
    moduleList || '- No modules listed',
    '',
    'Interaction style:',
    '- Ask one clarifying question at a time.',
    '- Offer one concrete action step per reply.',
    '- Close with a check-in question and confidence rating (0-10).',
  ].join('\n');

  console.log(prompt);
}

async function main() {
  const { positional, options } = parseArgs(process.argv.slice(2));
  const command = positional[0];

  if (!command || command === 'help' || command === '--help') {
    usage();
    return;
  }

  try {
    if (command === 'list') {
      cmdList(options);
      return;
    }

    if (command === 'show') {
      cmdShow(positional[1], options);
      return;
    }

    if (command === 'search') {
      const query = positional.slice(1).join(' ').trim();
      if (!query) throw new Error('Missing search query');
      searchPrograms(query, options);
      return;
    }

    if (command === 'recommend') {
      cmdRecommend(options);
      return;
    }

    if (command === 'validate') {
      cmdValidate(positional[1]);
      return;
    }

    if (command === 'scaffold') {
      cmdScaffold(positional[1], options);
      return;
    }

    if (command === 'improve') {
      await cmdImprove(positional[1], options);
      return;
    }

    if (command === 'progress') {
      cmdProgress(positional[1], options);
      return;
    }

    if (command === 'agent-prompt') {
      cmdAgentPrompt(positional[1], options);
      return;
    }

    throw new Error(`Unknown command: ${command}`);
  } catch (error) {
    console.error(`Error: ${error.message}`);
    process.exitCode = 1;
  }
}

main().catch((error) => {
  console.error(`Error: ${error.message}`);
  process.exitCode = 1;
});
