#!/usr/bin/env python3
"""
CLI for bank CSV → normalized BankStatement-shaped rows (Story 3-1).

Examples:
  python cli.py --input export.csv --account 7 --dry-run --format json
  python cli.py --input export.csv --account 7 --dry-run --format csv -o -
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from dispatch import parse_for_account  # noqa: E402


def main() -> int:
    p = argparse.ArgumentParser(description="Bank statement CSV → normalized rows")
    p.add_argument("--input", "-i", required=True, help="Path to bank CSV file")
    p.add_argument("--account", "-a", type=int, required=True, help="Directus Account id (e.g. 7 USD)")
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Only parse and emit output (default when not using --apply via extension)",
    )
    p.add_argument("--format", choices=("json", "csv"), default="json")
    p.add_argument(
        "--output",
        "-o",
        default="-",
        help="Output file path, or - for stdout (default: -)",
    )
    args = p.parse_args()

    rows = parse_for_account(args.account, args.input)

    out_fp = sys.stdout if args.output == "-" else open(args.output, "w", encoding="utf-8", newline="")

    try:
        if args.format == "json":
            json.dump(rows, out_fp, indent=2, ensure_ascii=False)
            out_fp.write("\n")
        else:
            if not rows:
                return 0
            fieldnames = ["Account", "Date", "Amount", "BankTransactionID", "Description", "Transaction"]
            w = csv.DictWriter(out_fp, fieldnames=fieldnames, extrasaction="ignore")
            w.writeheader()
            for r in rows:
                w.writerow({k: r.get(k, "") for k in fieldnames})
    finally:
        if out_fp is not sys.stdout:
            out_fp.close()

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
