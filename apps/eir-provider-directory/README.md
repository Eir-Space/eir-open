# EIR Provider Directory

Swedish healthcare provider discovery app for EIR Open.

This app combines:

- fast map + list discovery
- verified service capabilities from 1177 provider pages (for example self-referral)
- Cloudflare-native production infrastructure (Workers + D1 + R2)

## Monorepo location

`apps/eir-provider-directory`

Canonical source path:

- [Eir-Space/eir-open/apps/eir-provider-directory](https://github.com/Eir-Space/eir-open/tree/main/apps/eir-provider-directory)

## What the app provides

- Nationwide provider search across Swedish clinics and care units
- Map and list views with tuned clustering and high-density browsing
- "My Position" location centering for nearby care
- Digital-only clinics panel (separated from clinics with physical addresses)
- Verified self-referral indicator based on 1177 e-service signals
- Live provider detail enrichment from 1177 contact card structure
- API endpoints for providers, filtered queries, and text search

## Runtime architecture

### Frontend

- `pages/index.jsx` is the main UX shell
- `components/ProviderMap.jsx` handles map rendering and interaction
- `components/ProviderList.jsx` handles list rendering and provider selection

### API and data flow

- `/api/providers` and `/api/search` prefer D1 when bound
- If D1 is unavailable, dataset loading falls back to JSON snapshots
- Dataset loader order in runtime:

1. local filesystem (`public/data/*.json`)
2. R2 (`providers/*.json`)
3. Workers assets (`/data/*.json`)

### Cloudflare resources

Defined in [`wrangler.jsonc`](./wrangler.jsonc):

- D1 database: `eir-provider-db`
- R2 bucket: `eir-provider-data`
- Worker service: `eir-provider-directory`

## Local development

```bash
cd apps/eir-provider-directory
npm install
npm run dev
```

App runs at `http://localhost:3000`.

## Data model and enrichment

Primary local snapshots:

- `public/data/providers-sweden.json`
- `public/data/providers-sweden-verified.json`
- `public/data/agent/self-referral-clinics-sweden.json`
  - compact agent-facing index of clinics with verified `Egen vårdbegäran`
  - includes location, 1177 profile URL, short description, tags, booking/contact signals, and self-referral evidence
  - per-clinic keys: `name`, `type`, `specialties`, `tags`, `location`, `contact`, `links`, `self_referral`, `access`, `summary`

Agent export generation:

- `npm run build:agent-self-referral`
  - reads `providers-sweden-verified.json`
  - keeps only clinics with `services.self_referral_verified === true`
  - writes a compact JSON file intended for AI-agent skill use

1177 enrichment scripts:

- `npm run verify:self-referral`
  - verifies self-referral support from 1177 pages
  - writes `providers-sweden-verified.json`
- `npm run enrich:1177`
  - extracts broader 1177 capabilities and profile details
  - updates provider actions/e-services metadata

Notes:

- scripts include retry/backoff and concurrency controls
- heavy scraping can trigger upstream rate limiting; use lower concurrency and delays when needed

## D1 and R2 setup

```bash
cd apps/eir-provider-directory

# one-time
npm run d1:create
npm run r2:create-bucket

# schema + import
npm run d1:migrate
npm run d1:import:verified

# optional: upload snapshots to R2
npm run r2:upload:all
```

## Deploy

```bash
cd apps/eir-provider-directory
npm run deploy:cloudflare
```

## URL shortcuts

The app supports URL bootstrapping for verified self-referral specialists:

- `?self_referral_verified=true`
- `?self_referral_specialists=true`
- `?shortcut=self-referral-specialists`

## API endpoints

- `GET /api/providers`
  - supports `type`, `specialty`, `self_referral`, `location`, `lat`, `lng`, `radius`, `limit`, `offset`
- `GET /api/search?q=<query>&limit=<n>`
- `GET /api/provider-description?url=<1177-url>&allow_live=true`

## Tests and verification

```bash
cd apps/eir-provider-directory
npm test
npm run build
```

## Project structure

```text
apps/eir-provider-directory/
  components/      UI components
  lib/             filtering, capabilities, data access, parser logic
  pages/           Next/Vinext pages + API routes
  public/data/     provider snapshots
  scripts/         enrichment/import workflows
  tests/           Vitest suites
  worker/          Cloudflare worker entry/runtime bindings
```

## License

MIT
