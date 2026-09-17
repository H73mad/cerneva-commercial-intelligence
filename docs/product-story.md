# Cerneva product story

## The person in the room

Maya Khan is the Chief Revenue Officer at Ellery Systems. Her leadership meeting does not need another dashboard that says the pipeline is large. It needs a defensible answer to three questions:

1. Which part of the open book has enough evidence to discuss as a commitment?
2. Which records need a manager conversation this week?
3. What must the CRM capture before a forecast model can be trusted?

## The tension

The historical book looks healthy: $10.01m won, a 63.2% closed-deal win rate and a 45-day median cycle. Yet the open book contains 2,089 opportunities and 1,425 of them need basic context before a manager can explain the next move. A model trained on owner, product, region and account fields cannot see buyer motion; its chronological holdout AUC is 0.486, below a useful ranking.

## The product response

```text
Revenue room → pipeline desk → account lens → forecast lab → controls
```

- **Revenue room** gives the executive diagnosis.
- **Pipeline desk** turns incomplete and stalled records into an owned queue.
- **Account lens** separates value, volume and cycle time.
- **Forecast lab** shows the failed model beside its baseline instead of hiding it.
- **Controls** records the rule that keeps weak evidence out of operational forecasting.

## Why it is credible

- The result is grounded in a reproducible R pipeline, PostgreSQL model and Tableau workbook.
- The model is evaluated chronologically, not on a random split that leaks future behaviour.
- Recommendations are explicit and human-owned.
- The dataset is fictional and labelled as such; the project demonstrates method, not customer adoption.

## Success criteria

The project succeeds if a revenue leader can choose a review queue in under five minutes, explain why the forecast is not yet automated, and name the next data fields required for a stronger experiment.
