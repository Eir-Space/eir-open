---
name: buy-medication
description: Help users find over-the-counter medications they can buy on Apotea, match Apotea products to real Swedish medications via the swedish-medications skill, and compare suitable options without giving prescription, diagnosis, or emergency-care advice. Use when users ask what medicine to buy, which Apotea medication fits a symptom, or whether a product on Apotea is a real medication.
---

# Buy Medication

## Overview

This skill narrows medication buying to Swedish OTC products that are actually listed on Apotea and can be matched to the local `swedish-medications` data. Use it for shopping help, not for diagnosis, emergencies, or prescription treatment choices.

## Dependency

This skill depends on `swedish-medications`.

Do not use `buy-medication` as a standalone source of medication truth. It relies on `swedish-medications` to:
- confirm that an Apotea product maps to a real Swedish medication
- provide what the medication is for
- provide active substance, OTC vs prescription status, dosing basics, and warnings

If `swedish-medications` is unavailable, say that the medication verification step is missing and avoid making confident medication recommendations.

## Workflow

### 1. Triage before suggesting products

Do not recommend a product first. Start by checking whether the request is appropriate for OTC self-care.

Escalate instead of suggesting medication when the user mentions:
- chest pain, breathing trouble, stroke symptoms, severe allergic reaction, seizures, overdose, suicidal intent
- pregnancy, breastfeeding, infants, major chronic disease, cancer treatment, anticoagulants, or complicated polypharmacy
- symptoms that are severe, rapidly worsening, recurrent without explanation, or red-flagged by 1177/FASS
- prescription-only treatment, antibiotics, ADHD medication, antidepressants, or controlled substances

If the case is not clearly suitable for OTC self-care, say that directly and recommend pharmacist, 1177, or urgent care depending on severity.

### 2. Gather the minimum decision context

If the user is asking what to buy, ask only for the details needed to avoid a bad suggestion:
- main symptom and how long it has lasted
- age, and whether the medicine is for the user or someone else
- pregnancy or breastfeeding if relevant
- important conditions, allergies, and current medications
- preferred dosage form if that matters, such as tablet, nasal spray, cream, drops

### 3. Confirm the medication is real

Always use the `swedish-medications` skill before trusting an Apotea product as a medication. This is a required dependency, not an optional check.

Preferred checks:
```bash
node /Users/birger/Community/eir-open/skills/swedish-medications/scripts/fass_lookup.js "alvedon"
node /Users/birger/Community/eir-open/skills/swedish-medications/scripts/fass_lookup.js "omeprazol"
```

Use the lookup to confirm:
- active substance
- OTC vs prescription status
- dosing basics
- key warnings or interactions

### 4. Confirm it is available on Apotea

Apotea availability is time-sensitive. Prefer the live scraper when the user wants current availability.

Refresh the catalog:
```bash
node /Users/birger/Community/eir-open/skills/buy-medication/scripts/scrape_apotea_otc_medications.cjs
```

The scraper:
- pulls Apotea's live sitemap
- keeps OTC-like candidates only
- verifies each product page still has a medication classification
- matches the product back to `swedish-medications`
- writes a fresh snapshot to `references/apotea-otc-medications.json` and `.md`

If you do not need a fresh scrape, read:
- `references/apotea-otc-medications.md` for a quick summary
- `references/apotea-otc-medications.json` for exact product rows

The current snapshot was generated from live Apotea pages and includes 465 matched product pages across 169 unique medications.

### 5. Recommend narrowly and concretely

When the case is appropriate for OTC self-care, give a short comparison instead of a single overconfident answer.

Good output shape:
1. State the likely OTC category that fits the symptom.
2. List 2-4 Apotea options that are real medications.
3. Include active substance, dosage form, and a short reason each might fit.
4. Add the most relevant warning or exclusion.
5. Link or name the exact Apotea product when possible.

Prefer substance-first reasoning. Example:
- "For short-term heartburn, omeprazole options and alginate/antacid options solve different problems."
- "For allergy symptoms, loratadine and cetirizine are both real antihistamines, but drowsiness risk differs."

### 6. Keep medical claims tight

Do not:
- diagnose
- claim a medication is definitely safe for the user
- recommend combining medicines without checking warnings first
- tell the user to buy prescription medications
- present supplements, medical devices, or cosmetics as medications

Do:
- distinguish symptom relief from disease treatment
- mention when pharmacist advice is the right next step
- say when the request goes beyond OTC self-care

## Common Requests

### "What should I buy on Apotea for pollen allergy?"

Use the live catalog or snapshot to find Apotea-listed antihistamines and eye/nasal allergy medications, then validate them with `swedish-medications`. Compare by substance and sedation risk.

### "Is this Apotea product a real medication?"

Check the product name against `swedish-medications`, then confirm the Apotea page classification is a medication in the snapshot or by re-running the scraper.

### "What is the cheapest effective option?"

Stay within a single OTC indication and compare a few verified medications by active substance, form, pack size, and current Apotea price if available in the live scrape.

## References

- `scripts/scrape_apotea_otc_medications.cjs`: live Apotea scraper and matcher
- `references/apotea-otc-medications.md`: generated medication summary
- `references/apotea-otc-medications.json`: generated structured product catalog
