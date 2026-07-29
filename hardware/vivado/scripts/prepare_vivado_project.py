#!/usr/bin/env python3
"""Extract the clean Vivado project and packaged custom-IP sources."""
from __future__ import annotations

import shutil
import sys
import tempfile
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
VIVADO_DIR = ROOT / "hardware" / "vivado"
IP_DIR = ROOT / "hardware" / "ip"


def extract_single_root(archive: Path, destination: Path) -> None:
    if not archive.is_file():
        raise FileNotFoundError(f"Missing archive: {archive}")
    with tempfile.TemporaryDirectory() as tmp:
        tmp_path = Path(tmp)
        with zipfile.ZipFile(archive) as zf:
            bad = zf.testzip()
            if bad:
                raise RuntimeError(f"Corrupt member in {archive.name}: {bad}")
            zf.extractall(tmp_path)
        entries = [p for p in tmp_path.iterdir() if p.name != "__MACOSX"]
        source = entries[0] if len(entries) == 1 and entries[0].is_dir() else tmp_path
        destination.mkdir(parents=True, exist_ok=True)
        shutil.copytree(source, destination, dirs_exist_ok=True)


def main() -> int:
    project_zip = VIVADO_DIR / "vivado_project_files.zip"
    project_dir = VIVADO_DIR / "project"
    if not project_zip.is_file():
        raise FileNotFoundError(f"Missing archive: {project_zip}")
    project_dir.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(project_zip) as zf:
        bad = zf.testzip()
        if bad:
            raise RuntimeError(f"Corrupt member in {project_zip.name}: {bad}")
        zf.extractall(project_dir)

    extract_single_root(
        IP_DIR / "redundant_link_core" / "redundant_link_core_source.zip",
        IP_DIR / "redundant_link_core",
    )
    extract_single_root(
        IP_DIR / "sensor_guard_ip" / "sensor_guard_ip_source.zip",
        IP_DIR / "sensor_guard_ip",
    )
    extract_single_root(
        IP_DIR / "voltage_display_ip" / "voltage_display_ip_source.zip",
        IP_DIR / "voltage_display_ip",
    )

    xpr = project_dir / "redundant_link" / "redundant_link.xpr"
    if not xpr.is_file():
        raise RuntimeError(f"Vivado project was not reconstructed: {xpr}")
    print(f"Prepared Vivado project: {xpr}")
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except Exception as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1)
