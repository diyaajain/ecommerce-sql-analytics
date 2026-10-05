-- Technique: timing a live aggregate query against reading the same
-- result from a materialized view, using psql's \timing meta-command.
-- Run with: psql $DB -f queries/08_materialized_view_comparison.sql
-- (requires sql/06_materialized_view.sql to have been run first)
--
-- What to expect: at this dataset's size (~110k fact rows), both should
-- be fast in absolute terms — the honest point here isn't "huge speedup",
-- it's that the materialized view's time should be flat/small regardless
-- of how expensive the underlying query is, because it's just reading a
-- stored result, not recomputing anything. That gap grows a lot more at
-- real-world data volumes or with heavier queries (multiple large joins,
-- window functions over millions of rows).

\pset pager off
\timing on

-- (1) The live aggregate — recomputed from scratch every time
SELECT
    date_trunc('month', f.date_key)::date AS month,
    dp.category_english,
    SUM(f.price) AS revenue,
    COUNT(*) AS items_sold
FROM warehouse.fact_order_items f
JOIN warehouse.dim_product dp
    ON dp.product_key = f.product_key
WHERE f.order_status NOT IN ('canceled', 'unavailable')
GROUP BY 1, 2
ORDER BY month, category_english;

-- (2) The same result, read from the materialized view instead
SELECT *
FROM warehouse.mv_monthly_category_revenue
ORDER BY month, category_english;

\timing off

-- Reminder: if you reload or change fact_order_items later, this view
-- will NOT reflect that until you explicitly run:
--   REFRESH MATERIALIZED VIEW warehouse.mv_monthly_category_revenue;