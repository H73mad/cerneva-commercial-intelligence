# Data provenance and handling

## Source

The raw files reproduce the **CRM Sales Opportunities** practice dataset published through [Maven Analytics Data Playground](https://mavenanalytics.io/data-playground). The scenario is fictional: a computer-hardware company records its sales pipeline, products, accounts and sales teams.

The files were retrieved from a public GitHub mirror of the Maven dataset because the Data Playground download is delivered interactively. The original Maven field dictionary is retained as `raw/data_dictionary.csv`.

## Raw tables

| File | Rows | Grain |
|---|---:|---|
| `sales_pipeline.csv` | 8,800 | One sales opportunity |
| `accounts.csv` | 85 | One named account |
| `sales_teams.csv` | 35 | One sales agent |
| `products.csv` | 7 | One product |
| `data_dictionary.csv` | 21 | One source field definition |

## Reproducible corrections

The R pipeline preserves source values and applies only documented standardisation:

- `GTXPro` is aligned to the product dimension value `GTX Pro`.
- Blank account names become `Unknown`; they are not assigned to an invented company.
- Sector labels are lower-cased and the source typo `technolgy` becomes `technology`.
- Missing enrichment stays missing or `Unknown` and contributes to the pipeline-completeness score.

## Processed outputs

- `processed/cerneva_deal_detail.csv` is the Tableau-ready opportunity grain.
- `processed/cerneva_action_queue.csv` contains only open Prospecting or Engaging opportunities, with transparent priority components.
- `processed/run_summary.csv` exposes headline results for tests and documentation.

## Rights

The MIT licence in this repository applies to the project code, not the third-party dataset. The data remains attributable to its original publisher and is included solely to make the educational analysis reproducible.

