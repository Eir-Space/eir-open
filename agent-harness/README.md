# @eir-open/agent-harness

A lightweight, open-source agent harness for building health agents. Extracted from the Eir health platform to provide a shared foundation for health AI projects.

## Packages

| Package                                              | Description                                                                      |
| ---------------------------------------------------- | -------------------------------------------------------------------------------- |
| [`@eir-open/agent-core`](packages/agent-core/)       | Tool loop engine, LLM provider interface, mode router, types                     |
| [`@eir-open/skill-kit`](packages/skill-kit/)         | Skill format spec, loader, and prompt assembly                                   |
| [`@eir-open/health-memory`](packages/health-memory/) | Open Health Memory Standard — schemas, store interface, reference implementation |

**Independent consumption:** Skill authors need only `skill-kit`. Health apps need only `health-memory`. Agent builders use all three.

## Quick Start

```bash
npm install @eir-open/agent-core @eir-open/skill-kit @eir-open/health-memory
```

```typescript
import { executeToolLoop, OpenAICompatibleProvider, KeywordModeRouter } from '@eir-open/agent-core';
import { loadSkillDirectory, getSkillsForMode, buildSkillPrompt } from '@eir-open/skill-kit';
import { InMemoryHealthMemoryStore, formatMemoryContext } from '@eir-open/health-memory';

// Wrap any OpenAI-compatible client
const provider = new OpenAICompatibleProvider(openaiClient);

// Load skills from a directory
const skills = loadSkillDirectory('./skills');

// Run the agent tool loop
const result = await executeToolLoop({
  provider,
  model: 'gpt-4o',
  messages: [
    { role: 'system', content: systemPrompt },
    { role: 'user', content: userMessage },
  ],
  tools: myToolDefinitions,
  toolHandlers: myToolHandlers,
  maxIterations: 5,
});
```

See [`examples/`](examples/) for complete working demos.

## Packages Overview

### `@eir-open/agent-core`

- **LLM Provider Interface** — Thin `createCompletion()` abstraction. Ships with `OpenAICompatibleProvider` for OpenAI, Groq, Together, Mistral, etc.
- **Tool Loop Engine** — Provider-agnostic tool execution loop with lifecycle hooks (`beforeToolCall`, `afterToolCall`, `shouldBreakEarly`, `onProviderError`).
- **Mode Router** — Abstract `ModeRouter` interface + `KeywordModeRouter` implementation. Each mode defines allowed tools, active skills, iteration limits.
- **Types & Contracts** — SDK-independent `ToolDefinition`, `ToolHandler`, `AgentAction`, `UnifiedAgentResponse` Zod schema.
- **Context Builders** — `buildSystemContent()`, `buildHistoryMessages()`, `buildModeToolInstruction()`, `formatMemoryContext()`.

### `@eir-open/skill-kit`

Unified skill format using Markdown with YAML frontmatter:

```markdown
---
name: base-personality
description: Core role and tone
modes: [general, assessment]
requiredTools: []
languages: [en, sv]
---

# Base Personality

You are a health agent...
```

- `loadSkill(dir)` — Parse a single skill directory
- `loadSkillDirectory(parentDir)` — Load all skills from a directory
- `getSkillsForMode(skills, mode)` — Filter by mode
- `buildSkillPrompt(skills, language)` — Concatenate prompts with language fallback
- Backward-compatible with `skill.json` format

### `@eir-open/health-memory`

Open standard for how agents build memory about user health. See [`HEALTH-MEMORY-SPEC.md`](packages/health-memory/HEALTH-MEMORY-SPEC.md).

- **Data model:** Categories (diagnosis, concern, interest, observation, summary), confidence scoring, status lifecycle (inferred → confirmed/dismissed)
- **`HealthMemoryStore` interface** — Abstract CRUD with dedup and confirmation logic
- **`InMemoryHealthMemoryStore`** — Reference implementation for testing and demos
- **`ConditionExtractor` interface** — For LLM-based health condition extraction
- **Context injection** — `formatMemoryContext()` with "untrusted factual snippets" framing

## Development

```bash
# Install all workspace dependencies
npm install

# Build all packages
npm run build

# Typecheck all packages
npm run typecheck

# Run tests
npm run test
```

## Only Dependency

`zod` — used for schema validation across all packages.

## License

[Eir Space License v1.0](../LICENSE)
