"""
LegalEntity Financial Summary
Report 1: Internal-entity Annual Cash Flow (inflows vs outflows bar + net line)
Report 2: 6-Month Cash-Flow Forecast from open invoices
Report 3: External entity comparison table with Directus deep-links
"""

import streamlit as st
import pandas as pd
import numpy as np
import plotly.graph_objects as go
import os
import urllib.parse
from datetime import date
from dateutil.relativedelta import relativedelta
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

# ── Auth Guard ───────────────────────────────────────────────────────────────
if not st.session_state.get("user_email"):
    st.warning("🔐 Please sign in from the **Home** page first.")
    st.stop()

USER_EMAIL = st.session_state["user_email"]

# ── Styling ──────────────────────────────────────────────────────────────────
st.markdown("""
<style>
    @import url('https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap');
    html, body, [class*="st-"] { font-family: 'Inter', sans-serif; }
    .block-container { padding-top: 2rem; }
    h1 {
        background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
        -webkit-background-clip: text;
        -webkit-text-fill-color: transparent;
        font-weight: 700;
    }
    .stMetric > div {
        background: linear-gradient(135deg, #1a1a2e 0%, #16213e 100%);
        border: 1px solid rgba(102, 126, 234, 0.3);
        border-radius: 12px;
        padding: 1rem;
    }
</style>
""", unsafe_allow_html=True)


# ── Database ─────────────────────────────────────────────────────────────────
@st.cache_resource
def get_engine():
    db_user = os.environ.get("DB_USER", "bs4_dev")
    db_pass = urllib.parse.quote_plus(os.environ.get("DB_PASS", ""))
    db_name = os.environ.get("DB_NAME", "bidstruct4")
    instance_conn = os.environ.get("INSTANCE_CONNECTION_NAME")
    if instance_conn:
        socket_dir = "/cloudsql"
        url = (
            f"postgresql+psycopg2://{db_user}:{db_pass}@/{db_name}"
            f"?host={socket_dir}/{instance_conn}"
        )
    else:
        db_host = os.environ.get("DB_HOST", "213.55.244.201")
        url = f"postgresql+psycopg2://{db_user}:{db_pass}@{db_host}:5432/{db_name}?sslmode=require"
    return create_engine(url, pool_pre_ping=True)


DB_SCHEMA = os.environ.get("DB_SCHEMA", "BS4Prod09Feb2026")
DIRECTUS_BASE = "https://bs4.expertflow.com"


# ══════════════════════════════════════════════════════════════════════════════
# REPORT 1: Internal-Entity Annual Cash Flow
# ══════════════════════════════════════════════════════════════════════════════

@st.cache_data(ttl=600, show_spinner=False)
def fetch_internal_annual_cashflow(schema: str) -> pd.DataFrame:
    """
    Annual inflows/outflows for LegalEntity.Type = 'Internal'.
    - Inflow:  DestinationAccount belongs to Internal entity (money IN)
    - Outflow: OriginAccount belongs to Internal entity (money OUT)
    - Excluded: Both legs belong to Internal entities (internal transfers)
    """
    engine = get_engine()
    query = text(f"""
        SELECT
            EXTRACT(YEAR FROM t."Date")::int AS year,
            SUM(CASE
                WHEN dest_le."Type" = 'Internal'
                 AND (orig_le."Type" IS NULL OR orig_le."Type" != 'Internal')
                THEN t."USDAmount" ELSE 0
            END) AS inflows,
            SUM(CASE
                WHEN orig_le."Type" = 'Internal'
                 AND (dest_le."Type" IS NULL OR dest_le."Type" != 'Internal')
                THEN t."USDAmount" ELSE 0
            END) AS outflows
        FROM "{schema}"."Transaction" t
        LEFT JOIN "{schema}"."Account" oa ON t."OriginAccount" = oa.id
        LEFT JOIN "{schema}"."Account" da ON t."DestinationAccount" = da.id
        LEFT JOIN "{schema}"."LegalEntity" orig_le ON oa."LegalEntity" = orig_le.id
        LEFT JOIN "{schema}"."LegalEntity" dest_le ON da."LegalEntity" = dest_le.id
        WHERE t."USDAmount" IS NOT NULL AND t."USDAmount" != 0
          AND t."Date" IS NOT NULL
          AND (
            (orig_le."Type" = 'Internal'
             AND (dest_le."Type" IS NULL OR dest_le."Type" != 'Internal'))
            OR
            (dest_le."Type" = 'Internal'
             AND (orig_le."Type" IS NULL OR orig_le."Type" != 'Internal'))
          )
        GROUP BY year
        ORDER BY year
    """)

    with engine.connect() as conn:
        df = pd.read_sql(query, conn)

    df["inflows"] = pd.to_numeric(df["inflows"], errors="coerce").fillna(0)
    df["outflows"] = pd.to_numeric(df["outflows"], errors="coerce").fillna(0)
    df["net"] = df["inflows"] - df["outflows"]
    return df


