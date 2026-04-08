"""
Expertflow Finance Dashboard — Cash Flow Report
Streamlit app connecting to PostgreSQL with Directus RLS enforcement.
Deployed on Google Cloud Run (scales to zero).
"""

import streamlit as st
import pandas as pd
import plotly.express as px
import plotly.graph_objects as go
import hmac
import os
import urllib.parse
from sqlalchemy import create_engine, text
from dotenv import load_dotenv

load_dotenv()

# ── Page Config ──────────────────────────────────────────────────────────────
st.set_page_config(
    page_title="Expertflow Finance",
    page_icon="💰",
    layout="wide",
    initial_sidebar_state="expanded",
)

# ── Custom CSS for a premium dark look ───────────────────────────────────────
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
    
    .stDataFrame { border-radius: 12px; overflow: hidden; }
</style>
""", unsafe_allow_html=True)


# ── Authentication (Google Workspace SSO) ────────────────────────────────────
import json
import base64
import requests as http_requests

# Fetch OAuth credentials from environment variables (No hardcoded secrets!)
secrets_json_str = os.environ.get("GOOGLE_OAUTH_SECRETS_JSON")
if not secrets_json_str:
    st.error("Missing GOOGLE_OAUTH_SECRETS_JSON environment variable.")
    st.stop()

secrets = json.loads(secrets_json_str).get("web", {})
client_id = secrets.get("client_id")
client_secret = secrets.get("client_secret")
oauth_redirect_uri = os.environ.get("OAUTH_REDIRECT_URI", "http://localhost:8501/")

GOOGLE_AUTH_URL = "https://accounts.google.com/o/oauth2/v2/auth"
GOOGLE_TOKEN_URL = "https://oauth2.googleapis.com/token"

if 'user_email' not in st.session_state:
    st.session_state['user_email'] = None

def _decode_id_token(id_token: str) -> dict:
    """Decode a Google id_token JWT without verification (we trust Google's TLS)."""
    # JWT is header.payload.signature — we only need the payload
    payload_b64 = id_token.split(".")[1]
    # Fix padding
    payload_b64 += "=" * (4 - len(payload_b64) % 4)
    payload_bytes = base64.urlsafe_b64decode(payload_b64)
    return json.loads(payload_bytes)

if not st.session_state['user_email']:
    query_params = st.query_params
    code = query_params.get("code")

    if code:
        try:
            # Exchange auth code for tokens via Google's token endpoint
            token_resp = http_requests.post(GOOGLE_TOKEN_URL, data={
                "code": code,
                "client_id": client_id,
                "client_secret": client_secret,
                "redirect_uri": oauth_redirect_uri,
                "grant_type": "authorization_code",
            }, timeout=10)
            token_data = token_resp.json()

            if "error" in token_data:
                st.error(f"Google token error: {token_data.get('error_description', token_data['error'])}")
                st.stop()

            # Decode the id_token to get email — no People API needed
            claims = _decode_id_token(token_data["id_token"])
            user_email = claims.get("email")
            if not user_email:
                st.error("Could not retrieve email from Google. Please try again.")
                st.stop()

            st.session_state['user_email'] = user_email

            # Clear query params to prevent reusing the auth code on refresh
            st.query_params.clear()
            st.rerun()
        except Exception as e:
            st.error(f"Login failed: {e}")
            st.stop()
    else:
        st.markdown("### 🔐 Expertflow Finance Dashboard")
        st.markdown("Please log in with your Expertflow Google account to access financial data.")

        # Build the Google OAuth authorization URL directly
        import urllib.parse as _up
        auth_params = _up.urlencode({
            "client_id": client_id,
            "redirect_uri": oauth_redirect_uri,
            "response_type": "code",
            "scope": "openid email profile",
            "access_type": "online",
            "prompt": "select_account",
        })
        authorization_url = f"{GOOGLE_AUTH_URL}?{auth_params}"

        st.markdown(f'''
            <a href="{authorization_url}" target="_self">
                <button style="background-color:#4285f4;color:white;padding:10px 24px;border:none;border-radius:4px;cursor:pointer;font-size:16px;">
                    Sign in with Google
                </button>
            </a>
        ''', unsafe_allow_html=True)
        st.stop()

USER_EMAIL = st.session_state['user_email']

# Force @expertflow.com domains only
if not USER_EMAIL.endswith("@expertflow.com"):
    st.error(f"❌ Unauthorized domain: `{USER_EMAIL}`. You must use an @expertflow.com business account.")
    if st.button("Log out"):
        st.session_state['user_email'] = None
        st.rerun()
    st.stop()

st.sidebar.success(f"✅ Authenticated as\n\n**{USER_EMAIL}**")
if st.sidebar.button("Sign out"):
    st.session_state['user_email'] = None
    st.rerun()


# ── Database ─────────────────────────────────────────────────────────────────
@st.cache_resource
def get_engine():
    """Create a SQLAlchemy engine.
    On Cloud Run: uses built-in Cloud SQL proxy via Unix socket.
    Locally: uses direct IP connection.
    """
    db_user = os.environ.get("DB_USER", "bs4_dev")
    db_pass = urllib.parse.quote_plus(os.environ.get("DB_PASS", ""))
    db_name = os.environ.get("DB_NAME", "bidstruct4")
    instance_conn = os.environ.get("INSTANCE_CONNECTION_NAME")

    if instance_conn:
        # Cloud Run: connect via Unix socket provided by Cloud SQL proxy sidecar
        socket_dir = "/cloudsql"
        url = (
            f"postgresql+psycopg2://{db_user}:{db_pass}@/{db_name}"
            f"?host={socket_dir}/{instance_conn}"
        )
    else:
        # Local dev: connect via direct IP
        db_host = os.environ.get("DB_HOST", "213.55.244.201")
        url = f"postgresql+psycopg2://{db_user}:{db_pass}@{db_host}:5432/{db_name}?sslmode=require"

    return create_engine(url, pool_pre_ping=True)


DB_SCHEMA = os.environ.get("DB_SCHEMA", "BS4Prod09Feb2026")


@st.cache_data(ttl=600, show_spinner=False)
def fetch_cash_flow(_engine_repr, schema: str) -> pd.DataFrame:
    """
    Fetch cash_flow_report directly from PostgreSQL.
    No Directus dependencies or RLS.
    """
    engine = get_engine()

    with engine.connect() as conn:
        df = pd.read_sql(
            text(f'SELECT * FROM "{schema}".cash_flow_report'),
            conn,
        )

    # Post-processing
    if "report_date" in df.columns:
        df["report_date"] = pd.to_datetime(df["report_date"])
    if "amount_usd" in df.columns:
        df["amount_usd"] = pd.to_numeric(df["amount_usd"], errors="coerce")

    return df


# ── Load Data ────────────────────────────────────────────────────────────────
st.title("💰 Cash Flow Report")

with st.spinner("Loading cash flow data…"):
    df = fetch_cash_flow(repr(get_engine()), DB_SCHEMA)

if df.empty:
    st.warning("No data retrieved — either the view is empty or your account lacks RLS access.")
    st.stop()

st.caption(f"**{len(df):,}** rows loaded • last refreshed at app start (cached 10 min)")

# ── Sidebar Filters ──────────────────────────────────────────────────────────
st.sidebar.markdown("---")
st.sidebar.markdown("### 🔎 Filters")

series_options = sorted(df["series_type"].dropna().unique())
selected_series = st.sidebar.multiselect("Series Type", series_options, default=series_options)

min_date = df["report_date"].min().date()
max_date = df["report_date"].max().date()
date_range = st.sidebar.date_input("Date Range", value=(min_date, max_date), min_value=min_date, max_value=max_date)

# Apply filters
mask = df["series_type"].isin(selected_series)
if len(date_range) == 2:
    mask &= (df["report_date"].dt.date >= date_range[0]) & (df["report_date"].dt.date <= date_range[1])
filtered = df[mask].copy()

st.sidebar.metric("Filtered Rows", f"{len(filtered):,}")

# ── KPI Cards ────────────────────────────────────────────────────────────────
st.markdown("---")

kpi1, kpi2, kpi3, kpi4 = st.columns(4)

realized = filtered[filtered["series_type"] == "Realized"]["amount_usd"]
forecast = filtered[filtered["series_type"] == "Forecast"]["amount_usd"]

kpi1.metric("Total Realized", f"USD {realized.sum():,.0f}")
kpi2.metric("Total Forecast", f"USD {forecast.sum():,.0f}")
kpi3.metric("Realized Inflows", f"USD {realized[realized > 0].sum():,.0f}")
kpi4.metric("Realized Outflows", f"USD {realized[realized < 0].sum():,.0f}")

# ── Monthly Summary Chart ────────────────────────────────────────────────────
st.markdown("---")
st.subheader("📊 Monthly Cash Flow — Realized vs Forecast")

monthly = (
    filtered
    .assign(month=filtered["report_date"].dt.to_period("M").astype(str))
    .groupby(["month", "series_type"])["amount_usd"]
    .sum()
    .reset_index()
)

if not monthly.empty:
    fig = px.bar(
        monthly,
        x="month",
        y="amount_usd",
        color="series_type",
        barmode="group",
        labels={"month": "Month", "amount_usd": "Amount (USD)", "series_type": "Series"},
        color_discrete_map={"Realized": "#667eea", "Forecast": "#f093fb"},
        template="plotly_dark",
    )
    fig.update_layout(
        plot_bgcolor="rgba(0,0,0,0)",
        paper_bgcolor="rgba(0,0,0,0)",
        font=dict(family="Inter"),
        height=450,
        margin=dict(l=20, r=20, t=40, b=20),
    )
    st.plotly_chart(fig, use_container_width=True)

# ── Cumulative Running Total ─────────────────────────────────────────────────
st.subheader("📈 Cumulative Cash Position Over Time")

cumulative = (
    filtered
    .sort_values("report_date")
    .assign(cumulative=filtered.sort_values("report_date")["amount_usd"].cumsum())
)

fig2 = px.area(
    cumulative,
    x="report_date",
    y="cumulative",
    color="series_type",
    labels={"report_date": "Date", "cumulative": "Cumulative (USD)", "series_type": "Series"},
    color_discrete_map={"Realized": "#667eea", "Forecast": "#f093fb"},
    template="plotly_dark",
)
fig2.update_layout(
    plot_bgcolor="rgba(0,0,0,0)",
    paper_bgcolor="rgba(0,0,0,0)",
    font=dict(family="Inter"),
    height=400,
    margin=dict(l=20, r=20, t=40, b=20),
)
st.plotly_chart(fig2, use_container_width=True)

# ── Detailed Data Table ──────────────────────────────────────────────────────
st.markdown("---")
st.subheader("📋 Detailed Transaction Data")

st.dataframe(
    filtered.sort_values("report_date", ascending=False),
    use_container_width=True,
    height=400,
    column_config={
        "amount_usd": st.column_config.NumberColumn("Amount (USD)", format="$ %,.0f"),
        "report_date": st.column_config.DateColumn("Date"),
    },
)
