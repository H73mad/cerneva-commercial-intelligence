# Cerneva Revenue Room

This is the product-facing layer for Cerneva. It turns the R/SQL/Tableau analysis into a believable commercial operating surface rather than a static chart sheet.

## Run it

From the repository root:

```bash
python -m http.server 8000
```

Open `http://localhost:8000/web/`.

The prototype has four connected lenses:

- **Revenue room** — the executive diagnosis and decision memo.
- **Pipeline desk** — an owned queue of evidence gaps and next moves.
- **Accounts** — product/value/cycle lenses for commercial trade-offs.
- **Forecast lab** — the rejected model, its baseline and the evidence required next.
- **Controls** — governance rules that stop weak forecasts becoming false certainty.

The numbers are intentionally aligned with the committed Cerneva outputs. The interface is a static review surface; the reproducible R pipeline and PostgreSQL model remain the source of truth.