# ══════════════════════════════════════════════════════════════════════════════
# REPORT 2: 6-Month Forecast from Open Invoices
# ══════════════════════════════════════════════════════════════════════════════

@st.cache_data(ttl=600, show_spinner=False)
def fetch_open_invoice_forecast(schema: str) -> tuple[pd.DataFrame, pd.DataFrame]:
    """
    Fetch open (Status='Sent') invoices with one leg to an Internal entity.
    Uses RecurMonths to project recurring invoices into future months.
    Returns (raw_invoices_df, monthly_forecast_df).
    """
    engine = get_engine()
    query = text(f"""
        SELECT
            i.id,
            i."Description",
            i."USDAmount",
            i."DueDate",
            i."SentDate",
            COALESCE(i."RecurMonths", 0) AS "RecurMonths",
            oa_le."Name" AS origin_entity,
            oa_le."Type" AS origin_type,
            da_le."Name" AS dest_entity,
            da_le."Type" AS dest_type,
            CASE
                WHEN da_le."Type" = 'Internal'
                 AND (oa_le."Type" IS NULL OR oa_le."Type" != 'Internal')
                THEN 'inflow'
                WHEN oa_le."Type" = 'Internal'
                 AND (da_le."Type" IS NULL OR da_le."Type" != 'Internal')
                THEN 'outflow'
            END AS direction
        FROM "{schema}"."Invoice" i
        LEFT JOIN "{schema}"."Account" oa ON i."OriginAccount" = oa.id
        LEFT JOIN "{schema}"."Account" da ON i."DestinationAccount" = da.id
        LEFT JOIN "{schema}"."LegalEntity" oa_le ON oa."LegalEntity" = oa_le.id
        LEFT JOIN "{schema}"."LegalEntity" da_le ON da."LegalEntity" = da_le.id
        WHERE i."Status" = 'Sent'
          AND i."USDAmount" IS NOT NULL AND i."USDAmount" != 0
          AND (
            (oa_le."Type" = 'Internal'
             AND (da_le."Type" IS NULL OR da_le."Type" != 'Internal'))
            OR
            (da_le."Type" = 'Internal'
             AND (oa_le."Type" IS NULL OR oa_le."Type" != 'Internal'))
          )
        ORDER BY i."DueDate"
    """)

    with engine.connect() as conn:
        inv_df = pd.read_sql(query, conn)

    inv_df["USDAmount"] = pd.to_numeric(inv_df["USDAmount"], errors="coerce").fillna(0)
    inv_df["RecurMonths"] = pd.to_numeric(inv_df["RecurMonths"], errors="coerce").fillna(0).astype(int)
    inv_df["DueDate"] = pd.to_datetime(inv_df["DueDate"], errors="coerce")

    # Build monthly forecast for the next 6 months
    today = date.today()
    forecast_start = today.replace(day=1)  # first of current month
    months = [forecast_start + relativedelta(months=m) for m in range(6)]
    month_labels = [m.strftime("%Y-%m") for m in months]
    # End of forecast window
    forecast_end = forecast_start + relativedelta(months=6)

    forecast_rows = []
    for ml in month_labels:
        forecast_rows.append({"month": ml, "inflows": 0.0, "outflows": 0.0})
    forecast = pd.DataFrame(forecast_rows)

    def add_to_forecast(month_str: str, amount: float, direction: str):
        """Add amount to the correct forecast bucket."""
        if month_str in month_labels:
            idx = month_labels.index(month_str)
            if direction == "inflow":
                forecast.loc[idx, "inflows"] += amount
            else:
                forecast.loc[idx, "outflows"] += amount

    for _, row in inv_df.iterrows():
        if pd.isna(row["DueDate"]):
            continue

        amt = float(row["USDAmount"])
        direction = row["direction"]
        recur = int(row["RecurMonths"])
        due = row["DueDate"].to_pydatetime().date()

        if recur <= 0:
            # One-time invoice: place at DueDate month
            add_to_forecast(due.strftime("%Y-%m"), amt, direction)
        else:
            # Recurring invoice: starting from DueDate, repeat every RecurMonths
            # Generate all occurrences that fall within the forecast window
            occurrence = due
            while occurrence < forecast_end:
                if occurrence >= forecast_start:
                    add_to_forecast(occurrence.strftime("%Y-%m"), amt, direction)
                occurrence = occurrence + relativedelta(months=recur)

    forecast["net"] = forecast["inflows"] - forecast["outflows"]
    return inv_df, forecast


