#!/usr/bin/env python3
"""SeaCraft shared ship look pipeline: v1 global, v2 material-aware, v3 production show-look."""
import argparse,json
from pathlib import Path
import cv2,numpy as np
from PIL import Image,ImageDraw
from skimage import color

ORDER=['N','NE','E','SE','S','SW','W','NW']
Q1=np.array([0,.01,.03,.07,.15,.30,.50,.70,.85,.93,.97,.99,1.])
QM=np.array([.01,.03,.08,.18,.35,.50,.65,.82,.92,.97,.99])
V1={'style':.72,'l':.66,'ab':.70}
V2={'l':{'sail':.78,'wood':.72,'metal':.62,'other':.40},'ab':{'sail':.78,'wood':.72,'metal':.58,'other':.34},'blend':.82}
V3={'l':{'sail':.72,'wood':.66,'metal':.52,'other':.30},'ab':{'sail':.76,'wood':.70,'metal':.48,'other':.24},'blend':.78,'cube_blend':.38,'shadow_a':-.6,'shadow_b':-1.6,'wood_a':.8,'wood_b':1.4,'sail_b':[3.,18.]}

def args():
 p=argparse.ArgumentParser();p.add_argument('input_dir',type=Path);p.add_argument('reference_image',type=Path);p.add_argument('output_dir',type=Path);p.add_argument('--stage',choices=['v1','v2','v3'],default='v3');p.add_argument('--cube-size',type=int,default=33);p.add_argument('--comparison-direction',choices=ORDER,default='E');return p.parse_args()
def sm(m):
 v,q=np.linalg.eigh(m);v=np.clip(v,1e-6,None);return q@np.diag(np.sqrt(v))@q.T
def ism(m):
 v,q=np.linalg.eigh(m);v=np.clip(v,1e-6,None);return q@np.diag(1/np.sqrt(v))@q.T
def load(p):
 x={d:Image.open(p/f'{d}.png').convert('RGBA') for d in ORDER};s={i.size for i in x.values()};
 if len(s)!=1: raise SystemExit(f'canvas mismatch: {s}')
 return x
