import { z } from 'zod';
import { agentActionStatusSchema } from './types.js';

export const validationErrorSchema = z.object({
  tool: z.string().min(1),
  code: z.string().min(1),
  message: z.string().min(1),
  field: z.string().optional(),
});

export const genericAgentActionSchema = z.object({
  type: z.string().min(1), // open — platforms define their own action types
  status: agentActionStatusSchema.default('proposed'),
  payload: z.record(z.unknown()).default({}),
  validationErrors: z.array(validationErrorSchema).optional(),
});

export const citationSchema = z.object({
  entryId: z.string().min(1),
  reference: z.string().min(1),
});

export const unifiedAgentResponseSchema = z.object({
  assistant_message: z.string(),
  ui_blocks: z.array(z.record(z.unknown())).default([]), // platform defines block schema
  actions: z.array(genericAgentActionSchema).default([]),
  suggested_followups: z.array(z.string().min(1)).max(5).optional(),
  citations: z.array(citationSchema).optional(),
  safety_notice: z.string().optional(),
  debug: z.unknown().optional(),
});

export type UnifiedAgentResponse = z.infer<typeof unifiedAgentResponseSchema>;
export type GenericAgentAction = z.infer<typeof genericAgentActionSchema>;
