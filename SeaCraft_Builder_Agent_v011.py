#!/usr/bin/env python3
"""SeaCraft v0.11 headless recipe, render, inspect and provisional sprite registration.
Requires Node.js 18+, Python 3.10+, Pillow; transfer additionally numpy, OpenCV, scipy.
No server, ZIP or browser needed. Reads the exact source modules inside the offline HTML.
"""
import argparse,base64,hashlib,json,os,re,subprocess,tempfile,sys
from pathlib import Path
from PIL import Image,ImageDraw

HERE=Path(__file__).resolve().parent
ORDER=['N','NE','E','SE','S','SW','W','NW']
DERIVED={'E':'W','SW':'SE','NW':'NE'}
DRIVER=r'''
import fs from 'node:fs';
import {createShip,normalizeShip} from './ship.mjs';
import {presets} from './presets.mjs';
import {renderCD,renderSingle,project,collect,rasterView,headings} from './render.mjs';
import {projectedMounts,inspectShip,makeProductionPrompt,disposeShip} from './pro.mjs';
let a=JSON.parse(fs.readFileSync(process.argv[2],'utf8'));let out=a.out;
const save=(n,o)=>fs.writeFileSync(out+'/'+n,JSON.stringify(o,null,2));
const raw=(n,im)=>{fs.writeFileSync(out+'/'+n+'.rgba',im.data);save(n+'.size.json',[im.width,im.height]);};
if(a.action==='list'){console.log(JSON.stringify(Object.fromEntries(Object.entries(presets).map(([k,p])=>[k,p.name]))));process.exit(0)}
let q=a.recipe??presets[a.ship];if(!q)throw Error('Unknown ship');q=structuredClone(q);
for(const [key,v] of Object.entries(a.patch||{})){let path=key.split('.');if(path.some(k=>['__proto__','prototype','constructor'].includes(k)))throw Error('Invalid path');let obj=q;for(let k of path.slice(0,-1)){if(obj[k]==null)throw Error('Unknown path '+key);obj=obj[k]}obj[path.at(-1)]=v;}
q=normalizeShip(q);save('recipe.json',q);if(a.action==='recipe')process.exit(0);
let m=createShip(q),eight=m.userData.needsEight||a.eight;
try{let im=renderCD(m,a.size,'studio',eight);raw('reference_neutral',im);save('projected_mounts.json',projectedMounts(m,im.meta));save('qa_report.json',inspectShip(m));fs.writeFileSync(out+'/prompt.txt',makeProductionPrompt(q,eight));
 if(a.material)raw('reference_material',renderCD(m,a.size,a.studio?'material-studio':'material',eight));if(a.diag)raw('reference_color_id',renderCD(m,a.size,true,eight));
 if(a.views){let parts=collect(m);for(let v of im.meta.views)raw('view_'+v.heading,rasterView(project(parts,headings[v.heading]),im.meta.scale,'studio'));}
 if(a.angles){for(let [name,az,el] of [['bow',180,0],['stern',0,0],['side',90,0],['top',90,89.999],['iso',225,55]])raw('qa_'+name,renderSingle(m,640,az,el,'studio'));}
}finally{disposeShip(m)}
'''
def engine(args,action,views=False):
    html=Path(args.html).read_text();start=html.index('const sources=')+len('const sources=');sources,_=json.JSONDecoder().raw_decode(html[start:]);out=Path(args.out).resolve();out.mkdir(parents=True,exist_ok=True)
    with tempfile.TemporaryDirectory(prefix='seacraft-engine-') as tmp:
        root=Path(tmp);(root/'package.json').write_text('{"type":"module"}')
        for name,src in sources.items():
            if name=='main.mjs':continue
            file=root/name;file.parent.mkdir(parents=True,exist_ok=True)
            def sub(m):
                rel=os.path.relpath(root/m[1],file.parent).replace(os.sep,'/');return rel if rel.startswith('.') else './'+rel
            file.write_text(re.sub(r'@@([^@]+)@@',sub,src))
        (root/'driver.mjs').write_text(DRIVER);data={'action':action,'ship':args.ship,'recipe':json.loads(Path(args.recipe).read_text()) if args.recipe else None,'patch':json.loads(args.patch or '{}'),'out':str(out),'size':args.size,'views':views,'eight':args.eight,'material':args.material,'studio':args.studio,'diag':args.diag,'angles':args.angles}
        (root/'args.json').write_text(json.dumps(data));subprocess.run(['node',str(root/'driver.mjs'),str(root/'args.json')],check=True)
    for raw in out.glob('*.rgba'):
        sizefile=out/(raw.stem+'.size.json');size=tuple(json.loads(sizefile.read_text()));Image.frombytes('RGBA',size,raw.read_bytes()).save(out/(raw.stem+'.png'));raw.unlink();sizefile.unlink()
    if action=='render':
        overlay(out);if_angles(out)
    return out

