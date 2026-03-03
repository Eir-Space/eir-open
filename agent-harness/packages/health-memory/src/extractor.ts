import { randomUUID } from 'node:crypto';
import type { MemoryItem } from './schemas.js';
import { toCertainty } from './confidence.js';

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
  return conditions.map((condition) => ({
    id: randomUUID(),
    category: condition.category,
    label: condition.label,
    sourceType,
    confidence: Math.max(0, Math.min(1, condition.confidence)),
    certaintyLevel: toCertainty(condition.confidence),
    status: 'inferred' as const,
    evidenceRefs: [],
    observedAt: now,
    updatedAt: now,
  }));
}
