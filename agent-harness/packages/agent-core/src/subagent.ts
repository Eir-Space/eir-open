import type { LlmProvider } from './provider.js';
import type { LlmMessage, ToolDefinition, ToolHandler, ToolHandlerResult } from './types.js';
import { executeToolLoop, type ToolLoopHooks } from './toolLoop.js';

// --- Subagent Tool Creation ---

export interface SubagentToolParams {
  /** Unique name for the subagent tool (used as the tool function name). */
  name: string;
  /** Description shown to the LLM for when to invoke this subagent. */
  description: string;
  /** LLM provider for the subagent. */
  provider: LlmProvider;
  /** Model to use for the subagent. */
  model: string;
  /** System prompt defining the subagent's role and behavior. */
  systemPrompt: string;
  /** Tools available to the subagent. */
  tools?: ToolDefinition[];
  /** Tool handlers for the subagent. */
  toolHandlers?: Record<string, ToolHandler>;
  /** Maximum tool loop iterations for the subagent. Default: 5. */
  maxIterations?: number;
  /** Temperature for the subagent's LLM calls. Default: 0.4. */
  temperature?: number;
  /** Hooks for the subagent's tool loop. */
  hooks?: ToolLoopHooks;
  /** JSON Schema for the parameters the parent LLM passes to invoke this subagent. */
  parameters?: Record<string, unknown>;
}

export interface SubagentTool {
  definition: ToolDefinition;
  handler: ToolHandler;
}

/**
 * Create a tool that delegates to a nested agent (subagent).
 * The parent LLM can invoke this tool to run a sub-task with its own
 * system prompt, tools, and model.
 *
 * The subagent receives the parent's `query` argument as a user message,
 * runs its own tool loop, and returns the final assistant response.
 */
export function createSubagentTool(params: SubagentToolParams): SubagentTool {
  const {
    name,
    description,
    provider,
    model,
    systemPrompt,
    tools = [],
    toolHandlers = {},
    maxIterations = 5,
    temperature = 0.4,
    hooks,
    parameters,
  } = params;

  const definition: ToolDefinition = {
    type: 'function',
    function: {
      name,
      description,
      parameters: parameters ?? {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'The task or question to delegate to the subagent.',
          },
        },
        required: ['query'],
      },
    },
  };

  const handler: ToolHandler = async (args) => {
    const query = typeof args.query === 'string' ? args.query : JSON.stringify(args);

    const messages: LlmMessage[] = [
      { role: 'system', content: systemPrompt },
      { role: 'user', content: query },
    ];

    const result = await executeToolLoop({
      provider,
      model,
      messages,
      tools,
      toolHandlers,
      maxIterations,
      temperature,
      hooks,
    });

    const response = result.responseMessage.content ?? 'Subagent returned no response.';

    return {
      toolResponse: {
        status: 'success' as const,
        message: response,
        data: {
          iterations: result.iterations,
          actions: result.actions,
        },
      },
    };
  };

  return { definition, handler };
}
