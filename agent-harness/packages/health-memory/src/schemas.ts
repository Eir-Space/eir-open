import { z } from 'zod';

// --- Enums ---
export const memoryCategorySchema = z.enum(['diagnosis', 'concern', 'interest', 'observation', 'summary']);
export type MemoryCategory = z.infer<typeof memoryCategorySchema>;

export const memorySourceTypeSchema = z.enum(['chat', 'journal', 'uploaded_record', 'manual_user_confirmed']);
export type MemorySourceType = z.infer<typeof memorySourceTypeSchema>;

export const memoryStatusSchema = z.enum(['inferred', 'user_confirmed', 'record_backed', 'dismissed']);
export type MemoryStatus = z.infer<typeof memoryStatusSchema>;

export const memoryCertaintySchema = z.enum(['low', 'medium', 'high']);
export type MemoryCertainty = z.infer<typeof memoryCertaintySchema>;

// --- Evidence Reference ---
export const evidenceRefSchema = z.object({
  type: z.enum(['message', 'journal_note', 'document', 'assessment']),
  id: z.string().min(1),
});
export type EvidenceRef = z.infer<typeof evidenceRefSchema>;

// --- Full Memory Item (database record) ---
export const memoryItemSchema = z.object({
  id: z.string().min(1),
  category: memoryCategorySchema,
  label: z.string().min(1),
  detail: z.string().optional(),
  sourceType: memorySourceTypeSchema,
  confidence: z.number().min(0).max(1),
  certaintyLevel: memoryCertaintySchema,
  status: memoryStatusSchema,
  evidenceRefs: z.array(evidenceRefSchema).default([]),
  observedAt: z.string().min(1),
  updatedAt: z.string().min(1),
  lastUsedAt: z.string().optional(),
});
export type MemoryItem = z.infer<typeof memoryItemSchema>;

// --- Snippet (lightweight, for API transport / context injection) ---
export const healthMemorySnippetSchema = z.object({
  id: z.string().min(1),
  category: memoryCategorySchema,
  label: z.string().min(1),
  detail: z.string().optional(),
  confidence: z.number().min(0).max(1),
  certaintyLevel: memoryCertaintySchema,
  status: memoryStatusSchema,
});
export type HealthMemorySnippet = z.infer<typeof healthMemorySnippetSchema>;
