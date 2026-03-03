import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { toCertainty, dedupKey, confirmItem, dismissItem } from './confidence.js';
import type { MemoryItem } from './schemas.js';

function makeItem(overrides: Partial<MemoryItem> = {}): MemoryItem {
  const now = new Date().toISOString();
  return {
    id: 'test-1',
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

describe('toCertainty', () => {
  it('returns high for >= 0.85', () => {
    assert.equal(toCertainty(0.9), 'high');
    assert.equal(toCertainty(1.0), 'high');
  });

  it('returns high for exactly 0.85 (boundary)', () => {
    assert.equal(toCertainty(0.85), 'high');
  });

  it('returns medium for >= 0.6 and < 0.85', () => {
    assert.equal(toCertainty(0.7), 'medium');
    assert.equal(toCertainty(0.84), 'medium');
  });

  it('returns medium for exactly 0.6 (boundary)', () => {
    assert.equal(toCertainty(0.6), 'medium');
  });

  it('returns low for < 0.6', () => {
    assert.equal(toCertainty(0.5), 'low');
    assert.equal(toCertainty(0.0), 'low');
    assert.equal(toCertainty(0.59), 'low');
  });
});

describe('dedupKey', () => {
  it('combines category and lowercased trimmed label', () => {
    assert.equal(dedupKey({ category: 'diagnosis', label: ' Diabetes ' }), 'diagnosis:diabetes');
  });

  it('handles mixed case labels', () => {
    assert.equal(dedupKey({ category: 'concern', label: 'HeAdAcHe' }), 'concern:headache');
  });
});

describe('confirmItem', () => {
  it('sets status to user_confirmed', () => {
    const item = makeItem();
    const confirmed = confirmItem(item);
    assert.equal(confirmed.status, 'user_confirmed');
  });

  it('sets confidence to at least 0.92', () => {
    const item = makeItem({ confidence: 0.5 });
    const confirmed = confirmItem(item);
    assert.ok(confirmed.confidence >= 0.92);
  });

  it('preserves higher existing confidence', () => {
    const item = makeItem({ confidence: 0.95 });
    const confirmed = confirmItem(item);
    assert.equal(confirmed.confidence, 0.95);
  });

  it('sets certaintyLevel to high', () => {
    const item = makeItem({ certaintyLevel: 'low' });
    const confirmed = confirmItem(item);
    assert.equal(confirmed.certaintyLevel, 'high');
  });

  it('updates updatedAt timestamp', () => {
    const item = makeItem({ updatedAt: '2020-01-01T00:00:00.000Z' });
    const confirmed = confirmItem(item);
    assert.notEqual(confirmed.updatedAt, '2020-01-01T00:00:00.000Z');
  });
});

describe('dismissItem', () => {
  it('sets status to dismissed', () => {
    const item = makeItem();
    const dismissed = dismissItem(item);
    assert.equal(dismissed.status, 'dismissed');
  });

  it('updates updatedAt timestamp', () => {
    const item = makeItem({ updatedAt: '2020-01-01T00:00:00.000Z' });
    const dismissed = dismissItem(item);
    assert.notEqual(dismissed.updatedAt, '2020-01-01T00:00:00.000Z');
  });

  it('preserves other fields', () => {
    const item = makeItem({ label: 'Test', confidence: 0.8 });
    const dismissed = dismissItem(item);
    assert.equal(dismissed.label, 'Test');
    assert.equal(dismissed.confidence, 0.8);
    assert.equal(dismissed.id, item.id);
  });
});
