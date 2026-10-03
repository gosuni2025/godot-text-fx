#!/usr/bin/env python3
"""Godot Text FX 보고서 조회: 공용 도구에 프로젝트와 저장 경로만 전달한다."""
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
REPO = Path(os.environ.get("PROFILER_REPO", ROOT.parent / "godot-web-profiler")).expanduser().resolve()
SCRIPT = REPO / "tools" / "profile_reports.py"
ARGS = ["--project", "godot-text-fx", "--captures", str(ROOT / "captures")]

if not SCRIPT.is_file():
    sys.exit(f"공용 스크립트가 없다: {SCRIPT} (PROFILER_REPO로 지정)")
os.chdir(ROOT)
os.execv(sys.executable, [sys.executable, str(SCRIPT), *ARGS, *sys.argv[1:]])
