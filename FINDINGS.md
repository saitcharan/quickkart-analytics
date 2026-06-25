# QuickKart — What the Data Tells Us (Consolidated Findings)

This document pulls together everything the analysis surfaced — from the initial data checks
(`Dataset_overview.sql`), the exploratory queries (`Section_a_answers.sql`), the focused SQL questions
(`Section_b_answers.sql`), and the interactive dashboard (`application.py`). It's written for the two
stakeholders: the **Head of Marketplace** and the **Head of Logistics**.

**The data:** 18 months (Jul 2024 – Dec 2025), 100,000 orders, **₹339 crore** gross GMV, ~9.5% blended
take-rate, across 12 cities and 4 carriers.

---

## First, what I had to settle before trusting any number

Before analysing, I checked the data and found a few things that shaped every result:

- **Orders ↔ shipments is 1:1.** Every order has at most one shipment; the 8,006 orders with no shipment
  are all **Cancelled** (cancelled before they ship).
- **`delivery_status` has a 6th value the brief didn't list — `InTransit`** (5,043 not-yet-delivered
  orders). So I only measure delays on orders that actually completed (have a `delivered_at`).
- **The two ways of defining "delayed" disagree.** Using the pre-computed `delivery_status` buckets gives
  **26%** delayed; using the literal `delivered_at > promised_date` formula gives **8%**. The difference
  is a **same-day rule**: 15,831 orders were delivered *exactly on* the promised day — the buckets count
  those as late (`Late_1_2d`), while the strict formula counts same-day as on-time. (63,682 before + 7,008
  strictly after + 15,831 on the day → 26% bucket-late vs 8% formula-late.) **I use the bucket definition**
  (it's what the SQL questions reference, and it reflects misses the customer actually feels). This is
  the single most important assumption in the whole analysis.
- **The promise structure is clean:** fast-eligible orders get 2 days; everyone else gets 3, 4, or 5 days.

---

## The 5 findings that matter

### 1. The delay problem is THREE broken lanes — not a system-wide failure
Overall ~26% of delivered orders are late, but it's heavily concentrated:

| Lane | Delay rate | Baseline elsewhere |
|---|---|---|
| **Delhivery → Jaipur** | **87%** | ~28% |
| **Delhivery → Lucknow** | **87%** | ~28% |
| **Ekart → Kolkata** | **81%** | ~28% |

On every *other* lane the third-party carriers run a fairly uniform ~27–29%.
→ **Recommendation:** Fix or re-assign these three lanes first. It's the single highest-ROI action and
would visibly move the overall on-time number.

### 2. InHouse is ~4× better than every third-party carrier — but only runs in metros
| Carrier | Delayed % |
|---|---|
| Delhivery | 33.2% |
| Ekart | 32.4% |
| BlueDart | 27.3% |
| **InHouse** | **7.4%** |

InHouse only operates in Bangalore, Delhi, Hyderabad, and Mumbai — it never serves the problem cities.
→ **Recommendation:** Extend the InHouse model (or hold 3P carriers contractually to InHouse's SLA) on
the failing lanes.

### 3. GMV is 76% Electronics — the high-value, most delay-sensitive category
| Category | % of GMV |
|---|---|
| **Electronics** | **75.6%** |
| Home & Kitchen | 14.5% |
| Fashion | 7.3% |
| Grocery | 1.4% |
| Books | 1.2% |

QuickKart is, by value, an electronics marketplace. Delivery reliability and GMV protection are the same
problem — the broken lanes are degrading the experience on exactly the products that matter most.
→ **Recommendation:** Prioritise delivery reliability for Electronics into the affected cities.

### 4. A delayed FIRST order has only a small effect on 90-day repeat
| First delivered order | 90-day repeat rate |
|---|---|
| OnTime | 46.2% |
| Delayed | 45.4% |

The gap is only ~1 percentage point, and it's not consistent across delay severity (the worst bucket has
just 8 customers — too few to trust). So the feared "one bad delivery loses the customer" story is **weak
in this data**.
→ **Recommendation:** Don't over-invest in blanket delivery-recovery for marginal 1-day misses; focus on
the genuinely catastrophic lanes. *(Caveat: a longer horizon and controls for city/segment would firm
this up — worth a follow-up.)*

### 5. The business is flat — so retention economics dominate
Orders (~5,500/month), active customers (~4,900/month), and GMV (~₹185–195M/month) are all sideways for
18 months. The repeat-purchase rate climbs from ~9% to ~92%, but that's the **cumulative** definition
mechanically compounding as the customer base matures — not month-over-month loyalty improving.
→ **Recommendation:** With little net-new demand, protecting repeat behaviour on the high-value
Electronics base is worth more than chasing marginal on-time gains everywhere.

---

## How this maps to the deliverables
- **Dataset_overview.sql** → the data checks (1:1 cardinality, the 26%-vs-8% delay finding, the SLA tiers).
- **Section_a_answers.sql** → monthly GMV by city/category, orders & active customers, repeat rate, and
  the delayed-share breakdowns (carrier, city, and the city×carrier cross-tab that pinpoints the 3 lanes).
- **Section_b_answers.sql** → the focused questions (B1 monthly metrics, B2 first-order delay→repeat,
  B3 seller×carrier×city performance, B4 the optimised query).
- **application.py** → lets the stakeholders explore all of this interactively (filter by city, category,
  carrier, date; switch metrics; see the same numbers update live).

---

## The one-line summary for leadership
> Delays look like a 26% platform-wide problem, but they're really **three broken carrier-lanes**
> (Delhivery→Jaipur/Lucknow, Ekart→Kolkata). Fixing those — and extending the InHouse model that already
> runs at 7% late — protects the Electronics GMV that is 76% of the business. The delivery→repeat link is
> weaker than feared, so the priority is the broken lanes, not blanket recovery.
