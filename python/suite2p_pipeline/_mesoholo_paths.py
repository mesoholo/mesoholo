"""Repository-relative paths for the mesoholo suite2p helpers.

This package lives at ``<repo>/python/suite2p_pipeline/``. The repository root
is two levels up. Use ``REPO_ROOT`` and ``DATA_DIR`` so scripts do not hardcode
lab machine paths (e.g. ``D:/HS/...``).
"""
from __future__ import annotations

from pathlib import Path
import os

REPO_ROOT = Path(__file__).resolve().parents[2]
_default_data = REPO_ROOT / "data"
DATA_DIR = Path(os.environ.get("MESOHOLO_DATA_ROOT", str(_default_data)))
