import type { LlmMessage, ToolDefinition } from './types.js';

export interface LlmCompletionRequest {
  model: string;
  messages: LlmMessage[];
  tools?: ToolDefinition[];
  tool_choice?: 'auto' | 'none' | { type: 'function'; function: { name: string } };
  temperature?: number;
  max_tokens?: number;
  response_format?: Record<string, unknown>;
}

export interface LlmCompletionResponse {
  choices: Array<{
    message: LlmMessage;
    finish_reason: string | null;
  }>;
  usage?: { prompt_tokens: number; completion_tokens: number; total_tokens: number };
}

export interface LlmProvider {
  createCompletion(request: LlmCompletionRequest): Promise<LlmCompletionResponse>;
}

/**
 * Wraps any OpenAI-compatible SDK client instance.
 * Works with openai, groq, together, mistral, etc.
 */
export class OpenAICompatibleProvider implements LlmProvider {
  constructor(private client: { chat: { completions: { create: (params: any) => Promise<any> } } }) {}

  async createCompletion(request: LlmCompletionRequest): Promise<LlmCompletionResponse> {
    const response = await this.client.chat.completions.create(request);
    return response as LlmCompletionResponse;
  }
}
