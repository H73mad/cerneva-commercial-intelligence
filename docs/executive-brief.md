# Cerneva executive commercial brief

**Decision question:** Where should sales leadership intervene, and how much confidence should it place in the current CRM forecast?

## What the evidence says

- **$10.01m** was won across **6,711** closed opportunities.
- The overall closed-deal win rate was **63.2%**, with a median sales cycle of **45 days**.
- The two highest-revenue products generated **61.4%** of won revenue. Commercial planning should separate premium-product value from unit volume.
- Regional win rates differed by only **1.4 percentage points**. The data does not justify declaring one region structurally superior.
- **1425** open opportunities need basic CRM fields completed before leadership can rely on pipeline reporting.

## Forecast integrity

The known-at-engagement logistic model produced a chronological holdout ROC AUC of **0.486**. Its Brier score was **0.242**, compared with **0.241** for the simple training win-rate baseline.

**Model decision:** Do not operationalise: collect stage history, activities and buyer signals first.

The CRM records who owned the opportunity, the product and the account, but not stage changes, calls, meetings, stakeholder engagement, next-step dates or buyer intent. Those missing behavioural signals are the priority data-engineering requirement; a more complex algorithm would not repair the evidence gap.

## Recommended actions

1. Work the ranked open-pipeline queue, beginning with incomplete and long-stalled opportunities.
2. Add activity history, stage-transition timestamps, buyer-role coverage and next-step dates to the CRM model.
3. Review premium-product pipeline separately because it drives revenue concentration.
4. Reassess forecast modelling only after the new signals cover at least two complete sales cycles.

## Analytical guardrail

Cerneva does not present a weak model as artificial certainty. It uses the failed holdout test as a decision: improve the underlying commercial evidence before operationalising predictive scores.
