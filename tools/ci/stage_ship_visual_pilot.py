#!/usr/bin/env python3
"""Stage only approved 4×2 runtime atlases, never the source boards."""
import argparse
import hashlib
import json
import math
import re
import struct
import zipfile
from pathlib import Path
from PIL import Image, ImageDraw
from io import BytesIO

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "src/presentation/ship/pilot_atlases"
EXPECTED = {
    "SC-01": "SC01_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip",
    "SC-02": "SC02_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip",
    "SC-03": "SC03_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip",
    "SC-04": "SC04_FINAL_MANUAL_ALIGNED_GITHUB_UPLOAD.zip",
    "SC-06": "SC06_PERCIN_HATTI_ALIGNED_FINAL.zip",
    "SC-08": "SC08_SUPPORT_ANCHOR_FINAL.zip",
    "M01": "M01_TUZ_DISI_B_FINAL_160PX_BODY.zip",
    "M02": "M02_KABUK_KISKAC_B_FINAL_GITHUB_UPLOAD.zip",
}
ORDER = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
# Visually checked 2026-11-25 against the exact staged contact sheet:
# SC01 rudder and SC04 split-jaw prow point opposite their authored labels.
# Canonical runtime cells always point along their world heading.
SOURCE_HEADING_OFFSET = {"SC-01": 4, "SC-04": 4}
PNG = b"\x89PNG\r\n\x1a\n"


