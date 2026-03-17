# Decision Guide

Use this file when several clinics match and you need to rank or explain them.

## Ranking Order

1. Exact municipality match
2. County match
3. Specialty match
4. Query match in clinic name
5. Query match in tags or summary
6. Distance, if `--near` is available

## Trust Rules

- Every clinic in this dataset has verified 1177 self-referral support.
- Prefer linking directly to `links.profile_1177` in your answer.
- Use `self_referral.evidence` when you need to justify why a clinic is included.

## Presentation Guidance

- Return 3 to 5 clinics unless the user asked for more.
- Include county and municipality so the user can orient quickly.
- If a clinic lacks coordinates, do not imply it is near the user.
- If a clinic lacks a strong specialty match but still appears, state that clearly.

## Useful Fields

- `tags`
  - type, specialty, and action-derived search tags
- `summary`
  - compressed clinic description
- `access.booking_actions`
  - signals whether the clinic supports online booking, rescheduling, or contact flows
- `self_referral.actions`
  - names of the verified self-referral actions
- `self_referral.evidence`
  - short 1177-backed excerpts
