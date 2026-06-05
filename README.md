# OlistFlow 🛒

> A production-ready ELT pipeline that ingests the Brazilian E-Commerce (Olist) dataset into Google BigQuery and transforms it into an analytics-ready Star Schema using dbt Core — built with Medallion Architecture, custom macros, and data quality tests.

---

## Architecture

```
9 CSV Files (Olist 2016–2018)
          ↓
   script/ingest.py          ← Python ingestion (google-cloud-bigquery)
          ↓
   bronze.*  (9 tables)      ← Raw data, loaded as-is
          ↓ dbt
   silver.*  (9 models)      ← Cleaned, typed, deduplicated
          ↓ dbt
   gold.*    (4 models)      ← Star Schema, analytics-ready
```

---

## Tech Stack

| Layer | Technology |
|---|---|
| Ingestion | Python 3.12 + google-cloud-bigquery |
| Storage | Google BigQuery |
| Transformation | dbt Core + dbt-bigquery 1.11.1 |
| Data Model | Star Schema + Medallion Architecture |
| Authentication | GCP Service Account JSON (via env vars) |
| Package Manager | uv |

---

## Project Structure

```
olistflow/
├── script/
│   └── ingest.py                         ← Loads 9 CSV files into BigQuery Bronze
├── data/
│   ├── olist_orders_dataset.csv
│   ├── olist_order_items_dataset.csv
│   ├── olist_order_payments_dataset.csv
│   ├── olist_order_reviews_dataset.csv
│   ├── olist_customers_dataset.csv
│   ├── olist_sellers_dataset.csv
│   ├── olist_products_dataset.csv
│   ├── olist_geolocation_dataset.csv
│   └── product_category_name_translation.csv
├── olist_ecommerce/                       ← dbt project
│   ├── models/
│   │   ├── silver/
│   │   │   ├── properties.yml            ← Consolidated sources & staging metadata
│   │   │   ├── stg_customers.sql
│   │   │   ├── stg_orders.sql
│   │   │   ├── stg_order_items.sql
│   │   │   ├── stg_order_payments.sql
│   │   │   ├── stg_order_reviews.sql
│   │   │   ├── stg_products.sql
│   │   │   ├── stg_sellers.sql
│   │   │   ├── stg_geolocation.sql
│   │   │   └── stg_product_category.sql
│   │   └── gold/
│   │       ├── schema.yml                ← Star schema validation & integrity constraints
│   │       ├── dim_customers.sql
│   │       ├── dim_products.sql
│   │       ├── dim_date.sql
│   │       └── fct_order.sql
│   ├── macros/
│   │   ├── clean_timestamp.sql           ← Reusable timestamp cleaning macro
│   │   └── quarantine_schema.sql         ← Schema name override macro
│   ├── tests/
│   │   └── generic/
│   │       └── test_not_negative.sql     ← Custom business rule test
│   ├── packages.yml
│   ├── dbt_project.yml
│   └── profiles.yml
├── logs/
├── pyproject.toml
└── README.md
```

---

## Data Model

### Bronze Layer

Raw CSV files loaded into BigQuery with `autodetect=True`. No transformations applied.

| Table | Rows | Description |
|---|---|---|
| `olist_orders` | 99,441 | Order headers |
| `olist_order_items` | 112,650 | Line items per order |
| `olist_order_payments` | 103,886 | Payment transactions |
| `olist_order_reviews` | ~100k | Customer reviews (PT-BR) |
| `olist_customers` | ~99k | Customer records |
| `olist_sellers` | ~3k | Seller records |
| `olist_products` | ~32k | Product catalog |
| `olist_geolocation` | ~1M | Brazilian zip codes + coordinates |
| `product_category_name` | 71 | PT → EN category translations |

---

### Silver Layer

One staging model per source table. All configurations are co-located within a single `properties.yml` for unified metadata management. All models apply:

- `SAFE_CAST` for runtime type safety
- Timestamp cleaning via the `clean_timestamp` macro
- Explicit trimming, null handling, and deduplication where needed

| Model | Key Transformations |
|---|---|
| `stg_orders` | Timestamp standardization (`_at`), status typing |
| `stg_order_items` | Price/freight casting, shipping date alignment |
| `stg_order_payments` | Payment type standardization |
| `stg_order_reviews` | Score validation, text null handling |
| `stg_customers` | TRIM and geographic formatting |
| `stg_sellers` | State normalization and validation |
| `stg_products` | Product metadata cleaning |
| `stg_product_category` | Category translation (PT to EN mapping) |
| `stg_geolocation` | Coordinate boundary validation |
---

### Gold Layer — Star Schema

```
              dim_date
                 ↑
dim_customers ← fct_order → dim_products
```

**`dim_customers`**

