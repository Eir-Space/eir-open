import { z } from 'zod';

export const scriptDeclarationSchema = z.object({
  name: z.string().min(1),
  entrypoint: z.string().min(1),
  description: z.string().optional(),
  parameters: z.record(z.unknown()).optional(),
});

export const skillMetaSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
  modes: z.array(z.string()).default([]),
  requiredTools: z.array(z.string()).default([]),
  languages: z.array(z.string()).default(['en']),
  scripts: z.array(scriptDeclarationSchema).default([]),
});

export type SkillMeta = z.infer<typeof skillMetaSchema>;

export interface SkillScript {
  name: string;
  /** Resolved absolute path to the script entrypoint */
  entrypoint: string;
  description?: string;
  parameters?: Record<string, unknown>;
}

export interface LoadedSkill {
  meta: SkillMeta;
  /** Map of language code to prompt text. Key 'default' is the SKILL.md prompt. */
  prompts: Record<string, string>;
  /** Filesystem path to the skill directory */
  path: string;
  /** Resolved executable scripts for this skill */
  scripts: SkillScript[];
}
