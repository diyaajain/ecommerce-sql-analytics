-- Indexes on the fact table's foreign keys (the columns every analytical
-- query joins or filters on). Run queries/07_query_optimization_demo.sql
-- BEFORE this script to see the un-indexed EXPLAIN plan, then again AFTER
-- to see the difference.

CREATE INDEX idx_fact_date     ON warehouse.fact_order_items (date_key);
CREATE INDEX idx_fact_customer ON warehouse.fact_order_items (customer_key);
CREATE INDEX idx_fact_product  ON warehouse.fact_order_items (product_key);
CREATE INDEX idx_fact_seller   ON warehouse.fact_order_items (seller_key);
CREATE INDEX idx_fact_status   ON warehouse.fact_order_items (order_status);

CREATE INDEX idx_dim_customer_unique ON warehouse.dim_customer (customer_unique_id);
