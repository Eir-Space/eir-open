import { describe, it, beforeEach } from 'node:test';
import * as assert from 'node:assert/strict';
import {
  PluginRegistry,
  pluginManifestSchema,
  type EirPlugin,
  type PluginRegistration,
} from './plugin.js';
import type { ToolDefinition, ToolHandler } from './types.js';
import type { ToolLoopHooks as _ToolLoopHooks } from './toolLoop.js';

function makeTool(name: string): { definition: ToolDefinition; handler: ToolHandler } {
  return {
    definition: {
      type: 'function',
      function: {
        name,
        description: `Tool ${name}`,
        parameters: { type: 'object', properties: {} },
      },
    },
    handler: async () => ({ toolResponse: { status: 'success', message: 'ok' } }),
  };
}

function makePlugin(name: string, registration: PluginRegistration = {}): EirPlugin {
  return {
    manifest: pluginManifestSchema.parse({ name }),
    activate: () => registration,
  };
}

describe('pluginManifestSchema', () => {
  it('validates a minimal manifest', () => {
    const result = pluginManifestSchema.parse({ name: 'test-plugin' });
    assert.equal(result.name, 'test-plugin');
    assert.equal(result.version, '0.1.0');
  });

  it('applies defaults for provides and requires', () => {
    const result = pluginManifestSchema.parse({ name: 'test' });
    assert.deepEqual(result.provides, { tools: [], hooks: [] });
    assert.deepEqual(result.requires, { tools: [], skills: [] });
  });

  it('rejects manifest without name', () => {
    assert.throws(() => pluginManifestSchema.parse({}));
  });
});

