---
title: "Why a Computational View of Disease Matters Now"
description: "AI is changing medicine because more and more diseases are best understood as hard search problems over personal data, time, and treatment options."
pubDate: 2025-09-29
author: Eir Open
tags:
  - AI
  - medicine
  - computation
  - patient empowerment
featured: true
---

The biggest shift in medicine over the next decade may not be a new drug class or a new device. It may be a new way of seeing the problem.

For a long time, medicine has treated disease labels as the main unit of understanding. Cancer. Lupus. Epilepsy. Heart failure. Those labels matter. They give clinicians a common language. They shape guidelines. They help patients name what is happening to them.

But the label is often just the doorway.

What matters next, especially in the age of AI, is often computational. A patient is not just "a cancer case" or "an autoimmune case." A patient is a large, messy, time-dependent reasoning problem. Their records live across systems. Their biology changes over time. Their treatment history matters. The difference between a good next step and a bad one may depend on an interaction between labs, imaging, pathology, prior failures, family history, side effects, and constraints that never make it into the neat diagnostic label.

If you think of disease only as a category, you build static systems. If you think of disease as a search problem, you build systems that can actually reason.

## Some medical problems are fundamentally compute-hungry

Not every case needs a large reasoning budget.

A simple sore throat usually does not. A routine urinary infection often does not. Many medical decisions are still best handled by short protocols and straightforward pattern recognition.

But some problems are different. They expand the moment you touch them.

Metastatic cancer can involve genomics, scans, pathology, treatment sequencing, resistance mechanisms, and trial matching. Rare genetic disease can require stitching together phenotype notes, family pedigrees, prior negative tests, and variant interpretation. Drug-resistant infection can depend on organism identity, resistance genes, prior exposure, host factors, and local treatment constraints.

These are not just "hard cases." They are cases where more synthesis can change the answer in a way the patient can feel.

That is the key distinction. The value of AI is not that it makes every medical interaction feel futuristic. The value is that, in the right disease classes, more compute can meaningfully reduce uncertainty, surface overlooked options, and help people reason through branches that would otherwise remain invisible.

This is why we built the [AI compute disease ranking](/docs/ai-compute-disease-ranking/): to make that distinction explicit. Some diseases are much more likely than others to benefit from large-context reasoning and higher inference budgets. That is not hype. It is triage.

The longer argument now lives in the white paper [A Computational View of Medicine](/docs/computational-view-of-medicine/), which lays out the evidence for why some disease classes are fundamentally more compute-sensitive than others.

## The future patient will not just carry records. They will carry leverage.

This is the part I think many people still underestimate.

Once patients have access to their own structured data, the center of gravity starts to move. A patient with their labs, imaging reports, medication history, pathology, wearable signals, discharge notes, and family history is no longer limited to whatever can be reconstructed in a rushed appointment from memory. They can bring the full case with them. More than that, they can run serious reasoning on top of it.

That changes the balance.

Today, the typical patient experience is shaped by fragmentation. One system has the scan. Another has the prescription history. A specialist has one interpretation. A generalist has another. The patient, who is the one person present for the entire timeline, often has the least effective tooling.

That is backwards, and people feel it every day.

In the future, patients will increasingly be able to take their own data, run it through AI systems with large reasoning budgets, and ask better questions before, during, and after clinical encounters. Not "diagnose me from scratch" in some naive way. Something much more powerful than that:

- summarize the true timeline of this illness,
- identify the missing pieces in the record,
- surface the highest-value hypotheses,
- rank the most important next tests or specialist questions,
- explain tradeoffs between options,
- and keep track of how the case changes over time.

That does not replace clinicians. It changes the quality of the interaction between patient and clinician.

The patient arrives less helpless. Less dependent on memory. Less dependent on whether the right sentence was said in the right ten-minute window. They arrive with a working model of their own case.

That is empowering in a real sense, not in the fake self-help sense. It gives people more capacity to participate in the reasoning around their own body.

## Compute will become part of personal health infrastructure

We already accept that storage matters. We already accept that access matters. Soon it will be obvious that compute matters too.

If two patients have the same raw records, but one can only glance through PDFs while the other can run deep synthesis over years of data, literature, prior outcomes, and differential possibilities, those two patients do not have the same practical access to care. One of them has a much stronger ability to convert information into action.

That is the next frontier: not just data portability, but reasoning portability.

A future personal health stack should let someone:

- collect their own records in an interoperable format,
- preserve a longitudinal view of symptoms, treatments, and responses,
- run high-context AI over the full timeline,
- compare changing hypotheses over time,
- and carry those outputs into clinical care.

Once that exists, compute stops being an abstract infrastructure story and becomes something intimate. A patient with enough context and enough inference can ask better questions, catch contradictions earlier, notice patterns sooner, and push harder for the right referral or follow-up.

That will matter most in exactly the disease areas where the reasoning burden is highest.

## The real opportunity is not automation. It is asymmetry reduction.

Medicine is full of asymmetries.

The system knows more than the patient. The specialist knows more than the generalist. The academic center knows more than the local clinic. The patient has lived inside the case the longest but often has the weakest tools to assemble it.

AI will not erase those asymmetries completely. But it can narrow some of them.

A patient with strong personal data access and strong compute can begin to close the gap between "I have pieces of my story" and "I can reason across the whole story." That is a profound shift. It means difficult cases no longer depend entirely on whether the institution around you is unusually organized, unusually well-resourced, or unusually curious.

That is why a computational view of disease is not just a research lens. It is also a patient-rights lens.

If the core challenge in many serious diseases is synthesis, then access to synthesis matters. If synthesis can be improved with compute, then access to compute matters too.

## We should build for the patient who has the full timeline

I think the systems that win here will assume the patient is not a passive recipient of medical output. They will assume the patient is a participant in an ongoing reasoning process.

That means building tools that respect the full complexity of the case. Tools that can absorb years of records without collapsing into generic advice. Tools that can show their work. Tools that can distinguish between strong evidence, weak evidence, missing evidence, and open questions. Tools that help someone prepare for an oncology consult, a genetics workup, an autoimmune evaluation, or a treatment-resistance discussion with more clarity than they had the day before.

And it means being honest about where this matters most. We should not spread compute evenly across all of medicine just because we can. We should aim it where more reasoning has the best chance of changing the outcome.

That is the point of taking a computational view seriously.

It helps us see that the future of medicine is not just better models. It is better leverage for the people living inside the case.
