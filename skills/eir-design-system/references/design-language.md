# Eir Design Language

Use this file for the visual rules behind Eir Space products.

## Brand Core

- Primary interaction color: Eir Teal `#1E94A8`
- Signature brand gradient: gold to blue
- Warm neutrals: sand palette, never cold gray
- Dark mode is the home state

## Color Roles

- `teal`: primary actions, active controls, links, focused states
- `gold`: AI actions, assistants, moments of delight, system intelligence
- `blue`: informational cards, trust markers, documentation surfaces
- `green`: health-positive states only
- `red`: critical and unsafe states only

## Canonical Gradient

```css
linear-gradient(135deg, #D4A76A 0%, #C9B88A 30%, #A8C5D4 70%, #8BB8CE 100%)
```

Use it on:

- hero accents
- product marks
- featured cards
- onboarding moments

Do not use it on:

- large text blocks
- every card border
- warning or error states

## Surfaces

- Light background: `#FAFAF7`
- Dark background: `#111110`
- Light card: white or `#F5F4F0`
- Dark card: `#1A1917` or `#252320`
- Use thin borders and soft depth before strong shadows

## Typography

- UI font: Geist Sans
- Data font: Geist Mono
- Body size floor: `16px`
- Comfortable prose width: `65ch`

Suggested hierarchy:

- Hero: `36px` to `48px`
- Section titles: `24px` to `30px`
- Card titles: `20px`
- Labels/meta: `12px` to `14px`

## Layout Rhythm

- Use the 4px spacing system
- Prefer 16px, 24px, 32px, 48px, 64px jumps
- Large sections should breathe; avoid compressed dashboards
- Keep primary reading/action column focused, not edge-to-edge

## Motion

- Instant: `50ms`
- Fast: `100ms`
- Base: `200ms`
- Slow: `300ms`

Use motion for:

- staggered card reveals
- hover lift
- active/focus state polish
- drawer or modal transitions

Avoid ornamental looping motion.
