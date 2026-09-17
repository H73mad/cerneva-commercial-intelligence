<p align="center">
  <img src="assets/cerneva-lockup.svg" width="620" alt="Cerneva Commercial Intelligence">
</p>

<p align="center"><strong>See the deal behind the pipeline.</strong></p>

Cerneva is a decision-first commercial intelligence project built from a fictional B2B CRM. It uses R, SQL, statistics and Tableau-ready outputs to answer a practical question: **where should sales leadership intervene, and how much confidence should it place in the current forecast?**

![Cerneva executive preview](outputs/figures/cerneva_executive_preview.png)

## The decision, not just the dashboard

| Evidence | Result | Commercial implication |
|---|---:|---|
| Won revenue | **$10.01m** | Premium product lines require separate value planning |
| Closed-deal win rate | **63.2%** | A useful baseline, not a personalised probability |
| Median sales cycle | **45 days** | Stalled Engaging deals need a defined review threshold |
| Open opportunities | **2,089** | A ranked action queue is more useful than another KPI tile |
| Chronological holdout AUC | **0.486** | Current CRM fields do not support automated win prediction |
| Model Brier score vs baseline | **0.242 vs 0.241** | The model is rejected rather than presented as false certainty |

The most important finding is negative: owner, product, region and basic account attributes do not predict outcomes better than the historical win rate. Cerneva therefore recommends collecting stage history, sales activities, stakeholder coverage and buyer-intent signals before a forecast model is operationalised.

## What this project demonstrates

- **R:** reproducible ingestion, cleaning, joins, feature engineering, grouped analysis, visualisation and logistic regression using base R
- **Statistics:** chronological validation, ROC AUC, Brier score, log loss, calibration and empirical-Bayes shrinkage for fair agent comparisons
- **Tableau:** a packaged workbook, calculated KPIs, executive dashboard design and decision-oriented storytelling
- **SQL:** PostgreSQL staging, dimensional modelling, CTEs, window functions, percentiles and data-quality controls
- **Commercial thinking:** pipeline hygiene, territory analysis, product mix, sales-cycle analysis and action prioritisation
- **Governance:** automated tests and an explicit rule that prevents a weak model from reaching operations

## Architecture

```mermaid
flowchart LR
    A[CRM exports] --> B[R quality pipeline]
    B --> C[Analytical marts]
    C --> D[Tableau workbook]
    C --> E[Forecast diagnostic]
    E --> F{Evidence strong?}
    F -- No --> G[Human action queue]
    F -- Yes --> H[Monitored pilot]
```

## Repository map

| Path | Purpose |
|---|---|
| `R/run_pipeline.R` | Complete, dependency-free R analysis pipeline |
| `tests/run_tests.R` | Executable output and business-rule tests |
| `sql/` | PostgreSQL model and portfolio analysis queries |
| `tableau/Cerneva.twbx` | Packaged Tableau workbook with its CSV data |
| `data/raw/` | Original CRM source tables |
| `data/processed/` | Tableau-ready deal grain and action queue |
| `outputs/tables/` | Auditable summaries, diagnostics and model evidence |
| `docs/executive-brief.md` | One-page recommendation for sales leadership |
| `docs/methodology.md` | Assumptions, validation design and limitations |

## Reproduce the analysis

The analytical pipeline deliberately uses base R so it can run without package installation.

```bash
Rscript R/run_pipeline.R
Rscript tests/run_tests.R
python tableau/build_workbook.py
```

The Tableau builder packages `Cerneva.twb` and the processed deal file into `Cerneva.twbx`. Tableau Desktop or Tableau Public is still required to open and publish the workbook.

## Data

The source is the public **CRM Sales Opportunities** practice dataset from [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground). It represents a fictional computer-hardware sales organisation and contains 8,800 opportunities across products, accounts, agents and regions. See [data/README.md](data/README.md) for provenance and field-level notes.

## Limits

- The dataset is fictional and covers one historical period.
- It has no activity log, stage-transition history, decision-maker coverage, competitor detail or buyer-intent signal.
- The model is diagnostic, not causal, and is intentionally not operationalised.
- The Tableau package is source-controlled and structurally validated here; final pixel-level publishing requires Tableau Desktop/Public.

## Interview version

> I built Cerneva to test whether a CRM could support reliable win forecasting. I created a reproducible R pipeline and SQL analytical layer, then evaluated a logistic model on a chronological holdout. It performed worse than the historical-rate baseline, so I did not disguise that result. I converted the project into a governed commercial action system: it ranks incomplete or stalled pipeline records, explains product and territory performance, and specifies the behavioural data needed before predictive scoring would be trustworthy.

