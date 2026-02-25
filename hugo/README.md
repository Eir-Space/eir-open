# Eir Open Documentation

Built with [Hugo](https://gohugo.io/) and the [Geekdoc](https://github.com/thegeeklab/hugo-geekdoc) theme.

## Local development

```bash
hugo server
```

Open http://localhost:1313/eir-open/

## Build

```bash
hugo --gc --minify
```

Output goes to `public/`. The GitHub Actions workflow builds and deploys this to GitHub Pages.

## Structure

- `content/docs/` — Markdown documentation for each project
- `static/projects/` — Static files (validator, skill.md, skill.json, privacy policy)
- `static/css/custom.css` — Eir.space color overrides
- `assets/css/` — Additional theme overrides (if needed)
