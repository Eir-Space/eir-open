# cbt-programs

Open-source CBT program registry for Eir Open.

This package modularizes CBT programs so they can be:

- reused across health problems,
- translated into many languages,
- audited via trust labels,
- tracked with markdown progress logs,
- consumed by CLI tools and agent skills.

## Data model

Each program lives in:

`data/programs/<program-id>/`

Required files:

- `program.json` - machine-readable metadata and trust lineage
- `locales/<lang>.json` - language-specific content
- `changelog.md` - user-facing change history
- `progress/*.md` - implementation/review logs

## Add a new language (5 steps)

1. Create `locales/<lang>.json` (example: `locales/es.json`) in the target program folder.
2. Add translation metadata to `program.json` in `translations[]`:
   `lang`, `status`, `completion`, `path`.
3. Set `status` to `draft`, `human-reviewed`, or `expert-verified`.
4. Add a markdown note in `progress/` describing translation changes.
5. Run `cbt-programs validate <program-id>`.

This keeps language work isolated, so translators can contribute without editing unrelated program metadata.

## Trust lineage

Every program has explicit booleans in `program.json.lineage`:

- `aiCreated`
- `humanCreated`
- `humanReviewed`
- `healthcareExpertVerified`

These power labels surfaced by the CLI.

## CLI

```bash
node scripts/cbt_programs.js list
node scripts/cbt_programs.js search "low mood"
node scripts/cbt_programs.js recommend --problem "difficulty sleeping"
node scripts/cbt_programs.js validate
node scripts/cbt_programs.js improve cbt-example --title "Improved title" --note "Refined module framing"
```

After global install, use:

```bash
cbt-programs list
```

## Agent integration

See `SKILL.md` for agent workflow and prompt-generation commands.

## Creating a new program

```bash
cbt-programs scaffold cbt-example \
  --title "CBT Example" \
  --condition "Example Condition" \
  --creator ai-assisted
```

Then update:

- `program.json` metadata and lineage
- locale content under `locales/`
- `progress/` markdown notes
- `changelog.md`

## Improving an existing program

```bash
cbt-programs improve cbt-example \
  --lang en \
  --dry-run \
  --program-summary "Sharper summary and outcomes" \
  --add-tags "relapse-prevention,emotion-regulation" \
  --add-problems "sleep anxiety,rumination" \
  --new-module-title "Relapse Prevention Toolkit" \
  --new-module-overview "Create a practical early-warning and response plan." \
  --mark-human-reviewed \
  --note "Expanded coverage and improved review status"
```

LLM-assisted update flow:

```bash
cbt-programs improve cbt-example \
  --llm \
  --llm-plan-file ./my-llm-plan.json \
  --goal "Improve adherence for users with night waking and add a practical relapse module" \
  --dry-run
```

In this mode, the host LLM/agent provides the plan (`--llm-plan` JSON or `--llm-plan-file`), so no additional API key is required by this CLI.

This command:

- updates `program.json` and locale content,
- bumps patch version,
- appends `changelog.md`,
- writes a markdown entry in `progress/`.

Use `--dry-run` to preview changes without writing files.
Use `--interactive` to run a guided prompt-based editing flow.

## Validate

```bash
cbt-programs validate cbt-example
```

## Import legacy YAML programs

```bash
node scripts/import_legacy_yaml.js \
  --source /Users/birger/Community/egen_journal/backend/content/programs \
  --target ./data/programs \
  --status draft
```

Use `--overwrite` to replace existing imported programs.
Migration parsing uses Python + PyYAML (`pip install PyYAML`).

## License

MIT