| Column | Type | Description |
|---|---|---|
| `customer_pk` | STRING | Surrogate key (hash of `customer_unique_id`) |
| `customer_unique_id` | STRING | Natural key — true customer identifier |
| `customer_city` | STRING | City |
| `customer_state` | STRING | State (BR) |
| `customer_segment` | STRING | Casual / Loyal / VIP / New |
| `customer_region` | STRING | North / South / Southeast / Northeast / Central-West |



**`dim_products`**

| Column | Type | Description |
|---|---|---|
| `product_pk` | STRING | Surrogate key |
| `product_id` | STRING | Natural key |
| `product_category` | STRING | Category name (EN) |
| `product_weight_g` | NUMERIC | Weight in grams |
| `product_length_cm` | NUMERIC | Length in centimeters |
| `product_height_cm` | NUMERIC | height in centimeters |
| `product_width_cm` | NUMERIC | width in centimeters |
| `product_category_name_pt` | STRING | Category name in Portuguese (PT-BR)|
| `product_category_name_en` | STRING | Category name in English (EN) |

**`dim_date`**

Generated procedurally using `calogica/dbt_date` (or similar package) to ensure a comprehensive, fully-materialized time-intelligence backbone. This structure eliminates the need for complex date-math in downstream BI tools by providing pre-calculated prior-year and standardized ISO alignments.

| Column | Type | Description |
| :--- | :--- | :--- |
| `date_day` | DATE | Calendar date (Primary Key) |
| `prior_date_day` | DATE | Previous calendar date (T-1) |
| `next_date_day` | DATE | Next calendar date (T+1) |
| `prior_year_date_day` | DATE | Exact same date in the previous year (T-365) |
| `prior_year_over_year_date_day` | DATE | YoY aligned comparison date |
| `day_of_week` | INTEGER | Index of the day within the week |
| `day_of_week_iso` | INTEGER | ISO standard day index (1 = Monday, 7 = Sunday) |
| `day_of_week_name` | STRING | Full day name (e.g., Monday, Tuesday) |
| `day_of_week_name_short` | STRING | Short day name (e.g., Mon, Tue) |
| `day_of_month` | INTEGER | Day number within the month (1 - 31) |
| `day_of_year` | INTEGER | Day number within the year (1 - 365/366) |
| `week_start_date` | DATE | First day of the standard week |
| `week_end_date` | DATE | Last day of the standard week |
| `prior_year_week_start_date` | DATE | First day of the exact same week last year |
| `prior_year_week_end_date` | DATE | Last day of the exact same week last year |
| `week_of_year` | INTEGER | Standard week number |
| `iso_week_start_date` | DATE | First day of the ISO standard week |
| `iso_week_end_date` | DATE | Last day of the ISO standard week |
| `prior_year_iso_week_start_date` | DATE | First day of the ISO week last year |
| `prior_year_iso_week_end_date` | DATE | Last day of the ISO week last year |
| `iso_week_of_year` | INTEGER | ISO standard week number |
| `prior_year_week_of_year` | INTEGER | Week number from the previous year |
| `prior_year_iso_week_of_year` | INTEGER | ISO week number from the previous year |
| `month_of_year` | INTEGER | Month index (1 - 12) |
| `month_name` | STRING | Full month name (e.g., January) |
| `month_name_short` | STRING | Short month name (e.g., Jan, Feb) |
| `month_start_date` | DATE | First day of the month |
| `month_end_date` | DATE | Last day of the month |
| `prior_year_month_start_date` | DATE | First day of the same month last year |
| `prior_year_month_end_date` | DATE | Last day of the same month last year |
| `quarter_of_year` | INTEGER | Quarter index (1 - 4) |
| `quarter_start_date` | DATE | First day of the current quarter |
| `quarter_end_date` | DATE | Last day of the current quarter |
| `year_number` | INTEGER | Calendar year (e.g., 2018) |
| `year_start_date` | DATE | First day of the year (Jan 1) |
| `year_end_date` | DATE | Last day of the year (Dec 31) |

**`fct_order`** — Grain: One row per order line item

