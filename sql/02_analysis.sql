-- Cerneva portfolio analysis
-- Demonstrates CTEs, filtered aggregates, windows, percentiles, date logic
-- and an interpretable action score in PostgreSQL.

SET search_path TO cerneva, public;

-- 1. Executive scorecard --------------------------------------------------
SELECT
    count(*) FILTER (WHERE is_closed) AS closed_deals,
    count(*) FILTER (WHERE is_won = 1) AS won_deals,
    round(avg(is_won) FILTER (WHERE is_closed) * 100, 1) AS win_rate_pct,
    sum(close_value) FILTER (WHERE is_won = 1) AS won_revenue,
    percentile_cont(0.5) WITHIN GROUP (ORDER BY sales_cycle_days)
        FILTER (WHERE is_closed) AS median_cycle_days
FROM vw_deal_detail;

-- 2. Product mix and cumulative revenue concentration ---------------------
WITH product_revenue AS (
    SELECT
        product_name,
        sum(close_value) FILTER (WHERE is_won = 1) AS won_revenue
    FROM vw_deal_detail
    GROUP BY product_name
), ranked AS (
    SELECT
        product_name,
        won_revenue,
        dense_rank() OVER (ORDER BY won_revenue DESC) AS revenue_rank,
        won_revenue / sum(won_revenue) OVER () AS revenue_share,
        sum(won_revenue) OVER (ORDER BY won_revenue DESC)
            / sum(won_revenue) OVER () AS cumulative_revenue_share
    FROM product_revenue
)
SELECT *
FROM ranked
ORDER BY revenue_rank;

-- 3. Region comparison with sample size and organisational baseline -------
WITH region_result AS (
    SELECT
        regional_office,
        count(*) FILTER (WHERE is_closed) AS closed_deals,
        avg(is_won) FILTER (WHERE is_closed) AS win_rate,
        sum(close_value) FILTER (WHERE is_won = 1) AS won_revenue
    FROM vw_deal_detail
    GROUP BY regional_office
), baseline AS (
    SELECT avg(is_won) FILTER (WHERE is_closed) AS global_win_rate
    FROM vw_deal_detail
)
SELECT
    r.*,
    b.global_win_rate,
    r.win_rate - b.global_win_rate AS variance_to_global
FROM region_result AS r
CROSS JOIN baseline AS b
ORDER BY r.win_rate DESC;

-- 4. Fairer agent comparison using a 30-deal prior ------------------------
WITH baseline AS (
    SELECT avg(is_won) FILTER (WHERE is_closed) AS global_win_rate
    FROM vw_deal_detail
), agent_result AS (
    SELECT
        agent_name,
        manager_name,
        regional_office,
        count(*) FILTER (WHERE is_closed) AS closed_deals,
        sum(is_won) FILTER (WHERE is_closed) AS wins,
        avg(is_won) FILTER (WHERE is_closed) AS raw_win_rate,
        sum(close_value) FILTER (WHERE is_won = 1) AS won_revenue
    FROM vw_deal_detail
    GROUP BY agent_name, manager_name, regional_office
)
SELECT
    a.*,
    (a.wins + 30 * b.global_win_rate) / (a.closed_deals + 30)
        AS adjusted_win_rate,
    dense_rank() OVER (
        ORDER BY (a.wins + 30 * b.global_win_rate) / (a.closed_deals + 30) DESC
    ) AS adjusted_rank
FROM agent_result AS a
CROSS JOIN baseline AS b
ORDER BY adjusted_rank, won_revenue DESC;

-- 5. Monthly movement and three-month rolling revenue ---------------------
WITH monthly AS (
    SELECT
        date_trunc('month', close_date)::date AS close_month,
        count(*) AS closed_deals,
        avg(is_won) AS win_rate,
        sum(close_value) FILTER (WHERE is_won = 1) AS won_revenue
    FROM vw_deal_detail
    WHERE is_closed
    GROUP BY 1
)
SELECT
    *,
    sum(won_revenue) OVER (
        ORDER BY close_month ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ) AS rolling_3m_revenue,
    won_revenue - lag(won_revenue) OVER (ORDER BY close_month)
        AS revenue_change
FROM monthly
ORDER BY close_month;

-- 6. Sales-cycle quartiles by outcome ------------------------------------
SELECT
    deal_stage,
    count(*) AS deals,
    round(avg(sales_cycle_days), 1) AS mean_days,
    percentile_cont(0.25) WITHIN GROUP (ORDER BY sales_cycle_days) AS p25,
    percentile_cont(0.50) WITHIN GROUP (ORDER BY sales_cycle_days) AS median,
    percentile_cont(0.75) WITHIN GROUP (ORDER BY sales_cycle_days) AS p75
FROM vw_deal_detail
WHERE is_closed
GROUP BY deal_stage
ORDER BY deal_stage;

-- 7. Transparent open-pipeline action queue -------------------------------
WITH reference_date AS (
    SELECT max(coalesce(close_date, engage_date)) + 1 AS as_of_date
    FROM fact_opportunity
), open_deals AS (
    SELECT
        d.*,
        r.as_of_date - d.engage_date AS stale_days,
        round(100.0 * (
            (d.account_label <> 'Unknown')::integer
            + (d.engage_date IS NOT NULL)::integer
            + d.account_enriched
            + 1  -- valid product dimension
            + 1  -- valid sales-team dimension
        ) / 5) AS record_completeness,
        percent_rank() OVER (ORDER BY list_price) AS value_percentile
    FROM vw_deal_detail AS d
    CROSS JOIN reference_date AS r
    WHERE d.deal_stage IN ('Prospecting', 'Engaging')
), scored AS (
    SELECT
        *,
        round(
            (100 - record_completeness) * 0.45
            + least(coalesce(stale_days, 90)::numeric / 90, 1) * 35
            + value_percentile * 20
        ) AS priority_score
    FROM open_deals
)
SELECT
    opportunity_id,
    deal_stage,
    agent_name,
    manager_name,
    regional_office,
    product_name,
    account_label,
    list_price,
    stale_days,
    record_completeness,
    priority_score,
    CASE
        WHEN record_completeness < 80 THEN 'Complete CRM record'
        WHEN deal_stage = 'Engaging' AND stale_days >= 60 THEN 'Review stalled opportunity'
        WHEN deal_stage = 'Engaging' AND stale_days >= 30 THEN 'Confirm next step or close'
        ELSE 'Progress next action'
    END AS recommended_action
FROM scored
ORDER BY priority_score DESC, list_price DESC;

-- 8. Account opportunity map: value without claiming causality ------------
SELECT
    account_label,
    sector,
    count(*) FILTER (WHERE is_closed) AS closed_deals,
    round(avg(is_won) FILTER (WHERE is_closed) * 100, 1) AS win_rate_pct,
    sum(close_value) FILTER (WHERE is_won = 1) AS won_revenue,
    count(*) FILTER (WHERE deal_stage IN ('Prospecting', 'Engaging')) AS open_deals,
    sum(list_price) FILTER (WHERE deal_stage IN ('Prospecting', 'Engaging'))
        AS open_list_value
FROM vw_deal_detail
WHERE account_label <> 'Unknown'
GROUP BY account_label, sector
HAVING count(*) FILTER (WHERE is_closed) >= 3
ORDER BY won_revenue DESC;

-- 9. Executable quality gate ---------------------------------------------
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM vw_data_quality WHERE failures > 0) THEN
        RAISE EXCEPTION 'Cerneva quality gate failed';
    END IF;
END $$;

