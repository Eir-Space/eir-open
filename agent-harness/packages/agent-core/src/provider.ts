import type { LlmMessage, ToolDefinition } from './types.js';

export interface LlmCompletionRequest {
  model: string;
  messages: LlmMessage[];
  tools?: ToolDefinition[];
  tool_choice?: 'auto' | 'none' | { type: 'function'; function: { name: string } };
  temperature?: number;
  max_tokens?: number;
  response_format?: Record<string, unknown>;
  signal?: AbortSignal;
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
 * Wraps any client with an OpenAI-compatible chat.completions.create method.
 * Works with openai, groq, together, mistral, ollama, etc.
 */
export class ChatCompletionsProvider implements LlmProvider {
  constructor(
    private client: {
      chat: {
        completions: {
          create: (params: LlmCompletionRequest) => Promise<unknown>;
        };
      };
    },
  ) {}

  async createCompletion(request: LlmCompletionRequest): Promise<LlmCompletionResponse> {
    const response = await this.client.chat.completions.create(request);
    return response as LlmCompletionResponse;
  }
}

/** @deprecated Use `ChatCompletionsProvider` instead. */
export const OpenAICompatibleProvider = ChatCompletionsProvider;
