# @eir-space/skills

CLI for the `skills.eir.space` health skill registry.

## Usage

```bash
npx @eir-space/skills help
```

### Search

```bash
npx @eir-space/skills search pregnancy
```

### Add

```bash
npx @eir-space/skills add eir-space/pregnancy
npx @eir-space/skills add eir-space/pregnancy --clone
```

### Submit / Update

```bash
npx @eir-space/skills submit \
  --name pregnancy \
  --repo https://github.com/Eir-Space/pregnancy \
  --path pregnancy/ \
  --summary "Pregnancy grounding + pregnancy.md" \
  --tags pregnancy,prenatal-care \
  --health-md \
  --creates-linked-file \
  --linked-files pregnancy.md

npx @eir-space/skills update \
  --name pregnancy \
  --repo https://github.com/Eir-Space/pregnancy \
  --path pregnancy/ \
  --summary "Updated pregnancy grounding reference"
```

## API Override

Point the CLI to a non-production API:

```bash
npx @eir-space/skills search diabetes --api http://localhost:3000
```

Or set:

```bash
export EIR_SKILLS_API=http://localhost:3000
```
