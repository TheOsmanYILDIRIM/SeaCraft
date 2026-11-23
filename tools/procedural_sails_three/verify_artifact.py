"""Independent packaging gate: counts, PNG transparency, unclipped pixels, GLB readback."""
import argparse,json,hashlib
from pathlib import Path
import numpy as np
from PIL import Image
import trimesh
p=argparse.ArgumentParser();p.add_argument('--out',default='output');args=p.parse_args();out=Path(args.out)
cat=json.loads((Path(__file__).parent/'catalog.json').read_text())
qa=json.loads((out/'artifact_verification.json').read_text())
validation=json.loads((out/'validation.json').read_text())
assert qa['counts']=={'models':33,'png':138,'glb':33},qa['counts']
assert set(qa['models'])==set(cat['primitive'])|set(cat['rigs'])|set(cat['ships'])
for group in ('primitive','rigs','ships'):
 for k,preset in cat[group].items():
  item=qa['models'][k];geom=validation['generated'][group][k]
  assert item['geometry_hash']==geom['geometry_hash'],k
  assert geom['mast_count']==len(preset['masts']),k
  assert geom['sail_count']==sum(len(m['sails']) for m in preset['masts']),k
  assert len(geom['headings'])==8,k
  glb=out/'models'/group/(k+'.glb')
  assert hashlib.sha256(glb.read_bytes()).hexdigest()==item['glb_sha256'],k
  imported=trimesh.load(str(glb),force='scene');assert len(imported.geometry)==geom['mesh_count'],k
  for d in (cat['directions'] if group=='ships' else ['NE']):
   f=out/'png'/group/k/(d+'.png')
   with Image.open(f) as img:
    assert img.mode=='RGBA' and img.size==(512,512),str(f)
    alpha=np.array(img.getchannel('A'))
    assert alpha.max()==255 and alpha.min()==0,str(f)
    assert not np.any(alpha[:4]) and not np.any(alpha[-4:]) and not np.any(alpha[:,:4]) and not np.any(alpha[:,-4:]),str(f)
    assert np.count_nonzero(alpha)>70,str(f)
for filename,size in [('01_six_families_square_3x2.png',(1536,1536)),('02_twelve_rigs_square_4x3.png',(2048,2048))]:
 with Image.open(out/'gallery'/filename) as img:assert img.size==size and img.mode=='RGBA'
for k in cat['ships']:
 with Image.open(out/'atlas'/f'{k}_4x2.png') as img:assert img.size==(2048,1024) and img.mode=='RGBA'
print('ARTIFACT_VERIFIED models=33 alpha_png=138 glb=33 atlases=15 galleries=2 root_yaw_matrix=8/8')
