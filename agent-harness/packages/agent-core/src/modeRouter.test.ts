import { describe, it } from 'node:test';
import * as assert from 'node:assert/strict';
import { KeywordModeRouter, type KeywordModeRouterConfig } from './modeRouter.js';

const defaultConfig: KeywordModeRouterConfig = {
  modes: {
    triage: {
      allowedTools: ['symptom_check'],
      activeSkills: ['triage-skill'],
      maxToolIterations: 3,
      retrievalBudget: 5,
    },
    consult: {
      allowedTools: ['lookup', 'summarize'],
      activeSkills: ['consult-skill'],
      maxToolIterations: 5,
      retrievalBudget: 10,
    },
    general: { allowedTools: [], activeSkills: [], maxToolIterations: 2, retrievalBudget: 3 },
  },
  rules: [
    { keywords: ['symptom', 'pain', 'hurts'], mode: 'triage' },
    { keywords: ['consult', 'specialist', 'refer'], mode: 'consult' },
  ],
  defaultMode: 'general',
};

describe('KeywordModeRouter', () => {
  describe('keyword matching', () => {
    it('matches a rule by keyword in message', () => {
      const router = new KeywordModeRouter(defaultConfig);
      const result = router.resolve({ message: 'I have a symptom' });
      assert.equal(result.mode, 'triage');
      assert.deepEqual(result.allowedTools, ['symptom_check']);
    });

    it('matches keywords case-insensitively', () => {
      const router = new KeywordModeRouter(defaultConfig);
      const result = router.resolve({ message: 'I have PAIN in my back' });
      assert.equal(result.mode, 'triage');
    });

    it('falls back to default mode when no rules match', () => {
      const router = new KeywordModeRouter(defaultConfig);
      const result = router.resolve({ message: 'hello there' });
      assert.equal(result.mode, 'general');
      assert.deepEqual(result.allowedTools, []);
    });

    it('matches first rule in priority order', () => {
      const config: KeywordModeRouterConfig = {
        ...defaultConfig,
        rules: [
          { keywords: ['test'], mode: 'triage' },
          { keywords: ['test'], mode: 'consult' },
        ],
      };
      const router = new KeywordModeRouter(config);
      const result = router.resolve({ message: 'test keyword' });
      assert.equal(result.mode, 'triage');
    });
  });

  describe('history scanning', () => {
    it('matches keywords in recent history messages', () => {
      const router = new KeywordModeRouter(defaultConfig);
      const result = router.resolve({
        message: 'what should I do?',
        history: [{ role: 'user', content: 'I have pain in my chest' }],
      });
      assert.equal(result.mode, 'triage');
    });

    it('respects historyScanDepth limit', () => {
      const config: KeywordModeRouterConfig = { ...defaultConfig, historyScanDepth: 1 };
      const router = new KeywordModeRouter(config);
      const result = router.resolve({
        message: 'what should I do?',
        history: [
          { role: 'user', content: 'I have pain' },
          { role: 'assistant', content: 'Tell me more' },
          { role: 'user', content: 'Its bad' },
        ],
      });
      // Only the last 1 message is scanned — "Its bad" has no keywords
      assert.equal(result.mode, 'general');
    });
  });

  describe('exclude patterns', () => {
    it('skips rule when excludePatterns match the message', () => {
      const config: KeywordModeRouterConfig = {
        ...defaultConfig,
        rules: [{ keywords: ['symptom'], mode: 'triage', excludePatterns: [/just kidding/i] }],
      };
      const router = new KeywordModeRouter(config);
      const result = router.resolve({ message: 'just kidding about that symptom' });
      assert.equal(result.mode, 'general');
    });
  });

  describe('excludeInformational', () => {
    it('skips rule when message is informational and excludeInformational is true', () => {
      const config: KeywordModeRouterConfig = {
        ...defaultConfig,
        rules: [{ keywords: ['symptom'], mode: 'triage', excludeInformational: true }],
      };
      const router = new KeywordModeRouter(config);
      const result = router.resolve({ message: 'what is a symptom?' });
      assert.equal(result.mode, 'general');
    });

    it('matches rule when message is not informational', () => {
      const config: KeywordModeRouterConfig = {
        ...defaultConfig,
        rules: [{ keywords: ['symptom'], mode: 'triage', excludeInformational: true }],
      };
      const router = new KeywordModeRouter(config);
      const result = router.resolve({ message: 'I have a symptom' });
      assert.equal(result.mode, 'triage');
    });
  });

  describe('error handling', () => {
    it('throws when default mode is not in modes config', () => {
      const config: KeywordModeRouterConfig = {
        modes: {},
        rules: [],
        defaultMode: 'nonexistent',
      };
      const router = new KeywordModeRouter(config);
      assert.throws(() => router.resolve({ message: 'hello' }), /not found in modes config/);
    });

    it('skips rule when mode is not defined in modes config', () => {
      const config: KeywordModeRouterConfig = {
        modes: {
          general: { allowedTools: [], activeSkills: [], maxToolIterations: 2, retrievalBudget: 3 },
        },
        rules: [{ keywords: ['test'], mode: 'nonexistent' }],
        defaultMode: 'general',
      };
      const router = new KeywordModeRouter(config);
      const result = router.resolve({ message: 'test' });
      assert.equal(result.mode, 'general');
    });
  });
});
