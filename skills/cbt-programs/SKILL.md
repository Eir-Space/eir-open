---
name: cbt-programs
description: Discover, recommend, translate, and co-create open-source CBT programs for different health problems. Use when users ask for CBT program suggestions, multilingual program content, program provenance labels (AI-created/human-created/human-reviewed/healthcare-expert-verified), or want to create and publish a new CBT program in the repository.
---

# CBT Programs Skill

Use this skill for open-source CBT program operations backed by the `cbt-programs` CLI and `data/programs/` registry.

## Core capabilities

- Discover CBT programs by condition and language
- Recommend programs based on user-stated problems
- Show trust/provenance labels:
  - `AI-CREATED`
  - `HUMAN-CREATED`
  - `HUMAN-REVIEWED`
  - `EXPERT-VERIFIED`
- Scaffold new programs for user-specific needs
- Improve and edit existing programs with tracked updates
- Track updates in markdown progress logs
- Generate agent prompts for guided support sessions

## Fast workflow

1. Discover candidates:

```bash
cbt-programs list --lang en
cbt-programs search "sleep anxiety"
cbt-programs recommend --problem "difficulty sleeping" --lang en --limit 3
```

2. Inspect one program:

```bash
cbt-programs show cbt-insomnia --lang en
```

3. Validate trust/readiness:

```bash
cbt-programs validate cbt-insomnia
```

4. Create user-specific program scaffold:

```bash
cbt-programs scaffold cbt-shift-work-sleep \
  --title "CBT for Shift Work Sleep" \
  --condition "Shift Work Sleep Disturbance" \
  --creator ai-assisted
```

5. Track progress in markdown:

```bash
cbt-programs progress cbt-shift-work-sleep \
  --title "Added module drafts" \
  --summary "Drafted first two modules and updated recommendation signals"
```

6. Improve an existing program:

```bash
cbt-programs improve cbt-shift-work-sleep \
  --llm \
  --llm-plan-file ./llm-improve-plan.json \
  --goal "Improve adherence and add relapse prevention support for sleep setbacks" \
  --dry-run \
  --note "Improved content quality and review status"
```

Or use guided mode:

```bash
cbt-programs improve cbt-shift-work-sleep --interactive
```

LLM mode expects the host agent to supply the plan JSON (`--llm-plan` or `--llm-plan-file`), so no separate API call is needed by this tool.

7. Build assistant prompt for any agent system:

```bash
cbt-programs agent-prompt cbt-shift-work-sleep --lang en --goal "Prepare week 1 plan"
```

## Translation workflow

- Add a new locale file under `data/programs/<id>/locales/<lang>.json`
- Add translation metadata to `program.json.translations[]`
- Set `status` to one of: `draft`, `human-reviewed`, `expert-verified`
- Run `cbt-programs validate <id>`

## Legacy import workflow

```bash
node scripts/import_legacy_yaml.js \
  --source /Users/birger/Community/egen_journal/backend/content/programs \
  --status draft
```

Requires Python + PyYAML for parsing legacy YAML.

## Publishing rules

For `status: published`, ensure:

- At least one translation is `human-reviewed` or `expert-verified`
- `lineage` flags are truthful and complete
- Safety disclaimer exists
- `progress/` has markdown entries

Governance details: `references/governance.md`
