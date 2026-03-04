/**
 * Minimal Agent Example
 *
 * Demonstrates using the @eir-open agent harness with a mock LLM provider.
 * Loads a skill, sets up a tool, and runs the tool loop.
 */

import {
  executeToolLoop,
  buildSystemContent,
  buildModeToolInstruction,
  buildHistoryMessages,
  KeywordModeRouter,
  type LlmProvider,
  type LlmCompletionRequest,
  type LlmCompletionResponse,
  type ToolDefinition,
  type ToolHandler,
} from '@eir-open/agent-core';

import { loadSkillDirectory, getSkillsForMode, buildSkillPrompt } from '@eir-open/skill-kit';

import {
  InMemoryHealthMemoryStore,
  formatMemoryContext,
  toCertainty,
  type MemoryItem,
} from '@eir-open/health-memory';

// --- Mock LLM Provider ---
// In production, use: new OpenAICompatibleProvider(new OpenAI({ apiKey: '...' }))

const mockProvider: LlmProvider = {
  async createCompletion(request: LlmCompletionRequest): Promise<LlmCompletionResponse> {
    const lastMessage = request.messages[request.messages.length - 1];
    const userText = typeof lastMessage.content === 'string' ? lastMessage.content : '';

    // If tools are available, simulate a tool call for greetings
    if (request.tools?.length && userText.toLowerCase().includes('hello')) {
      return {
        choices: [
          {
            message: {
              role: 'assistant',
              content: null,
              tool_calls: [
                {
                  id: 'call_1',
                  type: 'function',
                  function: {
                    name: 'greet_user',
                    arguments: JSON.stringify({ name: 'friend' }),
                  },
                },
              ],
            },
            finish_reason: 'tool_calls',
          },
        ],
      };
    }

    // Default: text response
    return {
      choices: [
        {
          message: {
            role: 'assistant',
            content: `I understood: "${userText}". How can I help with your health?`,
          },
          finish_reason: 'stop',
        },
      ],
    };
  },
};

// --- Tool Setup ---

const greetTool: ToolDefinition = {
  type: 'function',
  function: {
    name: 'greet_user',
    description: 'Greet the user by name',
    parameters: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'The user name' },
      },
      required: ['name'],
    },
  },
};

const greetHandler: ToolHandler = (args) => ({
  toolResponse: {
    status: 'success',
    message: `Greeted ${args.name}`,
  },
  action: {
    type: 'ui:greeting',
    status: 'executed',
    payload: { name: args.name },
  },
});

// --- Mode Router ---

const router = new KeywordModeRouter({
  modes: {
    general: {
      allowedTools: ['greet_user'],
      activeSkills: ['base-personality'],
      maxToolIterations: 3,
      retrievalBudget: 5,
    },
  },
  rules: [],
  defaultMode: 'general',
});

// --- Main ---

async function main() {
  console.log('=== Minimal Agent Example ===\n');

  // 1. Load skills
  const skills = loadSkillDirectory(new URL('./skills', import.meta.url).pathname);
  console.log(`Loaded ${skills.size} skill(s): ${[...skills.keys()].join(', ')}`);

  // 2. Route mode
  const userMessage = 'Hello, can you help me?';
  const decision = router.resolve({ message: userMessage });
  console.log(`Mode: ${decision.mode}, Tools: [${decision.allowedTools.join(', ')}]`);

  // 3. Build system prompt
  const modeSkills = getSkillsForMode(skills, decision.mode);
  const skillPrompt = buildSkillPrompt(modeSkills, 'en');
  const modeInstruction = buildModeToolInstruction({
    mode: decision.mode,
    toolNames: decision.allowedTools,
  });

  // 4. Set up health memory
  const memoryStore = new InMemoryHealthMemoryStore();
  const now = new Date().toISOString();
  await memoryStore.upsert({
    id: 'demo-1',
    category: 'concern',
    label: 'frequent headaches',
    sourceType: 'chat',
    confidence: 0.7,
    certaintyLevel: toCertainty(0.7),
    status: 'inferred',
    evidenceRefs: [],
    observedAt: now,
    updatedAt: now,
  });

  const memoryItems = await memoryStore.getAll();
  const memoryContext = formatMemoryContext(memoryItems);

  const systemContent = buildSystemContent([skillPrompt, modeInstruction, memoryContext]);

  // 5. Run tool loop
  const result = await executeToolLoop({
    provider: mockProvider,
    model: 'mock-model',
    messages: [
      { role: 'system', content: systemContent },
      { role: 'user', content: userMessage },
    ],
    tools: [greetTool],
    toolHandlers: { greet_user: greetHandler },
    maxIterations: decision.maxToolIterations,
    allowedToolNames: new Set(decision.allowedTools),
  });

  console.log(`\nIterations: ${result.iterations}`);
  console.log(`Actions: ${result.actions.length}`);
  result.actions.forEach((a) => console.log(`  - ${a.type}: ${JSON.stringify(a.payload)}`));
  console.log(`\nAssistant: ${result.responseMessage.content}`);
}

main().catch(console.error);
