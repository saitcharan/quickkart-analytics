# QuickKart Analytics Assessment — Submission

**Author:** T Saicharan 

This is my solution to the QuickKart marketplace & logistics take-home. It covers the exploratory
analysis, the SQL questions, an interactive dashboard, and an honest note on how I used AI tools.

## What's in this folder

| File / folder | What it is |
|---|---|
| `Dataset_overview.sql` | The data-quality checks I ran *first*, before trusting any numbers |
| `Section_a_answers.sql` | **Section A** — exploratory analysis (monthly GMV by city/category, orders & active customers, repeat rate, delayed-share by city & carrier) |
| `Section_b_answers.sql` | **Section B** — the four SQL questions (B1–B4) |
| **`dashboard_app/`** | **Section C** — the self-contained Streamlit dashboard (see below) |
| `dashboard_app/application.py` | The dashboard app |
| `dashboard_app/dashboard_data.csv` | Pre-aggregated data the app reads (one row per order) |
| `dashboard_app/requirements.txt` | The 3 Python packages for the app |
| `dashboard_app/HOW_TO_RUN_APP.md` | How to run the app **+ an explanation of `dashboard_data.csv`** |
| `FINDINGS.md` | The consolidated business findings & recommendations |
| `README.md` | This file |

## My approach (short version)

I worked in **dependency order, not document order**: I verified the data first
(`Dataset_overview.sql`), then wrote the SQL (Sections A & B) since those numbers feed everything, and
finally built the dashboard on top. This keeps every figure consistent — for example, GMV sums to
**₹339 crore** identically in the SQL, the EDA, and the app.

## Key assumptions (where the data was ambiguous)

1. **"Delayed" = the `delivery_status` Late bucket (≈26% of delivered orders), not the literal
   `delivered_at > promised_date` formula (≈8%).** The two disagree because the buckets use the delivery
   timestamp (an intraday cutoff). I went with the bucket because the SQL questions themselves reference
   "Late buckets" and it reflects misses the customer actually feels. **This is my most important
   assumption.**
2. **"Delivered" = `status = 'Delivered'`; repeat customer = ≥2 delivered orders.**
3. **GMV = Σ(quantity × unit_price), before platform fee** — the fee is kept as a separate figure.
4. **Delay rates use only completed orders** (`delivered_at IS NOT NULL`), so the 5,043 still-`InTransit`
   orders (a delivery status the brief didn't list) don't distort the denominator.
5. **B3's "≥100 delivered orders" threshold returns nothing** at the (seller × carrier × city) grain — the
   largest such combo has only 39 orders. I kept the requested grain but lowered the threshold to **≥25**
   so the question is actually answerable. *(See the note in `Section_b_answers.sql` / FINDINGS.md.)*

## Main findings (full detail in `FINDINGS.md`)

1. The delay problem is **three broken lanes**: Delhivery→Jaipur (87%), Delhivery→Lucknow (87%),
   Ekart→Kolkata (81%) — vs a ~28% baseline.
2. **InHouse is ~4× better** than third-party carriers (7.4% vs 27–33% late) but only runs in metros.
3. **GMV is 76% Electronics** — the high-value, delay-sensitive category.
4. A delayed *first* order has only a **~1pp** effect on 90-day repeat (weaker than expected).
5. The business is **flat**, so retention economics dominate.

## How to run

**SQL:** load the six provided CSVs into a MySQL database (`OJ_Commerce`), then run the `.sql` files in
order — `Dataset_overview.sql`, `Section_a_answers.sql`, `Section_b_answers.sql`.

**Dashboard:** everything is in the **`dashboard_app/`** folder. From there:
`pip install -r requirements.txt` then `streamlit run application.py` (opens at `localhost:8501`).
Full steps + an explanation of how `dashboard_data.csv` is built are in **`dashboard_app/HOW_TO_RUN_APP.md`**.

---

## Section D — Use of AI Tools (and how I verified everything)

I want to be straightforward about this, since the brief asks for it.

I used an AI coding assistant to help me **draft** the SQL structure, the dashboard boilerplate, and the
write-ups. But the analysis is mine: I made the judgement calls, I ran everything myself, and I checked
every output before trusting it. Here's exactly how.

**Where I used AI:**
- Drafting the SQL for Sections A and B (the CTE structure, window functions) and the small `v_order_gmv` view.
- The Streamlit for the dashboard.
- Tidying up the explanatory text in these markdown files.

**The decisions I made myself (not the AI):**
- Choosing the "delayed = bucket vs formula" definition — I looked at both numbers (26% vs 8%), dug into
  *why* they differed, and decided the bucket was the right call.
- The metric definitions (delivered, repeat, active customer, GMV before fee) and the dashboard layout.

**How I verified the outputs were correct:**
- I ran **every query myself in MySQL Workbench** and read the results
- I **reconciled the totals**: I confirmed GMV always sums to ₹339 crore and orders to 100,000 across the
  different queries, so I knew nothing was being silently dropped in the joins.
- For the delay-definition question, I compared the bucket vs formula numbers side by side and inspected
  sample delivery timestamps to understand the discrepancy before deciding.
- For the dashboard, I checked its KPI numbers against my SQL results (GMV ₹339.20 Cr, delayed rate 26.4%,
  repeat rate 80.0% all matched) and ran the app to confirm the charts and filters behave correctly.

I'm comfortable walking through any query or part of the app, explaining why I built it that way, and
modifying it live.
