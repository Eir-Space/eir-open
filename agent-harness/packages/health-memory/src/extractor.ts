import type { MemoryItem } from './schemas.js';

/**
 * Extracted condition from conversation, before being turned into a MemoryItem.
 */
export interface ExtractedCondition {
  label: string;
  category: 'diagnosis' | 'concern' | 'observation';
  confidence: number;
}

/**
 * Abstract interface for LLM-based condition extraction.
 * Platforms implement this with their own LLM provider and prompts.
 */
export interface ConditionExtractor {
  /**
   * Extract health conditions from conversation messages.
   * Returns raw extracted conditions (not yet stored in memory).
   */
  extract(messages: Array<{ role: 'user' | 'assistant'; content: string }>): Promise<ExtractedCondition[]>;
}

/**
 * Convert raw extracted conditions to MemoryItems.
 */
export function toMemoryItems(conditions: ExtractedCondition[], sourceType: 'chat' | 'journal' = 'chat'): MemoryItem[] {
  const now = new Date().toISOString();
  return conditions.map((condition, i) => ({
    id: `extracted-${Date.now()}-${i}`,
    category: condition.category,
    label: condition.label,
    sourceType,
    confidence: Math.max(0, Math.min(1, condition.confidence)),
    certaintyLevel: toCertaintyLevel(condition.confidence),
    status: 'inferred' as const,
    evidenceRefs: [],
    observedAt: now,
    updatedAt: now,
  }));
}

function toCertaintyLevel(confidence: number): 'low' | 'medium' | 'high' {
  if (confidence >= 0.85) return 'high';
  if (confidence >= 0.6) return 'medium';
  return 'low';
}
