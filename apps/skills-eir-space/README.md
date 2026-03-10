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

## Fly.io Hosting

This app now supports durable Postgres-backed storage on Fly.io.

### Recommended production setup

1. Provision a Fly Postgres database
2. Set `DATABASE_URL` on the app
3. Deploy the Next.js app as a normal Node service

### Included deployment files

- `apps/skills-eir-space/fly.toml`
- `apps/skills-eir-space/Dockerfile.fly`
- root `.dockerignore`

### Deploy commands

From the repo root:

```bash
flyctl apps create skills-eir-space --org personal
flyctl mpg create --name skills-eir-space-db --org personal --region arn --plan development
flyctl mpg attach skills-eir-space-db --app skills-eir-space
flyctl deploy -c apps/skills-eir-space/fly.toml
```

### Custom domain

After deploy:

```bash
flyctl certs add skills.eir.space -a skills-eir-space
flyctl certs check skills.eir.space -a skills-eir-space
flyctl certs setup skills.eir.space -a skills-eir-space
```

At runtime the store resolves in this order:

1. `DATABASE_URL` / `POSTGRES_URL` -> Postgres
2. Cloudflare D1 credentials -> D1
3. Local `data/skills.json` -> local dev fallback

### Minimal schema

The app auto-creates:

```sql
CREATE TABLE IF NOT EXISTS skill_store (
  store_key TEXT PRIMARY KEY,
  store_value JSONB NOT NULL
);
```

The current production store is still a single JSON document keyed by `main`. That is durable and
working on Fly, but not yet normalized for advanced moderation, audit trails, or analytics.

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

- Normalize the registry store beyond the single JSON document when moderation workflows grow
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
