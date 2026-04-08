"""Resolve registry and run the parser for a house-bank Account id."""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

ROOT = Path(__file__).resolve().parent
REGISTRY_PATH = ROOT / "registry.json"


def load_registry() -> dict[str, str]:
    data = json.loads(REGISTRY_PATH.read_text(encoding="utf-8"))
    return {str(k): str(v) for k, v in data.items()}


def parse_for_account(account_id: int, csv_path: str | Path) -> list[dict[str, Any]]:
    reg = load_registry()
    key = str(account_id)
    if key not in reg:
        raise ValueError(
            f"No bank importer registered for Account id={account_id}. "
            f"Known ids: {', '.join(sorted(reg.keys(), key=int))}"
        )
    importer = reg[key]
    path = Path(csv_path)
    if importer == "ubs_ebanking_csv":
        from parsers.ubs_ebanking_csv import parse_file

        rows = parse_file(path)
    elif importer == "generic_csv":
        from parsers.generic_csv import parse_file

        rows = parse_file(path)
    else:
        raise ValueError(f"Unknown importer key: {importer}")

    for r in rows:
        r["Account"] = account_id
    return rows
