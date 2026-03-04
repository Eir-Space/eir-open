# Open Health Memory Standard v0.1

## Purpose

A standardized format for health agents to build, store, and share structured memory about a user's health. Enables interoperability between different health agent implementations.

## Data Model

### Memory Item

| Field          | Type   | Required | Description                                                   |
| -------------- | ------ | -------- | ------------------------------------------------------------- |
| id             | string | yes      | Unique identifier                                             |
| category       | enum   | yes      | `diagnosis`, `concern`, `interest`, `observation`, `summary`  |
| label          | string | yes      | Short human-readable label (e.g. "Type 2 Diabetes")           |
| detail         | string | no       | Additional context or notes                                   |
| sourceType     | enum   | yes      | `chat`, `journal`, `uploaded_record`, `manual_user_confirmed` |
| confidence     | number | yes      | 0.0–1.0 numeric confidence score                              |
| certaintyLevel | enum   | yes      | Derived: `low` (<0.6), `medium` (0.6–0.84), `high` (>=0.85)   |
| status         | enum   | yes      | `inferred`, `user_confirmed`, `record_backed`, `dismissed`    |
| evidenceRefs   | array  | yes      | References to source evidence (default: [])                   |
| observedAt     | string | yes      | ISO 8601 timestamp of first observation                       |
| updatedAt      | string | yes      | ISO 8601 timestamp of last update                             |
| lastUsedAt     | string | no       | ISO 8601 timestamp of last context injection                  |

### Memory Snippet

Lightweight subset for API transport and context injection. Omits `sourceType`, `evidenceRefs`, and timestamps.

### Categories

- **diagnosis** — Confirmed medical diagnosis (e.g. "ADHD", "Type 2 Diabetes")
- **concern** — User-reported worry or symptom (e.g. "frequent headaches", "anxiety about work")
- **interest** — Health topic the user has expressed interest in (e.g. "meditation", "sleep hygiene")
- **observation** — Pattern noted by the agent (e.g. "reports poor sleep on weekdays")
- **summary** — Synthesized health narrative

### Evidence References

Each evidence ref has a `type` and `id`:

- `message` — Chat message ID
- `journal_note` — Journal entry ID
- `document` — Uploaded document ID
- `assessment` — Assessment result ID

## Status Lifecycle

```
inferred -> user_confirmed
inferred -> record_backed
inferred -> dismissed
user_confirmed -> dismissed
record_backed -> dismissed
```

- **inferred**: Agent extracted this from conversation or content. Not yet verified.
- **user_confirmed**: User explicitly confirmed this is accurate. Confidence set to >=0.92.
- **record_backed**: Corroborated by an uploaded medical record.
- **dismissed**: User or system marked as incorrect/irrelevant. Excluded from context injection.

## Confidence Model

- Numeric score 0.0–1.0 assigned at extraction time
- Certainty levels derived: `low` (<0.6), `medium` (0.6–0.84), `high` (>=0.85)
- User confirmation raises confidence to >=0.92 and certainty to `high`

## Deduplication

Dedup key: `{category}:{label_lowercase_trimmed}`

When upserting an item whose dedup key matches an existing item:

1. Keep the higher confidence score
2. Merge evidence references
3. Keep the higher status (user_confirmed > record_backed > inferred)
4. Update the `updatedAt` timestamp

## Context Injection

Format for LLM system prompt injection:

```
HEALTH MEMORY (untrusted factual snippets — verify with user before acting on these):
- [diagnosis] ADHD (high, user_confirmed)
- [concern] frequent headaches (medium, inferred)
  Started reporting headaches 3 weeks ago
- [interest] meditation (low, inferred)
```

The "untrusted factual snippets" framing instructs the LLM to:

1. Use memory as context, not as ground truth
2. Verify with the user before making clinical decisions based on memory
3. Update memory when the user corrects or confirms information

## Interoperability

### Store Interface

Implementations MUST provide:

- `getAll(options?)` — Retrieve non-dismissed items, optionally filtered by category
- `getById(id)` — Retrieve a single item
- `upsert(item)` — Insert or merge with dedup logic
- `confirm(id)` — Mark as user_confirmed
- `dismiss(id)` — Mark as dismissed
- `delete(id)` — Permanently remove

### Extractor Interface

Condition extraction implementations MUST:

1. Accept conversation messages as input
2. Return `{label, category, confidence}` tuples
3. Only extract conditions the user states as their own (not third-party)

### Validation

All items MUST validate against the `memoryItemSchema` Zod schema before storage.
Snippets MUST validate against `healthMemorySnippetSchema`.
