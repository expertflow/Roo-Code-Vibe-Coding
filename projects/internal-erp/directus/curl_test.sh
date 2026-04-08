#!/bin/bash
curl -X POST http://127.0.0.1:8055/bank-statement-import/run \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer undefined" \
  -d '{
    "account": 7,
    "csv": "Transaction no.,Date,Amount,Description\nZD81069TI1276631,2026-03-10,-40000.00,Test from curl"
  }'
