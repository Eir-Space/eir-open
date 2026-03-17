---
name: health-actions
description: Suggest brief, context-aware health actions when a user wants to improve sleep, stress, movement, routines, recovery, or general wellbeing. Use when the user asks what to do next, feels stuck, or shares health context and would benefit from 2-5 specific actions instead of broad advice.
---

# Health Actions

Suggest short, practical health actions that fit the user's current context.

Use this skill when the user expresses a goal like "I want to sleep better", "I need to manage stress", "I should move more", or "what can I do today?".

## Core behavior

- Default to `3` actions unless the user asks for a longer list.
- Keep each action small enough to do today. Aim for `5-15 minutes` per action.
- Personalize using available context: `health.md`, journal notes, symptoms, routines, energy, constraints, medications, environment, and stated goals.
- Prefer practical actions with low setup cost.
- Explain why each action fits this user, not just why it is healthy in general.
- If the user has red-flag symptoms, acute deterioration, self-harm risk, or another urgent safety concern, do not pivot into a routine action list. Surface appropriate urgent follow-up instead.

## Response pattern

For each action, include:

- A short title
- One concise description
- Estimated time
- Why it fits this user
- Clear steps
- An optional tip when useful

## Action quality bar

- Be specific: "Walk outside for 10 minutes after lunch" is better than "exercise more".
- Be realistic: match the user's energy, mobility, schedule, and current situation.
- Be additive, not moralizing.
- Avoid making diagnostic claims.
- Avoid suggesting medication changes unless the user is explicitly following a clinician plan already described in context.

## References

Read `references/action-principles.md` when you need categories, action patterns, or additional guardrails for shaping the list.
