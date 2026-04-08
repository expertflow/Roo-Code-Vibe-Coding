"""
UBS e-banking CSV export (semicolon-delimited).

Product rules (Story 3-1, 2026-03-26):
- Skip metadata lines until header row containing Trade date + Transaction no.
- Group rows by Transaction no.; drop summary row when group has multiple rows
  (keep only rows with Individual amount); single-row groups use Debit / Credit / Individual amount.
- Do not import Footnotes; Trade time, Booking date, Value date, Balance are not stored.
"""

from __future__ import annotations

import csv
from collections import defaultdict
from decimal import Decimal, InvalidOperation
from io import StringIO
from pathlib import Path
from typing import Any


def _strip_row(raw: dict[str, Any]) -> dict[str, str]:
    out: dict[str, str] = {}
    for k, v in raw.items():
        key = (k or "").strip()
        if not key or key.startswith("_col_"):
            continue
        if isinstance(v, list):
            val = " | ".join(str(x).strip() for x in v if str(x).strip())
        else:
            val = (v or "").strip() if isinstance(v, str) else str(v).strip()
        out[key] = val
    return out


def parse_decimal(val: str | None) -> Decimal | None:
    if val is None:
        return None
    s = val.strip().replace(" ", "").replace("'", "")
    if not s:
        return None
    try:
        return Decimal(s.replace(",", "."))
    except InvalidOperation:
        return None


def _find_header_line(lines: list[str]) -> int:
    for i, line in enumerate(lines):
        if "Trade date" in line and "Transaction no." in line:
            return i
    raise ValueError(
        "UBS e-banking CSV: header row not found (expected columns Trade date … Transaction no.)"
    )


def _unique_headers(parts: list[str]) -> list[str]:
    """UBS lines often end with `;` → duplicate empty column names break DictReader."""
    headers: list[str] = []
    seen: dict[str, int] = {}
    for i, raw in enumerate(parts):
        h = raw.strip()
        if not h:
            h = f"_col_{i}"
        elif h in seen:
            seen[h] += 1
            h = f"{h}__{seen[h]}"
        else:
            seen[h] = 0
        headers.append(h)
    return headers


def _read_data_rows(text: str) -> list[dict[str, str]]:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    lines = text.split("\n")
    hdr = _find_header_line(lines)
    hdr_parts = next(csv.reader(StringIO(lines[hdr]), delimiter=";"))
    headers = _unique_headers(list(hdr_parts))
    body = "\n".join(lines[hdr + 1 :])
    reader = csv.reader(StringIO(body), delimiter=";")
    out: list[dict[str, str]] = []
    for parts in reader:
        if not parts or all(not (p or "").strip() for p in parts):
            continue
        row = {headers[j]: (parts[j].strip() if j < len(parts) else "") for j in range(len(headers))}
        out.append(_strip_row(row))
    return out


def merged_description(row: dict[str, str]) -> str:
    parts: list[str] = []
    for key in ("Description1", "Description2", "Description3"):
        t = row.get(key, "").strip()
        if t:
            parts.append(t)
    return " | ".join(parts)


def first_anchor_date(rows: list[dict[str, str]]) -> str:
    for r in rows:
        d = r.get("Trade date", "").strip()
        if d:
            return d[:10] if len(d) >= 10 else d
    for r in rows:
        d = r.get("Booking date", "").strip()
        if d:
            return d[:10] if len(d) >= 10 else d
    return ""


def _row_amount_components(row: dict[str, str]) -> tuple[Decimal | None, Decimal | None, Decimal | None]:
    return (
        parse_decimal(row.get("Debit")),
        parse_decimal(row.get("Credit")),
        parse_decimal(row.get("Individual amount")),
    )


def _emit_row(
    txn: str,
    trade_date: str,
    amount: Decimal,
    description: str,
) -> dict[str, Any]:
    return {
        "BankTransactionID": txn,
        "Date": trade_date,
        "Amount": str(amount),
        "Description": description,
        "Transaction": None,
    }


def parse_file(path: str | Path) -> list[dict[str, Any]]:
    path = Path(path)
    text = path.read_text(encoding="utf-8-sig")
    return parse_string(text)


def parse_string(text: str) -> list[dict[str, Any]]:
    rows = _read_data_rows(text)
    groups: dict[str, list[dict[str, str]]] = defaultdict(list)

    for row in rows:
        txn = row.get("Transaction no.", "").strip()
        if not txn:
            continue
        deb, cred, ind = _row_amount_components(row)
        if deb is None and cred is None and ind is None:
            continue
        groups[txn].append(row)

    out: list[dict[str, Any]] = []
    for txn, grow in groups.items():
        anchor = first_anchor_date(grow)
        if len(grow) == 1:
            r = grow[0]
            deb, cred, ind = _row_amount_components(r)
            if ind is not None:
                amt = ind
            elif deb is not None:
                amt = deb
            elif cred is not None:
                amt = cred
            else:
                continue
            td = r.get("Trade date", "").strip()
            if len(td) >= 10:
                td = td[:10]
            elif anchor:
                td = anchor
            else:
                continue
            out.append(_emit_row(txn, td, amt, merged_description(r)))
        else:
            for r in grow:
                _, _, ind = _row_amount_components(r)
                if ind is None:
                    continue
                td = r.get("Trade date", "").strip()
                if len(td) >= 10:
                    td = td[:10]
                elif anchor:
                    td = anchor
                else:
                    continue
                out.append(_emit_row(txn, td, ind, merged_description(r)))

    return out
