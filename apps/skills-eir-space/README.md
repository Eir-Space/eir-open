# skills.eir.space (MVP)

Minimal Next.js registry for health-focused agent skills with:
- public submissions
- badges and moderation tiers
- health.md compatibility metadata
- skill detail pages
- `find-health-skill` seeded as a catalog skill

## Local Run

```bash
cd /Users/birger/Community/eir-open/apps/skills-eir-space
npm install
npm run dev
```

Open `http://localhost:3000`.

## What Is Implemented

- Directory page with search/filter
- Hybrid moderation model UI (`community`, `verified`, `clinician_reviewed`)
- Skill detail pages
- Submission/update form
- API routes:
  - `GET /api/skills`
  - `POST /api/submit`
  - `POST /api/ingest/github` (ingest one GitHub repo)
  - `POST /api/ingest/sync` (ingest many repos)
- Local persistence in `data/skills.json` (fast MVP)

## Cloudflare Hosting (Fast Path)

This app is ready to deploy to Cloudflare as a Next.js app.

### Option A: Cloudflare Pages with Next.js support
1. Create a new Pages project connected to this repo
2. Set root directory: `apps/skills-eir-space`
3. Build command: `npm run build`
4. Output directory: `.next`
5. Add custom domain: `skills.eir.space`

### Option B: OpenNext + Cloudflare Workers (recommended for production APIs)
Use OpenNext Cloudflare adapter and move store from local JSON to Cloudflare D1 or KV.

Project files already include:
- `wrangler.jsonc`
- `open-next.config.ts`
- `npm run deploy`

Recommended Cloudflare build settings:
- Root directory: `apps/skills-eir-space`
- Build command: `npm run build`
- Deploy command: `npm run deploy`

Important:
- Do not use `npx wrangler deploy` directly as deploy command in CI.
- It may run migration prompts in non-interactive mode and generate mismatched self-bindings.

## Production TODO (Required)

- Replace file writes in `lib/skill-store.js` with Cloudflare D1/KV persistence
- Add auth for moderation actions
- Add validation worker for repo ingestion and `SKILL.md` parsing
- Add moderation dashboard

## GitHub Ingestion

Use ingestion to pull `SKILL.md` files from GitHub repos and upsert skills automatically.

### Required/optional env vars

- `EIR_INGEST_API_KEY` (recommended for route protection)
- `GITHUB_TOKEN` (optional, needed for private repos / higher rate limits)
- `EIR_REGISTRY_REPOS` (optional, comma-separated list for `/api/ingest/sync`)

### Ingest one repo

```bash
curl -X POST "https://skills.eir.space/api/ingest/github" \
  -H "content-type: application/json" \
  -H "x-ingest-key: $EIR_INGEST_API_KEY" \
  -d '{"repo":"Eir-Space/find-health-skill","ref":"main"}'
```

### Sync configured repos

```bash
curl -X POST "https://skills.eir.space/api/ingest/sync" \
  -H "content-type: application/json" \
  -H "x-ingest-key: $EIR_INGEST_API_KEY" \
  -d '{"ref":"main"}'
```

## How skills.sh / agentskill.sh Works (high-level)

- Repo-first submission model (GitHub repo URL + skill path)
- Skill discovery based on `SKILL.md` metadata
- Submission goes through analysis/security checks
- Ranking/discoverability influenced by install telemetry

This MVP keeps that repo-first model and adds health-specific trust metadata.