def ref_ship(im):
 u=np.asarray(im.convert('RGB'));h,w,_=u.shape;g=np.full((h,w),cv2.GC_PR_BGD,np.uint8);b=max(8,min(h,w)//80);g[:b]=g[-b:]=cv2.GC_BGD;g[:,:b]=g[:,-b:]=cv2.GC_BGD;l=cv2.cvtColor(u,cv2.COLOR_RGB2LAB);c=u.max(2)-u.min(2);z=np.zeros((h,w),np.uint8);z[int(.04*h):int(.96*h),int(.03*w):int(.97*w)]=1;g[z.astype(bool)&((l[...,0]>42)|(c>15))]=cv2.GC_PR_FGD;bg=np.zeros((1,65));fg=np.zeros((1,65));cv2.grabCut(cv2.cvtColor(u,cv2.COLOR_RGB2BGR),g,None,bg,fg,7,cv2.GC_INIT_WITH_MASK);m=((g==cv2.GC_FGD)|(g==cv2.GC_PR_FGD)).astype(np.uint8);m=cv2.morphologyEx(m,cv2.MORPH_CLOSE,cv2.getStructuringElement(cv2.MORPH_ELLIPSE,(7,7)));n,lb,st,_=cv2.connectedComponentsWithStats(m,8);m=(lb==(1+np.argmax(st[1:,cv2.CC_STAT_AREA]))) if n>1 else m.astype(bool);return u.astype(np.float32)/255,m
def masks(rgb,a=None):
 q=color.rgb2lab(np.clip(rgb,0,1));L,A,B=q[...,0],q[...,1],q[...,2];fg=np.ones(L.shape,bool) if a is None else a>.15;s=fg&(L>42)&(L<94)&(B>1)&(B<24)&(np.abs(A)<15);w=fg&(L>10)&(L<75)&(A>1.5)&(B>5);m=fg&(L<50)&(np.abs(A)<11)&(B<9);m&=~s;w&=~s&~m;o=fg&~s&~w&~m;return {'sail':s,'wood':w,'metal':m,'other':o}
def stat(mask,lab,q):
 p=lab[mask];p=p[(p[:,0]>3)&(p[:,0]<98)]
 if len(p)<100:return None
 ab=p[:,1:3];return {'q':q,'L':np.quantile(p[:,0],q),'med':np.median(ab,0),'cov':np.cov(ab.T)+np.eye(2)*1e-3}
def src_global(imgs):
 p=[]
 for im in imgs.values():
  a=np.asarray(im).astype(np.float32)/255;l=color.rgb2lab(a[...,:3]);x=l[a[...,3]>.15];x=x[(x[:,0]>4)&(x[:,0]<97)];p.append(x)
 p=np.concatenate(p);ab=p[:,1:3];return {'q':Q1,'L':np.quantile(p[:,0],Q1),'med':np.median(ab,0),'cov':np.cov(ab.T)+np.eye(2)*1e-3}
def src_mat(imgs,k):
 p=[]
 for im in imgs.values():
  a=np.asarray(im).astype(np.float32)/255;l=color.rgb2lab(a[...,:3]);x=l[masks(a[...,:3],a[...,3])[k]];x=x[(x[:,0]>3)&(x[:,0]<98)];
  if len(x):p.append(x)
 if not p:return None
 p=np.concatenate(p);ab=p[:,1:3];return {'q':QM,'L':np.quantile(p[:,0],QM),'med':np.median(ab,0),'cov':np.cov(ab.T)+np.eye(2)*1e-3}
def grade(lab,ss,rs,ls,cs,mask=None):
 L=np.interp(lab[...,0],np.maximum.accumulate(ss['L']+np.arange(len(ss['L']))*1e-5),rs['L']);T=sm(rs['cov'])@ism(ss['cov']);ab=((lab[...,1:3].reshape(-1,2)-ss['med'])@T.T+rs['med']).reshape(lab.shape[0],lab.shape[1],2);o=lab.copy()
 if mask is None:o[...,0]=lab[...,0]*(1-ls)+L*ls;o[...,1:3]=lab[...,1:3]*(1-cs)+ab*cs
 else:o[...,0][mask]=lab[...,0][mask]*(1-ls)+L[mask]*ls;o[...,1:3][mask]=lab[...,1:3][mask]*(1-cs)+ab[mask]*cs
 return o
def film(L):
 x=np.clip(L/100,0,1);y=.5+(x-.5)*1.055;y=np.where(y<.16,.16*((np.clip(y,0,None)/.16)**.88),y);h=y>.78;y[h]=.78+.22*(1-np.exp(-(y[h]-.78)*3.3))/(1-np.exp(-.22*3.3));return np.clip(y*100,0,100)
def run_v1(im,ss,rs):
 a=np.asarray(im).astype(np.float32)/255;lab=color.rgb2lab(a[...,:3]);st=np.clip(color.lab2rgb(grade(lab,ss,rs,V1['l'],V1['ab'])),0,1);rgb=a[...,:3]*(1-V1['style'])+st*V1['style'];o=np.dstack([rgb,a[...,3]]);o[a[...,3]<.005,:3]=0;return Image.fromarray((o*255).astype(np.uint8),'RGBA')
def run_mat(im,ss,rs,stage):
 c=V2 if stage=='v2' else V3;a=np.asarray(im).astype(np.float32)/255;alpha,rgb=a[...,3],a[...,:3];lab=color.rgb2lab(rgb);mm=masks(rgb,alpha);o=lab.copy()
 for k,m in mm.items():
  if ss[k] is not None and rs[k] is not None and m.sum()>=50:o=grade(o,ss[k],rs[k],c['l'][k],c['ab'][k],m)
 if stage=='v3':
  o[...,0]=film(o[...,0]);sh=(o[...,0]<38)&(alpha>.15);o[...,1][sh]+=V3['shadow_a'];o[...,2][sh]+=V3['shadow_b'];mw=mm['wood']&(o[...,0]>22)&(o[...,0]<65);o[...,1][mw]+=V3['wood_a'];o[...,2][mw]+=V3['wood_b'];sa=mm['sail'];o[...,1][sa]*=.90;o[...,2][sa]=np.clip(o[...,2][sa],*V3['sail_b'])
 st=np.clip(color.lab2rgb(o),0,1);rgb=rgb*(1-c['blend'])+st*c['blend'];out=np.dstack([rgb,alpha]);out[alpha<.005,:3]=0;return Image.fromarray((out*255).astype(np.uint8),'RGBA')
def finish(rgb):
 l=color.rgb2lab(rgb.reshape((-1,1,3))).reshape((-1,3));l[:,0]=film(l[:,0]);s=l[:,0]<38;l[s,1]+=V3['shadow_a'];l[s,2]+=V3['shadow_b'];st=np.clip(color.lab2rgb(l.reshape((-1,1,3))).reshape((-1,3)),0,1);b=V3['cube_blend'];return np.clip(rgb*(1-b)+st*b,0,1)
def cube(p,n):
 if not 2<=n<=65:raise SystemExit('cube size 2..65')
 g=np.array([[r,g,b] for b in np.linspace(0,1,n) for g in np.linspace(0,1,n) for r in np.linspace(0,1,n)]);m=finish(g);p.write_text('\n'.join(['TITLE "SeaCraft ShowLook v3"',f'LUT_3D_SIZE {n}','DOMAIN_MIN 0 0 0','DOMAIN_MAX 1 1 1']+[f'{r:.7f} {g:.7f} {b:.7f}' for r,g,b in m]))
def contact(imgs,p):
 w,h=imgs['N'].size;o=Image.new('RGBA',(w*4,h*2));
 for i,d in enumerate(ORDER):o.alpha_composite(imgs[d],((i%4)*w,(i//4)*h))
 o.save(p)
def compare(a,b,d,p,s):
 w,h=a.size;m=36;hd=78;o=Image.new('RGBA',(w*2+m*3,h+hd+m*2),(34,37,43,255));dr=ImageDraw.Draw(o);dr.text((m,24),f'SeaCraft · {d} · {s}',fill='white')
 for i,(im,t) in enumerate(((a,'BEFORE'),(b,f'AFTER · {s.upper()}'))):
  x=m+i*(w+m);c=Image.new('RGBA',(w,h),(34,37,43,255));c.alpha_composite(im);o.alpha_composite(c,(x,hd));dr.rounded_rectangle((x+18,hd+18,x+220,hd+58),9,fill=(15,17,21,220));dr.text((x+34,hd+29),t,fill='white')
 o.convert('RGB').save(p,quality=96)
def ser(x):
 if x is None:return None
 return {k:(v.tolist() if isinstance(v,np.ndarray) else v) for k,v in x.items()}
def main():
 a=args();a.output_dir.mkdir(parents=True,exist_ok=True);imgs=load(a.input_dir);rr,rm=ref_ship(Image.open(a.reference_image));rl=color.rgb2lab(rr)
 if a.stage=='v1':
  rs=stat(rm,rl,Q1);ss=src_global(imgs);out={d:run_v1(imgs[d],ss,rs) for d in ORDER};prof={'stage':'v1','name':'SeaCraft Global Theme LUT v1','settings':V1,'source':ser(ss),'reference':ser(rs)}
 else:
  rmask=masks(rr,rm.astype(np.float32));rs={k:stat(rmask[k],rl,QM) for k in rmask};ss={k:src_mat(imgs,k) for k in rmask};out={d:run_mat(imgs[d],ss,rs,a.stage) for d in ORDER};prof={'stage':a.stage,'name':'SeaCraft Global Theme LUT v2 material-aware' if a.stage=='v2' else 'SeaCraft ShowLook v3','settings':V2 if a.stage=='v2' else V3,'source':{k:ser(v) for k,v in ss.items()},'reference':{k:ser(v) for k,v in rs.items()}}
 val={}
 for d in ORDER:
  out[d].save(a.output_dir/f'{d}.png');al=np.asarray(out[d].getchannel('A'));val[d]={'size':list(out[d].size),'mode':out[d].mode,'edge_alpha_max':max(int(al[0].max()),int(al[-1].max()),int(al[:,0].max()),int(al[:,-1].max()))}
 contact(out,a.output_dir/f'contactsheet_{a.stage}.png');compare(imgs[a.comparison_direction],out[a.comparison_direction],a.comparison_direction,a.output_dir/f'comparison_{a.comparison_direction}_{a.stage}.png',a.stage)
 if a.stage=='v3':cube(a.output_dir/f'SeaCraft_ShowLook_v3_{a.cube_size}.cube',a.cube_size)
 (a.output_dir/f'profile_{a.stage}.json').write_text(json.dumps(prof,indent=2));(a.output_dir/'validation.json').write_text(json.dumps({'all_same_canvas':len({out[d].size for d in ORDER})==1,'all_rgba':all(out[d].mode=='RGBA' for d in ORDER),'all_edge_alpha_zero':all(val[d]['edge_alpha_max']==0 for d in ORDER),'frames':val},indent=2));print(json.dumps({'ok':True,'stage':a.stage,'output':str(a.output_dir)},indent=2))
if __name__=='__main__':main()
