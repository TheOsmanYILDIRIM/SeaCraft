#!/usr/bin/env python3
"""Visualize measured Godot physics samples, not a second simulation."""
import json
import math
import sys
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(__file__).resolve().parents[2]
log, out = Path(sys.argv[1]), Path(sys.argv[2])
out.mkdir(parents=True, exist_ok=True)
traces = {}
for line in log.read_text(errors="replace").splitlines():
    if "PLAY01_TRACE {" in line:
        data = json.loads(line.split("PLAY01_TRACE ", 1)[1].split("\x1b", 1)[0])
        traces[data["scenario"]] = data
if set(traces) != {"coast", "boundary"}:
    raise ValueError(f"Missing measured scenarios: {traces.keys()}")
atlas = Image.open(root / "src/presentation/ship/pilot_atlases/SC-01.png").convert("RGBA")
cell = atlas.height // 2
frames = [atlas.crop(((i % 4) * cell, (i // 4) * cell, (i % 4 + 1) * cell, (i // 4 + 1) * cell)).resize((65, 65), Image.Resampling.LANCZOS) for i in range(8)]
scale = 0.75
def xy(x, y):
    return (round(x * scale + 480), round(y * scale + 300))
for name, trace in traces.items():
    samples = trace["samples"]
    if len(samples) < 2 or len(samples) > 400 or not trace["route"]:
        raise ValueError(f"Invalid trace {name}")
    (out / f"{name}.json").write_text(json.dumps(trace, indent=2))
    images = []
    trail = []
    for tick, x, y, heading, vx, vy in samples:
        im = Image.new("RGBA", (960, 600), (11, 28, 34, 255))
        d = ImageDraw.Draw(im)
        d.rectangle((*xy(-640, -360), *xy(640, 360)), outline=(76, 108, 116), width=2)
        d.rectangle((*xy(-48, -160), *xy(48, 160)), fill=(64, 73, 67))
        d.line([xy(*p) for p in trace["route"]], fill=(89, 190, 184), width=2)
        trail.append(xy(x, y))
        if len(trail) > 1:
            d.line(trail, fill=(250, 216, 110), width=2)
        direction = (math.floor(heading / (math.pi / 4) + .5) + 2) % 8
        authored = (direction - 2) * math.pi / 4
        residual = (heading - authored + math.pi) % (2 * math.pi) - math.pi
        sprite = frames[direction].rotate(-math.degrees(residual), Image.Resampling.BICUBIC, expand=True)
        cx, cy = xy(x, y)
        im.alpha_composite(sprite, (cx - sprite.width // 2, cy - sprite.height // 2))
        d.line([(cx, cy), xy(x + vx * .35, y + vy * .35)], fill=(250, 150, 95), width=2)
        d.text((12, 6), f"PLAY-01 | {name} | measured Godot tick {tick} | speed {math.hypot(vx, vy):.1f}", fill="white")
        d.text((12, 581), "Turquoise: planned route | gold: actual path | orange: actual velocity | CPU atlas replay", fill="white")
        images.append(im.convert("RGB"))
    images[0].save(out / f"{name}.gif", save_all=True, append_images=images[1:], duration=133, loop=0, optimize=True)
    images[-1].save(out / f"{name}-final.png")
    print(f"PLAY01_REPLAY_OK scenario={name} samples={len(samples)}")
