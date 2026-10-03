"""Stamp and print the Butler userversion with a Korean build date and time."""
from datetime import datetime
import argparse
import json
import subprocess
from pathlib import Path
import re
import sys
from zoneinfo import ZoneInfo


def build_version(version, now=None):
    if not version or any(ord(char) < 32 for char in version):
        raise ValueError("Build version must be a non-empty, single-line value")
    if re.match(r"^\d{8}-\d{6}(?:-|$)", version):
        return version
    now = now or datetime.now(ZoneInfo("Asia/Seoul"))
    label = re.sub(r"^\d{8}-", "", version)
    return f"{now:%Y%m%d-%H%M%S}-{label}"


def stamp(project, label, build_number=None):
    now = datetime.now(ZoneInfo("Asia/Seoul"))
    version = build_version(label, now)
    number = str(build_number) if build_number is not None else now.strftime("%Y%m%d%H%M%S")
    if not number.isdigit():
        raise ValueError("Build number must contain only digits")
    revision = subprocess.run(["git", "-C", str(project), "rev-parse", "HEAD"],
                              capture_output=True, text=True).stdout.strip()
    data = {"version": version, "build_number": number, "revision": revision,
            "built_at": now.isoformat(timespec="seconds")}
    (project / "build_info.json").write_text(
        json.dumps(data, ensure_ascii=False) + "\n", encoding="utf-8")
    return version


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("version")
    parser.add_argument("--project", type=Path, default=Path(__file__).resolve().parents[3])
    parser.add_argument("--build-number", type=int)
    args = parser.parse_args()
    try:
        print(stamp(args.project, args.version, args.build_number))
    except ValueError as error:
        parser.error(str(error))


if __name__ == "__main__":
    main()
