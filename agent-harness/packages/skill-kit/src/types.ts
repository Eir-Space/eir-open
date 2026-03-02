import { z } from 'zod';

export const skillMetaSchema = z.object({
  name: z.string().min(1),
  description: z.string().optional(),
  modes: z.array(z.string()).default([]),
  requiredTools: z.array(z.string()).default([]),
  languages: z.array(z.string()).default(['en']),
});

export type SkillMeta = z.infer<typeof skillMetaSchema>;

export interface LoadedSkill {
  meta: SkillMeta;
  /** Map of language code to prompt text. Key 'default' is the SKILL.md prompt. */
  prompts: Record<string, string>;
  /** Filesystem path to the skill directory */
  path: string;
}