| Column | Type | Description |
| :--- | :--- | :--- |
| `order_item_pk` | STRING | Surrogate key (hash of `order_id` + `order_item_id`) |
| `customer_pk` | STRING | FK → `dim_customers` (Derived from `customer_unique_id`) |
| `product_pk` | STRING | FK → `dim_products` |
| `seller_pk` | STRING | FK → `dim_sellers` |
| `order_purchase_date` | DATE | FK → `dim_date` (Partition Key) |
| `order_id` | STRING | Natural key (Original transaction ID) |
| `order_item_id` | INTEGER | Natural key (Sequence ID within order) |
| `order_status` | STRING | Status (delivered / shipped / etc) |
| `seller_id` | STRING | Natural key for the seller |
| `order_purchase_at` | TIMESTAMP | Exact timestamp of purchase |
| `order_approved_at` | TIMESTAMP | Timestamp of order approval |
| `order_delivered_carrier_at` | TIMESTAMP | Timestamp of delivery to carrier |
| `order_delivered_customer_at` | TIMESTAMP | Timestamp of final delivery |
| `order_estimated_delivery_at` | TIMESTAMP | Predicted delivery timestamp |
| `shipping_limit_at` | TIMESTAMP | Seller shipping deadline |
| `item_price` | NUMERIC | Unit price per item |
| `item_freight_value` | NUMERIC | Freight cost per item |
| `total_item_cost` | NUMERIC | Total item cost (price + freight) |
| `total_order_payment_value` | NUMERIC | Full aggregated payment amount for the order |
| `payment_methods_count` | INTEGER | Number of payment methods used |
| `actual_delivery_days` | INTEGER | Total days: Purchase → actual delivery |
| `estimated_delivery_days` | INTEGER | Total days: Purchase → estimated delivery |
| `is_delivery_delayed` | INTEGER | 1 = delayed, 0 = on time |

---

## Setup

### Prerequisites

- Python 3.12+
- [uv](https://github.com/astral-sh/uv) package manager
- Google Cloud project with BigQuery API enabled
- GCP Service Account with `BigQuery Admin` role

### Installation

```bash
# Clone the repo
git clone https://github.com/yourusername/olistflow.git
cd olistflow

# Install dependencies
uv sync

# Activate virtual environment
source .venv/bin/activate       # Linux/Mac
.venv\Scripts\activate          # Windows

# Install dbt packages
cd olist_ecommerce
dbt deps
```

### Environment Variables

Create a `.env` file at the project root:

```dotenv
GCP_PROJECT=your-project-id
GCP_PRIVATE_KEY_ID=your-private-key-id
GCP_PRIVATE_KEY="-----BEGIN RSA PRIVATE KEY-----\n...\n-----END RSA PRIVATE KEY-----\n"
GCP_CLIENT_EMAIL=your-service-account@project.iam.gserviceaccount.com
GCP_CLIENT_ID=your-client-id
```

### Run the Pipeline

```bash
# Step 1 — Ingest CSV files into BigQuery Bronze (run once)
python script/ingest.py

# Step 2 — Run dbt transformations
cd olist_ecommerce
dbt run

# Step 3 — Run data quality tests
dbt test

# Step 4 — Explore lineage
dbt docs generate
dbt docs serve
```

---

## Data Quality

| Test | Model | Column | Type |
|---|---|---|---|
| `unique` | `fct_order` | `order_item_pk` | Generic |
| `not_null` | `fct_order` | `order_item_pk`, `customer_pk`, `product_pk` | Generic |
| `not_negative` | `fct_order` | `item_price`, `item_freight_value` | Custom |
| `accepted_values` | `stg_orders` | `order_status` | Generic |
| `relationships` | `fct_order` | `customer_pk` → `dim_customers` | Generic |

---

## Production Debrief: The Referential Integrity Trap

During pipeline testing, the `relationships` validation test failed with a 100% data drop across all 112,650 rows.

**Root Cause:** In the Olist dataset, `customer_id` is a volatile transaction token generated per order, while `customer_unique_id` represents the actual persistent buyer identity. Generating surrogate keys in `fct_order` using `customer_id` broke referential integrity against `dim_customers` — which aggregates on `customer_unique_id` — producing completely unmatched hashes.

**Resolution:** Refactored `fct_order` to join `stg_orders` with `stg_customers` upstream, extracting the true natural key (`customer_unique_id`) before hashing. This aligned the surrogate key strategy across both models and restored full referential integrity.

---

## Key Design Decisions

| Decision | Reason |
|---|---|
| ELT over ETL | Push transformations inside BigQuery — cheaper, faster, maintainable |
| Medallion Architecture | Clear lineage: Bronze (raw) → Silver (clean) → Gold (analytics) |
| Star Schema | Optimized for BI tools and analytical queries |
| Surrogate Keys | Stable joins via `dbt_utils.generate_surrogate_key` |
| `clean_timestamp` macro | Reusable timestamp normalization across all staging models |
| `SAFE_CAST` everywhere | Pipeline never crashes on malformed data |
| `WRITE_TRUNCATE` ingestion | Idempotent loads — safe to re-run at any time |
| Consolidated `properties.yml` | Single source of truth for Silver metadata — prevents schema drift |

---

## Dataset

[Brazilian E-Commerce Public Dataset by Olist](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce) — Kaggle

> ~100,000 real marketplace orders placed between 2016 and 2018 across multiple Brazilian marketplaces, including order status, price, payment, freight performance, customer location, seller attributes, product catalog, and customer reviews written in Portuguese.

---

## License

MIT