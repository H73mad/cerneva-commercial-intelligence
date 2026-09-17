-- Cerneva PostgreSQL analytical layer
-- Run from the repository root with psql. Load the four raw CSV files into
-- the staging tables before executing the dimensional INSERT statements.

BEGIN;

DROP SCHEMA IF EXISTS cerneva CASCADE;
CREATE SCHEMA cerneva;
SET search_path TO cerneva, public;

CREATE TABLE stg_accounts (
    account             text,
    sector              text,
    year_established    integer,
    revenue             numeric(14, 2),
    employees           integer,
    office_location     text,
    subsidiary_of       text
);

CREATE TABLE stg_products (
    product             text,
    series              text,
    sales_price         numeric(12, 2)
);

CREATE TABLE stg_sales_pipeline (
    opportunity_id      text,
    sales_agent         text,
    product             text,
    account             text,
    deal_stage          text,
    engage_date         date,
    close_date          date,
    close_value         numeric(12, 2)
);

CREATE TABLE stg_sales_teams (
    sales_agent         text,
    manager             text,
    regional_office     text
);

-- psql examples (remove the leading comment markers when running locally):
-- \copy cerneva.stg_accounts FROM 'data/raw/accounts.csv' CSV HEADER;
-- \copy cerneva.stg_products FROM 'data/raw/products.csv' CSV HEADER;
-- \copy cerneva.stg_sales_pipeline FROM 'data/raw/sales_pipeline.csv' CSV HEADER;
-- \copy cerneva.stg_sales_teams FROM 'data/raw/sales_teams.csv' CSV HEADER;

CREATE TABLE dim_account (
    account_key         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    account_name        text NOT NULL UNIQUE,
    sector              text NOT NULL,
    year_established    integer,
    revenue_m           numeric(14, 2),
    employees           integer,
    office_location     text,
    subsidiary_of       text,
    CONSTRAINT account_year_reasonable
        CHECK (year_established IS NULL OR year_established BETWEEN 1800 AND 2100),
    CONSTRAINT account_revenue_nonnegative
        CHECK (revenue_m IS NULL OR revenue_m >= 0),
    CONSTRAINT account_employees_nonnegative
        CHECK (employees IS NULL OR employees >= 0)
);

CREATE TABLE dim_product (
    product_key         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    product_name        text NOT NULL UNIQUE,
    series              text NOT NULL,
    list_price          numeric(12, 2) NOT NULL CHECK (list_price > 0)
);

CREATE TABLE dim_sales_agent (
    agent_key           bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    agent_name          text NOT NULL UNIQUE,
    manager_name        text NOT NULL,
    regional_office     text NOT NULL
);

CREATE TABLE fact_opportunity (
    opportunity_id      text PRIMARY KEY,
    agent_key           bigint NOT NULL REFERENCES dim_sales_agent(agent_key),
    product_key         bigint NOT NULL REFERENCES dim_product(product_key),
    account_key         bigint REFERENCES dim_account(account_key),
    account_label       text NOT NULL,
    deal_stage          text NOT NULL,
    engage_date         date,
    close_date          date,
    close_value         numeric(12, 2),
    CONSTRAINT stage_valid CHECK (deal_stage IN ('Prospecting', 'Engaging', 'Won', 'Lost')),
    CONSTRAINT close_after_engage CHECK (
        close_date IS NULL OR engage_date IS NULL OR close_date >= engage_date
    ),
    CONSTRAINT won_has_value CHECK (
        deal_stage <> 'Won' OR (close_value IS NOT NULL AND close_value > 0)
    ),
    CONSTRAINT closed_has_date CHECK (
        deal_stage NOT IN ('Won', 'Lost') OR close_date IS NOT NULL
    )
);

CREATE INDEX ix_fact_stage ON fact_opportunity (deal_stage);
CREATE INDEX ix_fact_close_date ON fact_opportunity (close_date);
CREATE INDEX ix_fact_agent ON fact_opportunity (agent_key);
CREATE INDEX ix_fact_product ON fact_opportunity (product_key);

INSERT INTO dim_account (
    account_name, sector, year_established, revenue_m, employees,
    office_location, subsidiary_of
)
SELECT
    trim(account),
    CASE
        WHEN lower(trim(sector)) = 'technolgy' THEN 'technology'
        ELSE lower(trim(sector))
    END,
    year_established,
    revenue,
    employees,
    nullif(trim(office_location), ''),
    coalesce(nullif(trim(subsidiary_of), ''), 'Independent')
FROM stg_accounts;

INSERT INTO dim_product (product_name, series, list_price)
SELECT trim(product), trim(series), sales_price
FROM stg_products;

INSERT INTO dim_sales_agent (agent_name, manager_name, regional_office)
SELECT trim(sales_agent), trim(manager), trim(regional_office)
FROM stg_sales_teams;

INSERT INTO fact_opportunity (
    opportunity_id, agent_key, product_key, account_key, account_label,
    deal_stage, engage_date, close_date, close_value
)
SELECT
    trim(p.opportunity_id),
    a.agent_key,
    pr.product_key,
    ac.account_key,
    coalesce(nullif(trim(p.account), ''), 'Unknown'),
    trim(p.deal_stage),
    p.engage_date,
    p.close_date,
    p.close_value
FROM stg_sales_pipeline AS p
JOIN dim_sales_agent AS a
  ON a.agent_name = trim(p.sales_agent)
JOIN dim_product AS pr
  ON pr.product_name = CASE
      WHEN trim(p.product) = 'GTXPro' THEN 'GTX Pro'
      ELSE trim(p.product)
  END
LEFT JOIN dim_account AS ac
  ON ac.account_name = nullif(trim(p.account), '');

CREATE VIEW vw_deal_detail AS
SELECT
    f.opportunity_id,
    f.deal_stage,
    f.engage_date,
    f.close_date,
    to_char(f.close_date, 'YYYY-MM') AS close_month,
    a.agent_name,
    a.manager_name,
    a.regional_office,
    p.product_name,
    p.series,
    p.list_price,
    f.account_label,
    coalesce(ac.sector, 'unknown') AS sector,
    ac.office_location,
    ac.revenue_m AS account_revenue_m,
    ac.employees,
    f.deal_stage IN ('Won', 'Lost') AS is_closed,
    (f.deal_stage = 'Won')::integer AS is_won,
    f.close_value,
    f.close_date - f.engage_date AS sales_cycle_days,
    CASE
        WHEN f.deal_stage = 'Won' THEN 1 - f.close_value / nullif(p.list_price, 0)
    END AS discount_pct,
    (f.account_key IS NOT NULL)::integer AS account_enriched
FROM fact_opportunity AS f
JOIN dim_sales_agent AS a USING (agent_key)
JOIN dim_product AS p USING (product_key)
LEFT JOIN dim_account AS ac USING (account_key);

CREATE VIEW vw_data_quality AS
SELECT 'unique opportunity IDs' AS check_name,
       count(*) - count(DISTINCT opportunity_id) AS failures
FROM fact_opportunity
UNION ALL
SELECT 'closed opportunities have dates',
       count(*) FILTER (WHERE deal_stage IN ('Won', 'Lost') AND close_date IS NULL)
FROM fact_opportunity
UNION ALL
SELECT 'won opportunities have values',
       count(*) FILTER (WHERE deal_stage = 'Won' AND coalesce(close_value, 0) <= 0)
FROM fact_opportunity
UNION ALL
SELECT 'dimension joins complete',
       count(*) FILTER (WHERE agent_key IS NULL OR product_key IS NULL)
FROM fact_opportunity;

COMMIT;

