import type { LoadedSkill } from './types.js';
import { createScriptToolHandler, type ScriptToolHandler } from './scriptRunner.js';

export interface SkillToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

export interface SkillToolSet {
  definitions: SkillToolDefinition[];
  handlers: Record<string, ScriptToolHandler>;
}

/**
 * Build tool definitions and handlers from loaded skills that have scripts.
 * Each script becomes a tool the LLM can call.
 */
export function buildToolsFromSkills(
  skills: LoadedSkill[],
  options?: { timeoutMs?: number }
): SkillToolSet {
  const definitions: SkillToolDefinition[] = [];
  const handlers: Record<string, ScriptToolHandler> = {};

  for (const skill of skills) {
    for (const script of skill.scripts) {
      const toolName = `${skill.meta.name}__${script.name}`;

      definitions.push({
        type: 'function',
        function: {
          name: toolName,
          description: script.description ?? `Run ${script.name} from ${skill.meta.name} skill`,
          parameters: script.parameters ?? {
            type: 'object',
            properties: {
              query: { type: 'string', description: 'The query or input for the script' },
            },
          },
        },
      });

      handlers[toolName] = createScriptToolHandler(script, options);
    }
  }

  return { definitions, handlers };
}
