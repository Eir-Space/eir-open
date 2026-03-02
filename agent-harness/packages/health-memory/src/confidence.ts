import type { MemoryCertainty, MemoryItem } from './schemas.js';

/**
 * Map a numeric confidence score to a certainty level.
 * >= 0.85 -> high, >= 0.6 -> medium, else -> low
 */
export function toCertainty(confidence: number): MemoryCertainty {
  if (confidence >= 0.85) return 'high';
  if (confidence >= 0.6) return 'medium';
  return 'low';
}

/**
 * Generate a dedup key for a memory item.
 * Two items with the same dedup key represent the same concept.
 */
export function dedupKey(item: Pick<MemoryItem, 'category' | 'label'>): string {
  return `${item.category}:${item.label.toLowerCase().trim()}`;
}

/**
 * Apply user confirmation to a memory item.
 * Confirmed items get confidence >= 0.92 and certainty = high.
 */
export function confirmItem(item: MemoryItem): MemoryItem {
  return {
    ...item,
    status: 'user_confirmed',
    confidence: Math.max(item.confidence, 0.92),
    certaintyLevel: 'high',
    updatedAt: new Date().toISOString(),
  };
}

/**
 * Dismiss a memory item.
 */
export function dismissItem(item: MemoryItem): MemoryItem {
  return {
    ...item,
    status: 'dismissed',
    updatedAt: new Date().toISOString(),
  };
}
