import test from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs';
import {DIRECTIONS,headingYaw,buildRig,verifyRig,validateCatalog,catalogs} from '../geometry.mjs';
const catalog=JSON.parse(fs.readFileSync(new URL('../catalog.json',import.meta.url),'utf8'));

test('catalog matches 6/12/15 canonical mast and sail roster',()=>{
  assert.equal(validateCatalog(catalog),true);
  assert.deepEqual(catalog.camera,{elevation_deg:55,roll_deg:0,orthographic_scale:12,resolution:512});
  assert.equal(catalogs(catalog).length,33);
  assert.equal(catalog.ships['SC-14'].masts.length,4);
  assert.deepEqual(catalog.ships['SC-15'].masts.map(m=>m.broken),[false,true,false]);
  assert.equal(catalog.ships['SC-11'].clear_zone.center_y[0],-.85);
});

test('actual meshes, rigging and every attachment verify for all 33 model presets',()=>{
  for(const {id,preset} of catalogs(catalog)){
    const model=buildRig(preset,id);
    const qa=verifyRig(model,preset);
    assert.ok(qa.mesh_count>3,id);
    assert.ok(qa.vertex_count>qa.triangle_count/3,id);
    assert.equal(qa.mast_anchors.length,preset.masts.length,id);
    assert.equal(model.meshes.filter(o=>o.sail_type).length,model.sails.length,id);
    assert.ok(model.meshes.every(o=>o.parent!=='ShipRigRoot'),id);
  }
});

test('heading is solely root yaw, never modifies local vertices or object identity',()=>{
  const m=buildRig(catalog.ships['SC-08'],'SC-08');
  const before=JSON.stringify(m.meshes);
  const sets=new Set();
  for(const d of DIRECTIONS){m.root.yaw=headingYaw(d);sets.add(m.root.yaw.toFixed(9));assert.equal(JSON.stringify(m.meshes),before);}
  assert.equal(sets.size,8);
  assert.ok(Math.abs(headingYaw('N'))<1e-9);
  assert.ok(Math.abs(Math.abs(headingYaw('S'))-Math.PI)<1e-9);
  assert.ok(Math.abs(headingYaw('E')+Math.PI/2)<1e-9);
  assert.ok(Math.abs(headingYaw('W')-Math.PI/2)<1e-9);
});

test('SC-15 broken mast does not grow intact sail after build or heading change',()=>{
  const m=buildRig(catalog.ships['SC-15'],'SC-15');
  assert.deepEqual(m.masts.map(x=>x.broken),[false,true,false]);
  assert.equal(m.sails.length,2);
  assert.ok(m.sails.every(s=>s.damaged));
  assert.ok(m.sails.every(s=>s.mast!=='Mast_02'));
  assert.ok(m.meshes.filter(x=>x.name.startsWith('Sail_')).every(x=>x.damaged));
});

test('JSON parameters change real 3D geometry without changing catalog originals',()=>{
  const source=catalog.primitive.A_square;
  const changed=structuredClone(source);
  changed.masts[0].sails[0].billow=.68;
  const a=buildRig(source,'A_square');
  const b=buildRig(changed,'A_square');
  assert.notDeepEqual(a.meshes.find(x=>x.sail_type),b.meshes.find(x=>x.sail_type));
  assert.equal(source.masts[0].sails[0].billow,.24);
});

test('negative scenarios reject detached mast foot, unsupported cloth and malformed config',()=>{
  const p=structuredClone(catalog.ships['SC-15']);p.masts[1].sails=[{type:'square'}];
  const broken=structuredClone(catalog);broken.ships['SC-15']=p;
  assert.throws(()=>validateCatalog(broken),/sail on broken mast/);
  const good=buildRig(catalog.ships['SC-01'],'SC-01');
  good.attachments=good.attachments.filter(x=>x.kind!=='mast_foot');
  assert.throws(()=>verifyRig(good,catalog.ships['SC-01']),/missing mast foot/);
});
