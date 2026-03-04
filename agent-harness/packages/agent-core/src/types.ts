import { z } from 'zod';

// --- LLM Message Types ---
export interface LlmMessage {
  role: 'system' | 'user' | 'assistant' | 'tool';
  content: string | null;
  name?: string;
  tool_call_id?: string;
  tool_calls?: LlmToolCall[];
}

export interface LlmToolCall {
  id: string;
  type: 'function';
  function: { name: string; arguments: string };
}

// --- Tool Types (decoupled from any SDK) ---
export interface ToolDefinition {
  type: 'function';
  function: {
    name: string;
    description: string;
    parameters: Record<string, unknown>;
  };
}

export interface ToolResponse {
  status: 'success' | 'error';
  message: string;
  data?: unknown;
}

export interface ToolHandlerResult {
  toolResponse: ToolResponse;
  action?: AgentAction | AgentAction[];
}

export type ToolHandler = (
  args: Record<string, unknown>,
) => ToolHandlerResult | Promise<ToolHandlerResult>;

// --- Agent Action ---
export const agentActionStatusSchema = z.enum([
  'proposed',
  'confirmed',
  'rejected',
  'executed',
  'failed',
]);
export type AgentActionStatus = z.infer<typeof agentActionStatusSchema>;

export interface AgentAction {
  type: string; // open string, not closed enum — platforms define their own types
  status?: AgentActionStatus;
  payload: Record<string, unknown>;
  validationErrors?: ValidationError[];
}

export interface ValidationError {
  tool: string;
  code: string;
  message: string;
  field?: string;
}

// --- Chat History ---
export interface ChatHistoryItem {
  role: 'user' | 'assistant';
  content: string;
}
