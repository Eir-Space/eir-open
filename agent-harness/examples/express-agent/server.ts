/**
 * Express Agent Example
 *
 * Demonstrates an HTTP agent server using the @eir-open agent harness.
 * Serves a POST /chat endpoint that runs the tool loop.
 */

import express from 'express';

import {
  executeToolLoop,
  buildSystemContent,
  buildModeToolInstruction,
  buildHistoryMessages,
  KeywordModeRouter,
  unifiedAgentResponseSchema,
  type LlmProvider,
  type LlmCompletionRequest,
  type LlmCompletionResponse,
  type ToolDefinition,
  type ToolHandler,
  type ChatHistoryItem,
} from '@eir-open/agent-core';

import { loadSkillDirectory, getSkillsForMode, buildSkillPrompt } from '@eir-open/skill-kit';

import {
  InMemoryHealthMemoryStore,
  formatMemoryContext,
  toMemoryItems,
  type ConditionExtractor,
  type ExtractedCondition,
} from '@eir-open/health-memory';

// --- Configuration ---
// In production, replace with a real LLM provider:
//   import OpenAI from 'openai';
//   import { OpenAICompatibleProvider } from '@eir-open/agent-core';
//   const provider = new OpenAICompatibleProvider(new OpenAI({ apiKey: process.env.OPENAI_API_KEY }));

const mockProvider: LlmProvider = {
  async createCompletion(request: LlmCompletionRequest): Promise<LlmCompletionResponse> {
    const lastUserMsg = [...request.messages].reverse().find(m => m.role === 'user');
    const text = typeof lastUserMsg?.content === 'string' ? lastUserMsg.content : '';

    // Simple echo response for demo
    return {
      choices: [{
        message: { role: 'assistant', content: `Thank you for sharing. Regarding "${text}" — I recommend discussing this with your healthcare provider for personalized advice.` },
        finish_reason: 'stop',
      }],
    };
  },
};

// --- Tools ---

const tools: ToolDefinition[] = [
  {
    type: 'function',
    function: {
      name: 'log_concern',
      description: 'Log a health concern mentioned by the user',
      parameters: {
        type: 'object',
        properties: {
          concern: { type: 'string', description: 'The health concern' },
          severity: { type: 'string', enum: ['low', 'medium', 'high'] },
        },
        required: ['concern'],
      },
    },
  },
];

const toolHandlers: Record<string, ToolHandler> = {
  log_concern: (args) => ({
    toolResponse: { status: 'success', message: `Logged concern: ${args.concern}` },
    action: {
      type: 'concern:logged',
      status: 'executed',
      payload: { concern: args.concern, severity: args.severity ?? 'medium' },
    },
  }),
};

// --- Mode Router ---

const router = new KeywordModeRouter({
  modes: {
    general: {
      allowedTools: ['log_concern'],
      activeSkills: ['base-personality'],
      maxToolIterations: 3,
      retrievalBudget: 5,
    },
    safety: {
      allowedTools: [],
      activeSkills: ['base-personality'],
      maxToolIterations: 0,
      retrievalBudget: 0,
    },
  },
  rules: [
    {
      keywords: ['suicide', 'self-harm', 'kill myself'],
      mode: 'safety',
    },
  ],
  defaultMode: 'general',
});

// --- Server ---

const app = express();
app.use(express.json());

const skills = loadSkillDirectory(
  new URL('../minimal-agent/skills', import.meta.url).pathname,
);
const memoryStore = new InMemoryHealthMemoryStore();

app.post('/chat', async (req, res) => {
  try {
    const { message, history = [] } = req.body as {
      message: string;
      history?: ChatHistoryItem[];
    };

    if (!message?.trim()) {
      res.status(400).json({ error: 'message is required' });
      return;
    }

    // 1. Route mode
    const decision = router.resolve({ message, history });

    // 2. Build system prompt
    const modeSkills = getSkillsForMode(skills, decision.mode);
    const skillPrompt = buildSkillPrompt(modeSkills, 'en');
    const modeInstruction = buildModeToolInstruction({
      mode: decision.mode,
      toolNames: decision.allowedTools,
    });

    const memoryItems = await memoryStore.getAll();
    const memoryContext = formatMemoryContext(memoryItems);

    const systemContent = buildSystemContent([skillPrompt, modeInstruction, memoryContext]);

    // 3. Build messages
    const historyMessages = buildHistoryMessages(history);
    const messages = [
      { role: 'system' as const, content: systemContent },
      ...historyMessages,
      { role: 'user' as const, content: message },
    ];

    // 4. Filter tools for mode
    const modeTools = decision.allowedTools.length > 0
      ? tools.filter(t => decision.allowedTools.includes(t.function.name))
      : [];

    // 5. Run tool loop
    const result = await executeToolLoop({
      provider: mockProvider,
      model: 'mock-model',
      messages,
      tools: modeTools,
      toolHandlers,
      maxIterations: decision.maxToolIterations,
      allowedToolNames: new Set(decision.allowedTools),
    });

    // 6. Build response envelope
    const response = unifiedAgentResponseSchema.parse({
      assistant_message: result.responseMessage.content ?? '',
      actions: result.actions,
      ui_blocks: [],
      suggested_followups: [],
    });

    res.json({
      ...response,
      metadata: {
        mode: decision.mode,
        iterations: result.iterations,
        timestamp: new Date().toISOString(),
      },
    });
  } catch (error) {
    console.error('Chat error:', error);
    res.status(500).json({ error: 'Internal server error' });
  }
});

const PORT = process.env.PORT ?? 3000;
app.listen(PORT, () => {
  console.log(`Health agent server running on http://localhost:${PORT}`);
  console.log(`Loaded ${skills.size} skill(s)`);
  console.log('\nTry: curl -X POST http://localhost:3000/chat -H "Content-Type: application/json" -d \'{"message":"I have been having headaches"}\'');
});
