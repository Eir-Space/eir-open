// Types
export type {
  LlmMessage,
  LlmToolCall,
  ToolDefinition,
  ToolResponse,
  ToolHandlerResult,
  ToolHandler,
  AgentAction,
  AgentActionStatus,
  ValidationError,
  ChatHistoryItem,
} from './types.js';
export { agentActionStatusSchema } from './types.js';

// Contracts (Zod schemas)
export {
  validationErrorSchema,
  genericAgentActionSchema,
  citationSchema,
  unifiedAgentResponseSchema,
} from './contracts.js';
export type { UnifiedAgentResponse, GenericAgentAction } from './contracts.js';

// Provider
export type { LlmProvider, LlmCompletionRequest, LlmCompletionResponse } from './provider.js';
export { OpenAICompatibleProvider } from './provider.js';

// Tool Loop
export { executeToolLoop } from './toolLoop.js';
export type { ToolLoopHooks, ToolLoopContext, ToolLoopResult } from './toolLoop.js';

// Mode Router
export type { ModeDefinition, RouterDecision, ModeRouter, ModeRouterInput, KeywordRule, KeywordModeRouterConfig } from './modeRouter.js';
export { KeywordModeRouter } from './modeRouter.js';

// Context Builder
export { buildHistoryMessages, buildModeToolInstruction, buildSystemContent, formatMemoryContext } from './contextBuilder.js';
