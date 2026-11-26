"""Make inspection sheets from actual Godot pixels, with trace timestamps."""
import json
import sys
from pathlib import Path
from PIL import Image, ImageDraw

root = Path(sys.argv[1])
data = json.loads((root / "trace.json").read_text())
frames = sorted(root.glob("frame_*.png"))
assert len(frames) == data["frames"] == len(data["samples"]) and len(frames) > 0
# Inspect every captured frame (5 fps), not just selected successful moments.
for start in range(0, len(frames), 16):
    sheet = Image.new("RGB", (1280, 816), (17, 21, 28))
    draw = ImageDraw.Draw(sheet)
    for j, frame in enumerate(frames[start:start+16]):
        index = start+j
        sample = data["samples"][index]
        x, y = j%4*320, j//4*204
        with Image.open(frame) as im:
            sheet.paste(im.resize((320,180), Image.Resampling.LANCZOS), (x,y))
        draw.text((x+4,y+182), f"{data['profile']} {index/5:.1f}s tick {sample['tick']} HP {sample['npc_hull']:.0f}", fill="white")
    sheet.save(root / f"review-{start//16:03d}.jpg", quality=88)
print(json.dumps({k:v for k,v in data.items() if k not in ("actions","samples")}, indent=2))
