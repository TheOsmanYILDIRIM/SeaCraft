#!/usr/bin/env python3
"""Stage only approved 4×2 runtime atlases, never the source boards."""
import argparse
import math
import json
import re
import struct
import zipfile
from pathlib import Path
from PIL import Image, ImageDraw
from io import BytesIO

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/presentation/ship/pilot_atlases"
EXPECTED = {
    "SC-02": "SC02_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip",
    "SC-03": "SC03_Tuz_Ambari_AUTO_FINAL_GITHUB_UPLOAD.zip",
}
ORDER = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
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
            if ("atlas" in name and width == height * 2
                    and height % 2 == 0 and 0 < width <= 4096):
                matches.append((entry, height // 2))
        if len(matches) > 1 and ship == "SC-02":
            runtime = [match for match in matches if match[1] == 160]
            if runtime:
                matches = runtime
        if len(matches) > 1:
            raise ValueError(f"{archive.name}: ambiguous atlas")
        if matches:
            entry, cell = matches[0]
            atlas_source = entry.filename
            with Image.open(BytesIO(z.read(entry))) as source:
                if "A" not in source.getbands() and "transparency" not in source.info:
                    raise ValueError(f"{ship}: approved atlas has no alpha")
                atlas = source.convert("RGBA")
        elif ship == "SC-03":
            # This approved AUTO FINAL package contains eight aligned master
            # frames, not an atlas. Its opaque contact sheet is QA only.
            cell = 1024
            atlas_source = "approved_8_master_frames"
            atlas = Image.new("RGBA", (4 * cell, 2 * cell))
            for index, direction in enumerate(ORDER):
                source_name = f"SC03_Tuz_Ambari/{direction}.png"
                with Image.open(BytesIO(z.read(source_name))) as source:
                    if source.mode != "RGBA" or source.size != (cell, cell):
                        raise ValueError(f"{ship} {direction}: expected approved RGBA master")
                    atlas.paste(source, ((index % 4) * cell, (index // 4) * cell))
            report = json.loads(z.read("SC03_Tuz_Ambari/normalization_report.json"))
            for direction in ORDER:
                print(f"VISUAL_PILOT_NORMALIZATION ship={ship} direction={direction} original_measure={report.get(direction, {})}")
        else:
            print(f"VISUAL_PILOT_MISSING ship={ship}")
            return
        runtime_cell = {"SC-02": 160, "SC-03": 224, "SC-07": 224}[ship]
        if runtime_cell > cell:
            raise ValueError(f"{ship}: refusing to upscale atlas from {cell} to {runtime_cell}")
        runtime = Image.new("RGBA", (4 * runtime_cell, 2 * runtime_cell))
        for index, direction in enumerate(ORDER):
            x, y = (index % 4) * cell, (index // 4) * cell
            frame = atlas.crop((x, y, x + cell, y + cell))
            box = frame.getchannel("A").getbbox()
            if not box:
                raise ValueError(f"{ship} {direction}: blank frame")
            if box[0] == 0 or box[1] == 0 or box[2] == cell or box[3] == cell:
                print(f"VISUAL_PILOT_EDGE_CONTACT ship={ship} direction={direction} source_cell={cell}")
            print(f"VISUAL_PILOT_FRAME ship={ship} direction={direction} atlas_alpha_bbox={box}")
            if runtime_cell != cell:
                frame = frame.resize((runtime_cell, runtime_cell), Image.Resampling.LANCZOS)
            runtime.paste(frame, ((index % 4) * runtime_cell, (index // 4) * runtime_cell))
        runtime.save(OUT / f"{ship}.png")
        print(f"VISUAL_PILOT_ATLAS ship={ship} archive={archive.name} atlas={atlas_source} source_cell={cell} cell={runtime_cell} pivot={runtime_cell/2:g},{runtime_cell/2:g}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sc07", type=Path, help="Approved SC-07 final archive; omit if unavailable")
    parser.add_argument('--qa-dir', type=Path)
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
    if args.qa_dir:
        proof(args.qa_dir)



def proof(out):
    """Exact runtime textures, at game world sizes, on CPU-modelled sea backgrounds."""
    out.mkdir(parents=True, exist_ok=True)
    directions = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
    ships = [(ship, size) for ship, size in (("SC-02", 104), ("SC-03", 132), ("SC-07", 120))
             if (OUT / f"{ship}.png").is_file()]
    for factor in (1, 2):
        stride, row = 148 * factor, 146 * factor
        for water in ("current", "preview"):
            board = Image.new("RGBA", (stride * 8, row * len(ships) + 24), (9, 24, 29, 255))
            if water == "preview":
                for y in range(board.height):
                    for x in range(board.width):
                        px, py = x / factor * 0.039, y / factor * 0.039
                        a = math.sin(px * 0.7 + py * 0.6 + math.cos(py * 0.38))
                        b = math.cos(px * -0.36 + py * 0.94 + math.sin(px * 0.47))
                        v = 0.5 + 0.26 * a + 0.19 * b
                        board.putpixel((x, y), (round((0.025 + 0.030 * v) * 255),
                                                round((0.075 + 0.070 * v) * 255),
                                                round((0.095 + 0.070 * v) * 255), 255))
            draw = ImageDraw.Draw(board)
            for i, direction in enumerate(directions):
                draw.text((i * stride + stride // 2 - 5, 5), direction, fill="white")
            for j, (ship, size) in enumerate(ships):
                with Image.open(OUT / f"{ship}.png") as atlas:
                    cell = atlas.height // 2
                    for i in range(8):
                        x, y = (i % 4) * cell, (i // 4) * cell
                        part = atlas.crop((x, y, x + cell, y + cell))
                        part = part.resize((size * factor, size * factor), Image.Resampling.BILINEAR)
                        cx, cy = i * stride + stride // 2, 24 + j * row + row // 2
                        board.alpha_composite(part, (cx - part.width // 2, cy - part.height // 2))
                        # Mark the pivot next to the image, never over the hull.
                        draw.line((i * stride + 2, cy, i * stride + 8, cy), fill=(126, 216, 242))
                    draw.text((4, 25 + j * row), ship, fill="white")
            board.save(out / f"{water}-{factor}x.png")
    print("VISUAL_PILOT_PROOF exact_runtime_atlas cpu_sea_model scales=1,2")


if __name__ == "__main__":
    main()
