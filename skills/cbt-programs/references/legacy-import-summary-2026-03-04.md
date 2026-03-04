# Legacy CBT YAML Import Summary

Date: 2026-03-04

## Command

```bash
node scripts/import_legacy_yaml.js \
  --source /Users/birger/Community/egen_journal/backend/content/programs \
  --target /Users/birger/Community/eir-open/skills/cbt-programs/data/programs \
  --status draft
```

## Result

- Imported: 40 programs
- Skipped: 2 programs
- Failed: 0 programs
- Total program folders after import: 42

Skipped programs (already existed):

- `cbt-depression-mood`
- `cbt-insomnia`

## Validation

Ran:

```bash
node scripts/cbt_programs.js validate
```

Result: all 42 programs validated successfully.

## Notes

- Existing curated programs were preserved because import was run without `--overwrite`.
- Imported programs were created in `draft` status with lineage marked as AI-created migration artifacts.
- Each imported program includes `program.json`, `locales/en.json`, `changelog.md`, and `progress/` entry.
