"""
Generic Bank Parser for BMAD (Story 3.1 fallback).
Expects a CSV with columns: Date, Amount, Description, TransactionID (optional).
"""

from __future__ import annotations
import csv
from decimal import Decimal, InvalidOperation
from io import StringIO
from pathlib import Path
from typing import Any

def parse_decimal(val: str | None) -> Decimal | None:
    if not val: return None
    try:
        return Decimal(val.strip().replace("'", "").replace(",", ""))
    except InvalidOperation:
        return None

def parse_file(path: str | Path) -> list[dict[str, Any]]:
    path = Path(path)
    text = path.read_text(encoding="utf-8-sig")
    return parse_string(text)

def parse_string(text: str) -> list[dict[str, Any]]:
    reader = csv.DictReader(StringIO(text))
    out: list[dict[str, Any]] = []
    
    # Normalization map for flexible headers
    HMAP = {
        'Date': ['Date', 'date', 'Booking Date', 'Valutadatum'],
        'Amount': ['Amount', 'amount', 'Value', 'Betrag', 'Individual amount'],
        'Description': ['Description', 'description', 'Narrative', 'Verwendungszweck'],
        'BankTransactionID': ['BankTransactionID', 'ID', 'Transaction ID', 'Transaction no.']
    }

    for row in reader:
        # Resolve columns
        d_val = next((row.get(h) for h in HMAP['Date'] if row.get(h)), None)
        a_val = next((row.get(h) for h in HMAP['Amount'] if row.get(h)), None)
        desc = next((row.get(h) for h in HMAP['Description'] if row.get(h)), "")
        tid = next((row.get(h) for h in HMAP['BankTransactionID'] if row.get(h)), None)

        amt = parse_decimal(a_val)
        if amt is None or not d_val:
            continue
            
        out.append({
            "BankTransactionID": tid.strip() if tid else None,
            "Date": d_val.strip()[:10], # Assumes YYYY-MM-DD or similar
            "Amount": str(amt),
            "Description": desc.strip(),
            "Transaction": None
        })
    return out
