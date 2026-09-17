# Tableau workbook

`Cerneva.twbx` packages a source-controlled Tableau workbook with the processed opportunity-level CSV, so it opens without database credentials. `Cerneva.twb` is retained beside it for code review.

## Dashboard structure

- Won revenue and closed-deal win-rate KPIs
- Won revenue by product
- Win rate by region
- Monthly won-revenue movement
- Open list value by pipeline stage

The executive preview in the repository root is generated from the same analytical outputs. Tableau is used for interactive slicing and the R output provides a stable GitHub preview.

## Rebuild

```bash
Rscript R/run_pipeline.R
python tableau/build_workbook.py
```

The Python builder uses only the standard library. It checks the expected schema and 8,800-row grain, generates deterministic workbook XML, parses it for structural validity and verifies the contents of the TWBX archive.

## Publishing note

Open `Cerneva.twbx` in Tableau Desktop or Tableau Public, inspect the six sheets, then publish **Commercial Command**. Tableau is proprietary desktop software and is not available in this repository's automated test environment, so the final visual publish should receive a manual desktop check.

