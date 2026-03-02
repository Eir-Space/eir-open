import { parseSkillMarkdown } from './parser.js';
import type { LoadedSkill } from './types.js';

// --- Registry Types ---

export interface SkillRegistryEntry {
  name: string;
  title: string;
  slug: string;
  owner: string;
  repoUrl: string;
  skillPath: string;
  summary: string;
  domainTags: string[];
  version: string;
  healthMdCompatible: boolean;
}

export interface SkillRegistryClient {
  /** Search for skills by query string. */
  search(query: string): Promise<SkillRegistryEntry[]>;
  /** Get a single skill by its slug. */
  getBySlug(slug: string): Promise<SkillRegistryEntry | null>;
}

// --- Default Implementation ---

/**
 * Client for the EIR skill registry at skills.eir.space.
 * Uses only fetch (Node 18+ built-in), no external dependencies.
 */
export class EirSkillRegistryClient implements SkillRegistryClient {
  constructor(private baseUrl: string = 'https://skills.eir.space') {}

  async search(query: string): Promise<SkillRegistryEntry[]> {
    const url = `${this.baseUrl}/api/skills?q=${encodeURIComponent(query)}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`Registry search failed: ${response.status} ${response.statusText}`);
    }
    const data = await response.json() as { skills?: SkillRegistryEntry[] };
    return data.skills ?? [];
  }

  async getBySlug(slug: string): Promise<SkillRegistryEntry | null> {
    const results = await this.search(slug);
    return results.find(s => s.slug === slug) ?? null;
  }
}

// --- Remote Skill Loading ---

/**
 * Load a skill from a remote registry entry.
 * Fetches the SKILL.md from the GitHub raw URL and parses it.
 * Scripts are not supported for remote skills (scripts array will be empty).
 */
export async function loadRemoteSkill(entry: SkillRegistryEntry): Promise<LoadedSkill | null> {
  // Build raw GitHub URL for SKILL.md
  const repoMatch = entry.repoUrl.match(/github\.com\/([^/]+)\/([^/]+)/);
  if (!repoMatch) return null;

  const [, owner, repo] = repoMatch;
  const skillPath = entry.skillPath.replace(/^\//, '').replace(/\/$/, '');
  const rawUrl = `https://raw.githubusercontent.com/${owner}/${repo}/main/${skillPath}/SKILL.md`;

  const response = await fetch(rawUrl);
  if (!response.ok) return null;

  const content = await response.text();
  const parsed = parseSkillMarkdown(content);

  return {
    meta: { ...parsed.meta, name: entry.name || parsed.meta.name },
    prompts: { default: parsed.body },
    path: entry.repoUrl,
    scripts: [],
  };
}