# ══════════════════════════════════════════════════════════════════════════════
# REPORT 3: External Entity Comparison
# ══════════════════════════════════════════════════════════════════════════════

@st.cache_data(ttl=600, show_spinner=False)
def fetch_entity_comparison(schema: str) -> pd.DataFrame:
    engine = get_engine()
    query = text(f"""
        WITH invoice_sums AS (
            SELECT lei.legal_entity_id AS le_id,
                   COALESCE(SUM(i."USDAmount"), 0) AS total_invoices
            FROM "{schema}"."LegalEntity_Invoice" lei
            JOIN "{schema}"."Invoice" i ON lei.invoice_id = i.id
            GROUP BY lei.legal_entity_id
        ),
        transaction_sums AS (
            SELECT let.legal_entity_id AS le_id,
                   COALESCE(SUM(t."USDAmount"), 0) AS total_transactions
            FROM "{schema}"."LegalEntity_Transaction" let
            JOIN "{schema}"."Transaction" t ON let.transaction_id = t.id
            GROUP BY let.legal_entity_id
        )
        SELECT
            le.id,
            le."Name",
            COALESCE(inv.total_invoices, 0)      AS "TotalInvoicesUSD",
            COALESCE(txn.total_transactions, 0)   AS "TotalTransactionsUSD",
            COALESCE(inv.total_invoices, 0)
              - COALESCE(txn.total_transactions, 0) AS "DifferenceUSD"
        FROM "{schema}"."LegalEntity" le
        LEFT JOIN invoice_sums inv ON le.id = inv.le_id
        LEFT JOIN transaction_sums txn ON le.id = txn.le_id
        WHERE (COALESCE(inv.total_invoices, 0) != 0
           OR COALESCE(txn.total_transactions, 0) != 0)
          AND le."Type" != 'Internal'
        ORDER BY ABS(COALESCE(inv.total_invoices, 0)
                   - COALESCE(txn.total_transactions, 0)) DESC
        LIMIT 100
    """)

    with engine.connect() as conn:
        df = pd.read_sql(query, conn)

    for col in ["TotalInvoicesUSD", "TotalTransactionsUSD", "DifferenceUSD"]:
        df[col] = pd.to_numeric(df[col], errors="coerce").fillna(0)
    return df


# ══════════════════════════════════════════════════════════════════════════════
# PAGE LAYOUT
# ══════════════════════════════════════════════════════════════════════════════

st.title("🏢 LegalEntity Financial Summary")

# ─────────────────────────────────────────────────────────────────────────────
# REPORT 1: Internal-Entity Annual Cash Flow
# ─────────────────────────────────────────────────────────────────────────────
st.header("📊 Internal Entities — Annual Cash Flow")
st.caption("Transactions where one leg belongs to a LegalEntity of Type = Internal, excluding internal-to-internal transfers")

with st.spinner("Loading annual cash flow…"):
    cf_df = fetch_internal_annual_cashflow(DB_SCHEMA)