describe('PluginRegistry', () => {
  let registry: PluginRegistry;

  beforeEach(() => {
    registry = new PluginRegistry();
  });

  describe('register / unregister', () => {
    it('registers a plugin and activates it', async () => {
      await registry.register(makePlugin('test'));
      assert.equal(registry.has('test'), true);
      assert.equal(registry.size, 1);
    });

    it('rejects duplicate plugin registration', async () => {
      await registry.register(makePlugin('test'));
      await assert.rejects(() => registry.register(makePlugin('test')), /already registered/);
    });

    it('unregisters and deactivates a plugin', async () => {
      let deactivated = false;
      const plugin = makePlugin('test');
      plugin.deactivate = () => {
        deactivated = true;
      };
      await registry.register(plugin);
      await registry.unregister('test');
      assert.equal(registry.has('test'), false);
      assert.equal(deactivated, true);
    });

    it('unregister is a no-op for unknown plugin', async () => {
      await registry.unregister('nonexistent');
      // Should not throw
    });
  });

  describe('collectTools', () => {
    it('collects tool definitions and handlers from all plugins', async () => {
      await registry.register(makePlugin('p1', { tools: [makeTool('tool-a')] }));
      await registry.register(makePlugin('p2', { tools: [makeTool('tool-b')] }));

      const { definitions, handlers } = registry.collectTools();
      assert.equal(definitions.length, 2);
      assert.ok(handlers['tool-a']);
      assert.ok(handlers['tool-b']);
    });

    it('warns on duplicate tool names', async () => {
      const warnings: string[] = [];
      const origWarn = console.warn;
      console.warn = (...args: unknown[]) => {
        warnings.push(String(args[0]));
      };

      try {
        await registry.register(makePlugin('p1', { tools: [makeTool('same-name')] }));
        await registry.register(makePlugin('p2', { tools: [makeTool('same-name')] }));

        registry.collectTools();
        assert.ok(warnings.some((w) => w.includes('Duplicate tool name')));
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('collectHooks', () => {
    it('returns empty object when no plugins have hooks', async () => {
      await registry.register(makePlugin('p1'));
      const hooks = registry.collectHooks();
      assert.deepEqual(hooks, {});
    });

    it('returns single plugin hooks directly', async () => {
      const myHook = () => true;
      await registry.register(
        makePlugin('p1', {
          hooks: { shouldBreakEarly: myHook },
        }),
      );
      const hooks = registry.collectHooks();
      assert.equal(hooks.shouldBreakEarly, myHook);
    });
  });

  describe('chainHooks — beforeToolCall', () => {
    it('chains args through multiple beforeToolCall hooks', async () => {
      await registry.register(
        makePlugin('p1', {
          hooks: {
            beforeToolCall: async (_name, args) => ({ ...args, fromP1: true }),
          },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: {
            beforeToolCall: async (_name, args) => ({ ...args, fromP2: true }),
          },
        }),
      );

      const hooks = registry.collectHooks();
      const result = await hooks.beforeToolCall!('test', { original: true });
      assert.deepEqual(result, { original: true, fromP1: true, fromP2: true });
    });

    it('short-circuits on false from any hook', async () => {
      let p2Called = false;
      await registry.register(
        makePlugin('p1', {
          hooks: { beforeToolCall: async () => false as const },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: {
            beforeToolCall: async () => {
              p2Called = true;
              return {};
            },
          },
        }),
      );

      const hooks = registry.collectHooks();
      const result = await hooks.beforeToolCall!('test', {});
      assert.equal(result, false);
      assert.equal(p2Called, false);
    });

    it('catches hook errors and returns false', async () => {
      const warnings: unknown[] = [];
      const origWarn = console.warn;
      console.warn = (...args: unknown[]) => {
        warnings.push(args);
      };

      try {
        await registry.register(
          makePlugin('p1', {
            hooks: {
              beforeToolCall: async () => {
                throw new Error('boom');
              },
            },
          }),
        );
        // Need 2+ hooks to trigger chainHooks (single hooks are returned directly)
        await registry.register(
          makePlugin('p2', {
            hooks: { beforeToolCall: async (_name, args) => args },
          }),
        );

        const hooks = registry.collectHooks();
        const result = await hooks.beforeToolCall!('test', {});
        assert.equal(result, false);
        assert.ok(warnings.length > 0);
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('chainHooks — afterToolCall', () => {
    it('runs all afterToolCall hooks in order', async () => {
      const order: string[] = [];
      await registry.register(
        makePlugin('p1', {
          hooks: {
            afterToolCall: async () => {
              order.push('p1');
            },
          },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: {
            afterToolCall: async () => {
              order.push('p2');
            },
          },
        }),
      );

      const hooks = registry.collectHooks();
      await hooks.afterToolCall!('test', { toolResponse: { status: 'success', message: 'ok' } });
      assert.deepEqual(order, ['p1', 'p2']);
    });

    it('catches errors without crashing', async () => {
      const warnings: unknown[] = [];
      const origWarn = console.warn;
      console.warn = (...args: unknown[]) => {
        warnings.push(args);
      };

      try {
        await registry.register(
          makePlugin('p1', {
            hooks: {
              afterToolCall: async () => {
                throw new Error('boom');
              },
            },
          }),
        );
        await registry.register(
          makePlugin('p2', {
            hooks: { afterToolCall: async () => {} },
          }),
        );

        const hooks = registry.collectHooks();
        // Should not throw
        await hooks.afterToolCall!('test', { toolResponse: { status: 'success', message: 'ok' } });
        assert.ok(warnings.length > 0);
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('chainHooks — decideFollowupToolChoice', () => {
    it('last hook wins', async () => {
      await registry.register(
        makePlugin('p1', {
          hooks: { decideFollowupToolChoice: () => 'auto' },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: { decideFollowupToolChoice: () => 'none' },
        }),
      );

      const hooks = registry.collectHooks();
      assert.equal(hooks.decideFollowupToolChoice!(1, 5), 'none');
    });

    it('catches errors in hooks', async () => {
      const origWarn = console.warn;
      console.warn = () => {};
      try {
        await registry.register(
          makePlugin('p1', {
            hooks: {
              decideFollowupToolChoice: () => {
                throw new Error('boom');
              },
            },
          }),
        );
        await registry.register(
          makePlugin('p2', {
            hooks: { decideFollowupToolChoice: () => 'auto' },
          }),
        );

        const hooks = registry.collectHooks();
        // Should not throw, returns 'auto' from p2
        const result = hooks.decideFollowupToolChoice!(1, 5);
        assert.equal(result, 'auto');
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('chainHooks — shouldBreakEarly', () => {
    it('returns true if any hook returns true', async () => {
      await registry.register(
        makePlugin('p1', {
          hooks: { shouldBreakEarly: () => false },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: { shouldBreakEarly: () => true },
        }),
      );

      const hooks = registry.collectHooks();
      assert.equal(hooks.shouldBreakEarly!(1, 5), true);
    });

    it('catches errors in hooks', async () => {
      const origWarn = console.warn;
      console.warn = () => {};
      try {
        await registry.register(
          makePlugin('p1', {
            hooks: {
              shouldBreakEarly: () => {
                throw new Error('boom');
              },
            },
          }),
        );
        await registry.register(
          makePlugin('p2', {
            hooks: { shouldBreakEarly: () => false },
          }),
        );

        const hooks = registry.collectHooks();
        assert.equal(hooks.shouldBreakEarly!(1, 5), false);
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('chainHooks — onProviderError', () => {
    it('first non-null recovery wins', async () => {
      await registry.register(
        makePlugin('p1', {
          hooks: { onProviderError: async () => null },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: { onProviderError: async () => ({ role: 'assistant', content: 'recovered' }) },
        }),
      );

      const hooks = registry.collectHooks();
      const result = await hooks.onProviderError!(new Error('fail'), 1);
      assert.equal(result?.content, 'recovered');
    });

    it('catches errors in hooks', async () => {
      const origWarn = console.warn;
      console.warn = () => {};
      try {
        await registry.register(
          makePlugin('p1', {
            hooks: {
              onProviderError: async () => {
                throw new Error('hook error');
              },
            },
          }),
        );
        await registry.register(
          makePlugin('p2', {
            hooks: { onProviderError: async () => null },
          }),
        );

        const hooks = registry.collectHooks();
        const result = await hooks.onProviderError!(new Error('fail'), 1);
        assert.equal(result, null);
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('chainHooks — onSubagentSpawning', () => {
    it('runs all hooks in order', async () => {
      const order: string[] = [];
      await registry.register(
        makePlugin('p1', {
          hooks: {
            onSubagentSpawning: async () => {
              order.push('p1');
            },
          },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: {
            onSubagentSpawning: async () => {
              order.push('p2');
            },
          },
        }),
      );

      const hooks = registry.collectHooks();
      await hooks.onSubagentSpawning!('agent-1', {});
      assert.deepEqual(order, ['p1', 'p2']);
    });

    it('catches errors in hooks', async () => {
      const origWarn = console.warn;
      console.warn = () => {};
      try {
        await registry.register(
          makePlugin('p1', {
            hooks: {
              onSubagentSpawning: async () => {
                throw new Error('boom');
              },
            },
          }),
        );
        await registry.register(
          makePlugin('p2', {
            hooks: { onSubagentSpawning: async () => {} },
          }),
        );

        const hooks = registry.collectHooks();
        await hooks.onSubagentSpawning!('agent-1', {});
        // Should not throw
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('chainHooks — onSubagentEnded', () => {
    it('runs all hooks in order', async () => {
      const order: string[] = [];
      await registry.register(
        makePlugin('p1', {
          hooks: {
            onSubagentEnded: async () => {
              order.push('p1');
            },
          },
        }),
      );
      await registry.register(
        makePlugin('p2', {
          hooks: {
            onSubagentEnded: async () => {
              order.push('p2');
            },
          },
        }),
      );

      const hooks = registry.collectHooks();
      await hooks.onSubagentEnded!('agent-1', {
        toolResponse: { status: 'success', message: 'ok' },
      });
      assert.deepEqual(order, ['p1', 'p2']);
    });

    it('catches errors in hooks', async () => {
      const origWarn = console.warn;
      console.warn = () => {};
      try {
        await registry.register(
          makePlugin('p1', {
            hooks: {
              onSubagentEnded: async () => {
                throw new Error('boom');
              },
            },
          }),
        );
        await registry.register(
          makePlugin('p2', {
            hooks: { onSubagentEnded: async () => {} },
          }),
        );

        const hooks = registry.collectHooks();
        await hooks.onSubagentEnded!('agent-1', {
          toolResponse: { status: 'success', message: 'ok' },
        });
      } finally {
        console.warn = origWarn;
      }
    });
  });

  describe('deactivateAll', () => {
    it('deactivates all plugins and clears registry', async () => {
      const deactivated: string[] = [];
      const p1 = makePlugin('p1');
      p1.deactivate = () => {
        deactivated.push('p1');
      };
      const p2 = makePlugin('p2');
      p2.deactivate = () => {
        deactivated.push('p2');
      };

      await registry.register(p1);
      await registry.register(p2);
      await registry.deactivateAll();

      assert.equal(registry.size, 0);
      assert.deepEqual(deactivated, ['p1', 'p2']);
    });
  });

  describe('names and size', () => {
    it('returns plugin names', async () => {
      await registry.register(makePlugin('alpha'));
      await registry.register(makePlugin('beta'));
      assert.deepEqual(registry.names, ['alpha', 'beta']);
    });

    it('returns correct size', async () => {
      assert.equal(registry.size, 0);
      await registry.register(makePlugin('p1'));
      assert.equal(registry.size, 1);
    });
  });
});
