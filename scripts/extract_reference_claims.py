#!/usr/bin/env python3
"""Compatibility shim for tools/python/scripts/extract_reference_claims.py."""

from __future__ import annotations

import runpy
from pathlib import Path


if __name__ == "__main__":
    repo = Path(__file__).resolve().parents[1]
    runpy.run_path(str(repo / "tools/python/scripts/extract_reference_claims.py"), run_name="__main__")
