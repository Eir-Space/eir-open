# Vector Search & Embedding Architecture for EirViewer

## Status: Design Document (Draft)

---

## 1. How the LLM Currently Accesses Journal Data

```
User asks a question
        │
        ▼
┌─────────────────────────────────┐
│  System Prompt (lightweight)    │
│  - Agent identity (SOUL.md)     │
│  - User profile (USER.md)       │
│  - Memory (MEMORY.md)           │
│  - Skills (AGENTS.md)           │
│  - Records METADATA only:       │
│    "3 people loaded,             │
│     287 total entries,           │
│     categories: Anteckning (89), │
│     Lab (45), Recept (33)..."    │
└─────────────────────────────────┘
        │
        ▼
   LLM decides what to do
        │
        ├─── search_records(query: "headache", person: "Hedda")
        │         │
        │         ▼  Naive keyword matching (current)
        │         └── Returns top 20 matching entries with IDs
        │
        ├─── get_record_detail(entry_id: "abc123")
        │         │
        │         ▼  Exact ID lookup (unchanged by vector search)
        │         └── Returns full entry content
        │
        └─── summarize_health(focus: "medications", person: "Birk")
                  │
                  ▼  Iterates through all entries of that type
                  └── Returns structured summary
```

**Key point: The LLM never gets raw journal data in the system prompt.** It always goes through tools. Vector search improves the `search_records` tool specifically — making it semantic instead of keyword-based. The rest of the flow stays the same.

### What vector search fixes

| Query | Current (keyword) | With vector search |
|-------|-------------------|-------------------|
| "heart problems" | Misses entries about "bröstsmärta", "kardiella besvär" | Finds semantically related entries |
| "when was the last time Hedda was sick" | Matches "sick" literally | Understands intent, finds illness visits |
| "vaccination history" | Only matches "vaccination" string | Also finds "immunisering", "spruta" |
| "anxiety medication" | Only finds entries containing both words | Finds SSRIs, benzodiazepines, etc. |

---

## 2. Architecture Overview

```
~/Library/Application Support/EirViewer/
├── agent/{profileID}/           # Existing agent memory (SOUL/USER/MEMORY/AGENTS.md)
└── embeddings/{profileID}.sqlite  # NEW: Vector search database
         │
         ├── entries        (metadata: id, person, date, category, text, hash)
         ├── entries_vec    (sqlite-vec: float[N] vectors)
         └── entries_fts    (FTS5: keyword search index)
```

### Components

```
┌──────────────┐     ┌──────────────────┐     ┌──────────────┐
│  EirParser   │────▶│  EmbeddingEngine │────▶│  SQLite DB   │
│  (.eir file) │     │  (on-device LLM) │     │  + sqlite-vec│
└──────────────┘     └──────────────────┘     │  + FTS5      │
                                               └──────┬───────┘
                                                      │
                                               ┌──────▼───────┐
                                               │ HybridSearch │
                                               │ 70% vector   │
                                               │ 30% keyword  │
                                               └──────┬───────┘
                                                      │
                                               ┌──────▼───────┐
                                               │ search_records│
                                               │ (tool call)   │
                                               └──────────────┘
```

---

## 3. Embedding Model Decision

### Option A: Qwen3-Embedding-0.6B (Text-Only, Recommended Default)

| Property | Value |
|----------|-------|
| Size (Q8_0) | 639 MB |
| Dimensions | 32–1024 (configurable via MRL) |
| Languages | 100+ including Swedish |
| Context | 32K tokens |
| Purpose-built | Yes, specifically for embeddings |
| Multilingual MTEB | 64.33 |
| Speed | Fast (0.6B params, small model) |

**Pros**: Small, fast, designed for embeddings, great multilingual support.
**Cons**: Text only — no image/sound search.

### Option B: Qwen3-VL-2B (Multimodal, User Recommended)

| Property | Value |
|----------|-------|
| Size (Q5_K_M) | ~1.5–2 GB (text) + mmproj (~400MB) |
| Dimensions | Hidden state dims (varies) |
| Languages | Multilingual |
| Modalities | Text + Image + Video + Audio |
| Purpose-built | No (instruct model, embeddings from hidden states) |

**Pros**: Multimodal — can search by image/sound to find text memories. VL models produce richer representations even for text.
**Cons**: Larger, slower, not specifically trained for embedding tasks, requires mmproj file.

**Important note from user**: Use Q5_K_M minimum for embedding models (not Q4_K_M like chat models). Embedding quality degrades more with lower quantization.

### Option C: Qwen3-VL-Embedding-8B (Dedicated Multimodal Embedding)

| Property | Value |
|----------|-------|
| Size (Q5_K_M) | ~5-6 GB |
| Modalities | Text + Image + Video |
| Purpose-built | Yes, specifically for multimodal embeddings |
| MMEB-V2 | State-of-the-art |

**Pros**: Best quality, dedicated embedding model, SOTA multimodal retrieval.
**Cons**: 8B params is heavy for on-device use on some Macs.

### Decision

