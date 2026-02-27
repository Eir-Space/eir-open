# Eir Open Documentation

Built with [Astro](https://astro.build/), [Starlight](https://starlight.astro.build/), and [shadcn/ui](https://ui.shadcn.com/) styling.

## Local development

```bash
pnpm install
pnpm dev
```

Open http://localhost:4321/eir-open/

## Build

```bash
pnpm build
```

Output goes to `dist/`. The GitHub Actions workflow builds and deploys this to GitHub Pages.

## Structure

- `src/content/docs/` — Documentation content (MDX)
- `public/projects/` — Static files (validator, skill.md, skill.json, privacy policy)
- `src/styles/global.css` — shadcn design tokens and custom styles
