import { execFile } from 'node:child_process';
import { promisify } from 'node:util';
import type { SkillScript } from './types.js';

const execFileAsync = promisify(execFile);

export interface ScriptToolHandlerResult {
  toolResponse: { status: 'success' | 'error'; message: string; data?: unknown };
}

export type ScriptToolHandler = (args: Record<string, unknown>) => Promise<ScriptToolHandlerResult>;

/**
 * Create a tool handler that executes a skill script as a subprocess.
 * The script receives args as a JSON string on argv[1].
 * It should print JSON to stdout.
 */
export function createScriptToolHandler(
  script: SkillScript,
  options?: { timeoutMs?: number }
): ScriptToolHandler {
  return async (args) => {
    try {
      const { stdout } = await execFileAsync(
        'node',
        [script.entrypoint, JSON.stringify(args)],
        { timeout: options?.timeoutMs ?? 30_000 }
      );
      const trimmed = stdout.trim();
      if (!trimmed) {
        return { toolResponse: { status: 'success', message: 'Script completed with no output.' } };
      }
      try {
        const data = JSON.parse(trimmed);
        return { toolResponse: { status: 'success', message: 'OK', data } };
      } catch {
        // Not JSON - return raw text
        return { toolResponse: { status: 'success', message: trimmed } };
      }
    } catch (error) {
      const msg = error instanceof Error ? error.message : 'Script execution failed';
      return { toolResponse: { status: 'error', message: msg } };
    }
  };
}
