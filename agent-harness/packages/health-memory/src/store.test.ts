import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { InMemoryHealthMemoryStore } from './store.js';
import type { MemoryItem } from './schemas.js';

function makeItem(overrides: Partial<MemoryItem> = {}): MemoryItem {
  const now = new Date().toISOString();
  return {
    id: `test-${Math.random().toString(36).slice(2)}`,
    category: 'concern',
    label: 'Headache',
    sourceType: 'chat',
    confidence: 0.7,
    certaintyLevel: 'medium',
    status: 'inferred',
    evidenceRefs: [],
    observedAt: now,
    updatedAt: now,
    ...overrides,
  };
}

describe('InMemoryHealthMemoryStore', () => {
  describe('upsert — new items', () => {
    it('stores a new item and retrieves it by ID', async () => {
      const store = new InMemoryHealthMemoryStore();
      const item = makeItem({ id: 'item-1' });
      await store.upsert(item);
      const retrieved = await store.getById('item-1');
      assert.equal(retrieved?.label, 'Headache');
    });

    it('validates item against schema', async () => {
      const store = new InMemoryHealthMemoryStore();
      const invalid = { id: '', category: 'invalid' } as unknown as MemoryItem;
      await assert.rejects(() => store.upsert(invalid));
    });
  });

  describe('upsert — dedup/merge', () => {
    it('merges items with same dedup key', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Headache', confidence: 0.5 }));
      await store.upsert(makeItem({ id: 'b', label: 'Headache', confidence: 0.8 }));

      const all = await store.getAll();
      assert.equal(all.length, 1);
      assert.equal(all[0].confidence, 0.8);
    });

    it('deduplicates evidence refs on merge', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({
        id: 'a',
        label: 'Headache',
        evidenceRefs: [{ type: 'message', id: 'msg-1' }],
      }));
      await store.upsert(makeItem({
        id: 'b',
        label: 'Headache',
        evidenceRefs: [{ type: 'message', id: 'msg-1' }, { type: 'document', id: 'doc-1' }],
      }));

      const all = await store.getAll();
      assert.equal(all[0].evidenceRefs.length, 2, 'Should deduplicate message ref');
      const types = all[0].evidenceRefs.map(r => `${r.type}:${r.id}`);
      assert.ok(types.includes('message:msg-1'));
      assert.ok(types.includes('document:doc-1'));
    });

    it('keeps higher status on merge', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Headache', status: 'inferred' }));
      await store.upsert(makeItem({ id: 'b', label: 'Headache', status: 'record_backed' }));

      const all = await store.getAll();
      assert.equal(all[0].status, 'record_backed');
    });

    it('preserves detail from newer item', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Headache', detail: 'old' }));
      await store.upsert(makeItem({ id: 'b', label: 'Headache', detail: 'new' }));

      const all = await store.getAll();
      assert.equal(all[0].detail, 'new');
    });

    it('falls back to existing detail when new detail is undefined', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Headache', detail: 'existing' }));
      await store.upsert(makeItem({ id: 'b', label: 'Headache' }));

      const all = await store.getAll();
      assert.equal(all[0].detail, 'existing');
    });

    it('updates certaintyLevel based on merged confidence', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Headache', confidence: 0.5, certaintyLevel: 'low' }));
      await store.upsert(makeItem({ id: 'b', label: 'Headache', confidence: 0.9, certaintyLevel: 'high' }));

      const all = await store.getAll();
      assert.equal(all[0].certaintyLevel, 'high');
    });
  });

  describe('getAll', () => {
    it('returns all non-dismissed items', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'A' }));
      await store.upsert(makeItem({ id: 'b', label: 'B', status: 'dismissed' }));
      await store.upsert(makeItem({ id: 'c', label: 'C' }));

      const all = await store.getAll();
      assert.equal(all.length, 2);
    });

    it('filters by category', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'A', category: 'diagnosis' }));
      await store.upsert(makeItem({ id: 'b', label: 'B', category: 'concern' }));

      const diagnoses = await store.getAll({ category: 'diagnosis' });
      assert.equal(diagnoses.length, 1);
      assert.equal(diagnoses[0].category, 'diagnosis');
    });

    it('returns empty array when store is empty', async () => {
      const store = new InMemoryHealthMemoryStore();
      const all = await store.getAll();
      assert.deepEqual(all, []);
    });
  });

  describe('getById', () => {
    it('returns item by ID', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'item-1', label: 'Test' }));
      const item = await store.getById('item-1');
      assert.equal(item?.label, 'Test');
    });

    it('returns null for unknown ID', async () => {
      const store = new InMemoryHealthMemoryStore();
      assert.equal(await store.getById('nonexistent'), null);
    });
  });

  describe('confirm', () => {
    it('confirms an item', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'item-1' }));
      const confirmed = await store.confirm('item-1');
      assert.equal(confirmed?.status, 'user_confirmed');
      assert.ok((confirmed?.confidence ?? 0) >= 0.92);
    });

    it('returns null for unknown ID', async () => {
      const store = new InMemoryHealthMemoryStore();
      assert.equal(await store.confirm('nonexistent'), null);
    });
  });

  describe('dismiss', () => {
    it('dismisses an item', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'item-1' }));
      const dismissed = await store.dismiss('item-1');
      assert.equal(dismissed?.status, 'dismissed');
    });

    it('removes from dedup index so same label can be re-added', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'item-1', label: 'Headache' }));
      await store.dismiss('item-1');

      // New item with same label should create a new entry
      const newItem = await store.upsert(makeItem({ id: 'item-2', label: 'Headache' }));
      assert.equal(newItem.id, 'item-2');

      const all = await store.getAll();
      assert.equal(all.length, 1);
      assert.equal(all[0].id, 'item-2');
    });

    it('returns null for unknown ID', async () => {
      const store = new InMemoryHealthMemoryStore();
      assert.equal(await store.dismiss('nonexistent'), null);
    });
  });

  describe('delete', () => {
    it('removes item from store and dedup index', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'item-1', label: 'Headache' }));
      const result = await store.delete('item-1');
      assert.equal(result, true);
      assert.equal(await store.getById('item-1'), null);

      // Can add with same label now
      await store.upsert(makeItem({ id: 'item-2', label: 'Headache' }));
      assert.ok(await store.getById('item-2'));
    });

    it('returns false for unknown ID', async () => {
      const store = new InMemoryHealthMemoryStore();
      assert.equal(await store.delete('nonexistent'), false);
    });
  });

  describe('search', () => {
    it('returns items matching query terms', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Chronic Headache', category: 'concern' }));
      await store.upsert(makeItem({ id: 'b', label: 'Diabetes', category: 'diagnosis' }));

      const results = await store.search({ query: 'headache' });
      assert.equal(results.length, 1);
      assert.equal(results[0].item.label, 'Chronic Headache');
    });

    it('scores by fraction of matching terms', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Chronic Headache', detail: 'severe pain' }));

      const results = await store.search({ query: 'chronic headache' });
      assert.equal(results[0].score, 1); // Both terms match
    });

    it('respects limit parameter', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Pain A' }));
      await store.upsert(makeItem({ id: 'b', label: 'Pain B' }));
      await store.upsert(makeItem({ id: 'c', label: 'Pain C' }));

      const results = await store.search({ query: 'pain', limit: 2 });
      assert.equal(results.length, 2);
    });

    it('filters by category', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Pain', category: 'concern' }));
      await store.upsert(makeItem({ id: 'b', label: 'Pain Disorder', category: 'diagnosis' }));

      const results = await store.search({ query: 'pain', category: 'diagnosis' });
      assert.equal(results.length, 1);
      assert.equal(results[0].item.category, 'diagnosis');
    });

    it('filters by minConfidence', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Pain A', confidence: 0.3 }));
      await store.upsert(makeItem({ id: 'b', label: 'Pain B', confidence: 0.8 }));

      const results = await store.search({ query: 'pain', minConfidence: 0.5 });
      assert.equal(results.length, 1);
      assert.equal(results[0].item.confidence, 0.8);
    });

    it('returns empty for empty query', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Test' }));
      const results = await store.search({ query: '' });
      assert.deepEqual(results, []);
    });

    it('returns empty for no matches', async () => {
      const store = new InMemoryHealthMemoryStore();
      await store.upsert(makeItem({ id: 'a', label: 'Headache' }));
      const results = await store.search({ query: 'zzzzz' });
      assert.deepEqual(results, []);
    });
  });
});
