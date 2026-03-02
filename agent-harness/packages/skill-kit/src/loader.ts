import * as fs from 'node:fs';
import * as path from 'node:path';
import { parseSkillMarkdown } from './parser.js';
import { skillMetaSchema, type LoadedSkill, type SkillMeta, type SkillScript } from './types.js';

/**
 * Load a single skill from a directory.
 * Looks for SKILL.md (with frontmatter) first, falls back to skill.json.
 * Discovers SKILL.{lang}.md language variants.
 */
export function loadSkill(skillDir: string): LoadedSkill | null {
  const skillMdPath = path.join(skillDir, 'SKILL.md');
  const skillJsonPath = path.join(skillDir, 'skill.json');

  let meta: SkillMeta;
  const prompts: Record<string, string> = {};

  if (fs.existsSync(skillMdPath)) {
    // New format: SKILL.md with frontmatter
    const content = fs.readFileSync(skillMdPath, 'utf-8');
    const parsed = parseSkillMarkdown(content);
    meta = parsed.meta;
    prompts['default'] = parsed.body;

    // Detect default language from frontmatter
    if (meta.languages.length > 0) {
      prompts[meta.languages[0]] = parsed.body;
    }
  } else if (fs.existsSync(skillJsonPath)) {
    // Legacy format: skill.json
    try {
      const raw = JSON.parse(fs.readFileSync(skillJsonPath, 'utf-8'));
      meta = skillMetaSchema.parse({
        name: raw.name ?? path.basename(skillDir),
        description: raw.description,
        modes: raw.modes ?? [],
        requiredTools: raw.requiredTools ?? [],
        languages: raw.languages ?? ['en'],
      });
    } catch {
      return null;
    }
  } else {
    return null;
  }

  // Discover language-specific prompts: SKILL.{lang}.md
  try {
    const files = fs.readdirSync(skillDir);
    for (const file of files) {
      const match = file.match(/^SKILL\.([a-z]{2}(?:-[A-Z]{2})?)\.md$/);
      if (match) {
        const lang = match[1];
        const langContent = fs.readFileSync(path.join(skillDir, file), 'utf-8').trim();
        prompts[lang] = langContent;
      }
    }
  } catch {
    // Directory read failed, continue with what we have
  }

  // If we have language prompts from legacy format but no SKILL.md body
  if (!prompts['default'] && Object.keys(prompts).length > 0) {
    // Use first available language as default
    const firstLang = Object.keys(prompts)[0];
    prompts['default'] = prompts[firstLang];
  }

  if (!prompts['default'] && Object.keys(prompts).length === 0) {
    return null; // No prompt content at all
  }

  // Resolve scripts declared in frontmatter (explicit)
  const scripts: SkillScript[] = [];
  for (const scriptDef of meta.scripts) {
    const resolved = path.resolve(skillDir, scriptDef.entrypoint);
    if (fs.existsSync(resolved)) {
      scripts.push({
        name: scriptDef.name,
        entrypoint: resolved,
        description: scriptDef.description,
        parameters: scriptDef.parameters,
      });
    }
  }

  // Auto-discover from scripts/ directory if no explicit declarations
  if (scripts.length === 0) {
    const scriptsDir = path.join(skillDir, 'scripts');
    if (fs.existsSync(scriptsDir)) {
      const scriptFiles = fs.readdirSync(scriptsDir)
        .filter(f => f.endsWith('.js') || f.endsWith('.mjs'));
      for (const file of scriptFiles) {
        scripts.push({
          name: path.basename(file, path.extname(file)),
          entrypoint: path.join(scriptsDir, file),
        });
      }
    }
  }

  return { meta, prompts, path: skillDir, scripts };
}

/**
 * Load all skills from a parent directory.
 * Each subdirectory is treated as a potential skill.
 */
export function loadSkillDirectory(parentDir: string): Map<string, LoadedSkill> {
  const skills = new Map<string, LoadedSkill>();

  if (!fs.existsSync(parentDir)) return skills;

  const entries = fs.readdirSync(parentDir, { withFileTypes: true });
  for (const entry of entries) {
    if (!entry.isDirectory()) continue;

    const skill = loadSkill(path.join(parentDir, entry.name));
    if (skill) {
      skills.set(skill.meta.name, skill);
    }
  }

  return skills;
}

/**
 * Filter skills by mode. Returns skills whose modes array includes the given mode,
 * or skills with an empty modes array (available in all modes).
 */
export function getSkillsForMode(skills: Map<string, LoadedSkill> | LoadedSkill[], mode: string): LoadedSkill[] {
  const skillArray = skills instanceof Map ? Array.from(skills.values()) : skills;
  return skillArray.filter(skill =>
    skill.meta.modes.length === 0 || skill.meta.modes.includes(mode)
  );
}

/**
 * Build a combined prompt from skills for a given language.
 * Falls back: requested language → 'default' → first available.
 */
export function buildSkillPrompt(skills: LoadedSkill[], language: string = 'en'): string {
  const parts: string[] = [];

  for (const skill of skills) {
    const prompt = skill.prompts[language]
      ?? skill.prompts['default']
      ?? Object.values(skill.prompts)[0];

    if (prompt?.trim()) {
      parts.push(prompt.trim());
    }
  }

  return parts.join('\n\n');
}
