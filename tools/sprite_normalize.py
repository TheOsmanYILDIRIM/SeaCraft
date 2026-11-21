#!/usr/bin/env python3
"""SeaCraft 8-direction sprite normalizer.

Canonical pipeline:
1) foreground mask (alpha, or GrabCut for opaque studio backgrounds)
2) orthographic world-scale normalization using heading/projection ratios
3) hull-weighted anchor placement
4) 180-degree counterpart footprint lock
5) Lab/LUT-like color match to a canonical direction (default N)
6) no-crop safety fit + QA outputs

Dependencies: pillow, numpy, opencv-python, scikit-image

Input filenames must contain one of: N, NE, E, SE, S, SW, W, NW.
Example:
  python tools/sprite_normalize.py raw/ normalized/ --broadside-px 790 --anchor-y 560
"""
from __future__ import annotations

import argparse
import json
import math
import re
import zipfile
from pathlib import Path

import cv2
import numpy as np
from PIL import Image, ImageDraw
from skimage import color

ORDER = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
HEADING = {"N": -90, "NE": -45, "E": 0, "SE": 45, "S": 90, "SW": 135, "W": 180, "NW": -135}
PAIR = {"S": "N", "SW": "NE", "W": "E", "NW": "SE"}

def parse_args():
    p = argparse.ArgumentParser()
    p.add_argument("input_dir", type=Path)
    p.add_argument("output_dir", type=Path)
    p.add_argument("--canvas", type=int, default=1024)
    p.add_argument("--camera-elevation", type=float, default=55.0)
    p.add_argument("--broadside-px", type=float, default=790.0)
    p.add_argument("--anchor-x", type=float, default=512.0)
    p.add_argument("--anchor-y", type=float, default=560.0)
    p.add_argument("--padding", type=int, default=24)
    p.add_argument("--color-ref", choices=ORDER, default="N")
    p.add_argument("--lut-blend", type=float, default=0.92)
    p.add_argument("--gif-fps", type=float, default=6.0)
    p.add_argument("--no-pair-lock", action="store_true")
    return p.parse_args()

def direction_from_name(name: str):
    stem = Path(name).stem.upper()
    tokens = re.split(r"[^A-Z]+", stem)
    for d in ["NE", "SE", "SW", "NW", "N", "E", "S", "W"]:
        if d in tokens:
            return d
    m = re.search(r"(?:^|[_\- ])(NE|SE|SW|NW|N|E|S|W)(?:$|[_\- ])", stem)
    return m.group(1) if m else None

def find_inputs(input_dir: Path):
    found = {}
    for p in sorted(input_dir.iterdir()):
        if p.suffix.lower() not in {".png", ".webp", ".jpg", ".jpeg"}:
            continue
        d = direction_from_name(p.name)
        if d and d not in found:
            found[d] = p
    missing = [d for d in ORDER if d not in found]
    if missing:
        raise SystemExit(f"Missing directions in {input_dir}: {', '.join(missing)}")
    return found

def rgba_arr(im):
    return np.asarray(im.convert("RGBA"))

