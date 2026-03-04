import { skillMetaSchema, type SkillMeta } from './types.js';

interface ParseResult {
  meta: SkillMeta;
  body: string;
}

/**
 * Parse a SKILL.md file with YAML frontmatter.
 * Frontmatter is between --- delimiters at the start of the file.
 */
export function parseSkillMarkdown(content: string): ParseResult {
  const trimmed = content.trimStart();

  if (!trimmed.startsWith('---')) {
    // No frontmatter — return entire content as body with minimal meta
    return {
      meta: skillMetaSchema.parse({ name: 'unknown' }),
      body: content.trim(),
    };
  }

  const endIndex = trimmed.indexOf('---', 3);
  if (endIndex === -1) {
    return {
      meta: skillMetaSchema.parse({ name: 'unknown' }),
      body: content.trim(),
    };
  }

  const frontmatterStr = trimmed.slice(3, endIndex).trim();
  const body = trimmed.slice(endIndex + 3).trim();

  const raw = parseSimpleYaml(frontmatterStr);
  const meta = skillMetaSchema.parse(raw);

  return { meta, body };
}

/**
 * Minimal YAML parser for skill frontmatter.
 * Handles: string values, arrays (both inline [a, b] and multi-line - a\n- b)
 */
function parseSimpleYaml(yaml: string): Record<string, unknown> {
  const result: Record<string, unknown> = {};
  const lines = yaml.split('\n');
  let currentKey: string | null = null;
  let currentArray: string[] | null = null;

  for (const line of lines) {
    const trimmedLine = line.trim();
    if (!trimmedLine || trimmedLine.startsWith('#')) continue;

    // Array continuation: "  - value"
    if (trimmedLine.startsWith('- ') && currentKey && currentArray) {
      currentArray.push(trimmedLine.slice(2).trim());
      result[currentKey] = currentArray;
      continue;
    }

    // Key-value pair
    const colonIndex = trimmedLine.indexOf(':');
    if (colonIndex === -1) continue;

    // Flush previous array
    currentArray = null;

    const key = trimmedLine.slice(0, colonIndex).trim();
    const value = trimmedLine.slice(colonIndex + 1).trim();
    currentKey = key;

    if (!value) {
      // Value on next lines (array)
      currentArray = [];
      result[key] = currentArray;
    } else if (value.startsWith('[') && value.endsWith(']')) {
      // Inline array: [a, b, c]
      const items = value
        .slice(1, -1)
        .split(',')
        .map((s) => s.trim())
        .filter(Boolean);
      result[key] = items;
      currentArray = null;
    } else {
      // Simple string value (strip quotes if present)
      result[key] = value.replace(/^["']|["']$/g, '');
      currentArray = null;
    }
  }

  return result;
}
