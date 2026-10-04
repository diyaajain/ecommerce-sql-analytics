# CommerceLens
# E-Commerce SQL Analytics Warehouse

A SQL-first analytics project: real e-commerce order data loaded into
**PostgreSQL**, modeled into a proper star schema, and analyzed with SQL
alone — window functions, CTEs, ranking, cohort analysis, RFM segmentation,
and query optimization. Python's only job here is loading CSVs; every
transformation and every insight is SQL.

## Project structure

```
├── docker-compose.yml       # local Postgres
├── .env.example             # connection settings
├── requirements.txt
├── load_raw.py               # thin CSV -> raw.* loader (no logic)
├── data/                     # put the Kaggle CSVs here (git-ignored)
├── sql/
│   ├── 00_raw_schema.sql     # staging tables matching the CSVs
│   ├── 01_star_schema.sql    # dim_* and fact_order_items DDL
│   ├── 02_load_dim_date.sql  # date dimension via generate_series
│   ├── 03_load_dimensions.sql
│   ├── 04_load_fact.sql      # the main ETL join
│   └── 05_indexes.sql
└── queries/
    ├── 01_monthly_revenue_trend.sql       # window functions: LAG, moving avg
    ├── 02_top_products_by_category.sql    # DENSE_RANK PARTITION BY
    ├── 03_cohort_retention.sql            # multi-CTE cohort analysis
    ├── 04_rfm_segmentation.sql            # NTILE quartile scoring
    └── 05_query_optimization_demo.sql     # EXPLAIN ANALYZE, indexing
```

## Why Postgres, not SQLite

This project exists to demonstrate real SQL depth, and SQLite is missing or
weak on several things that matter for that: full window function support,
`EXPLAIN ANALYZE` with real cost estimates, proper indexing behavior, and
schemas as first-class objects. Postgres is the standard choice for this
kind of work.

## Data model

**Grain decision:** `fact_order_items` is at the **order-item** level —
one row per product within an order. Payments and reviews in the raw data
are at the **order** level (one review, and possibly several payment
installments, per order). To fit an item-grain fact table, payments are
summed per order and repeated across that order's items, and the order's
review score is likewise repeated. This means:
- `SUM(price)` and `SUM(freight_value)` are safe — each item's own values.
- `SUM(order_payment_total)` is **not** safe for orders with more than one
  item — it double-counts. Use `SUM(order_payment_total)` only after
  deduplicating to one row per `order_id` first.

This is a real, common data-warehouse modeling tradeoff, not an oversight
— see `sql/01_star_schema.sql`'s header comment for the full explanation.
It's worth being able to explain this tradeoff out loud; it's exactly the
kind of thing a technical interviewer asks about.

**The customer_id / customer_unique_id split:** Olist's `customer_id` is
actually per-*order*, not per-*person* — the same real customer gets a new
`customer_id` on every order. `customer_unique_id` is the real person
identifier. `dim_customer` keeps both; every query here that counts
"distinct customers" groups by `customer_unique_id`, not `customer_id`.
Getting this wrong is an easy, realistic mistake — worth calling out
explicitly in a portfolio write-up as something you caught.

## Known data characteristics (not bugs)

- **Repeat purchases are rare.** Most Olist customers buy exactly once, so
  cohort retention past month 0 is near-zero and RFM's frequency score is
  heavily tied. These are genuine findings about the dataset, not errors
  in the queries — see the header comments in
  `queries/03_cohort_retention.sql` and `queries/04_rfm_segmentation.sql`.
- **~100k fact rows is small** for a database engine built for millions.
  The optimization demo's before/after timing difference may be modest —
  say so honestly rather than overselling it; the technique (reading an
  execution plan) is the actual point, not a dramatic speedup number.

## Ideas to add next

- `SUM() OVER` running totals and percent-of-total by category
- A late-delivery analysis (`order_delivered_customer_date` vs.
  `order_estimated_delivery_date`) with a `CASE WHEN` flag
- A materialized view for one of the heavier queries, with a comparison
  of query time against the plain view
- A recursive CTE, if a hierarchical structure can be found or
  constructed in the category data
- Loading `olist_geolocation_dataset.csv` and adding geographic analysis

## Tech

PostgreSQL 16, Docker, Python (pandas, SQLAlchemy, psycopg2) for loading
only — all analysis is SQL.