def validate_embedded_mounts(z, ship, atlas_source, cell):
    """New packages bind mount data to the exact authored atlas; legacy stays readable."""
    names = z.namelist()
    if "manifest.json" not in names:
        return
    m = json.loads(z.read("manifest.json"))
    if m.get("package_format") != "seacraft-atlas-mounts-v2":
        if "mounts.json" in names:
            raise ValueError(f"{ship}: unbound mounts.json")
        return
    if len(names) != 5 or len(set(names)) != 5 or set(names) != set(m["package_members"]):
        raise ValueError(f"{ship}: invalid v2 archive members")
    if m["ship_id"] != ship or m["runtime_atlas"] != atlas_source or m["cell_px"] != cell or m["direction_order"] != list(ORDER):
        raise ValueError(f"{ship}: atlas metadata mismatch")
    b = m["mounts"]
    if b["file"] != "mounts.json" or b["location"] != "inside_archive":
        raise ValueError(f"{ship}: mounts must be embedded")
    atlas_hash = hashlib.sha256(z.read(atlas_source)).hexdigest()
    raw = z.read("mounts.json")
    if atlas_hash != m["runtime_atlas_sha256"] or atlas_hash != b["atlas_sha256"] or hashlib.sha256(raw).hexdigest() != b["sha256"]:
        raise ValueError(f"{ship}: atlas/mount checksum mismatch")
    data = json.loads(raw)
    mounts = data["mounts"]
    if data["frames"] != m["alignment"] or mounts["schema"] != "seacraft-mounts-v1" or set(mounts["frames"]) != set(ORDER):
        raise ValueError(f"{ship}: mount schema/alignment mismatch")
    if sum(len(v) for v in mounts["frames"].values()) != b["count"]:
        raise ValueError(f"{ship}: mount count mismatch")
    print(f"VISUAL_PILOT_MOUNTS_OK ship={ship} count={b['count']}")


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
        if len(matches) > 1:
            final = [match for match in matches if "final" in Path(match[0].filename).name.lower() or "runtime" in Path(match[0].filename).name.lower()]
            if len(final) == 1:
                matches = final
            else:
                raise ValueError(f"{archive.name}: ambiguous atlas: {[m[0].filename for m in matches]}")
        if matches:
            entry, cell = matches[0]
            atlas_source = entry.filename
            with Image.open(BytesIO(z.read(entry))) as source:
                if "A" not in source.getbands() and "transparency" not in source.info:
                    raise ValueError(f"{ship}: approved atlas has no alpha")
                atlas = source.convert("RGBA")
        else:
            # Some approved aligned packages contain the eight masters only.
            # Match full direction suffixes, never QA sheets or original boards.
            frames = []
            for direction in ORDER:
                pattern = re.compile(r"(?:^|[_-])" + direction + r"\.png$", re.I)
                candidates = [e for e in z.infolist() if pattern.search(Path(e.filename).name)]
                if len(candidates) != 1:
                    raise ValueError(f"{archive.name}: ambiguous/missing {direction}: {[e.filename for e in candidates]}")
                with Image.open(BytesIO(z.read(candidates[0]))) as source:
                    if source.mode != "RGBA" or source.width != source.height:
                        raise ValueError(f"{ship} {direction}: expected square RGBA")
                    frames.append(source.copy())
            cell = frames[0].width
            if not 0 < cell <= 1024 or any(f.size != (cell, cell) for f in frames):
                raise ValueError(f"{ship}: inconsistent master sizes")
            atlas = Image.new("RGBA", (4 * cell, 2 * cell))
            for index, frame in enumerate(frames):
                atlas.paste(frame, ((index % 4) * cell, (index // 4) * cell))
            atlas_source = "approved_aligned_frames"
        validate_embedded_mounts(z, ship, atlas_source, cell)
        # Preserve authored final cells. Legacy 1024 masters are kept intact,
        # rather than misinterpreting the visible hull pixel goal as cell size.
        runtime_cell = cell
        if runtime_cell > cell:
            raise ValueError(f"{ship}: refusing to upscale atlas from {cell} to {runtime_cell}")
        runtime = Image.new("RGBA", (4 * runtime_cell, 2 * runtime_cell))
        for index, direction in enumerate(ORDER):
            source_index = (index + SOURCE_HEADING_OFFSET.get(ship, 0)) % len(ORDER)
            x, y = (source_index % 4) * cell, (source_index // 4) * cell
            frame = atlas.crop((x, y, x + cell, y + cell))
            box = frame.getchannel("A").getbbox()
            if not box:
                raise ValueError(f"{ship} {direction}: blank frame")
            if box[0] == 0 or box[1] == 0 or box[2] == cell or box[3] == cell:
                print(f"VISUAL_PILOT_EDGE_CONTACT ship={ship} direction={direction} source_cell={cell}")
            print(f"VISUAL_PILOT_FRAME ship={ship} direction={direction} source_direction={ORDER[source_index]} atlas_alpha_bbox={box}")
            if runtime_cell != cell:
                frame = frame.resize((runtime_cell, runtime_cell), Image.Resampling.LANCZOS)
            runtime.paste(frame, ((index % 4) * runtime_cell, (index // 4) * runtime_cell))
        runtime.save(OUT / f"{ship}.png")
        print(f"VISUAL_PILOT_ATLAS ship={ship} archive={archive.name} atlas={atlas_source} source_cell={cell} cell={runtime_cell} pivot={runtime_cell/2:g},{runtime_cell/2:g}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--qa-dir', type=Path)
    args = parser.parse_args()
    OUT.mkdir(parents=True, exist_ok=True)
    for ship, name in EXPECTED.items():
        (OUT / f"{ship}.png").unlink(missing_ok=True)
        stage(ship, ROOT / name)
    for texture in OUT.glob("*.png"):
        if texture.stem not in EXPECTED:
            texture.unlink()
    for ship in EXPECTED:
        if not (OUT / f"{ship}.png").is_file():
            raise ValueError(f"Missing approved runtime atlas: {ship}")
    if args.qa_dir:
        proof(args.qa_dir)



def proof(out):
    """Exact runtime textures, at game world sizes, on CPU-modelled sea backgrounds."""
    out.mkdir(parents=True, exist_ok=True)
    directions = ("N", "NE", "E", "SE", "S", "SW", "W", "NW")
    ships = [(ship, size) for ship, size in (("SC-01", 86), ("SC-02", 104), ("SC-03", 132), ("SC-04", 132), ("SC-06", 144), ("SC-08", 174), ("M01", 70), ("M02", 90))
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
