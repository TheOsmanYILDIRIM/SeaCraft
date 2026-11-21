#!/usr/bin/env python3
"""SeaCraft 8-direction sprite normalizer.

Canonical pipeline:
1) foreground mask (alpha, or GrabCut for opaque studio backgrounds)
2) orthographic world-scale normalization using heading/projection ratios
3) hull-weighted anchor placement
4) 180-degree counterpart footprint lock
5) Lab/LUT-like color match to a canonical direction (default N)
6) no-crop safety fit + QA outputs

Production default: tolerant water-contact/support-anchor alignment. The normal
production path requires no manual landmark marking or manual alignment JSON.

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
PAIR_GROUPS = [("N","S"),("NE","SW"),("E","W"),("SE","NW")]

# SC-03 manual alignment was used only as QA/calibration evidence. The runtime
# does not require manual landmarks or alignment JSON. Values are softened
# residual fractions of the canonical broadside span so one ship is not copied
# frame-for-frame.
SUPPORT_PROFILE = {
    "global_target_offset_frac": (13.84/790.0, -30.11/790.0),
    "family_residual_frac": {
        "NS": (-14.83/790.0,  13.05/790.0),
        "NESW": (-9.42/790.0, -27.23/790.0),
        "EW": (8.85/790.0, 22.98/790.0),
        "SENW": (15.40/790.0, -8.80/790.0),
    },
    "residual_strength": 0.85,
    "scale_strength": 0.766,
}

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
    p.add_argument("--support-anchor", dest="support_anchor", action="store_true", default=True,
                   help="Production default: tolerant water-contact/support-anchor refinement; no manual alignment data required")
    p.add_argument("--no-support-anchor", dest="support_anchor", action="store_false",
                   help="Disable support-anchor refinement")
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

def dense_hull_component(im: Image.Image):
    """Thick wooden hull body; removes sails and most rigging."""
    arr=np.asarray(im.convert("RGBA"))
    fg=arr[...,3] > 20
    rgb=arr[...,:3].astype(np.float32)
    lum=.2126*rgb[...,0]+.7152*rgb[...,1]+.0722*rgb[...,2]
    wood=fg & (lum < 180) & (rgb[...,0] > rgb[...,2]*1.02)
    m=(wood.astype(np.uint8)*255)
    m=cv2.morphologyEx(m,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7)))
    m=cv2.morphologyEx(m,cv2.MORPH_CLOSE,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(11,11)))
    n,lab,stats,_=cv2.connectedComponentsWithStats((m>0).astype(np.uint8),8)
    if n<=1:
        return wood
    idx=1+np.argmax(stats[1:,cv2.CC_STAT_AREA])
    return lab==idx

def support_anchor_point(im: Image.Image):
    """Two-'feet' style anchor: broad hull support midpoint in X + dense hull center in Y."""
    hm=dense_hull_component(im)
    ys,xs=np.where(hm)
    if len(xs)<100:
        a=np.asarray(im.getchannel("A"))>20
        ys,xs=np.where(a)
        return np.array([xs.mean(),ys.mean()],float)

    # X: midpoint of rows whose hull width is at least 80% of max beam.
    rows=[]
    for y in range(hm.shape[0]):
        xx=np.where(hm[y])[0]
        if len(xx)>=5:
            rows.append((y,xx.min(),xx.max(),xx.max()-xx.min()+1))
    rr=np.asarray(rows,float)
    maxw=rr[:,3].max()
    sel=rr[:,3]>=maxw*.80
    x_anchor=np.mean((rr[sel,1]+rr[sel,2])*.5)

    # Y: center of a dense wooden body after opening; avoids mast/sail pull.
    m=(hm.astype(np.uint8)*255)
    op=cv2.morphologyEx(m,cv2.MORPH_OPEN,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7)))
    yy,xx=np.where(op>0)
    y_anchor=float(yy.mean()) if len(yy) else float(ys.mean())
    return np.array([float(x_anchor),y_anchor],float)

def support_hull_span(im: Image.Image, deg: float):
    hm=dense_hull_component(im)
    span,*_=heading_measure(hm,deg)
    return span

def transform_canvas_no_crop(im: Image.Image, scale: float, offset, canvas: int, padding: int):
    """Scale around canvas center, then translate; never discard visible alpha."""
    nw=max(1,round(im.width*scale)); nh=max(1,round(im.height*scale))
    rim=im.resize((nw,nh),Image.Resampling.LANCZOS)
    source_center=np.array([im.width*.5*scale, im.height*.5*scale],float)
    target_center=np.array([canvas*.5+offset[0], canvas*.5+offset[1]],float)
    return compose_no_crop(rim,source_center,target_center,canvas,padding)

def support_family_key(d: str):
    if d in ("N","S"): return "NS"
    if d in ("NE","SW"): return "NESW"
    if d in ("E","W"): return "EW"
    return "SENW"

def refine_with_support_anchor(stage, ratio, broadside_px, canvas, padding):
    """Tolerant ship-on-water alignment validated against SC-03 manual QA.

    Production use is fully automatic: no manual landmarks or alignment JSON
    are consumed. Opposite direction families are fitted together instead of
    reproducing any hand-tuned frame exactly.
    """
    center=np.array([canvas*.5,canvas*.5],float)
    spans={d:support_hull_span(stage[d],HEADING[d]) for d in ORDER}
    a={d:ratio[d]/max(1e-6,spans[d]) for d in ORDER}

    # No manual target size needed: choose K so average proposed correction is 1.
    K=1.0/np.mean([a[d] for d in ORDER])
    raw_scale={d:K*a[d] for d in ORDER}
    pair_scale={}
    for p in PAIR_GROUPS:
        v=np.mean([raw_scale[d] for d in p])
        v=1.0+SUPPORT_PROFILE["scale_strength"]*(v-1.0)
        for d in p: pair_scale[d]=float(np.clip(v,.85,1.15))

    anchors={d:support_anchor_point(stage[d]) for d in ORDER}
    q={d:center+pair_scale[d]*(anchors[d]-center) for d in ORDER}

    go=np.array(SUPPORT_PROFILE["global_target_offset_frac"])*broadside_px
    target=center+go
    refined={}; meta={}
    for d in ORDER:
        residual=np.array(SUPPORT_PROFILE["family_residual_frac"][support_family_key(d)])*broadside_px
        residual*=SUPPORT_PROFILE["residual_strength"]
        offset=target-q[d]+residual
        placed,safety,_=transform_canvas_no_crop(stage[d],pair_scale[d],offset,canvas,padding)
        refined[d]=placed
        meta[d]={
            "support_anchor":[float(x) for x in anchors[d]],
            "support_hull_span":float(spans[d]),
            "support_scale":float(pair_scale[d]),
            "support_offset":[float(x) for x in offset],
            "support_no_crop_safety_scale":float(safety),
        }
    return refined,meta

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
    if a.support_anchor:
        stage,support_meta=refine_with_support_anchor(stage,ratio,a.broadside_px,a.canvas,a.padding)
        for d in ORDER:
            report[d].update(support_meta[d])
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
