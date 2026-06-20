#!/usr/bin/env python3
"""Compatibility shim for tools/python/scripts/audit_references.py."""

from __future__ import annotations

import runpy
from pathlib import Path


if __name__ == "__main__":
    repo = Path(__file__).resolve().parents[1]
    runpy.run_path(str(repo / "tools/python/scripts/audit_references.py"), run_name="__main__")
