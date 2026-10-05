# E-Commerce SQL Analytics Warehouse

A SQL-first analytics project: real e-commerce order data loaded into
**PostgreSQL**, modeled into a proper star schema, and analyzed with SQL
alone — window functions, CTEs, ranking, cohort analysis, RFM segmentation,
and query optimization. Python's only job here is loading CSVs; every
transformation and every insight is SQL.

## Why Postgres, not SQLite

This project exists to demonstrate real SQL depth, and SQLite is missing or
weak on several things that matter for that: full window function support,
`EXPLAIN ANALYZE` with real cost estimates, proper indexing behavior, and
schemas as first-class objects. Postgres is the standard choice for this
kind of work.

## 1. Get Postgres running

Pick one. Everything after this step (the SQL scripts, `load_raw.py`) is
identical either way — they just connect to whatever Postgres is running
on `localhost:5432`.

**Option A — Postgres.app (simplest on Mac, no Docker needed):**
1. Download from [postgresapp.com](https://postgresapp.com), drag to
   Applications, open it, click **Initialize** — this starts a server and
   creates a default superuser matching your Mac username, no password
   (local connections are trusted automatically).
2. Make `psql` available in your terminal: Postgres.app's menu has a
   **"Configure PATH"** option that does this for you (adds a line to your
   shell config). If you skip it, use the full path instead:
   `/Applications/Postgres.app/Contents/Versions/latest/bin/psql`
3. Create the database:
   ```bash
   createdb ecommerce
   ```
4. Edit `.env` (after copying it from `.env.example` in step 3 below) to
   match — **no Docker-style `warehouse` user exists here**, so use your
   own Mac username and leave the password blank:
   ```
   PGUSER=your-mac-username
   PGPASSWORD=
   PGHOST=localhost
   PGPORT=5432
   PGDATABASE=ecommerce
   ```
   (Find your username with `whoami` if unsure.)

**Option B — Docker (if you'd rather not install Postgres directly):**
```bash
cd ecommerce-sql-warehouse
docker compose up -d
```
This starts Postgres 16 on `localhost:5432` with user `warehouse`,
password `warehouse`, database `ecommerce` (see `docker-compose.yml`) —
matching `.env.example` as-is, no edits needed. Check it's up:
`docker compose ps`.

## 2. Get the dataset

This uses the **Olist Brazilian E-Commerce** dataset — ~100k real orders,
free on Kaggle, requires a free Kaggle account:

1. Go to [kaggle.com/datasets/olistbr/brazilian-ecommerce](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)
2. Sign in (or create a free account) and click **Download**
3. Unzip it, and copy all the `.csv` files into this project's `data/` folder

You should end up with files like `data/olist_orders_dataset.csv`,
`data/olist_customers_dataset.csv`, etc. — 9 CSVs total (this project
doesn't use `olist_geolocation_dataset.csv`; leaving it out is fine).

## 3. Set up Python and load the raw data

```bash
python3 -m venv .venv
source .venv/bin/activate
python3 -m pip install -r requirements.txt
cp .env.example .env
```

Create the raw staging tables, then load the CSVs into them:
```bash
psql postgresql://warehouse:warehouse@localhost:5432/ecommerce -f sql/00_raw_schema.sql
python3 load_raw.py
```
`load_raw.py` does nothing clever — it reads each CSV and copies it
straight into a matching `raw.*` table. All the real work happens next, in
SQL.

## 4. Build the star schema

Run these **in order** — each one depends on the previous:

```bash
DB="postgresql://warehouse:warehouse@localhost:5432/ecommerce"
psql $DB -f sql/01_star_schema.sql      # creates dim_* and fact_order_items (empty)
psql $DB -f sql/02_load_dim_date.sql    # fills dim_date via generate_series
psql $DB -f sql/03_load_dimensions.sql  # fills dim_customer, dim_product, dim_seller
psql $DB -f sql/04_load_fact.sql        # fills fact_order_items (joins + aggregation)
```

**Don't run `sql/05_indexes.sql` yet** — see the optimization demo below,
which deliberately runs once before indexes and once after.

## 5. Run the analytical queries

```bash
psql $DB -f queries/01_monthly_revenue_trend.sql
psql $DB -f queries/02_top_products_by_category.sql
psql $DB -f queries/03_cohort_retention.sql
psql $DB -f queries/04_rfm_segmentation.sql
```

Each file's header comment names the specific SQL technique it's
demonstrating and any caveats about interpreting its output.

### Query optimization demo

```bash
psql $DB -f queries/05_query_optimization_demo.sql   # BEFORE — note the plan
psql $DB -f sql/05_indexes.sql                        # now add the indexes
psql $DB -f queries/05_query_optimization_demo.sql   # AFTER — compare
```
Look for `Seq Scan` (reads the whole table) changing to `Index Scan` /
`Bitmap Heap Scan`, and the `actual time` dropping. See the file's header
comment for what a realistic (not dramatic) result looks like at this data
size.

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

## Results

> Fill in each section below after running the query in Postico. Take a
> screenshot of the results grid, save it into `results/` using the
> filename noted under each query, then replace the `[bracketed]` text
> with your actual numbers and a one-line takeaway.

### 1. Monthly revenue trend — `queries/01_monthly_revenue_trend.sql`
*Technique: window functions (`LAG`, a moving-average frame)*

![Monthly revenue trend](results/01_monthly_revenue_trend.png)

**Finding:** [e.g. "Revenue grew from ₹X in month A to ₹Y by month B, with
the sharpest single-month jump of [X]% in [month] — worth checking whether
that lines up with a known sales event."]

### 2. Top products by category — `queries/02_top_products_by_category.sql`
*Technique: `DENSE_RANK() PARTITION BY`*

![Top products by category](results/02_top_products_by_category.png)

**Finding:** [e.g. "The top category by revenue is [X], and its #1 product
alone accounts for [X]% of that category's revenue."]

### 3. Cohort retention — `queries/03_cohort_retention.sql`
*Technique: multi-step CTEs*

![Cohort retention](results/03_cohort_retention.png)

**Finding:** [State the actual retention percentages you see. Given this
dataset's known near-single-purchase behavior (see "Known data
characteristics" above), a low number here is an expected, real finding —
report it as one rather than treating it as a failed query.]

### 4. RFM segmentation — `queries/04_rfm_segmentation.sql`
*Technique: `NTILE()` quartile scoring*

![RFM segmentation](results/04_rfm_segmentation.png)

**Finding:** [e.g. "The top RFM-scored segment (score 10-12) represents
[X] customers — worth describing who they are: recent, frequent, and/or
high-spend."]

### 5. Query optimization — `queries/05_query_optimization_demo.sql`
*Technique: `EXPLAIN ANALYZE`, indexing*

**Before indexing:** [paste the plan's top line, e.g. "Seq Scan on
fact_order_items (actual time=X..Y)"]
**After indexing:** [same, after running `sql/05_indexes.sql`]
**Finding:** [What changed in the plan, and by how much. If the
difference is modest at this data size, say so — see the file's header
comment for why that's still a legitimate result.]

### 6. Running totals and percent of total — `queries/06_running_totals_and_pct_of_total.sql`
*Technique: `SUM() OVER` with and without `ORDER BY` — cumulative total vs. grand-total share*

![Running totals and percent of total](results/06_running_totals_and_pct_of_total.png)

**Finding:** [e.g. "Cumulative revenue crossed ₹X by [month]. The top
category, [X], accounts for [X]% of total revenue — the top 3 categories
together make up [X]%."]

## Project structure

```
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
    ├── 05_query_optimization_demo.sql     # EXPLAIN ANALYZE, indexing
    └── 06_running_totals_and_pct_of_total.sql  # SUM() OVER, two ways
```

## Ideas to add next

- A late-delivery analysis (`order_delivered_customer_date` vs.
  `order_estimated_delivery_date`) with a `CASE WHEN` flag
- A materialized view for one of the heavier queries, with a comparison
  of query time against the plain view
- A recursive CTE, if a hierarchical structure can be found or
  constructed in the category data
- Loading `olist_geolocation_dataset.csv` and adding geographic analysis

## Tech

PostgreSQL 16, Python (pandas, SQLAlchemy, psycopg2) for loading only — all analysis is SQL.