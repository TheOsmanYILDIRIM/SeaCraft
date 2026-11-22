#!/usr/bin/env python3
"""Extract 8 isolated ship objects from a SeaCraft radial board.

Canonical rule:
- Never crop fixed angular wedges as final objects.
- Detect the 8 largest connected alpha objects globally.
- Assign each object to N/NE/E/SE/S/SW/W/NW from its centroid around board center.
- Keep only pixels belonging to that object; neighboring ships can never leak into the crop.
- Crop to the object's own alpha bbox with transparent padding.
"""
from __future__ import annotations
import argparse, json, math, zipfile
from pathlib import Path
import cv2, numpy as np
from PIL import Image, ImageDraw

ORDER=["N","NE","E","SE","S","SW","W","NW"]
SLOT_ANGLES={"E":0.0,"SE":45.0,"S":90.0,"SW":135.0,"W":180.0,"NW":225.0,"N":270.0,"NE":315.0}
OPPOSITE={"N":"S","NE":"SW","E":"W","SE":"NW","S":"N","SW":"NE","W":"E","NW":"SE"}

def parse_args():
    p=argparse.ArgumentParser()
    p.add_argument("input_image", type=Path)
    p.add_argument("output_dir", type=Path)
    p.add_argument("--padding", type=int, default=16)
    p.add_argument("--alpha-threshold", type=int, default=8)
    p.add_argument("--min-area", type=int, default=500)
    p.add_argument("--facing", choices=["outward","inward"], default="outward")
    return p.parse_args()

def nearest_slot(cx,cy,bx,by):
    a=(math.degrees(math.atan2(cy-by,cx-bx))+360.0)%360.0
    return min(SLOT_ANGLES, key=lambda d: abs(((a-SLOT_ANGLES[d]+180)%360)-180))

def main():
    a=parse_args()
    a.output_dir.mkdir(parents=True,exist_ok=True)
    im=Image.open(a.input_image).convert("RGBA")
    arr=np.asarray(im)
    alpha=arr[...,3]
    if alpha.min()>=250:
        raise SystemExit("Radial extractor requires real transparency/alpha. Opaque studio backgrounds must be alpha-extracted first.")

    fg=(alpha>a.alpha_threshold).astype(np.uint8)
    n,labels,stats,cents=cv2.connectedComponentsWithStats(fg,8)
    comps=[]
    for i in range(1,n):
        area=int(stats[i,cv2.CC_STAT_AREA])
        if area<a.min_area: continue
        x,y,w,h=[int(v) for v in stats[i,:4]]
        cx,cy=[float(v) for v in cents[i]]
        comps.append({"id":i,"area":area,"bbox":[x,y,x+w,y+h],"centroid":[cx,cy]})
    comps=sorted(comps,key=lambda c:c["area"],reverse=True)[:8]
    if len(comps)!=8:
        raise SystemExit(f"Expected 8 major objects, found {len(comps)}.")

    bx,by=im.width/2.0,im.height/2.0
    assigned={}
    for c in comps:
        slot=nearest_slot(c["centroid"][0],c["centroid"][1],bx,by)
        d=slot if a.facing=="outward" else OPPOSITE[slot]
        if d in assigned:
            raise SystemExit(f"Two major objects mapped to {d}; radial layout is ambiguous.")
        assigned[d]=c
    missing=[d for d in ORDER if d not in assigned]
    if missing:
        raise SystemExit("Missing radial slots: "+", ".join(missing))

    report={"source":str(a.input_image),"facing":a.facing,"padding":a.padding,"directions":{}}
    outputs={}
    for d in ORDER:
        c=assigned[d]
        comp=(labels==c["id"])
        ys,xs=np.where(comp)
        x0=max(0,int(xs.min())-a.padding); x1=min(im.width,int(xs.max())+1+a.padding)
        y0=max(0,int(ys.min())-a.padding); y1=min(im.height,int(ys.max())+1+a.padding)
        sub=arr[y0:y1,x0:x1].copy()
        sm=comp[y0:y1,x0:x1]
        out=np.zeros_like(sub)
        out[sm]=sub[sm]
        png=Image.fromarray(out,"RGBA")
        png.save(a.output_dir/f"{d}.png")
        outputs[d]=png
        report["directions"][d]={
            "component_area":c["area"],
            "centroid":c["centroid"],
            "source_bbox":[x0,y0,x1,y1],
            "output_size":[x1-x0,y1-y0]
        }

    cell=360
    sheet=Image.new("RGBA",(cell*4,cell*2),(68,72,78,255))
    for i,d in enumerate(ORDER):
        imd=outputs[d]
        s=min((cell-24)/imd.width,(cell-24)/imd.height)
        r=imd.resize((max(1,round(imd.width*s)),max(1,round(imd.height*s))),Image.Resampling.LANCZOS)
        x=(i%4)*cell+(cell-r.width)//2; y=(i//4)*cell+(cell-r.height)//2
        sheet.alpha_composite(r,(x,y))
        ImageDraw.Draw(sheet).text(((i%4)*cell+10,(i//4)*cell+10),d,fill=(255,255,255,230))
    sheet.convert("RGB").save(a.output_dir/"extraction_contactsheet.png",quality=95)
    (a.output_dir/"extraction_report.json").write_text(json.dumps(report,indent=2),encoding="utf-8")
    with zipfile.ZipFile(a.output_dir/"extracted_png.zip","w",zipfile.ZIP_DEFLATED) as z:
        for d in ORDER:z.write(a.output_dir/f"{d}.png",arcname=f"{d}.png")
    print(json.dumps({"ok":True,"output":str(a.output_dir),"report":report},indent=2))

if __name__=="__main__":
    main()