if not cf_df.empty:
    kpi1, kpi2, kpi3 = st.columns(3)
    total_in = cf_df["inflows"].sum()
    total_out = cf_df["outflows"].sum()
    total_net = cf_df["net"].sum()
    kpi1.metric("Total Inflows (all time)", f"${total_in:,.0f}")
    kpi2.metric("Total Outflows (all time)", f"${total_out:,.0f}")
    kpi3.metric("Net (all time)", f"${total_net:,.0f}",
                delta=f"{'↑' if total_net > 0 else '↓'} ${abs(total_net):,.0f}")

    fig = go.Figure()
    fig.add_trace(go.Bar(
        x=cf_df["year"], y=cf_df["inflows"],
        name="Inflows (to Internal)",
        marker_color="#4ade80",
        hovertemplate="Year: %{x}<br>Inflows: $%{y:,.0f}<extra></extra>",
    ))
    fig.add_trace(go.Bar(
        x=cf_df["year"], y=-cf_df["outflows"],
        name="Outflows (from Internal)",
        marker_color="#f87171",
        hovertemplate="Year: %{x}<br>Outflows: -$%{customdata:,.0f}<extra></extra>",
        customdata=cf_df["outflows"],
    ))
    fig.add_trace(go.Scatter(
        x=cf_df["year"], y=cf_df["net"],
        name="Net Cash Flow",
        mode="lines+markers",
        line=dict(color="#667eea", width=3),
        marker=dict(size=6),
        hovertemplate="Year: %{x}<br>Net: $%{y:,.0f}<extra></extra>",
    ))
    fig.add_hline(y=0, line_dash="dot", line_color="rgba(255,255,255,0.3)")
    fig.update_layout(
        barmode="relative",
        template="plotly_dark",
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        font=dict(family="Inter"),
        height=500,
        margin=dict(l=20, r=20, t=40, b=20),
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        xaxis=dict(title="Year", dtick=1),
        yaxis=dict(title="USD Amount", tickformat="$,.0f"),
    )
    st.plotly_chart(fig, use_container_width=True)

    with st.expander("📋 Annual Cash Flow Data"):
        display_cf = cf_df.copy()
        display_cf.columns = ["Year", "Inflows (USD)", "Outflows (USD)", "Net (USD)"]
        st.dataframe(display_cf, use_container_width=True, hide_index=True,
                      column_config={
                          "Year": st.column_config.NumberColumn("Year", format="%d"),
                          "Inflows (USD)": st.column_config.NumberColumn(format="$%,.0f"),
                          "Outflows (USD)": st.column_config.NumberColumn(format="$%,.0f"),
                          "Net (USD)": st.column_config.NumberColumn(format="$%,.0f"),
                      })
else:
    st.info("No transaction data found.")


# ─────────────────────────────────────────────────────────────────────────────
# REPORT 2: 6-Month Forecast from Open Invoices
# ─────────────────────────────────────────────────────────────────────────────
st.markdown("---")
st.header("🔮 6-Month Cash Flow Forecast")
st.caption("Based on open invoices (Status = Sent) with one leg to an Internal entity, placed at DueDate month")

with st.spinner("Loading forecast…"):
    inv_df, forecast_df = fetch_open_invoice_forecast(DB_SCHEMA)

