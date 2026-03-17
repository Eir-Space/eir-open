---
name: swedish-self-referral-clinics
description: Find Swedish clinics that have verified 1177 self-referral support (Egen vårdbegäran / egen remiss). Use when an agent needs to identify clinics a user can contact directly in Sweden, filter by county or municipality, match specialty or condition keywords, rank nearby options, and return 1177 profile links with evidence.
license: MIT
compatibility: Requires Node.js. CLI reads bundled JSON data and does not require network access for search.
metadata:
  author: Eir Space
  version: "1.0.0"
---

# Swedish Self-Referral Clinics

Use this skill when the user needs a Swedish clinic that accepts direct self-referral through 1177.

The bundled dataset contains only clinics with verified `Egen vårdbegäran` support from 1177. Do not claim self-referral support for clinics outside this dataset unless you verify them separately.

## Quick Start

Search by query:

```bash
node scripts/find-clinic.js --query adhd --limit 5 --format markdown
```

Filter by geography:

```bash
node scripts/find-clinic.js --county "Stockholms län" --specialty psychiatry --limit 10 --format json
```

Rank by proximity:

```bash
node scripts/find-clinic.js --query psykiatri --near 59.3293,18.0686 --radius-km 80 --limit 8 --format json
```

Exact municipality search:

```bash
node scripts/find-clinic.js --municipality Uppsala --limit 20 --format markdown
```

## What The CLI Returns

Each result includes:

- clinic name
- clinic type and specialty tags
- municipality, county, address, and coordinates when available
- phone number
- 1177 profile URL
- short summary
- verified self-referral evidence from 1177
- booking/contact signals such as `Boka tid`, `Av- eller omboka`, and other e-service actions

## Recommended Workflow

1. Start with `--query`, `--county`, `--municipality`, or `--specialty`.
2. If the user has a location, add `--near lat,lng` and optionally `--radius-km`.
3. Prefer exact municipality matches over county-wide matches.
4. Use the `self_referral.evidence` and `links.profile_1177` fields in your answer so the user can verify the clinic.
5. If multiple clinics look relevant, return a short ranked list instead of inventing certainty.

## Output Formats

- `--format json`
  - structured objects for agent pipelines
- `--format markdown`
  - compact human-readable shortlist
- `--format ndjson`
  - one JSON object per line for streaming or shell pipelines

## Safety Rules

- Treat this skill as a verified index of direct-contact clinics, not as medical advice.
- Use the clinic `summary`, `specialties`, and `tags` to narrow options, but do not diagnose.
- If no clear match exists, say that no verified self-referral clinic was found in the current filter set.
- If the user has urgent or emergency symptoms, do not rely on this skill alone.

## Install / Reuse

Codex-style local install:

```bash
mkdir -p ~/.codex/skills
cp -R swedish-self-referral-clinics ~/.codex/skills/
```

Generic agent workflow:

1. Download or clone the folder that contains `SKILL.md`.
2. Run `node scripts/find-clinic.js ...` from the skill root.
3. Read `references/decision-guide.md` when you need ranking guidance or field semantics.

## References

- `references/decision-guide.md`
  - how to rank and present clinics
- `data/self-referral-clinics-sweden.json`
  - compact verified dataset used by the CLI