**Phase 1**: Start with **Qwen3-Embedding-0.6B** (639MB) for text search. It's small enough to bundle/download quickly, purpose-built for embeddings, and covers Swedish well.

**Phase 2**: Add **Qwen3-VL-2B** or **Qwen3-VL-Embedding-8B** as an optional upgrade for users who want multimodal search (find records by photo of a prescription, etc.). Make the embedding model configurable in Settings.

User setting: `Settings > Embedding Model > [Qwen3-Embedding-0.6B | Qwen3-VL-2B | Qwen3-VL-Embedding-8B | None (keyword only)]`

---

## 4. Technology Stack

### SQLite + sqlite-vec + FTS5

**Package**: [jkrukowski/SQLiteVec](https://github.com/jkrukowski/SQLiteVec) (SPM)
- Bundles sqlite-vec C source + own SQLite amalgamation
- Actor-based async/await Swift API
- Compiles from source via SPM — no dynamic loading
- macOS 10.15+

### llama.cpp for On-Device Inference

**Package**: [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) (SPM) or [siuying/llama.swift](https://github.com/siuying/llama.swift)
- Runs GGUF models on Apple Silicon via Metal
- Supports embedding extraction via `llama_encode` + `llama_get_embeddings`
- ARM NEON + Accelerate + Metal optimized

### Alternative: swift-embeddings (lighter option)

**Package**: [jkrukowski/swift-embeddings](https://github.com/jkrukowski/swift-embeddings) (SPM)
- Uses Apple MLTensor (Core ML under the hood)
- Supports BERT, XLM-RoBERTa (multilingual/Swedish), LaBSE
- No GGUF needed — runs HuggingFace models directly
- Same author as SQLiteVec — designed to work together
- Trade-off: Smaller model selection, no multimodal, but simpler integration

---

## 5. Database Schema

```sql
-- Metadata for each embedded entry
CREATE TABLE IF NOT EXISTS entries (
    id TEXT PRIMARY KEY,           -- EirEntry.id
    person_name TEXT NOT NULL,     -- Which family member
    date TEXT,                     -- Entry date
    category TEXT,                 -- Anteckning, Lab, Recept, etc.
    text TEXT NOT NULL,            -- Concatenated searchable text
    hash TEXT NOT NULL,            -- SHA256 of text (for change detection)
    model TEXT NOT NULL,           -- Which embedding model was used
    embedded_at INTEGER NOT NULL   -- Unix timestamp
);

-- Vector storage (sqlite-vec virtual table)
CREATE VIRTUAL TABLE IF NOT EXISTS entries_vec USING vec0(
    id TEXT PRIMARY KEY,
    embedding float[1024]          -- Dimension matches model output
);

-- Full-text search index (FTS5)
CREATE VIRTUAL TABLE IF NOT EXISTS entries_fts USING fts5(
    text,
    id UNINDEXED,
    person_name UNINDEXED,
    category UNINDEXED,
    date UNINDEXED
);

-- Track file hashes to know when to re-embed
CREATE TABLE IF NOT EXISTS files (
    path TEXT PRIMARY KEY,
    hash TEXT NOT NULL,
    entry_count INTEGER NOT NULL,
    embedded_at INTEGER NOT NULL
);
```

---

## 6. Hybrid Search Algorithm

Following OpenClaw's proven approach:

```
hybrid_score = (0.7 × vector_score) + (0.3 × keyword_score)
```

### Vector Search (semantic)
```sql
SELECT e.id, e.person_name, e.date, e.category, e.text,
       vec_distance_cosine(v.embedding, ?) AS distance
FROM entries_vec v
JOIN entries e ON e.id = v.id
WHERE e.person_name = ? OR ? IS NULL  -- optional person filter
ORDER BY distance ASC
LIMIT ?
```
Score: `1.0 - distance` (cosine similarity, 0–1)

### Keyword Search (exact match)
```sql
SELECT id, person_name, date, category, text,
       bm25(entries_fts) AS rank
FROM entries_fts
WHERE entries_fts MATCH ?
ORDER BY rank ASC
LIMIT ?
```
Score: `1.0 / (1.0 + max(0, rank))` (normalized BM25, 0–1)

### Merge
1. Fetch `4 × maxResults` candidates from each search
2. Merge by entry ID, combine scores with 70/30 weighting
3. Filter by minimum score threshold (0.35)
4. Return top N results

---

## 7. Embedding Pipeline

### On Import (when .eir file is loaded)

```
Load .eir file
    │
    ▼
Check file hash against files table
    │
    ├── Hash matches → Skip (already embedded)
    │
    └── Hash changed or new file →
            │
            ▼
        For each EirEntry:
            │
            ├── Build searchable text:
            │   "{date} {category} {provider} {summary} {details} {notes}"
            │
            ├── Hash the text → check entries table
            │   ├── Hash matches → Skip (entry unchanged)
            │   └── Hash changed → Re-embed
            │
            └── Generate embedding via on-device model
                    │
                    ▼
                Store in entries + entries_vec + entries_fts
```

### Performance Estimates (Qwen3-Embedding-0.6B on M1/M2)

- ~50ms per entry embedding (0.6B model, Metal accelerated)
- 300 entries × 50ms = ~15 seconds for full re-index
- Incremental updates: only re-embed changed entries
- Background thread: non-blocking UI

---

## 8. Integration into Existing Tool System

### Modified: `search_records` tool

```swift
// Before (keyword only):
func searchRecords(query: String, ...) -> [Entry] {
    allEntries.filter { $0.text.contains(query) }
}

// After (hybrid search):
func searchRecords(query: String, ...) -> [Entry] {
    let embedding = embeddingEngine.embed(query)
    let vectorResults = vectorDB.search(embedding, limit: 24)
    let keywordResults = vectorDB.ftsSearch(query, limit: 24)
    return mergeHybrid(vector: vectorResults, keyword: keywordResults, limit: 20)
}
```

### Unchanged tools
- `get_record_detail` — exact ID lookup, no search needed
- `summarize_health` — iterates all entries of a type, no search needed
- `find_clinics` — uses clinic store, unrelated
- `update_memory`, `name_agent`, `update_user_profile` — agent memory, unrelated

---

## 9. New Files

| File | Purpose |
|------|---------|
| `Services/EmbeddingEngine.swift` | Load GGUF model, generate embeddings |
| `Services/VectorStore.swift` | SQLite + sqlite-vec + FTS5 database management |
| `Services/HybridSearch.swift` | Merge vector + keyword results |
| `ViewModels/EmbeddingStore.swift` | Observable state: indexing progress, model status |
| `Views/Settings/EmbeddingSettingsView.swift` | Model selection, re-index button, status |

### Modified Files

| File | Change |
|------|--------|
| `Package.swift` | Add SQLiteVec + llama.cpp dependencies |
| `Services/ToolRegistry.swift` | Update `search_records` to use hybrid search |
| `EirViewerApp.swift` | Initialize embedding engine + vector store |
| `Views/Settings/SettingsView.swift` | Add embedding settings section |

---

## 10. Model Management

### Download & Storage

```
~/Library/Application Support/EirViewer/models/
├── qwen3-embedding-0.6b-q8_0.gguf    (639 MB)
└── qwen3-vl-2b-instruct-q5_k_m.gguf  (optional, ~1.5 GB)
```

### First-Run Experience

1. App detects no embedding model downloaded
2. Shows banner: "Download embedding model for smarter search? (639 MB)"
3. Downloads in background with progress indicator
4. Once downloaded, auto-indexes all loaded medical records
5. Future launches: model is cached, only re-indexes changed files

### Settings UI

```
┌─────────────────────────────────────────────┐
│ Search & Embeddings                         │
│                                             │
│ Embedding Model: [Qwen3-Embedding-0.6B ▾]  │
│ Status: ● Ready (287 entries indexed)       │
│ Model size: 639 MB                          │
│                                             │
│ [Re-index All Records]  [Delete Model]      │
│                                             │
│ ☐ Enable multimodal search (requires        │
│   Qwen3-VL-2B, additional 1.5 GB download) │
└─────────────────────────────────────────────┘
```

---

## 11. Privacy Considerations

- All embeddings generated on-device — no data leaves the Mac
- GGUF models run via llama.cpp on Metal (Apple Silicon GPU)
- No API calls needed for search
- Vector database stored locally in Application Support
- Follows EirViewer's privacy-first architecture

---

## 12. Implementation Order

1. **Add SPM dependencies** (SQLiteVec, llama.cpp Swift bindings)
2. **VectorStore.swift** — SQLite schema, CRUD, FTS5 index
3. **EmbeddingEngine.swift** — Load GGUF model, generate embeddings
4. **HybridSearch.swift** — Merge algorithm
5. **EmbeddingStore.swift** — Observable state, background indexing
6. **Update ToolRegistry** — Wire hybrid search into `search_records`
7. **Settings UI** — Model download, status, re-index
8. **Wire into app lifecycle** — Auto-index on profile load
9. **Test with real records** — Verify Swedish medical term retrieval

---

## References

- [OpenClaw Memory Architecture](https://www.pingcap.com/blog/local-first-rag-using-sqlite-ai-agent-memory-openclaw/)
- [sqlite-vec](https://github.com/asg017/sqlite-vec)
- [SQLiteVec Swift Package](https://github.com/jkrukowski/SQLiteVec)
- [Qwen3-Embedding-0.6B](https://huggingface.co/Qwen/Qwen3-Embedding-0.6B-GGUF)
- [Qwen3-VL-2B-Instruct](https://huggingface.co/Qwen/Qwen3-VL-2B-Instruct-GGUF)
- [Qwen3-VL-Embedding](https://github.com/QwenLM/Qwen3-VL-Embedding)
- [llama.cpp Swift Package](https://swiftpackageindex.com/ggml-org/llama.cpp)
- [swift-embeddings](https://github.com/jkrukowski/swift-embeddings)