def overlay(out):
    j=json.loads((out/'projected_mounts.json').read_text());im=Image.open(out/'reference_neutral.png').convert('RGBA');bg=Image.new('RGBA',im.size,(225,231,234,255));bg.alpha_composite(im);d=ImageDraw.Draw(bg);k=max(1,im.width//512)
    for v in j['layout']['views']:
        d.text((v['x']+8*k,v['y']+5*k),v['heading'],fill='#172b36',stroke_width=0)
        for q in j['frames'][v['heading']]:
            if q['hidden']:continue
            points=[tuple(p) for p in q['p']];color='#e08732' if q['kind']=='gun' and q['render_layer']=='rear' else '#cc9d2a' if q['kind']=='gun' else '#168ac3' if q['kind'] in ['bow','stern'] else '#1a9f76'
            if len(points)>1:d.line(points+([points[0]] if q['kind'] in ['sail','jib'] else []),fill=color,width=2*k)
            for x,y in points:d.ellipse((x-2*k,y-2*k,x+2*k,y+2*k),fill=color)
    bg.convert('RGB').save(out/'qa_mount_overlay.jpg',quality=94)

def if_angles(out):
    files=[out/('qa_'+n+'.png') for n in ['bow','stern','side','top','iso']]
    if not all(p.exists() for p in files):return
    cell=340;board=Image.new('RGBA',(cell*3,cell*2),(224,230,234,255));d=ImageDraw.Draw(board)
    for i,p in enumerate(files):
        a=Image.open(p).convert('RGBA');a.thumbnail((cell-16,cell-30));x=(i%3)*cell;y=(i//3)*cell;board.alpha_composite(a,(x+(cell-a.width)//2,y+24));d.text((x+12,y+8),p.stem,fill='#243341')
    board.convert('RGB').save(out/'qa_contact.jpg',quality=94)

def transfer(out,sprite,aligner=None):
    import numpy as np, cv2
    from scipy.optimize import linear_sum_assignment
    from scipy.ndimage import distance_transform_edt
    j=json.loads((out/'projected_mounts.json').read_text());vs=j['layout']['views'];size=Image.open(out/'reference_neutral.png').width
    src=Image.open(sprite).convert('RGBA');a=np.array(src);h,w=a.shape[:2];mask=(a[:,:,3]>127).astype('uint8');n,lab,stat,cent=cv2.connectedComponentsWithStats(mask);nview=len(vs)
    ranked=sorted(range(1,n),key=lambda i:stat[i,4],reverse=True);main=ranked[:nview]
    if len(main)!=nview or min(stat[i,4] for i in main)<.002*w*h or len(ranked)>nview and stat[ranked[nview],4]>.15*min(stat[i,4] for i in main):raise ValueError('Expected separated views; connected components ambiguous. Do not assign automatically.')
    # Match normalized centroid slots globally. A positional sanity gate rejects badly reordered sheets.
    expect=np.array([[ (v['x']+v['w']/2)/size,(v['y']+v['h']/2)/size] for v in vs]);actual=cent[main]/[w,h];cost=((expect[:,None,:]-actual[None,:,:])**2).sum(axis=2);rr,cc=linear_sum_assignment(cost)
    if np.max(cost[rr,cc])>.19**2:raise ValueError('View layout mismatch. Confirm actual directions manually.')
    assignment={int(r):main[int(c)] for r,c in zip(rr,cc)}
    # Preserve thin connected alpha details; assign isolated fragments to nearest major component within 14 px (scaled with source).
    mainlabels=np.where(np.isin(lab,main),lab,0);dist,nearest=distance_transform_edt(mainlabels==0,return_indices=True);owners=mainlabels[nearest[0],nearest[1]];owners[(dist>max(8,min(w,h)*.016))| (a[:,:,3]==0)]=0
    info={};report={};maxdist=0
    for idx,v in enumerate(vs):
        heading=v['heading'];label=assignment[idx];target=a.copy();target[owners!=label]=0;im=Image.fromarray(target);bbox=im.getchannel('A').getbbox();x0,y0,x1,y1=bbox;tw,th=x1-x0,y1-y0;targetmask=(target[y0:y1,x0:x1,3]>127).astype('uint8')
        ref=np.array(Image.open(out/('view_'+heading+'.png')).convert('RGBA'));rb=Image.fromarray(ref[:,:,3]).getbbox();rx0,ry0,rx1,ry1=rb;rw,rh=rx1-rx0,ry1-ry0;refmask=(ref[ry0:ry1,rx0:rx1,3]>127).astype('uint8')
        # Silhouette registration in normalized 192x192 coordinates. Limited affine corrections, never deform output sprite.
        N=192;pad=24;span=N-2*pad;R=cv2.resize(refmask,(span,span),interpolation=cv2.INTER_NEAREST);T=cv2.resize(targetmask,(span,span),interpolation=cv2.INTER_NEAREST);R=cv2.copyMakeBorder(R,pad,pad,pad,pad,cv2.BORDER_CONSTANT);T=cv2.copyMakeBorder(T,pad,pad,pad,pad,cv2.BORDER_CONSTANT)
        def score(q):
            sx,sy,tx,ty=q;mat=np.array([[sx,0,(1-sx)*N/2+tx],[0,sy,(1-sy)*N/2+ty]],dtype='float32');W=cv2.warpAffine(R,mat,(N,N),flags=cv2.INTER_NEAREST);union=np.count_nonzero(W|T);return np.count_nonzero(W&T)/max(1,union)
        q=[1.,1.,0.,0.];initial=score(q);best=initial
        for st in [.10,.05,.025]:
            for _ in range(2):
                for k in range(4):
                    for sign in [-1,1]:
                        r=q.copy();r[k]+=sign*(st if k<2 else st*span*.5)
                        if not(.8<=r[0]<=1.2 and .8<=r[1]<=1.2 and abs(r[2])<span*.1 and abs(r[3])<span*.1):continue
                        vscore=score(r)
                        if vscore>best:q,best=r,vscore
        def transform(pt):
            px,py=pt;xx=(px-v['x']-rx0)/rw*span+pad;yy=(py-v['y']-ry0)/rh*span+pad;sx,sy,tx,ty=q;xx=sx*(xx-N/2)+N/2+tx;yy=sy*(yy-N/2)+N/2+ty;return [(xx-pad)/span*tw+x0,(yy-pad)/span*th+y0]
        pivot=transform([v['originX'],v['originY']]);pts=[dict(m,p=[transform(p) for p in m['p']]) for m in j['frames'][heading]];maxdist=max(maxdist,abs(x0-pivot[0]),abs(x1-pivot[0]),abs(y0-pivot[1]),abs(y1-pivot[1]));info[heading]=(im,pivot,pts,bbox);report[heading]={'bbox':bbox,'reference_bbox':rb,'silhouette_iou':round(best,4),'bbox_iou':round(initial,4),'registration':q,'estimated_pivot':pivot,'status':'manual_check_required'}
    # Same scale for every source frame, estimated waterline pivot; no per-direction rescaling.
    k=min(1.0,460/maxdist);frames={};imgs={};aligned={}
    for d,(im,pivot,pts,bbox) in info.items():
        # Pillow affine in premultiplied alpha; one uniform scale and translation across all.
        f=im.convert('RGBa').transform((1024,1024),Image.Transform.AFFINE,(1/k,0,pivot[0]-512/k,0,1/k,pivot[1]-512/k),resample=Image.Resampling.BICUBIC).convert('RGBA');imgs[d]=f
        for m in pts:
            m['p']=[[(x-pivot[0])*k,(y-pivot[1])*k] for x,y in m['p']];m['aligned']=[[x+512,y+512] for x,y in m['p']];m['aligned_masks']=[]
        aligned[d]=pts;frames[d]={'x':0,'y':0,'scale':1,'beam':1,'warp':[],'pins':[]}
    if j['direction_mode']=='five':
        for d,orig in DERIVED.items():
            imgs[d]=imgs[orig].transpose(Image.Transpose.FLIP_LEFT_RIGHT);frames[d]=dict(frames[orig]);aligned[d]=[]
            for m in aligned[orig]:
                ident=re.sub(r'PORT|STARBOARD',lambda z:'STARBOARD' if z.group()=='PORT' else 'PORT',m['id']);p=[[-x,y] for x,y in m['p']];aligned[d].append(dict(m,id=ident,p=p,aligned=[[x+512,y+512] for x,y in p],mirror=not m['mirror']))
    m={'direction_mode':j['direction_mode'],'derived':j['derived'],'schema':'seacraft-mounts-v1','space':'source-local-1024-centered','aligned_space':'cell-1024-top-left','frames':{d:aligned[d] for d in ORDER}}
    data={'fps':12,'direction_mode':j['direction_mode'],'frames':{d:frames[d] for d in ORDER},'mounts':m};(out/'alignment_seed.json').write_text(json.dumps(data,indent=2));(out/'registration_report.json').write_text(json.dumps({'status':'PROVISIONAL_NOT_APPROVED','common_scale':k,'views':report,'warning':'Direction correspondence and per-point registration must be visually approved. No occlusion masks inferred.'},indent=2));
    for d,im in imgs.items():
        if j['direction_mode']=='eight' or d not in DERIVED:im.save(out/(d+'.png'))
    # QA overview with projected sockets over actual GPT image. No changes to source image.
    cell=320;board=Image.new('RGBA',(cell*4,cell*2),(29,41,51,255));draw=ImageDraw.Draw(board)
    for i,d in enumerate(ORDER):
        x=(i%4)*cell;y=(i//4)*cell;part=imgs[d].resize((cell,cell),Image.Resampling.LANCZOS);board.alpha_composite(part,(x,y));draw.text((x+8,y+8),d,fill='white')
        for obj in aligned[d]:
            if obj['hidden']:continue
            p=[(x+u*cell/1024,y+v*cell/1024) for u,v in obj['aligned']];color='#e7a145' if obj['kind']=='gun' else '#49c5a2' if obj['kind'] in ['sail','jib','flag','ensign'] else '#5dc3f0'
            if len(p)>1:draw.line(p+([p[0]] if obj['kind'] in ['sail','jib'] else []),fill=color,width=1)
            for px,py in p:draw.ellipse((px-2,py-2,px+2,py+2),fill=color)
    board.convert('RGB').save(out/'registration_QA.jpg',quality=94)
    if aligner:
        template=Path(aligner).read_text();key=hashlib.sha256(Path(sprite).read_bytes()+json.dumps(data,sort_keys=True).encode()).hexdigest()[:16];template=re.sub(r"KEY='[^']*'","KEY='seacraft-seed-"+key+"'",template,count=1);assets={d:'data:image/png;base64,'+base64.b64encode((out/(d+'.png')).read_bytes()).decode() for d in ORDER if d in info};source=json.dumps(assets,separators=(',',':'));seed=json.dumps(data,separators=(',',':'))
        js='''<script>(async()=>{const assets=ASSETS,data=SEED;let saved=false;try{saved=!!localStorage.getItem(KEY+'-mounts')}catch(e){}if(!saved)SeaCraftMounts.setDirectionMode(data.direction_mode);await Promise.all(Object.entries(assets).map(async([d,url])=>{let im=new Image();await new Promise((ok,no)=>{im.onload=ok;im.onerror=no;im.src=url});imgs[d]=im;meta[d]=await analyze(im)}));await SeaCraftMounts.syncImages();if(!saved){for(const d of ORDER)Object.assign(state[d],data.frames[d]);fps=data.fps;SeaCraftMounts.load(data.mounts);save()}current=6;render();document.documentElement.dataset.ready='true';})().catch(console.error)</script>'''.replace('ASSETS',source).replace('SEED',seed)
        (out/'alignment_review.html').write_text(template.replace('</body>',js+'</body>'))
    return report

def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('action',choices=['list','recipe','render','transfer']);p.add_argument('--html',default=str(HERE/'SeaCraft_ShipBuilder_v011.html'));p.add_argument('--ship',default='SC-02');p.add_argument('--recipe');p.add_argument('--patch',help='JSON object of dotted paths, e.g. {"rigs.0.options.height":2.1}');p.add_argument('--out',default='seacraft_output');p.add_argument('--size',type=int,default=2048);p.add_argument('--eight',action='store_true');p.add_argument('--material',action='store_true');p.add_argument('--studio',action='store_true',help='Use studio material output instead of standard Material CD');p.add_argument('--diag',action='store_true');p.add_argument('--angles',action='store_true');p.add_argument('--views',action='store_true');p.add_argument('--sprite');p.add_argument('--aligner',help='Optional v6 alignment template; embeds seeded PNGs and points into HTML')
    a=p.parse_args();assert 256<=a.size<=4096,'size range';out=engine(a,'render' if a.action=='transfer' else a.action,a.views or a.action=='transfer');
    if a.action=='transfer':
        if not a.sprite:p.error('--sprite required');
        print(json.dumps(transfer(out,a.sprite,a.aligner),indent=2))
    print(out)
if __name__=='__main__':main()
