import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { toMemoryItems, type ExtractedCondition } from './extractor.js';

describe('toMemoryItems', () => {
  const conditions: ExtractedCondition[] = [
    { label: 'Headache', category: 'concern', confidence: 0.7 },
    { label: 'Diabetes', category: 'diagnosis', confidence: 0.9 },
    { label: 'Fatigue', category: 'observation', confidence: 0.4 },
  ];

  it('converts extracted conditions to MemoryItems', () => {
    const items = toMemoryItems(conditions);
    assert.equal(items.length, 3);
    assert.equal(items[0].label, 'Headache');
    assert.equal(items[0].category, 'concern');
    assert.equal(items[1].label, 'Diabetes');
    assert.equal(items[1].category, 'diagnosis');
  });

  it('generates unique randomUUID IDs', () => {
    const items = toMemoryItems(conditions);
    const ids = items.map(i => i.id);
    const uniqueIds = new Set(ids);
    assert.equal(uniqueIds.size, 3, 'All IDs should be unique');

    // Verify UUID format
    const uuidRegex = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/;
    for (const id of ids) {
      assert.match(id, uuidRegex, `ID "${id}" should be a valid UUID`);
    }
  });

  it('generates different IDs across calls', () => {
    const items1 = toMemoryItems([conditions[0]]);
    const items2 = toMemoryItems([conditions[0]]);
    assert.notEqual(items1[0].id, items2[0].id);
  });

  it('clamps confidence to [0, 1]', () => {
    const overHigh = toMemoryItems([{ label: 'X', category: 'concern', confidence: 1.5 }]);
    assert.equal(overHigh[0].confidence, 1);

    const underLow = toMemoryItems([{ label: 'X', category: 'concern', confidence: -0.3 }]);
    assert.equal(underLow[0].confidence, 0);
  });

  it('maps confidence to correct certaintyLevel', () => {
    const items = toMemoryItems(conditions);
    assert.equal(items[0].certaintyLevel, 'medium'); // 0.7
    assert.equal(items[1].certaintyLevel, 'high');   // 0.9
    assert.equal(items[2].certaintyLevel, 'low');    // 0.4
  });

  it('uses chat as default sourceType', () => {
    const items = toMemoryItems(conditions);
    for (const item of items) {
      assert.equal(item.sourceType, 'chat');
    }
  });

  it('uses journal sourceType when specified', () => {
    const items = toMemoryItems(conditions, 'journal');
    for (const item of items) {
      assert.equal(item.sourceType, 'journal');
    }
  });

  it('sets status to inferred', () => {
    const items = toMemoryItems(conditions);
    for (const item of items) {
      assert.equal(item.status, 'inferred');
    }
  });

  it('sets observedAt and updatedAt to valid ISO strings', () => {
    const items = toMemoryItems(conditions);
    for (const item of items) {
      assert.ok(!isNaN(Date.parse(item.observedAt)));
      assert.ok(!isNaN(Date.parse(item.updatedAt)));
    }
  });

  it('initializes evidenceRefs as empty array', () => {
    const items = toMemoryItems(conditions);
    for (const item of items) {
      assert.deepEqual(item.evidenceRefs, []);
    }
  });
});