if not forecast_df.empty and forecast_df[["inflows", "outflows"]].sum().sum() > 0:
    kpi1, kpi2, kpi3 = st.columns(3)
    fc_in = forecast_df["inflows"].sum()
    fc_out = forecast_df["outflows"].sum()
    fc_net = forecast_df["net"].sum()
    kpi1.metric("Forecast Inflows (6 mo)", f"${fc_in:,.0f}")
    kpi2.metric("Forecast Outflows (6 mo)", f"${fc_out:,.0f}")
    kpi3.metric("Net Forecast (6 mo)", f"${fc_net:,.0f}",
                delta=f"{'↑' if fc_net > 0 else '↓'} ${abs(fc_net):,.0f}")

    fig2 = go.Figure()
    fig2.add_trace(go.Bar(
        x=forecast_df["month"], y=forecast_df["inflows"],
        name="Expected Inflows",
        marker_color="#4ade80",
        hovertemplate="Month: %{x}<br>Inflows: $%{y:,.0f}<extra></extra>",
    ))
    fig2.add_trace(go.Bar(
        x=forecast_df["month"], y=-forecast_df["outflows"],
        name="Expected Outflows",
        marker_color="#f87171",
        hovertemplate="Month: %{x}<br>Outflows: -$%{customdata:,.0f}<extra></extra>",
        customdata=forecast_df["outflows"],
    ))
    fig2.add_trace(go.Scatter(
        x=forecast_df["month"], y=forecast_df["net"],
        name="Net Forecast",
        mode="lines+markers",
        line=dict(color="#a78bfa", width=3, dash="dash"),
        marker=dict(size=8),
        hovertemplate="Month: %{x}<br>Net: $%{y:,.0f}<extra></extra>",
    ))

    # Cumulative net line
    forecast_df["cumulative_net"] = forecast_df["net"].cumsum()
    fig2.add_trace(go.Scatter(
        x=forecast_df["month"], y=forecast_df["cumulative_net"],
        name="Cumulative Net",
        mode="lines+markers",
        line=dict(color="#fbbf24", width=2),
        marker=dict(size=5),
        hovertemplate="Month: %{x}<br>Cumulative: $%{y:,.0f}<extra></extra>",
    ))

    fig2.add_hline(y=0, line_dash="dot", line_color="rgba(255,255,255,0.3)")
    fig2.update_layout(
        barmode="relative",
        template="plotly_dark",
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        font=dict(family="Inter"),
        height=450,
        margin=dict(l=20, r=20, t=40, b=20),
        legend=dict(orientation="h", yanchor="bottom", y=1.02, xanchor="right", x=1),
        xaxis=dict(title="Month"),
        yaxis=dict(title="USD Amount", tickformat="$,.0f"),
    )
    st.plotly_chart(fig2, use_container_width=True)

    # Forecast data table
    with st.expander("📋 Monthly Forecast Data"):
        display_fc = forecast_df[["month", "inflows", "outflows", "net"]].copy()
        display_fc.columns = ["Month", "Inflows (USD)", "Outflows (USD)", "Net (USD)"]
        st.dataframe(display_fc, use_container_width=True, hide_index=True,
                      column_config={
                          "Inflows (USD)": st.column_config.NumberColumn(format="$%,.0f"),
                          "Outflows (USD)": st.column_config.NumberColumn(format="$%,.0f"),
                          "Net (USD)": st.column_config.NumberColumn(format="$%,.0f"),
                      })

    # Underlying open invoices detail
    with st.expander(f"📄 Open Invoices Detail ({len(inv_df)} invoices)"):
        display_inv = inv_df[["id", "Description", "USDAmount", "DueDate",
                              "direction", "origin_entity", "dest_entity"]].copy()
        display_inv["DueDate"] = display_inv["DueDate"].dt.strftime("%Y-%m-%d")
        st.dataframe(display_inv, use_container_width=True, hide_index=True, height=400,
                      column_config={
                          "id": st.column_config.NumberColumn("ID", width="small"),
                          "Description": st.column_config.TextColumn("Description", width="large"),
                          "USDAmount": st.column_config.NumberColumn("USD Amount", format="$%,.0f"),
                          "DueDate": st.column_config.TextColumn("Due Date"),
                          "direction": st.column_config.TextColumn("Direction"),
                          "origin_entity": st.column_config.TextColumn("From"),
                          "dest_entity": st.column_config.TextColumn("To"),
                      })
else:
    st.info("No open invoices fall within the next 6 months.")


# ─────────────────────────────────────────────────────────────────────────────
# REPORT 3: External Entity Comparison
# ─────────────────────────────────────────────────────────────────────────────
st.markdown("---")
st.header("🏷️ External Entity Summary")
st.caption("Top 100 non-Internal entities ranked by |Invoices − Transactions|")

with st.spinner("Loading entity data…"):
    df = fetch_entity_comparison(DB_SCHEMA)

if not df.empty:
    kpi1, kpi2, kpi3, kpi4 = st.columns(4)
    kpi1.metric("Entities", f"{len(df):,}")
    kpi2.metric("Total Invoices", f"${df['TotalInvoicesUSD'].sum():,.0f}")
    kpi3.metric("Total Transactions", f"${df['TotalTransactionsUSD'].sum():,.0f}")
    kpi4.metric("Total Difference", f"${df['DifferenceUSD'].sum():,.0f}")

    df["Directus Link"] = df["id"].apply(
        lambda x: f"{DIRECTUS_BASE}/admin/content/LegalEntity/{x}"
    )
    st.dataframe(
        df, use_container_width=True, height=600, hide_index=True,
        column_config={
            "id": st.column_config.NumberColumn("ID", width="small"),
            "Name": st.column_config.TextColumn("Legal Entity", width="medium"),
            "TotalInvoicesUSD": st.column_config.NumberColumn("Invoices (USD)", format="$%,.0f"),
            "TotalTransactionsUSD": st.column_config.NumberColumn("Transactions (USD)", format="$%,.0f"),
            "DifferenceUSD": st.column_config.NumberColumn("Difference (USD)", format="$%,.0f"),
            "Directus Link": st.column_config.LinkColumn("Open in Directus", display_text="View →", width="small"),
        },
        column_order=["id", "Name", "TotalInvoicesUSD", "TotalTransactionsUSD", "DifferenceUSD", "Directus Link"],
    )

st.markdown("---")
st.caption(f"Data cached for 10 minutes • Logged in as **{USER_EMAIL}**")
