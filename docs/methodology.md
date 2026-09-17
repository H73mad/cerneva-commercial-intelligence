# Methodology

## Decision frame

Cerneva separates three questions that are often mixed together:

1. **What happened?** Revenue, win rate, cycle time and product/territory performance.
2. **Where should a person act?** Missing CRM fields, stalled opportunities and high-value open pipeline.
3. **Can an outcome be predicted responsibly?** A chronological out-of-sample test, not in-sample accuracy.

## Data model

The pipeline treats `sales_pipeline` as the opportunity fact and enriches it from product, account and sales-team dimensions. The output remains at one row per opportunity to avoid accidental double-counting in Tableau.

Seven controls stop the run if identifiers, stages, dates, values or required dimension joins are invalid. The control results are published in `outputs/tables/data_quality_checks.csv`.

## Fair performance comparison

Raw sales-agent win rates are unstable when agents have different sample sizes. Cerneva reports an empirical-Bayes adjusted rate:

\[
\text{Adjusted rate} = \frac{\text{wins} + 30 \times \text{global rate}}{\text{closed deals} + 30}
\]

This shrinks small samples toward the organisation-wide result while allowing agents with more evidence to retain more of their observed rate. It is a comparison aid, not proof of an individual agent's causal impact.

## Forecast diagnostic

Only variables known at engagement are allowed: region, product list price, account revenue and employee count. Outcome-derived fields such as close value, close date, discount and sales-cycle duration are excluded to prevent leakage.

Closed opportunities are ordered by engagement date. The earliest 80% form the training set and the latest 20% form the test set, using a date boundary so identical dates are never split between sets.

The logistic model is compared with the training-period win-rate baseline using:

- ROC AUC for ranking discrimination
- Brier score for probability error
- log loss for confident probability errors
- calibration bands for predicted versus observed outcomes

Operationalisation requires both a holdout AUC of at least 0.60 and a Brier improvement greater than 0.005. The actual model does not meet either condition.

## Action priority

The open-opportunity score is deliberately interpretable:

- 45%: missing record completeness
- 35%: staleness, capped at 90 days
- 20%: product list-value percentile

The score routes attention; it does not claim to estimate win probability. Users can inspect every component and the recommended action.

## Limitations

The dataset lacks stage histories, activities, contacts, buyer roles and a clear extract timestamp. For open opportunities, the analysis date is set to one day after the latest date found in the source. The model findings should not be generalised beyond this scenario.

