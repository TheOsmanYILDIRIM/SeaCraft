#!/usr/bin/env python3
"""Deterministic CPU clay preview of exact procedural triangles emitted by geometry.mjs.
Rendering is a rasterized 3D orthographic projection; browser viewer separately uses Three.js WebGL.
NO geometry, frames, or sails are drawn in 2D: all pixels originate from 3D triangles.
"""
from __future__ import annotations
import argparse, json, math, hashlib, os
from pathlib import Path
from concurrent.futures import ThreadPoolExecutor
import cv2
import numpy as np
from PIL import Image, ImageDraw, ImageFont
import trimesh

DIRECTIONS=['N','NE','E','SE','S','SW','W','NW']
PALETTE={'cloth':(195,199,202),'wood':(76,82,90),'rope':(129,137,143),'metal':(111,120,126)}
ELEVATION=math.radians(55)
SUN=np.array([-0.65,-0.35,0.74],dtype=np.float32); SUN/=np.linalg.norm(SUN)

def yaw_for(direction):
    az={'E':0,'SE':45,'S':90,'SW':135,'W':180,'NW':225,'N':270,'NE':315}[direction]
    p=math.radians(az)
    return math.atan2(-math.cos(p),-math.sin(p)/math.sin(ELEVATION))

def render_3d(model, direction, resolution=512, ortho_scale=12, center_z=2.35):
    """Depth-sort triangles with fixed light, opaque double-side material and transparent RGBA."""
    out=np.zeros((resolution,resolution,4),dtype=np.uint8)
    a=yaw_for(direction); co,si=math.cos(a),math.sin(a)
    rot=np.array([[co,-si,0],[si,co,0],[0,0,1]],dtype=np.float32)
    scale=resolution/ortho_scale
    light=SUN
    opaque=[]
    for obj in model['meshes']:
        verts=np.array(obj['vertices'],dtype=np.float32)@rot.T
        v2d=np.empty((len(verts),2),dtype=np.float32)
        v2d[:,0]=resolution/2+verts[:,0]*scale
        v2d[:,1]=resolution/2-(math.sin(ELEVATION)*verts[:,1]+math.cos(ELEVATION)*(verts[:,2]-center_z))*scale
        depth=verts[:,2]*math.sin(ELEVATION)-verts[:,1]*math.cos(ELEVATION)
        face_ids=np.array(obj['triangles'],dtype=np.int32)
        f3=verts[face_ids]
        normals=np.cross(f3[:,1]-f3[:,0],f3[:,2]-f3[:,0])
        normal_norm=np.linalg.norm(normals,axis=1)
        if np.any(normal_norm<1e-9):raise ValueError(f'degenerate triangle: {model["id"]}/{obj["name"]}')
        normals/=normal_norm[:,None]
        shade=.70+.30*np.abs(normals@light)
        base=np.array(PALETTE[obj['material']], dtype=np.float32)
        colors=np.clip(base[None,:]*shade[:,None],0,255).astype(np.uint8)
        d=depth[face_ids].mean(axis=1)
        for i,ids in enumerate(face_ids):
            polygon=v2d[ids]
            if np.max(polygon[:,0])<0 or np.max(polygon[:,1])<0 or np.min(polygon[:,0])>=resolution or np.min(polygon[:,1])>=resolution:continue
            opaque.append((float(d[i]),polygon.astype(np.int32),tuple(int(x) for x in colors[i])+ (255,)))
    # Farthest first; no mirrored images. Polygon faces all come from 3D meshes.
    opaque.sort(key=lambda x:x[0])
    for _,poly,color in opaque:cv2.fillConvexPoly(out,poly,color)
    return Image.fromarray(out,mode='RGBA')

def inspect_bounds(img,margin=3):
    alpha=np.asarray(img.getchannel('A'))
    bbox=img.getchannel('A').getbbox()
    if not bbox:raise RuntimeError('empty render')
    if bbox[0]<=margin or bbox[1]<=margin or bbox[2]>=img.width-margin or bbox[3]>=img.height-margin:
        raise RuntimeError(f'clipped image {bbox} / {img.size}')
    if int((alpha>0).sum())<70:raise RuntimeError('render has too few opaque pixels')
    return dict(bbox=list(bbox),nonzero_pixels=int((alpha>0).sum()),alpha_mode='RGBA',edge_alpha_zero=True)

