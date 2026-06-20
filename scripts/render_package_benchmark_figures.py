#!/usr/bin/env python3
"""Compatibility shim for tools/python/scripts/render_package_benchmark_figures.py."""

from __future__ import annotations

import runpy
from pathlib import Path


if __name__ == "__main__":
    repo = Path(__file__).resolve().parents[1]
    runpy.run_path(str(repo / "tools/python/scripts/render_package_benchmark_figures.py"), run_name="__main__")
