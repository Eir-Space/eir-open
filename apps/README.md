# EIR Open Apps

Application modules that ship product experiences for EIR Open.

## Apps in this repository

### [`apps/eir-open-apps/`](./eir-open-apps/)

User-facing record apps (macOS, iOS, Chrome extension) for working with 1177 journal exports in the EIR format.

### [`apps/eir-provider-directory/`](./eir-provider-directory/)

Production-grade provider discovery app for Swedish healthcare with:

- interactive map and list views
- verified self-referral and e-service capabilities from 1177
- Cloudflare Workers + D1 + R2 deployment
- API endpoints for provider search and filtering

### [`apps/skills-eir-space/`](./skills-eir-space/)

Web app for browsing and generating EIR-related skills and workflows.

### [`apps/skills-eir-cli/`](./skills-eir-cli/)

CLI-focused tooling and packaging for EIR skills development.

## Quick start (provider directory)

```bash
cd apps/eir-provider-directory
npm install
npm run dev
```

Open `http://localhost:3000`.
