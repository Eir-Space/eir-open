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

// Session
export { SessionManager } from './session.js';
export type { Session, SessionManagerOptions } from './session.js';

// Context Builder
export { buildHistoryMessages, buildModeToolInstruction, buildSystemContent, formatMemoryContext } from './contextBuilder.js';

// Plugin
export { PluginRegistry, pluginManifestSchema } from './plugin.js';
export type { PluginManifest, PluginContext, PluginToolEntry, PluginRegistration, EirPlugin } from './plugin.js';

// Subagent
export { createSubagentTool } from './subagent.js';
export type { SubagentToolParams, SubagentTool } from './subagent.js';
