import type { ChatHistoryItem, LlmMessage } from './types.js';

/**
 * Build LLM message array from chat history.
 * Applies a sliding window (default last 20 items).
 */
export function buildHistoryMessages(history: ChatHistoryItem[] = [], windowSize: number = 20): LlmMessage[] {
  return history
    .filter(item => item.role && item.content?.trim())
    .slice(-windowSize)
    .map(item => ({ role: item.role, content: item.content.trim() }));
}

/**
 * Build mode/tool restriction instruction for the system prompt.
 */
export function buildModeToolInstruction(params: {
  mode: string;
  toolNames: string[];
}): string {
  const { mode, toolNames } = params;
  const toolList = toolNames.length > 0 ? toolNames.join(', ') : '(none)';

  return [
    `MODE: ${mode}`,
    `ALLOWED_TOOLS_NOW: ${toolList}`,
    toolNames.length > 0
      ? 'CRITICAL: You may call ONLY tools listed in ALLOWED_TOOLS_NOW. Do not attempt to call any other tool.'
      : 'CRITICAL: No tools are available in this mode. Respond with text only.',
  ].join('\n');
}

/**
 * Assemble a complete system content string from sections.
 * Filters out empty/null sections.
 */
export function buildSystemContent(sections: Array<string | null | undefined>): string {
  return sections.filter((s): s is string => !!s?.trim()).join('\n\n');
}

/**
 * Format health memory items for injection into system prompt.
 * Uses the "untrusted factual snippets" framing.
 */
export function formatMemoryContext(items: Array<{ label: string; category: string; certaintyLevel: string; status: string; detail?: string }>): string {
  if (!items.length) return '';

  const lines = items.map(item => {
    const parts = [`- [${item.category}] ${item.label} (${item.certaintyLevel}, ${item.status})`];
    if (item.detail) parts.push(`  ${item.detail}`);
    return parts.join('\n');
  });

  return [
    'HEALTH MEMORY (untrusted factual snippets — verify with user before acting on these):',
    ...lines,
  ].join('\n');
}