def foreground_mask(im: Image.Image):
    arr = rgba_arr(im)
    alpha = arr[..., 3]
    rgb = arr[..., :3]
    h, w = alpha.shape
    if alpha.min() < 250:
        m = (alpha > 20).astype(np.uint8)
        n, labels, stats, _ = cv2.connectedComponentsWithStats(m, 8)
        if n > 1:
            keep = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
            core = (labels == keep).astype(np.uint8)
            dil = cv2.dilate(core, np.ones((9, 9), np.uint8), iterations=1)
            m = ((m > 0) & (dil > 0)).astype(np.uint8) | core
        return m.astype(bool)
    mask = np.full((h, w), cv2.GC_PR_BGD, np.uint8)
    b = max(8, min(h, w) // 80)
    mask[:b, :] = cv2.GC_BGD; mask[-b:, :] = cv2.GC_BGD
    mask[:, :b] = cv2.GC_BGD; mask[:, -b:] = cv2.GC_BGD
    mask[int(h*.08):int(h*.94), int(w*.04):int(w*.96)] = cv2.GC_PR_FGD
    bgd = np.zeros((1, 65), np.float64); fgd = np.zeros((1, 65), np.float64)
    cv2.grabCut(cv2.cvtColor(rgb, cv2.COLOR_RGB2BGR), mask, None, bgd, fgd, 7, cv2.GC_INIT_WITH_MASK)
    m = np.where((mask == cv2.GC_FGD) | (mask == cv2.GC_PR_FGD), 1, 0).astype(np.uint8)
    m = cv2.morphologyEx(m, cv2.MORPH_CLOSE, cv2.getStructuringElement(cv2.MORPH_ELLIPSE, (5,5)))
    n, labels, stats, _ = cv2.connectedComponentsWithStats(m, 8)
    if n > 1:
        keep = 1 + np.argmax(stats[1:, cv2.CC_STAT_AREA])
        core = (labels == keep).astype(np.uint8)
        dil = cv2.dilate(core, np.ones((11,11), np.uint8), iterations=1)
        m = (((m > 0) & (dil > 0)) | (core > 0)).astype(np.uint8)
    return m.astype(bool)

def with_extracted_alpha(im: Image.Image, mask: np.ndarray):
    out = im.convert("RGBA")
    arr = np.asarray(out).copy()
    if arr[...,3].min() >= 250:
        arr[...,3] = (mask.astype(np.uint8) * 255)
        arr[~mask, :3] = 0
        out = Image.fromarray(arr, "RGBA")
    return out

def structural_hull_mask(im: Image.Image, fg: np.ndarray):
    rgb = np.asarray(im.convert("RGB"))
    lum = .2126*rgb[...,0] + .7152*rgb[...,1] + .0722*rgb[...,2]
    ys, xs = np.where(fg)
    if len(xs) < 100:
        return fg
    ymin, ymax = ys.min(), ys.max()
    hull = fg.copy()
    hull[:int(ymin + 0.35*(ymax-ymin)), :] = False
    hull &= lum < 180
    if hull.sum() < 300:
        hull = fg.copy()
        hull[:int(ymin + 0.30*(ymax-ymin)), :] = False
    return hull

def heading_measure(mask: np.ndarray, deg: float):
    ys, xs = np.where(mask)
    if len(xs) < 30:
        raise ValueError("Structural mask too small")
    th = math.radians(deg)
    hv = np.array([math.cos(th), math.sin(th)])
    pv = np.array([-hv[1], hv[0]])
    xy = np.column_stack([xs, ys]).astype(float)
    hp = xy @ hv; pp = xy @ pv
    lo, hi = np.percentile(hp, [1.5, 98.5])
    mid_sel = (hp > np.percentile(hp, 20)) & (hp < np.percentile(hp, 80))
    pmid = float(np.median(pp[mid_sel])) if mid_sel.any() else float(np.median(pp))
    return float(hi-lo), float((lo+hi)/2), pmid, hv, pv

def alpha_bbox(im: Image.Image, threshold=12):
    a = np.asarray(im.getchannel("A"))
    ys, xs = np.where(a > threshold)
    if not len(xs):
        return None
    return (int(xs.min()), int(ys.min()), int(xs.max()+1), int(ys.max()+1))

def alpha_diag(im: Image.Image):
    b = alpha_bbox(im)
    if not b: return 0.0
    x0,y0,x1,y1 = b
    return math.hypot(x1-x0, y1-y0)

def compose_no_crop(im: Image.Image, desired_anchor_src, target_anchor, canvas, padding):
    ax, ay = desired_anchor_src
    tx, ty = target_anchor
    bbox = alpha_bbox(im)
    if not bbox:
        return Image.new("RGBA", (canvas, canvas), (0,0,0,0)), 1.0, (0,0)
    x0,y0,x1,y1 = bbox
    left = ax - x0; right = x1 - ax; top = ay - y0; bottom = y1 - ay
    limits = []
    if left > 0: limits.append((tx-padding)/left)
    if right > 0: limits.append((canvas-padding-tx)/right)
    if top > 0: limits.append((ty-padding)/top)
    if bottom > 0: limits.append((canvas-padding-ty)/bottom)
    safety = max(0.01, min([1.0] + limits))
    if safety < 0.999:
        im = im.resize((max(1,round(im.width*safety)), max(1,round(im.height*safety))), Image.Resampling.LANCZOS)
        ax *= safety; ay *= safety
    x = int(round(tx-ax)); y = int(round(ty-ay))
    out = Image.new("RGBA", (canvas, canvas), (0,0,0,0))
    out.alpha_composite(im, (x,y))
    return out, safety, (x,y)

def sqrtm(M):
    v,Q = np.linalg.eigh(M); v = np.clip(v,1e-6,None)
    return Q @ np.diag(np.sqrt(v)) @ Q.T

def invsqrtm(M):
    v,Q = np.linalg.eigh(M); v = np.clip(v,1e-6,None)
    return Q @ np.diag(1/np.sqrt(v)) @ Q.T

def build_lut_reference(im: Image.Image):
    arr = np.asarray(im).astype(np.float32)/255.0
    mask = arr[...,3] > .15
    lab = color.rgb2lab(arr[...,:3]); L = lab[...,0]
    core = mask & (L>5) & (L<95)
    px = lab[core]
    qgrid = np.array([0,.01,.03,.07,.15,.30,.50,.70,.85,.93,.97,.99,1])
    Lq = np.quantile(px[:,0], qgrid)
    ab = px[:,1:3]; med = np.median(ab,axis=0); cov=np.cov(ab.T)+np.eye(2)*1e-3
    return qgrid, Lq, med, sqrtm(cov)

def lut_match(im: Image.Image, ref_stats, blend=.92):
    qgrid, refLq, ref_med, ref_sqrt = ref_stats
    arr = np.asarray(im).astype(np.float32)/255.0
    alpha = arr[...,3]; mask=alpha>.15
    lab=color.rgb2lab(arr[...,:3]); L=lab[...,0]
    core=mask&(L>5)&(L<95); px=lab[core]
    if len(px)<100: return im
    srcLq=np.quantile(px[:,0],qgrid); srcLq=np.maximum.accumulate(srcLq+np.arange(len(srcLq))*1e-5)
    newL=np.interp(L,srcLq,refLq)
    ab=px[:,1:3]; med=np.median(ab,axis=0); cov=np.cov(ab.T)+np.eye(2)*1e-3
    T=ref_sqrt @ invsqrtm(cov)
    flat=lab[...,1:3].reshape(-1,2)
    mapped=((flat-med)@T.T+ref_med).reshape(lab.shape[0],lab.shape[1],2)
    lab2=lab.copy(); lab2[...,0]=newL; lab2[...,1:3]=lab[...,1:3]*.18+mapped*.82
    rgb=np.clip(color.lab2rgb(lab2),0,1)
    out=np.zeros_like(arr); out[...,:3]=arr[...,:3]*(1-blend)+rgb*blend; out[...,3]=alpha
    out[alpha<.005,:3]=0
    return Image.fromarray((np.clip(out,0,1)*255).astype(np.uint8),"RGBA")

def make_contact_and_gif(images, out_dir: Path, fps: float):
    bg=(68,72,78,255); cell=320
    sheet=Image.new("RGBA",(cell*4,cell*2),bg)
    for i,d in enumerate(ORDER):
        fr=images[d].resize((cell,cell),Image.Resampling.LANCZOS)
        b=Image.new("RGBA",(cell,cell),bg); b.alpha_composite(fr)
        ImageDraw.Draw(b).text((8,8),d,fill=(255,255,255,230))
        sheet.alpha_composite(b,((i%4)*cell,(i//4)*cell))
    sheet.convert("RGB").save(out_dir/"contactsheet.png",quality=95)
    frames=[]
    for d in ORDER:
        b=Image.new("RGBA",images[d].size,bg); b.alpha_composite(images[d])
        frames.append(b.convert("RGB").resize((768,768),Image.Resampling.LANCZOS))
    duration=max(20,round(1000/max(.1,fps)))
    frames[0].save(out_dir/"rotation.gif",save_all=True,append_images=frames[1:],duration=duration,loop=0,optimize=True)

def main():
    a=parse_args(); a.output_dir.mkdir(parents=True,exist_ok=True)
    inputs=find_inputs(a.input_dir)
    originals={d:Image.open(inputs[d]).convert("RGBA") for d in ORDER}
    fg={d:foreground_mask(originals[d]) for d in ORDER}
    extracted={d:with_extracted_alpha(originals[d],fg[d]) for d in ORDER}
    s=math.sin(math.radians(a.camera_elevation)); diag=math.sqrt(.5+.5*s*s)
    ratio={"N":s,"NE":diag,"E":1.0,"SE":diag,"S":s,"SW":diag,"W":1.0,"NW":diag}
    target_anchor=np.array([a.anchor_x,a.anchor_y],float)
    stage={}; report={}
    for d in ORDER:
        hm=structural_hull_mask(originals[d],fg[d])
        span,hmid,pmid,hv,pv=heading_measure(hm,HEADING[d])
        base_scale=(a.broadside_px*ratio[d])/span
        rim=extracted[d].resize((max(1,round(extracted[d].width*base_scale)),max(1,round(extracted[d].height*base_scale))),Image.Resampling.LANCZOS)
        anchor=(hv*hmid+pv*pmid)*base_scale
        placed,safety,offset=compose_no_crop(rim,anchor,target_anchor,a.canvas,a.padding)
        stage[d]=placed
        report[d]={"measured_hull_span":span,"projection_ratio":ratio[d],"base_scale":base_scale,"no_crop_safety_scale":safety,"offset":offset}
    if not a.no_pair_lock:
        for d,ref in PAIR.items():
            rd,dd=alpha_diag(stage[ref]),alpha_diag(stage[d])
            if rd>0 and dd>0:
                pair_scale=rd/dd
                rim=stage[d].resize((max(1,round(a.canvas*pair_scale)),max(1,round(a.canvas*pair_scale))),Image.Resampling.LANCZOS)
                anchor=np.array([a.anchor_x*pair_scale,a.anchor_y*pair_scale])
                placed,safety,offset=compose_no_crop(rim,anchor,target_anchor,a.canvas,a.padding)
                stage[d]=placed
                report[d]["pair_scale"]=pair_scale; report[d]["pair_no_crop_safety_scale"]=safety
    ref_stats=build_lut_reference(stage[a.color_ref])
    final={}
    for d in ORDER:
        final[d]=stage[d] if d==a.color_ref else lut_match(stage[d],ref_stats,a.lut_blend)
        final[d].save(a.output_dir/f"{d}.png")
    make_contact_and_gif(final,a.output_dir,a.gif_fps)
    with zipfile.ZipFile(a.output_dir/"normalized_png.zip","w",zipfile.ZIP_DEFLATED) as z:
        for d in ORDER: z.write(a.output_dir/f"{d}.png",arcname=f"{d}.png")
    (a.output_dir/"normalization_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    print(json.dumps({"ok":True,"output":str(a.output_dir),"report":report},indent=2))

if __name__ == "__main__":
    main()
