#!/usr/bin/env python3
"""Stage only approved 4×2 runtime atlases, never the source boards."""
import argparse
import re
import struct
import zipfile
from pathlib import Path
from PIL import Image
from io import BytesIO

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
        print(f"VISUAL_PILOT_ARCHIVE ship={ship} members={z.namelist()}")
        for entry in z.infolist():
            name = Path(entry.filename).name.lower()
            if not name.endswith(".png"):
                continue
            with z.open(entry) as reader:
                header = reader.read(26)
            if len(header) != 26 or header[:8] != PNG or header[12:16] != b"IHDR":
                continue
            width, height = struct.unpack(">II", header[16:24])
            print(f"VISUAL_PILOT_PNG ship={ship} file={name} size={width}x{height} color_type={header[25]}")
            if width == height * 2 and height % 2 == 0 and 0 < width <= 4096:
                matches.append((entry, height // 2))
        labeled = [match for match in matches if "atlas" in Path(match[0].filename).name.lower()]
        if labeled:
            matches = labeled
        if len(matches) > 1 and ship == "SC-02":
            runtime = [match for match in matches if match[1] == 160]
            if runtime:
                matches = runtime
        if not matches:
            print(f"VISUAL_PILOT_MISSING ship={ship}")
            return
        if len(matches) != 1:
            raise ValueError(f"{archive.name}: expected one approved RGBA 4x2 atlas, found {len(matches)}")
        entry, cell = matches[0]
        if ship == "SC-07" and cell != 224:
            raise ValueError("SC-07 atlas must have approved 224 px cells")
        with Image.open(BytesIO(z.read(entry))) as source:
            if "A" not in source.getbands() and "transparency" not in source.info:
                raise ValueError(f"{ship}: approved atlas has no alpha")
            atlas = source.convert("RGBA")
        runtime_cell = 160 if ship == "SC-02" else cell
        if runtime_cell > cell:
            raise ValueError(f"{ship}: refusing to upscale atlas from {cell} to {runtime_cell}")
        runtime = Image.new("RGBA", (4 * runtime_cell, 2 * runtime_cell))
        for index, direction in enumerate(("N", "NE", "E", "SE", "S", "SW", "W", "NW")):
            x, y = (index % 4) * cell, (index // 4) * cell
            frame = atlas.crop((x, y, x + cell, y + cell))
            box = frame.getchannel("A").getbbox()
            if not box or box[0] == 0 or box[1] == 0 or box[2] == cell or box[3] == cell:
                raise ValueError(f"{ship} {direction}: blank frame or alpha touching cell boundary")
            print(f"VISUAL_PILOT_FRAME ship={ship} direction={direction} atlas_alpha_bbox={box}")
            if runtime_cell != cell:
                frame = frame.resize((runtime_cell, runtime_cell), Image.Resampling.LANCZOS)
            runtime.paste(frame, ((index % 4) * runtime_cell, (index // 4) * runtime_cell))
        runtime.save(OUT / f"{ship}.png")
        print(f"VISUAL_PILOT_ATLAS ship={ship} archive={archive.name} atlas={entry.filename} source_cell={cell} cell={runtime_cell} pivot={runtime_cell/2:g},{runtime_cell/2:g}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sc07", type=Path, help="Approved SC-07 final archive; omit if unavailable")
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for ship, name in EXPECTED.items():
        (OUT / f"{ship}.png").unlink(missing_ok=True)
        stage(ship, ROOT / name)
    if not (OUT / "SC-02.png").exists() and not (OUT / "SC-03.png").exists():
        raise ValueError("No approved pilot atlas available")
    if args.sc07:
        stage("SC-07", args.sc07)
    else:
        # Do not publish a stale local comparison atlas in a new export.
        (OUT / "SC-07.png").unlink(missing_ok=True)
        print("VISUAL_PILOT_MISSING ship=SC-07")


if __name__ == "__main__":
    main()
