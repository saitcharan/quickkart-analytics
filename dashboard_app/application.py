# QuickKart — Delivery & Marketplace Dashboard (Streamlit)
# Run: streamlit run application.py   (reads dashboard_data.csv from this folder — no database needed)

import os
import pandas as pd
import plotly.express as px
import streamlit as st

# Page setup
st.set_page_config(page_title="QuickKart Dashboard", page_icon="📦", layout="wide")
st.title("📦 QuickKart — Delivery & Marketplace Dashboard")
st.caption("How delivery performance affects GMV and repeat purchases.")

BRAND = "#2E86AB"
px.defaults.template = "plotly_white"
px.defaults.color_discrete_sequence = [BRAND]

# Load data (cached)
@st.cache_data
def load_data():
    path = os.path.join(os.path.dirname(__file__), "dashboard_data.csv")
    return pd.read_csv(path, parse_dates=["created_at", "month"])

df = load_data()

# Sidebar filters
st.sidebar.header("Filters")
min_date = df["created_at"].min().date()
max_date = df["created_at"].max().date()
date_range = st.sidebar.date_input("📅 Order date range", value=(min_date, max_date),
                                   min_value=min_date, max_value=max_date)

# Multi-select with a "Select all" button
def filter_group(label, options, key):
    if key not in st.session_state:
        st.session_state[key] = options
    st.sidebar.divider()
    if st.sidebar.button("Select all", key=f"{key}_all"):
        st.session_state[key] = options
    return st.sidebar.multiselect(label, options, key=key)

cities     = filter_group("🏙 City",     sorted(df["city"].unique()),     "city")
categories = filter_group("📦 Category", sorted(df["category"].unique()), "category")
carriers   = filter_group("🚚 Carrier",  sorted(df["carrier"].unique()),  "carrier")

st.sidebar.divider()
metric = st.sidebar.radio("📊 Metric to chart", ["GMV", "orders", "repeat_rate", "delayed_order_rate"])

# Apply filters
start, end = (date_range if len(date_range) == 2 else (min_date, max_date))
f = df[(df["created_at"].dt.date >= start) & (df["created_at"].dt.date <= end) &
       (df["city"].isin(cities)) & (df["category"].isin(categories)) & (df["carrier"].isin(carriers))]

if f.empty:
    st.warning("No data for these filters. Try widening them.")
    st.stop()

# Compute any metric on a slice of data
def metric_value(d, name):
    if name == "GMV":
        return d["gmv"].sum()
    if name == "orders":
        return len(d)
    if name == "delayed_order_rate":
        denom = d["has_outcome"].sum()
        return d["is_delayed"].sum() / denom if denom else 0
    if name == "repeat_rate":
        denom = d["customer_id"].nunique()
        return d.loc[d["is_repeat_customer"] == 1, "customer_id"].nunique() / denom if denom else 0

def fmt(name, value):
    if name == "GMV":
        return f"₹{value/1e7:,.2f} Cr"
    if name == "orders":
        return f"{int(value):,}"
    return f"{value*100:.1f}%"

# KPI strip
k1, k2, k3 = st.columns(3)
k1.metric("GMV", fmt("GMV", metric_value(f, "GMV")))
k2.metric("Delayed order rate", fmt("delayed_order_rate", metric_value(f, "delayed_order_rate")))
k3.metric("Repeat rate", fmt("repeat_rate", metric_value(f, "repeat_rate")))
st.divider()

# Time-series by month
st.subheader(f"{metric} by month")
ts = (f.groupby("month").apply(lambda d: metric_value(d, metric), include_groups=False)
        .reset_index(name=metric).sort_values("month"))
fig_ts = px.line(ts, x="month", y=metric, markers=True)
if metric in ("repeat_rate", "delayed_order_rate"):
    fig_ts.update_yaxes(tickformat=".0%")
st.plotly_chart(fig_ts, use_container_width=True)

# Breakdown bar (city / carrier toggle)
st.subheader(f"{metric} breakdown")
dim = st.radio("Break down by", ["city", "carrier"], horizontal=True)
bd = (f.groupby(dim).apply(lambda d: metric_value(d, metric), include_groups=False)
        .reset_index(name=metric).sort_values(metric, ascending=False))
fig_bd = px.bar(bd, x=dim, y=metric, text_auto=".2s")
if metric in ("repeat_rate", "delayed_order_rate"):
    fig_bd.update_yaxes(tickformat=".0%")
st.plotly_chart(fig_bd, use_container_width=True)

# Insights (computed from the filtered view)
st.subheader("💡 Insights for this view")
by_carrier = f[f["has_outcome"] == 1].groupby("carrier")["is_delayed"].mean().sort_values(ascending=False)
by_city = f[f["has_outcome"] == 1].groupby("city")["is_delayed"].mean().sort_values(ascending=False)
top_cat = f.groupby("category")["gmv"].sum().sort_values(ascending=False)

bullets = [
    f"**GMV** in this view is **{fmt('GMV', metric_value(f,'GMV'))}** across **{len(f):,}** orders.",
    f"**{top_cat.index[0]}** is the biggest category by GMV (**{top_cat.iloc[0]/top_cat.sum()*100:.0f}%** here).",
]
if len(by_carrier) > 0:
    bullets.append(f"Worst carrier: **{by_carrier.index[0]}** at **{by_carrier.iloc[0]*100:.0f}%** delayed; "
                   f"best: **{by_carrier.index[-1]}** at **{by_carrier.iloc[-1]*100:.0f}%**.")
if len(by_city) > 0:
    bullets.append(f"Worst city for delays: **{by_city.index[0]}** (**{by_city.iloc[0]*100:.0f}%** late).")
bullets.append(f"Overall **repeat rate** here is **{fmt('repeat_rate', metric_value(f,'repeat_rate'))}**.")

for b in bullets:
    st.markdown("- " + b)
