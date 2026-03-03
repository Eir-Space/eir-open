import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { buildHistoryMessages, buildModeToolInstruction, buildSystemContent, formatMemoryContext } from './contextBuilder.js';

describe('buildHistoryMessages', () => {
  it('converts ChatHistoryItem[] to LlmMessage[]', () => {
    const history = [
      { role: 'user' as const, content: 'Hello' },
      { role: 'assistant' as const, content: 'Hi there' },
    ];
    const messages = buildHistoryMessages(history);
    assert.equal(messages.length, 2);
    assert.equal(messages[0].role, 'user');
    assert.equal(messages[0].content, 'Hello');
    assert.equal(messages[1].role, 'assistant');
  });

  it('trims content whitespace', () => {
    const messages = buildHistoryMessages([{ role: 'user', content: '  Hello  ' }]);
    assert.equal(messages[0].content, 'Hello');
  });

  it('filters out items with empty content', () => {
    const history = [
      { role: 'user' as const, content: '  ' },
      { role: 'assistant' as const, content: 'Valid' },
    ];
    const messages = buildHistoryMessages(history);
    assert.equal(messages.length, 1);
    assert.equal(messages[0].content, 'Valid');
  });

  it('applies default sliding window of 20', () => {
    const history = Array.from({ length: 25 }, (_, i) => ({
      role: 'user' as const,
      content: `Message ${i}`,
    }));
    const messages = buildHistoryMessages(history);
    assert.equal(messages.length, 20);
    assert.equal(messages[0].content, 'Message 5');
  });

  it('applies custom window size', () => {
    const history = Array.from({ length: 10 }, (_, i) => ({
      role: 'user' as const,
      content: `Message ${i}`,
    }));
    const messages = buildHistoryMessages(history, 3);
    assert.equal(messages.length, 3);
    assert.equal(messages[0].content, 'Message 7');
  });

  it('handles empty history', () => {
    assert.deepEqual(buildHistoryMessages([]), []);
  });

  it('handles undefined history', () => {
    assert.deepEqual(buildHistoryMessages(undefined), []);
  });
});

describe('buildModeToolInstruction', () => {
  it('formats mode and tool list', () => {
    const result = buildModeToolInstruction({ mode: 'triage', toolNames: ['symptom_check', 'lookup'] });
    assert.ok(result.includes('MODE: triage'));
    assert.ok(result.includes('ALLOWED_TOOLS_NOW: symptom_check, lookup'));
  });

  it('shows (none) when no tools', () => {
    const result = buildModeToolInstruction({ mode: 'general', toolNames: [] });
    assert.ok(result.includes('(none)'));
    assert.ok(result.includes('Respond with text only'));
  });

  it('includes CRITICAL restriction message when tools present', () => {
    const result = buildModeToolInstruction({ mode: 'triage', toolNames: ['tool_a'] });
    assert.ok(result.includes('CRITICAL'));
    assert.ok(result.includes('ONLY tools listed'));
  });
});

describe('buildSystemContent', () => {
  it('joins non-empty sections with double newlines', () => {
    const result = buildSystemContent(['Section A', 'Section B']);
    assert.equal(result, 'Section A\n\nSection B');
  });

  it('filters null and undefined sections', () => {
    const result = buildSystemContent(['Section A', null, undefined, 'Section B']);
    assert.equal(result, 'Section A\n\nSection B');
  });

  it('filters whitespace-only sections', () => {
    const result = buildSystemContent(['Section A', '   ', '', 'Section B']);
    assert.equal(result, 'Section A\n\nSection B');
  });

  it('handles array of all empty sections', () => {
    const result = buildSystemContent([null, undefined, '  ']);
    assert.equal(result, '');
  });
});

describe('formatMemoryContext', () => {
  it('formats memory items with category, label, certainty, status', () => {
    const items = [{ label: 'Diabetes', category: 'diagnosis', certaintyLevel: 'high', status: 'user_confirmed' }];
    const result = formatMemoryContext(items);
    assert.ok(result.includes('[diagnosis] Diabetes (high, user_confirmed)'));
  });

  it('includes detail when present', () => {
    const items = [{ label: 'Diabetes', category: 'diagnosis', certaintyLevel: 'high', status: 'inferred', detail: 'Type 2' }];
    const result = formatMemoryContext(items);
    assert.ok(result.includes('  Type 2'));
  });

  it('returns empty string for empty array', () => {
    assert.equal(formatMemoryContext([]), '');
  });

  it('includes the untrusted snippets header', () => {
    const items = [{ label: 'X', category: 'concern', certaintyLevel: 'low', status: 'inferred' }];
    const result = formatMemoryContext(items);
    assert.ok(result.includes('HEALTH MEMORY'));
    assert.ok(result.includes('untrusted factual snippets'));
  });
});
