import test from 'node:test';
import assert from 'node:assert/strict';
import * as THREE from 'three';
import fs from 'node:fs';
import {buildRig,DIRECTIONS} from '../geometry.mjs';
import {makeThreeRig,setHeading,makeCamera,makeLights} from '../three_adapter.mjs';
const catalog=JSON.parse(fs.readFileSync(new URL('../catalog.json',import.meta.url),'utf8'));

test('real Three.js buffer meshes and scene hierarchy; 8 headings affect only root',()=>{
 for(const [id,preset] of Object.entries(catalog.ships)){
  const m=buildRig(preset,id),root=makeThreeRig(m);
  const objects=[];root.traverse(o=>objects.push(o));
  const meshes=objects.filter(o=>o.isMesh);
  assert.equal(meshes.length,m.meshes.length,id);
  assert.ok(meshes.every(o=>o.geometry instanceof THREE.BufferGeometry),id);
  assert.ok(meshes.every(o=>o.parent&&o.parent!==root),id);
  const coords=meshes.map(o=>o.geometry.attributes.position.array.join(','));
  for(const dir of DIRECTIONS){setHeading(root,dir);assert.deepEqual(meshes.map(o=>o.geometry.attributes.position.array.join(',')),coords);}
  assert.equal(root.name,'ShipRigRoot');
  assert.equal(root.userData.masts.length,m.masts.length);
 }
});

test('camera remains orthographic, elevation 55 and lighting is independent',()=>{
 const scene=new THREE.Scene(),cam=makeCamera(1,12);
 assert.equal(cam.isOrthographicCamera,true);
 const target=new THREE.Vector3(0,0,2.35);
 const rise=cam.position.z-target.z;
 const travel=-cam.position.y;
 assert.ok(Math.abs(Math.atan2(rise,travel)*180/Math.PI-55)<1e-8);
 makeLights(scene);assert.ok(scene.children.every(x=>x.name!=='ShipRigRoot'));
});
