# PostgreSQL layer

`01_schema.sql` creates staging tables, a compact star schema, integrity constraints, indexes and reusable analytical views. `02_analysis.sql` contains nine portfolio queries covering KPIs, revenue concentration, territory comparison, adjusted agent performance, rolling trends, percentiles, an action queue and an executable quality gate.

## Local run

```bash
createdb cerneva
psql -d cerneva -f sql/01_schema.sql
```

Before the dimensional `INSERT` statements run, load the four source CSVs into their matching staging tables. Example `\copy` commands are included in `01_schema.sql`; paths are resolved by the `psql` client.

The R pipeline is the canonical reproducible implementation in this repository. The SQL layer shows how the same decision logic would be deployed in PostgreSQL for BI consumption.

