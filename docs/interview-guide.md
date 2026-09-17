# Cerneva interview guide

## 30-second explanation

Cerneva is a commercial-intelligence project built on 8,800 fictional CRM opportunities. I used R to clean and join the data, created quality tests and decision-ready marts, modelled performance in PostgreSQL and prepared a Tableau dashboard. I also tested a win-probability model on later data. It did not beat the baseline, so I rejected automation and designed a transparent action queue for incomplete and stalled deals instead.

## Questions to expect

### Why did you use a chronological split?

A random split lets future and past deals mix together and can exaggerate performance. A chronological holdout better represents the real question: can a model trained on earlier deals generalise to later ones?

### Why is a failed model useful?

It prevents false confidence and identifies the data gap. The current CRM contains static account and product facts but not behaviours such as meetings, stage movement or stakeholder engagement. That is a concrete data-engineering recommendation.

### Why adjust agent win rates?

An agent with five deals can appear better than one with 200 by chance. Shrinking small samples toward the global average gives a fairer descriptive comparison, though it still does not prove that the agent caused the outcome.

### What would you build next?

I would add an append-only event table for stage transitions and sales activities, establish pipeline snapshots, define next-step completeness, and retrain only after at least two complete sales cycles. I would then monitor discrimination, calibration, drift and outcome differences across teams.

### What did you personally learn?

The strongest analytical answer is not always a prediction. Good analytics includes knowing when the evidence is too weak, explaining why, and offering an operational next step that is still useful.

