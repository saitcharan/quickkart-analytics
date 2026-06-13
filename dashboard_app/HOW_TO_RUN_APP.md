# Dashboard App — How to Run + How the Data Works

This folder is the **self-contained dashboard**. It has everything it needs:

| File | What it is |
|---|---|
| `application.py` | The Streamlit dashboard (the app itself) |
| `dashboard_data.csv` | The pre-aggregated data the app reads (one row per order) |
| `requirements.txt` | The 3 Python packages the app needs |

---

## How to run it (≈2 minutes)

```bash
# 1. open a terminal in THIS folder (dashboard_app)
cd path/to/dashboard_app

# 2. (recommended) make a clean virtual environment
python3 -m venv .venv

# 3. activate it
source .venv/bin/activate        # macOS / Linux
# .venv\Scripts\activate         # Windows (PowerShell)

# 4. install the 3 packages
pip install -r requirements.txt

# 5. launch the app
streamlit run application.py
```

It opens automatically in your browser at **http://localhost:8501**.
(If not, paste that address into any browser.) Press `Ctrl + C` in the terminal to stop it.

**Requirements:** Python 3.9+ and the packages `streamlit`, `pandas`, `plotly` (installed in step 4).

**What you'll see:** a sidebar with a date-range picker and City / Category / Carrier filters (each with a
"Select all" button) plus a metric selector; and a main panel with a KPI strip (GMV, delayed-order rate,
repeat rate), a monthly time-series, a city/carrier breakdown bar, and auto-generated insight bullets —
all updating live as you change the filters.

---

## What is `dashboard_data.csv`, and why did I create it this way?

**Short answer:** `dashboard_data.csv` is **not** one of the 6 original data files. It's a new,
**pre-aggregated** file I built *from* those 6 files — a single, flat table with **one row per order** that
already contains every column the dashboard needs.

### The pipeline

```
 6 raw CSVs                  database                  one SQL query                dashboard_data.csv        the app
(customers, orders,  ─load─> (6 linked tables)  ─join &─> (flattens them to    ─export─> (1 flat file,    ─reads─> filters it
 order_items, etc.)                              aggregate  1 row per order)              1 row/order)              with pandas
```

1. The 6 raw CSVs are loaded into a database as 6 separate tables.
2. One SQL query **joins** them and **flattens** the result into one row per order.
3. That result is saved as `dashboard_data.csv`.
4. The app simply **reads this one file** and filters it.

### Why not let the app read the 6 raw CSVs directly?

The 6 files are **normalized** — the data is split across tables and linked by IDs (an order in
`orders.csv`, its products in `order_items.csv` + `products.csv`, its customer in `customers.csv`, its
delivery in `shipments.csv`). To compute even "GMV by city and carrier," the app would have to **join 5
tables together every single time someone moves a filter** — that's complex and slow.

So I did that heavy joining **once**, in SQL, and baked the answer into `dashboard_data.csv`. Now the app
stays **simple, fast, and portable** — it doesn't even need a database to run.

### What's inside `dashboard_data.csv` (and where each column came from)

| Column | Source (raw file/table) |
|---|---|
| `order_id`, `created_at`, `month`, `customer_id` | orders |
| `city` | customers |
| `category` | products (the order's main category, via order_items → products) |
| `carrier` | shipments |
| `gmv` | order_items (Σ quantity × unit_price, before platform fee) |
| `is_delivered`, `has_outcome` | orders.status + shipments.delivered_at |
| `is_delayed` | shipments.delivery_status (a "Late_*" bucket) |
| `is_repeat_customer` | computed from orders (customer with ≥2 delivered orders) |

> **Important for rates:** I store **flags (0/1), not pre-computed percentages.** You can't average
> percentages across filtered rows — so the app computes rates *after* filtering, e.g.
> `delayed_order_rate = Σ is_delayed / Σ has_outcome` and
> `repeat_rate = distinct repeat customers / distinct customers`. This keeps the numbers correct no
> matter which filters are applied.

**In one line:** the 6 CSVs are the *raw ingredients*; `dashboard_data.csv` is the *finished dish* I cooked
from them with one SQL query — so the app serves it instantly instead of re-cooking on every click.
