---
name: eir-design-system
description: Build Eir Space web apps, landing pages, and agent interfaces with the official design language. Use when a user wants a beautiful Eir-branded UI, design-system-aligned frontend, reusable tokens, brand assets, or a polished visual refresh based on the Eir design guide.
---

# Eir Design System Skill

Use this skill when building or redesigning an Eir Space interface.

## Workflow

1. Read `references/design-language.md` first.
2. Read `references/app-patterns.md` when the task is a web app, dashboard, landing page, or form-heavy product.
3. Read `references/assets-map.md` when you need the exact file to copy or adapt.
4. Reuse files in `assets/web/` and `assets/brand/` instead of inventing a new visual language.

## Non-negotiables

- Use the Eir Aura gradient for branded emphasis, not as a universal page wash.
- Keep surfaces warm. Avoid sterile white and cold gray UI.
- Dark mode is the primary target; light mode should still feel intentional.
- Use teal for primary interaction, gold for AI/system intelligence, blue for trust/info, green only for health-positive semantics.
- Prefer Geist Sans for interface typography and Geist Mono for data/code.
- Keep layouts content-first: focused columns, calm depth, restrained chrome.
- Motion should be meaningful and brief. Default to 100ms to 300ms transitions.

## Starter Assets

- Raw tokens: `assets/web/eir-tokens.css`
- App shell starter: `assets/web/eir-app-shell.tsx`
- Brand aura asset: `assets/brand/eir-aura.svg`
- Rune mark asset: `assets/brand/eir-rune.svg`

## Output Checklist

- Colors match the Eir token system.
- Typography and spacing use the provided rhythm.
- Hero, cards, and forms feel part of the same system.
- Mobile layout is first-class, not a collapsed desktop.
- The result looks specific to Eir Space, not generic SaaS.
