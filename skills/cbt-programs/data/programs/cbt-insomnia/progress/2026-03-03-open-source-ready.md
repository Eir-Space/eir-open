# Open-source readiness

Date: 2026-03-03
Program: cbt-insomnia
Author: Human protocol team

## What changed

- Converted protocol into modular program package with locale files.
- Added explicit lineage and expert verification status.
- Added recommendation signals for matching by symptoms.

## Why this change

Open publication needs standard metadata and predictable structure so agents can consume it safely.

## Validation

- [x] Metadata validated with `cbt-programs validate`
- [x] Human review and expert verification metadata present
- [x] Safety disclaimer present in metadata

## Next steps

- Add Swedish translation.
- Add per-module contraindication notes.
