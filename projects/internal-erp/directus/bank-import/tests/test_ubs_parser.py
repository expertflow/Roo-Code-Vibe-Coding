"""Tests for UBS e-banking CSV parser (Story 3-1). Stdlib unittest only."""

from __future__ import annotations

import sys
import unittest
from decimal import Decimal
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))

from dispatch import parse_for_account  # noqa: E402
from parsers.ubs_ebanking_csv import parse_file  # noqa: E402

FIXTURE = Path(__file__).parent / "fixtures" / "ubs_sample.csv"


class TestUbsParser(unittest.TestCase):
    def test_parse_multi_drops_summary(self) -> None:
        rows = parse_file(FIXTURE)
        multi = [r for r in rows if r["BankTransactionID"] == "TXN-MULTI"]
        self.assertEqual(len(multi), 2)
        amounts = sorted(Decimal(r["Amount"]) for r in multi)
        self.assertEqual(amounts, [Decimal("-300"), Decimal("-200")])

    def test_parse_single_debit(self) -> None:
        rows = parse_file(FIXTURE)
        one = next(r for r in rows if r["BankTransactionID"] == "TXN-SINGLE")
        self.assertEqual(one["Date"], "2026-03-10")
        self.assertEqual(Decimal(one["Amount"]), Decimal("-100"))
        self.assertIn("Counterparty A", one["Description"])

    def test_parse_credit_only(self) -> None:
        rows = parse_file(FIXTURE)
        cr = next(r for r in rows if r["BankTransactionID"] == "TXN-CRED")
        self.assertEqual(Decimal(cr["Amount"]), Decimal("50"))

    def test_dispatch_sets_account(self) -> None:
        rows = parse_for_account(7, FIXTURE)
        self.assertTrue(all(r["Account"] == 7 for r in rows))

    def test_dispatch_unknown_account(self) -> None:
        with self.assertRaises(ValueError) as ctx:
            parse_for_account(99999, FIXTURE)
        self.assertIn("No bank importer", str(ctx.exception))


if __name__ == "__main__":
    unittest.main()
