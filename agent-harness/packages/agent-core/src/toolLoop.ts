import type { LlmProvider, LlmCompletionRequest } from './provider.js';
import type { LlmMessage, LlmToolCall, ToolDefinition, ToolHandler, ToolHandlerResult, AgentAction } from './types.js';

export interface ToolLoopHooks {
  /** Intercept/modify tool args before execution. Return false to block the call. */
  beforeToolCall?(name: string, args: Record<string, unknown>): Record<string, unknown> | false | Promise<Record<string, unknown> | false>;
  /** Called after a tool executes. */
  afterToolCall?(name: string, result: ToolHandlerResult): void | Promise<void>;
  /** Control tool_choice for follow-up LLM calls. Default: 'auto' until last iteration, then 'none'. */
  decideFollowupToolChoice?(iteration: number, maxIterations: number): 'auto' | 'none';
  /** Break out of loop early? Called after tool results are appended. */
  shouldBreakEarly?(iteration: number, maxIterations: number): boolean;
  /** Handle provider errors (e.g. tool_use_failed). Return a recovery message or null to throw. */
  onProviderError?(error: unknown, iteration: number): Promise<LlmMessage | null>;
  /** Called when a subagent tool is about to be spawned. */
  onSubagentSpawning?(agentId: string, context: Record<string, unknown>): void | Promise<void>;
  /** Called when a subagent tool completes. */
  onSubagentEnded?(agentId: string, result: ToolHandlerResult): void | Promise<void>;
}

export interface ToolLoopContext {
  provider: LlmProvider;
  model: string;
  messages: LlmMessage[];
  tools: ToolDefinition[];
  toolHandlers: Record<string, ToolHandler>;
  maxIterations?: number;
  allowedToolNames?: Set<string>;
  hooks?: ToolLoopHooks;
  temperature?: number;
  signal?: AbortSignal;
}

export interface ToolLoopResult {
  responseMessage: LlmMessage;
  actions: AgentAction[];
  iterations: number;
}

export async function executeToolLoop(context: ToolLoopContext): Promise<ToolLoopResult> {
  const {
    provider,
    model,
    messages,
    tools,
    toolHandlers,
    maxIterations = 5,
    allowedToolNames,
    hooks = {},
    temperature = 0.4,
    signal,
  } = context;

  const actions: AgentAction[] = [];
  let iteration = 0;

  // Check for abort before initial call
  if (signal?.aborted) {
    throw new DOMException('The operation was aborted', 'AbortError');
  }

  // Initial LLM call
  const request: LlmCompletionRequest = {
    model,
    messages: [...messages],
    tools: tools.length > 0 ? tools : undefined,
    tool_choice: tools.length > 0 ? 'auto' : undefined,
    temperature,
    signal,
  };

  let response;
  try {
    response = await provider.createCompletion(request);
  } catch (error) {
    const recovered = await hooks.onProviderError?.(error, iteration);
    if (recovered) {
      return { responseMessage: recovered, actions, iterations: iteration };
    }
    throw error;
  }

  let responseMessage = response.choices[0]?.message;
  if (!responseMessage) {
    throw new Error('No response from LLM provider');
  }

  // Append assistant message to conversation
  const conversationMessages = [...messages, responseMessage];

  // Tool loop
  while (responseMessage.tool_calls?.length && iteration < maxIterations) {
    iteration++;

    for (const toolCall of responseMessage.tool_calls) {
      const { name } = toolCall.function;

      // Check if tool is allowed
      if (allowedToolNames && !allowedToolNames.has(name)) {
        conversationMessages.push({
          role: 'tool',
          content: JSON.stringify({ status: 'error', message: `Tool "${name}" is not allowed in the current mode.` }),
          tool_call_id: toolCall.id,
        });
        continue;
      }

      // Parse arguments
      let args: Record<string, unknown>;
      try {
        args = JSON.parse(toolCall.function.arguments || '{}');
      } catch {
        conversationMessages.push({
          role: 'tool',
          content: JSON.stringify({ status: 'error', message: 'Invalid JSON in tool arguments.' }),
          tool_call_id: toolCall.id,
        });
        continue;
      }

      // Before hook
      const hookResult = await hooks.beforeToolCall?.(name, args);
      if (hookResult === false) {
        conversationMessages.push({
          role: 'tool',
          content: JSON.stringify({ status: 'error', message: `Tool call "${name}" was blocked by beforeToolCall hook.` }),
          tool_call_id: toolCall.id,
        });
        continue;
      }
      if (hookResult && typeof hookResult === 'object') {
        args = hookResult;
      }

      // Execute handler
      const handler = toolHandlers[name];
      if (!handler) {
        conversationMessages.push({
          role: 'tool',
          content: JSON.stringify({ status: 'error', message: `No handler registered for tool "${name}".` }),
          tool_call_id: toolCall.id,
        });
        continue;
      }

      // Check for abort before tool execution
      if (signal?.aborted) {
        throw new DOMException('The operation was aborted', 'AbortError');
      }

      let result: ToolHandlerResult;
      try {
        result = await handler(args);
      } catch (handlerError) {
        const errMsg = handlerError instanceof Error ? handlerError.message : 'Unknown handler error';
        result = { toolResponse: { status: 'error', message: errMsg } };
      }

      // Collect actions
      if (result.action) {
        const actionArray = Array.isArray(result.action) ? result.action : [result.action];
        actions.push(...actionArray);
      }

      // After hook
      await hooks.afterToolCall?.(name, result);

      // Append tool response
      conversationMessages.push({
        role: 'tool',
        content: JSON.stringify(result.toolResponse),
        tool_call_id: toolCall.id,
      });
    }

    // Check early break
    if (hooks.shouldBreakEarly?.(iteration, maxIterations)) {
      break;
    }

    // Determine tool_choice for follow-up
    const toolChoice = hooks.decideFollowupToolChoice?.(iteration, maxIterations)
      ?? (iteration >= maxIterations ? 'none' : 'auto');

    // Check for abort before follow-up call
    if (signal?.aborted) {
      throw new DOMException('The operation was aborted', 'AbortError');
    }

    // Follow-up LLM call
    try {
      response = await provider.createCompletion({
        model,
        messages: conversationMessages,
        tools: toolChoice === 'none' ? undefined : tools,
        tool_choice: toolChoice === 'none' ? undefined : toolChoice,
        temperature,
        signal,
      });
    } catch (error) {
      const recovered = await hooks.onProviderError?.(error, iteration);
      if (recovered) {
        return { responseMessage: recovered, actions, iterations: iteration };
      }
      throw error;
    }

    responseMessage = response.choices[0]?.message;
    if (!responseMessage) {
      throw new Error('No response from LLM provider on follow-up call');
    }

    conversationMessages.push(responseMessage);
  }

  return { responseMessage, actions, iterations: iteration };
}