def make_gallery(records,where,size,columns,rows,title,scale=12,center_z=2.35):
    page=Image.new('RGBA',(size,size),(18,23,29,255));draw=ImageDraw.Draw(page)
    try:
        font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',23)
        small=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
    except OSError:font=small=ImageFont.load_default()
    cell=size//columns
    assert cell*rows==size
    for idx,(id,model) in enumerate(records):
        x=(idx%columns)*cell;y=(idx//columns)*cell
        draw.rounded_rectangle([x+4,y+4,x+cell-4,y+cell-4],radius=9,fill=(29,36,45,255),outline=(56,65,76,255),width=2)
        rendered=render_3d(model,'NE',cell,ortho_scale=scale,center_z=center_z)
        page.alpha_composite(rendered,(x,y+10))
        label=id+'  '+model['name']
        draw.text((x+14,y+cell-47),id,font=font,fill=(230,233,237,255))
        draw.text((x+14,y+cell-20),model['name'][:38],font=small,fill=(174,185,197,255))
    page.save(where)
    return inspect_bounds(page,margin=-1)

def export_glb(model,destination):
    scene=trimesh.Scene(base_frame='world')
    # Preserve hierarchy and root identity in GLB; mesh vertices already vessel-local.
    def groups(node,parent):
        scene.graph.update(frame_from=parent,frame_to=node['name'],matrix=np.eye(4))
        for child in node.get('children',[]):
            if 'children' in child:groups(child,node['name'])
    groups(model['root'],'world')
    for m in model['meshes']:
        geo=trimesh.Trimesh(vertices=np.array(m['vertices'],dtype=np.float32),faces=np.array(m['triangles'],dtype=np.int32),process=False)
        rgb=np.array(PALETTE[m['material']],dtype=np.uint8)
        geo.visual.vertex_colors=np.tile(np.r_[rgb,255],(len(geo.vertices),1))
        scene.add_geometry(geo,geom_name=m['name'],node_name=m['name'],parent_node_name=m['parent'])
    binary=scene.export(file_type='glb')
    destination.write_bytes(binary)
    assert destination.stat().st_size>4000
    imported=trimesh.load(str(destination),force='scene')
    assert len(imported.geometry)==len(model['meshes']), (model['id'],'GLB mismatch')
    return {'glb_bytes':len(binary),'glb_sha256':hashlib.sha256(binary).hexdigest(),'glb_geometry_count':len(imported.geometry)}

def main():
    ap=argparse.ArgumentParser();ap.add_argument('--scene-data',default='output/scene_data');ap.add_argument('--out',default='output');ap.add_argument('--mode',choices=['all','sample'],default='all');a=ap.parse_args()
    data=Path(a.scene_data);out=Path(a.out);out.mkdir(parents=True,exist_ok=True)
    models={};QA={'schema':'seacraft.procedural_rig.three.verify.v1','render_engine':'triangle_software_rasterizer','elevation_deg':55,'models':{},'counts':{}}
    for section in ('primitive','rigs','ships'):
        for f in sorted((data/section).glob('*.json')):
            model=json.loads(f.read_text());models[f.stem]=model
            model_id=f.stem
            image_folder=out/'png'/section/model_id;image_folder.mkdir(parents=True,exist_ok=True)
            if a.mode=='sample' and section=='ships' and model_id not in ('SC-03','SC-07','SC-14','SC-15'):continue
            pngs={}
            dirs=DIRECTIONS if section=='ships' else ['NE']
            for d in dirs:
                image=render_3d(model,d)
                dest=image_folder/(d+'.png');image.save(dest)
                pngs[d]=inspect_bounds(image)
            if section=='ships':
                atlas=Image.new('RGBA',(2048,1024),(0,0,0,0))
                for i,d in enumerate(dirs):
                    with Image.open(image_folder/(d+'.png')) as img:atlas.alpha_composite(img,((i%4)*512,(i//4)*512))
                (out/'atlas').mkdir(exist_ok=True)
                atlas.save(out/'atlas'/f'{model_id}_4x2.png')
            glb_path=out/'models'/section/(model_id+'.glb');glb_path.parent.mkdir(parents=True,exist_ok=True)
            glb=export_glb(model,glb_path)
            QA['models'][model_id]={'group':section,'pngs':pngs,**glb,'mast_count':len(model['masts']),'sail_count':len(model['sails']),'geometry_hash':model['geometry_hash']}
            print(f'RENDER_OK {section}/{model_id} {len(pngs)} png GLB:{glb["glb_bytes"]}',flush=True)
    if a.mode=='all':
        gal=out/'gallery';gal.mkdir(parents=True,exist_ok=True)
        prim=[(k,v) for k,v in models.items() if k.startswith(('A_','B_','C_','D_','E_','F_'))]
        rigs=[(k,v) for k,v in models.items() if k.startswith('R') and k[1:3].isnumeric()]
        assert len(prim)==6 and len(rigs)==12
        # 3 columns x 2 rows -> 1536 x 1024; to meet required 1:1 square,
        # use 3x2 cells of 512x768 (retain orthographic aspect; vertical padding only).
        make_rect_gallery(prim,gal/'01_six_families_square_3x2.png',1536,3,2,5.7,1.6)
        make_rect_gallery(rigs,gal/'02_twelve_rigs_square_4x3.png',2048,4,3,9,2.35)
    QA['counts']={'models':len(QA['models']),'png':sum(len(x['pngs']) for x in QA['models'].values()),'glb':len(QA['models'])}
    if a.mode=='all':assert QA['counts']=={'models':33,'png':138,'glb':33},QA['counts']
    (out/'artifact_verification.json').write_text(json.dumps(QA,indent=2,ensure_ascii=False)+'\n')
    print('ALL_VERIFIED',QA['counts'],flush=True)

def make_rect_gallery(records,where,size,cols,rows,scale,center_z):
    """1:1 square, a regular cols x rows grid, each cell is taller/wider as needed."""
    page=Image.new('RGBA',(size,size),(17,22,28,255));draw=ImageDraw.Draw(page)
    try:
        font=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',24)
        small=ImageFont.truetype('/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf',18)
    except OSError:font=small=ImageFont.load_default()
    w=size//cols;h=size//rows
    assert len(records)==cols*rows
    for i,(id,model) in enumerate(records):
        x=(i%cols)*w;y=(i//cols)*h
        draw.rounded_rectangle([x+5,y+5,x+w-6,y+h-6],radius=12,fill=(28,35,44,255),outline=(55,65,76,255),width=2)
        render=render_3d(model,'NE',min(w,h)-16,ortho_scale=scale,center_z=center_z)
        # 3D geometry retains same physical scale, rendered square in each panel.
        page.alpha_composite(render,(x+(w-render.width)//2,y+(h-render.height)//2-15))
        draw.text((x+16,y+h-68),id,font=font,fill=(238,240,241,255))
        draw.text((x+16,y+h-36),model['name'][:40],font=small,fill=(174,186,195,255))
    page.save(where)
    assert page.width==page.height
    print('GALLERY_OK',where.name,flush=True)

if __name__=='__main__':main()
