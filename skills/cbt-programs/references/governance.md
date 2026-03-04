# CBT Program Governance

## Trust labels

Every program exposes four trust labels via `lineage` in `program.json`:

- `aiCreated`
- `humanCreated`
- `humanReviewed`
- `healthcareExpertVerified`

A program can carry multiple labels (for example AI-created and human-reviewed).

## Translation states

Each translation entry in `translations[]` must include:

- `lang`: BCP-47 style code (e.g. `en`, `sv`, `es`)
- `status`: `source`, `draft`, `human-reviewed`, or `expert-verified`
- `completion`: integer percentage (0-100)
- `path`: path to locale file

## Minimum publishing bar

For `status: published`, program metadata should include:

- at least one translation with `status` of `human-reviewed` or `expert-verified`
- safety disclaimer text
- recommendation signals (`problems` list)
- at least one progress note in `progress/`

## Change tracking

- User-facing summary updates go in `changelog.md`
- Development and review progress goes in `progress/YYYY-MM-DD-*.md`
- Lineage flags in `program.json` must be updated whenever authorship/review state changes
