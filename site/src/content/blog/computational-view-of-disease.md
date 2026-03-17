---
title: "Why a Computational View of Disease Matters Now"
description: "AI is forcing medicine to confront a simple fact: many diseases are not just labels but search problems over data, time, and intervention space."
pubDate: 2025-09-29
author: Eir Open
tags:
  - AI
  - medicine
  - computation
  - disease modeling
featured: true
---

I think a lot of medical thinking still starts from the wrong unit of analysis.

We talk about disease names as if the name is the thing. Lung cancer. Lupus. Sepsis. Alzheimer's. That is useful for billing, for communication, and often for clinical workflow. But it is increasingly a bad way to think about where good outcomes come from, especially if you care about what AI can and cannot actually improve.

The practical unit is not the label. It is the search problem.

For one patient, the real problem might be: which mutation matters, which prior treatment changed the biology, which drug combination still has a plausible mechanism, which contraindications narrow the field, which trial is geographically reachable, and which decision has to happen this week rather than next month. For another patient, it might be: which variant in the exome is actually causal, which phenotype details are noise, which family-history detail changes the ranking, and which confirmatory test is worth spending money on.

That is a computational view of disease. Not "computation" in the shallow sense of dashboards or automation, but in the older sense: a hard problem made of many interacting variables, imperfect observations, and an enormous space of possible actions.

Once you look at medicine that way, a few things become obvious.

## Some diseases are much more computational than others

A sore throat is usually not a giant reasoning problem. The data is thin, the action space is narrow, and the downside of missing some obscure branch in the decision tree is often small.

Metastatic cancer is the opposite. So is rare genetic disease. So are resistant infections in complex patients. These are cases where you can drown in relevant information. Genomics, scans, pathology, medication history, progression timeline, prior failures, lab drift, comorbidities, local constraints, and a literature base that no human can keep fully in working memory.

That matters because AI is not equally useful everywhere. The phrase "AI in healthcare" hides a huge category error. The right question is not whether AI helps with medicine in general. The right question is where more inference changes the decision boundary.

If a disease area already runs on short protocols with little ambiguity, bigger models and longer context do not buy you much. If the case is a compressed search problem with many possible branches, they might matter a lot.

## More compute is not magic, but it changes the kind of work you can do

People sometimes talk about AI compute as if it only means larger training runs. In practice, inference budget matters too. If a model can inspect more records, compare more hypotheses, weigh more conflicting evidence, and spend more tokens refining a ranked list of options, it can do a different class of work.

That does not mean it becomes a doctor. It does not mean it becomes reliable by default. It does mean it can participate in tasks that look less like "answer this question" and more like "search this ugly, high-dimensional case space and tell me what is still plausible."

That is why the most interesting use cases are not generic chatbot ones. They are cases where the human team is already struggling with combinatorics.

In oncology, that can mean narrowing from hundreds of biologically relevant facts to a tractable treatment strategy. In rare disease, it can mean cutting years off a diagnostic odyssey. In ICU care, it can mean catching a pattern across notes, labs, vitals, and medications before the pattern becomes obvious to a tired team at 3 a.m.

The common theme is not the organ system. It is the shape of the reasoning problem.

## Medicine has been richer in data than in synthesis

Modern medicine does not mainly suffer from a lack of measurements. It suffers from fragmentation.

One patient can have pathology reports in one system, radiology in another, prescriptions in a third, family history buried in prose, and the clinically important detail hidden in a scanned PDF or a note that nobody reopened. In theory this is "all available." In reality it is cognitively unavailable.

That is where a computational view becomes more than a metaphor. It gives you a way to ask: how much of the difficulty here comes from biology, and how much comes from the fact that the information is too spread out for ordinary human synthesis?

AI is unusually well matched to that second problem. It can read a lot, compare a lot, and keep a lot of weak signals alive long enough to see whether they matter together.

Not always. Not perfectly. But often enough that the bottleneck has shifted.

## The bottleneck is moving from access to judgment

As models improve, the hard part is less "can we retrieve the information?" and more "do we trust the synthesis, and under what constraints?"

That is a healthier conversation. It forces people to talk about evidence quality, actionability, and whether a better ranking of possibilities can actually change the patient's outcome.

It also forces a more honest prioritization. We should not aim the biggest models at every disease uniformly. That is lazy strategy. We should aim them where:

- the search space is large,
- the data is multimodal,
- the choice is patient-specific,
- and the downstream action can still change something meaningful.

That is why a computational ranking of disease areas is useful. It is not a philosophical exercise. It is a deployment map.

## Disease categories will survive, but they will matter less on their own

I do not think diagnosis labels disappear. Clinicians still need shared language. Regulators still need categories. Patients still need a name for what is happening to them.

But the label is becoming the entry point, not the endpoint.

The future system does not stop at "this is lung cancer" or "this looks autoimmune." It asks what kind of computational object this case is. How much hidden structure is in the record. How much heterogeneity sits behind the umbrella term. How many plausible interventions exist. How much value there is in spending another thousand seconds of machine reasoning on it.

That shift matters because AI is making medicine less about static categories and more about dynamic resolution. Not every case needs that. Some absolutely do.

If we miss that distinction, we will waste enormous effort building flashy AI for the wrong problems. If we get it right, we can direct serious compute toward the parts of medicine where better synthesis genuinely changes the odds.
