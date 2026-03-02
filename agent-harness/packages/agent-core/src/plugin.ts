import { z } from 'zod';
import type { ToolDefinition, ToolHandler, ToolHandlerResult } from './types.js';
import type { ToolLoopHooks } from './toolLoop.js';

// --- Plugin Manifest ---

export const pluginManifestSchema = z.object({
  name: z.string().min(1),
  version: z.string().default('0.1.0'),
  description: z.string().optional(),
  provides: z.object({
    tools: z.array(z.string()).default([]),
    hooks: z.array(z.string()).default([]),
  }).default({}),
  requires: z.object({
    tools: z.array(z.string()).default([]),
    skills: z.array(z.string()).default([]),
  }).default({}),
  configSchema: z.record(z.unknown()).optional(),
});

export type PluginManifest = z.infer<typeof pluginManifestSchema>;

// --- Plugin Interfaces ---

export interface PluginContext {
  config: Record<string, unknown>;
}

export interface PluginToolEntry {
  definition: ToolDefinition;
  handler: ToolHandler;
}

export interface PluginRegistration {
  tools?: PluginToolEntry[];
  hooks?: Partial<ToolLoopHooks>;
}

export interface EirPlugin {
  manifest: PluginManifest;
  /** Called once during registration. Returns tools and hooks to register. */
  activate(context: PluginContext): PluginRegistration | Promise<PluginRegistration>;
  /** Optional cleanup on deactivation. */
  deactivate?(): void | Promise<void>;
}

// --- Plugin Registry ---

interface RegisteredPlugin {
  plugin: EirPlugin;
  registration: PluginRegistration;
}

/**
 * Registry that manages plugin lifecycle and collects tools/hooks
 * for use with the tool loop.
 */
export class PluginRegistry {
  private plugins = new Map<string, RegisteredPlugin>();

  /** Register and activate a plugin. */
  async register(plugin: EirPlugin, config?: Record<string, unknown>): Promise<void> {
    const name = plugin.manifest.name;
    if (this.plugins.has(name)) {
      throw new Error(`Plugin "${name}" is already registered.`);
    }

    const registration = await plugin.activate({ config: config ?? {} });
    this.plugins.set(name, { plugin, registration });
  }

  /** Unregister and deactivate a plugin by name. */
  async unregister(name: string): Promise<void> {
    const entry = this.plugins.get(name);
    if (!entry) return;

    await entry.plugin.deactivate?.();
    this.plugins.delete(name);
  }

  /** Collect all registered tool definitions and handlers into flat structures. */
  collectTools(): { definitions: ToolDefinition[]; handlers: Record<string, ToolHandler> } {
    const definitions: ToolDefinition[] = [];
    const handlers: Record<string, ToolHandler> = {};

    for (const { registration } of this.plugins.values()) {
      for (const tool of registration.tools ?? []) {
        definitions.push(tool.definition);
        handlers[tool.definition.function.name] = tool.handler;
      }
    }

    return { definitions, handlers };
  }

  /**
   * Merge hooks from all registered plugins into a single ToolLoopHooks object.
   * When multiple plugins provide the same hook, they are chained in registration order.
   */
  collectHooks(): Partial<ToolLoopHooks> {
    const allHooks: Partial<ToolLoopHooks>[] = [];

    for (const { registration } of this.plugins.values()) {
      if (registration.hooks) {
        allHooks.push(registration.hooks);
      }
    }

    if (allHooks.length === 0) return {};
    if (allHooks.length === 1) return allHooks[0];

    return this.chainHooks(allHooks);
  }

  /** Deactivate all plugins and clear the registry. */
  async deactivateAll(): Promise<void> {
    for (const { plugin } of this.plugins.values()) {
      await plugin.deactivate?.();
    }
    this.plugins.clear();
  }

  /** Check if a plugin is registered. */
  has(name: string): boolean {
    return this.plugins.has(name);
  }

  /** Get the names of all registered plugins. */
  get names(): string[] {
    return Array.from(this.plugins.keys());
  }

  /** Get the number of registered plugins. */
  get size(): number {
    return this.plugins.size;
  }

  /**
   * Chain multiple hook objects into one. Each hook type is called in order.
   * - beforeToolCall: runs each in order; if any returns false, short-circuits.
   * - afterToolCall: runs each in order.
   * - decideFollowupToolChoice: last one wins.
   * - shouldBreakEarly: true if any returns true.
   * - onProviderError: first non-null recovery wins.
   */
  private chainHooks(hooksList: Partial<ToolLoopHooks>[]): Partial<ToolLoopHooks> {
    const merged: Partial<ToolLoopHooks> = {};

    // beforeToolCall — chain with short-circuit on false
    const beforeHooks = hooksList.map(h => h.beforeToolCall).filter(Boolean);
    if (beforeHooks.length > 0) {
      merged.beforeToolCall = async (name, args) => {
        let currentArgs = args;
        for (const hook of beforeHooks) {
          const result = await hook!(name, currentArgs);
          if (result === false) return false;
          if (result && typeof result === 'object') {
            currentArgs = result;
          }
        }
        return currentArgs;
      };
    }

    // afterToolCall — run all in order
    const afterHooks = hooksList.map(h => h.afterToolCall).filter(Boolean);
    if (afterHooks.length > 0) {
      merged.afterToolCall = async (name, result) => {
        for (const hook of afterHooks) {
          await hook!(name, result);
        }
      };
    }

    // decideFollowupToolChoice — last one wins
    const decideHooks = hooksList.map(h => h.decideFollowupToolChoice).filter(Boolean);
    if (decideHooks.length > 0) {
      merged.decideFollowupToolChoice = (iteration, maxIterations) => {
        let result: 'auto' | 'none' = 'auto';
        for (const hook of decideHooks) {
          result = hook!(iteration, maxIterations);
        }
        return result;
      };
    }

    // shouldBreakEarly — true if any returns true
    const breakHooks = hooksList.map(h => h.shouldBreakEarly).filter(Boolean);
    if (breakHooks.length > 0) {
      merged.shouldBreakEarly = (iteration, maxIterations) => {
        for (const hook of breakHooks) {
          if (hook!(iteration, maxIterations)) return true;
        }
        return false;
      };
    }

    // onProviderError — first non-null recovery wins
    const errorHooks = hooksList.map(h => h.onProviderError).filter(Boolean);
    if (errorHooks.length > 0) {
      merged.onProviderError = async (error, iteration) => {
        for (const hook of errorHooks) {
          const recovered = await hook!(error, iteration);
          if (recovered) return recovered;
        }
        return null;
      };
    }

    return merged;
  }
}
