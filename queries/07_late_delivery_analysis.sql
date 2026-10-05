-- Technique: CASE WHEN business-rule classification, date arithmetic, and
-- a GROUP BY aggregate — translating a plain-English business question
-- ("where are we delivering late, and by how much?") into SQL.
--
-- Only delivered orders are included (is_late IS NOT NULL filters out
-- orders still in transit or never delivered, which have no delivery
-- date to measure against).

SELECT
    dc.state,
    COUNT(*) AS delivered_items,
    SUM(CASE WHEN f.is_late THEN 1 ELSE 0 END) AS late_items,
    ROUND(100.0 * SUM(CASE WHEN f.is_late THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_late,
    ROUND(AVG(f.delivered_date - f.estimated_delivery_date), 1) AS avg_days_vs_estimate,
    ROUND(AVG(f.delivered_date - f.estimated_delivery_date)
          FILTER (WHERE f.is_late), 1) AS avg_days_late_when_late
FROM warehouse.fact_order_items f
JOIN warehouse.dim_customer dc
    ON dc.customer_key = f.customer_key
WHERE f.is_late IS NOT NULL
GROUP BY dc.state
HAVING COUNT(*) >= 30   -- drop states with too few orders for the rate to mean much
ORDER BY pct_late DESC;
