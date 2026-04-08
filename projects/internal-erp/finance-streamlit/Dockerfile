FROM python:3.11-slim

WORKDIR /app

# Install dependencies required by pg8000 and generic python builds
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .

RUN pip install --no-cache-dir -r requirements.txt

COPY . .

# Cloud Run injects $PORT (default 8080)
ENV PORT="8080"
EXPOSE 8080

HEALTHCHECK CMD curl --fail http://localhost:8080/_stcore/health || exit 1

# Streamlit config for Cloud Run
CMD streamlit run app.py \
    --server.port=$PORT \
    --server.address=0.0.0.0 \
    --server.enableCORS=false \
    --server.enableWebsocketCompression=false
