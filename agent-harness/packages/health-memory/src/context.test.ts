import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { formatMemoryContext, toSnippet } from './context.js';
import type { MemoryItem } from './schemas.js';

function makeItem(overrides: Partial<MemoryItem> = {}): MemoryItem {
  const now = new Date().toISOString();
  return {
    id: 'test-1',
    category: 'diagnosis',
    label: 'Diabetes',
    sourceType: 'chat',
    confidence: 0.9,
    certaintyLevel: 'high',
    status: 'user_confirmed',
    evidenceRefs: [],
    observedAt: now,
    updatedAt: now,
    ...overrides,
  };
}

describe('formatMemoryContext', () => {
  it('formats items with category, label, certainty, status', () => {
    const result = formatMemoryContext([makeItem()]);
    assert.ok(result.includes('[diagnosis] Diabetes (high, user_confirmed)'));
  });

  it('includes detail on indented line when present', () => {
    const result = formatMemoryContext([makeItem({ detail: 'Type 2, managed with metformin' })]);
    assert.ok(result.includes('  Type 2, managed with metformin'));
  });

  it('excludes dismissed items', () => {
    const result = formatMemoryContext([
      makeItem({ status: 'dismissed', label: 'Dismissed Item' }),
    ]);
    assert.equal(result, '');
  });

  it('returns empty string for empty array', () => {
    assert.equal(formatMemoryContext([]), '');
  });

  it('returns empty string when all items are dismissed', () => {
    const result = formatMemoryContext([
      makeItem({ status: 'dismissed' }),
      makeItem({ id: 'test-2', status: 'dismissed' }),
    ]);
    assert.equal(result, '');
  });

  it('includes the HEALTH MEMORY header', () => {
    const result = formatMemoryContext([makeItem()]);
    assert.ok(result.startsWith('HEALTH MEMORY'));
  });

  it('formats multiple items', () => {
    const items = [
      makeItem({ label: 'Diabetes', category: 'diagnosis' }),
      makeItem({
        id: 'test-2',
        label: 'Headache',
        category: 'concern',
        certaintyLevel: 'medium',
        status: 'inferred',
      }),
    ];
    const result = formatMemoryContext(items);
    assert.ok(result.includes('[diagnosis] Diabetes'));
    assert.ok(result.includes('[concern] Headache (medium, inferred)'));
  });
});

describe('toSnippet', () => {
  it('converts MemoryItem to lightweight snippet', () => {
    const item = makeItem({ detail: 'Some detail' });
    const snippet = toSnippet(item);
    assert.equal(snippet.id, item.id);
    assert.equal(snippet.category, item.category);
    assert.equal(snippet.label, item.label);
    assert.equal(snippet.detail, 'Some detail');
    assert.equal(snippet.confidence, item.confidence);
    assert.equal(snippet.certaintyLevel, item.certaintyLevel);
    assert.equal(snippet.status, item.status);
  });

  it('does not include sourceType, evidenceRefs, or timestamps', () => {
    const item = makeItem();
    const snippet = toSnippet(item) as Record<string, unknown>;
    assert.equal(snippet.sourceType, undefined);
    assert.equal(snippet.evidenceRefs, undefined);
    assert.equal(snippet.observedAt, undefined);
    assert.equal(snippet.updatedAt, undefined);
  });

  it('preserves undefined detail', () => {
    const item = makeItem();
    delete (item as Record<string, unknown>).detail;
    const snippet = toSnippet(item);
    assert.equal(snippet.detail, undefined);
  });
});
