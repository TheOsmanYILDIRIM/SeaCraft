#!/usr/bin/env python3
"""Stage only approved 4×2 runtime atlases, never the source boards."""
import argparse
import re
import struct
import zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/presentation/ship/pilot_atlases"
EXPECTED = {
    "SC-02": "SC02_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip",
    "SC-03": "SC03_Tuz_Ambari_AUTO_FINAL_GITHUB_UPLOAD.zip",
}
PNG = b"\x89PNG\r\n\x1a\n"


def stage(ship, archive):
    with zipfile.ZipFile(archive) as z:
        matches = []
        for entry in z.infolist():
            name = Path(entry.filename).name.lower()
            if not name.endswith(".png") or "atlas" not in name:
                continue
            with z.open(entry) as reader:
                header = reader.read(26)
            if len(header) != 26 or header[:8] != PNG or header[12:16] != b"IHDR":
                continue
            width, height = struct.unpack(">II", header[16:24])
            if width == height * 2 and height % 2 == 0 and 0 < width <= 4096 and header[25] == 6:
                matches.append((entry, height // 2))
        if len(matches) != 1:
            raise ValueError(f"{archive.name}: expected one approved RGBA 4x2 atlas, found {len(matches)}")
        entry, cell = matches[0]
        if ship == "SC-07" and cell != 224:
            raise ValueError("SC-07 atlas must have approved 224 px cells")
        (OUT / f"{ship}.png").write_bytes(z.read(entry))
        print(f"VISUAL_PILOT_ATLAS ship={ship} archive={archive.name} atlas={entry.filename} cell={cell} pivot={cell/2:g},{cell/2:g}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sc07", type=Path, help="Approved SC-07 final archive; omit if unavailable")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for ship, name in EXPECTED.items():
        stage(ship, ROOT / name)
    if args.sc07:
        stage("SC-07", args.sc07)
    else:
        # Do not publish a stale local comparison atlas in a new export.
        (OUT / "SC-07.png").unlink(missing_ok=True)
        print("VISUAL_PILOT_MISSING ship=SC-07")


if __name__ == "__main__":
    main()
