"""Prepend a standard documentation banner to MATLAB sources that lack it."""
from __future__ import annotations

import sys
from pathlib import Path

MARKER = "%MESOHOLO-DOC"
HEADER = """%MESOHOLO-DOC
% mesoholo — mesoscale holography code (Abdeladim et al., 2026).
% Relative path in repository: {rel}
% See README.md at repo root and docs/DEPENDENCIES.md for setup and hardware notes.
%

"""


def main() -> int:
    repo = Path(__file__).resolve().parents[1]
    paths: list[Path] = []
    paths += sorted(repo.glob("matlab/**/*.m"))
    paths += sorted(repo.glob("python/**/*.m"))
    changed = 0
    for p in paths:
        if "+ScanImageTiffReader" in p.parts:
            continue
        text = p.read_text(encoding="utf-8", errors="replace")
        if MARKER in text[:400]:
            continue
        rel = p.relative_to(repo).as_posix()
        p.write_text(HEADER.format(rel=rel) + text, encoding="utf-8")
        changed += 1
    print(f"Prepended documentation banner to {changed} file(s).")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
