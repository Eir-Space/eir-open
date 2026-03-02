import type { MemoryItem, MemoryCategory } from './schemas.js';
import { memoryItemSchema } from './schemas.js';
import { dedupKey, toCertainty, confirmItem, dismissItem } from './confidence.js';

/**
 * Abstract store interface. Platforms implement this with their own storage backend
 * (Supabase, SQLite, encrypted localStorage, etc.)
 */
export interface HealthMemoryStore {
  /** Get all non-dismissed items, optionally filtered by category */
  getAll(options?: { category?: MemoryCategory }): Promise<MemoryItem[]>;
  /** Get a single item by ID */
  getById(id: string): Promise<MemoryItem | null>;
  /** Upsert an item. If an item with the same dedup key exists, merge it. */
  upsert(item: MemoryItem): Promise<MemoryItem>;
  /** Confirm a memory item by ID */
  confirm(id: string): Promise<MemoryItem | null>;
  /** Dismiss a memory item by ID */
  dismiss(id: string): Promise<MemoryItem | null>;
  /** Delete an item by ID */
  delete(id: string): Promise<boolean>;
}

/**
 * Reference in-memory implementation of HealthMemoryStore.
 * Suitable for testing, demos, and single-session agents.
 */
export class InMemoryHealthMemoryStore implements HealthMemoryStore {
  private items = new Map<string, MemoryItem>();
  /** Maps dedup key -> item ID for fast dedup lookups */
  private dedupIndex = new Map<string, string>();

  async getAll(options?: { category?: MemoryCategory }): Promise<MemoryItem[]> {
    const all = Array.from(this.items.values()).filter(item => item.status !== 'dismissed');
    if (options?.category) {
      return all.filter(item => item.category === options.category);
    }
    return all;
  }

  async getById(id: string): Promise<MemoryItem | null> {
    return this.items.get(id) ?? null;
  }

  async upsert(item: MemoryItem): Promise<MemoryItem> {
    // Validate
    const validated = memoryItemSchema.parse(item);

    // Check for existing item with same dedup key
    const key = dedupKey(validated);
    const existingId = this.dedupIndex.get(key);

    if (existingId && existingId !== validated.id) {
      // Merge: keep higher confidence, merge evidence refs
      const existing = this.items.get(existingId)!;
      const merged: MemoryItem = {
        ...existing,
        confidence: Math.max(existing.confidence, validated.confidence),
        certaintyLevel: toCertainty(Math.max(existing.confidence, validated.confidence)),
        detail: validated.detail ?? existing.detail,
        evidenceRefs: [...existing.evidenceRefs, ...validated.evidenceRefs],
        updatedAt: new Date().toISOString(),
        // Keep higher status (user_confirmed > record_backed > inferred)
        status: this.higherStatus(existing.status, validated.status),
      };
      this.items.set(existingId, merged);
      return merged;
    }

    // New item or update by same ID
    this.items.set(validated.id, validated);
    this.dedupIndex.set(key, validated.id);
    return validated;
  }

  async confirm(id: string): Promise<MemoryItem | null> {
    const item = this.items.get(id);
    if (!item) return null;
    const confirmed = confirmItem(item);
    this.items.set(id, confirmed);
    return confirmed;
  }

  async dismiss(id: string): Promise<MemoryItem | null> {
    const item = this.items.get(id);
    if (!item) return null;
    const dismissed = dismissItem(item);
    this.items.set(id, dismissed);
    // Remove from dedup index so a new entry with same label can be added
    const key = dedupKey(dismissed);
    this.dedupIndex.delete(key);
    return dismissed;
  }

  async delete(id: string): Promise<boolean> {
    const item = this.items.get(id);
    if (!item) return false;
    const key = dedupKey(item);
    this.dedupIndex.delete(key);
    this.items.delete(id);
    return true;
  }

  private higherStatus(a: string, b: string): MemoryItem['status'] {
    const rank: Record<string, number> = {
      dismissed: 0,
      inferred: 1,
      record_backed: 2,
      user_confirmed: 3,
    };
    return (rank[a] ?? 0) >= (rank[b] ?? 0) ? a as MemoryItem['status'] : b as MemoryItem['status'];
  }
}
