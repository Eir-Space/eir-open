export interface ModeDefinition {
  allowedTools: string[];
  activeSkills: string[];
  maxToolIterations: number;
  retrievalBudget: number;
}

export interface RouterDecision extends ModeDefinition {
  mode: string;
}

/** Abstract interface for mode routing. Platforms implement their own routing logic. */
export interface ModeRouter {
  resolve(input: ModeRouterInput): RouterDecision;
}

export interface ModeRouterInput {
  message: string;
  history?: Array<{ role: 'user' | 'assistant'; content: string }>;
  context?: Record<string, unknown>;
}

export interface KeywordRule {
  keywords: string[];
  mode: string;
  /** If true, check that keyword is not merely informational (e.g. "what is X?") */
  excludeInformational?: boolean;
  /** If provided, only match when these patterns are NOT present */
  excludePatterns?: RegExp[];
}

export interface KeywordModeRouterConfig {
  modes: Record<string, ModeDefinition>;
  rules: KeywordRule[];
  defaultMode: string;
  /** How many recent history messages to include in keyword scan. Default: 3 */
  historyScanDepth?: number;
}

export class KeywordModeRouter implements ModeRouter {
  constructor(private config: KeywordModeRouterConfig) {}

  resolve(input: ModeRouterInput): RouterDecision {
    const { message, history = [] } = input;
    const messageLower = message.toLowerCase();

    // Build context string from recent history
    const recentHistory = history.slice(-(this.config.historyScanDepth ?? 3));
    const contextText = recentHistory.map(m => m.content).join(' ').toLowerCase();
    const fullText = `${messageLower} ${contextText}`;

    // Check rules in priority order
    for (const rule of this.config.rules) {
      const matched = rule.keywords.some(kw => fullText.includes(kw.toLowerCase()));
      if (!matched) continue;

      // Check exclude patterns
      if (rule.excludePatterns?.some(p => p.test(messageLower))) continue;

      // Check informational exclusion
      if (rule.excludeInformational && this.isInformational(messageLower)) continue;

      const modeDef = this.config.modes[rule.mode];
      if (!modeDef) continue;

      return { mode: rule.mode, ...modeDef };
    }

    // Default mode
    const defaultDef = this.config.modes[this.config.defaultMode];
    if (!defaultDef) {
      throw new Error(`Default mode "${this.config.defaultMode}" not found in modes config`);
    }
    return { mode: this.config.defaultMode, ...defaultDef };
  }

  private isInformational(text: string): boolean {
    const informationalPatterns = [
      /^(what|how|why|when|where|who|which|can you explain|tell me about)\b/i,
      /\b(what is|what are|how does|how do|explain)\b/i,
    ];
    return informationalPatterns.some(p => p.test(text));
  }
}
