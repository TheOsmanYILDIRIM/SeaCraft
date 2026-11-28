"""SC-16 approved cloth preview, 2026-11-28. Offline CPU reference, not runtime shader.
Usage: python tools/sc16_sail_demo.py SC16_FINAL_MAX_QUALITY_GITHUB_UPLOAD.zip SC16_yelken_demo.mp4
Dependencies: numpy, opencv-python, Pillow, ffmpeg.
"""
import sys
import numpy as np, cv2, zipfile,json,io, subprocess
from PIL import Image
z=zipfile.ZipFile(sys.argv[1]); a=Image.open(io.BytesIO(z.read('atlas_4x2.png'))).convert('RGBA'); m=json.loads(z.read('mounts.json'))['mounts']['frames']; dirs=['N','NE','E','SE','S','SW','W','NW']; W,H=800,540
Y,X=np.mgrid[:576,:576].astype(np.float32); bg=np.zeros((H,W,3),np.uint8); bg[:]=[37,67,77];
for y in range(H): bg[y]=np.clip(np.array([43,75,85])-y*.025,0,255)
font=cv2.FONT_HERSHEY_SIMPLEX
proc=subprocess.Popen(['ffmpeg','-y','-f','rawvideo','-pix_fmt','rgb24','-s',f'{W}x{H}','-r','30','-i','-','-c:v','libx264','-preset','fast','-crf','19','-pix_fmt','yuv420p','-movflags','+faststart',sys.argv[2]],stdin=subprocess.PIPE,stderr=subprocess.DEVNULL)
def setup(d):
 i=dirs.index(d); im=np.array(a.crop((i%4*576,i//4*576,i%4*576+576,i//4*576+576))); regions=[]; flags=[]
 for q in m[d]:
  if q['hidden']:continue
  p=np.array(q['aligned'],np.float32)
  if q['kind'] in ['sail','jib']:
   mask=np.zeros((576,576),np.uint8); cv2.fillPoly(mask,[np.round(p).astype(np.int32)],255); dist=cv2.distanceTransform(mask,cv2.DIST_L2,5); x,y,w,h=cv2.boundingRect(p); sl=np.s_[y:y+h,x:x+w]; rgb=im[sl][:,:,:3].astype(float); # protect dark rigging and non-cloth
   lum=rgb.mean(2); sat=rgb.max(2)-rgb.min(2); cloth=np.clip((lum-65)/65,0,1)*np.clip((85-sat)/45,0,1); weight=np.clip(dist[sl]/9,0,1)*cloth*(im[sl][:,:,3]/255); regions.append((sl,X[sl].copy(),Y[sl].copy(),weight.astype(np.float32)))
  elif q['kind'] in ['flag','ensign']:flags.append(p)
 return im,regions,flags
scenes={d:setup(d) for d in ['E','NE','SE']}
for k in range(450):
 t=k/30; d=['E','NE','SE'][min(2,int(t/5))]; im,regions,flags=scenes[d]; out=im.copy(); wind=.55+.35*np.sin(t*1.2)**2; zoom=.78 if t<12 else .48
 for sl,x,y,w in regions:
  phase=x*.105+y*.035-t*5; phase2=x*.047-y*.077+t*3.1; wave=np.sin(phase)+.38*np.sin(phase2); dx=(wave*w*wind*2.6).astype(np.float32); dy=(np.cos(phase)*w*wind*.9).astype(np.float32); sample=cv2.remap(im,x+dx,y+dy,cv2.INTER_LINEAR,borderMode=cv2.BORDER_REPLICATE); shade=1+w*wind*(.13*np.cos(phase)+.045*np.cos(phase2)); out[sl][:,:,:3]=np.clip(sample[:,:,:3]*shade[:,:,None],0,255).astype(np.uint8)
 # flags drawn with actual fixed attachment and shaded mesh strips
 for p in flags:
  A,B=p; v=B-A; L=np.linalg.norm(v); u=v/L; n=np.array([-u[1],u[0]]); prev=None
  for j in range(41):
   s=j/40; ph=s*10-t*7; center=A+v*s+n*(s**1.2*wind*(8*np.sin(ph)+3*np.sin(s*17-t*9))); half=7*(1-s)**.65+.45; pair=np.array([center+n*half,center-n*half]);
   if prev is not None:
    shade=.85+.20*np.cos(ph); color=tuple(int(c*shade) for c in [115,103,79]); cv2.fillConvexPoly(out,np.rint([prev[0],pair[0],pair[1],prev[1]]).astype(np.int32),(*color,255),cv2.LINE_AA)
   prev=pair
 frame=bg.copy(); size=int(576*zoom); ship=cv2.resize(out,(size,size),interpolation=cv2.INTER_AREA); x0=(W-size)//2;y0=(H-size)//2+12; dst=frame[y0:y0+size,x0:x0+size]; alpha=ship[:,:,3:4]/255.; dst[:]=ship[:,:,:3]*alpha+dst*(1-alpha); cv2.putText(frame,'SEACRAFT / SC-16', (26,35),font,.65,(220,226,224),1,cv2.LINE_AA); cv2.putText(frame,'UV cloth + dynamic shading   |   '+d,(26,510),font,.55,(205,215,215),1,cv2.LINE_AA); proc.stdin.write(frame.tobytes())
proc.stdin.close(); assert proc.wait()==0
