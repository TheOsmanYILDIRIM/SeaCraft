/** Three.js adapter: source mesh vertices are unchanged; root yaw is the only heading transform. */
import * as THREE from 'three';
import {headingYaw} from './geometry.mjs';
export const CLAY_MATERIALS={
  cloth:new THREE.MeshStandardMaterial({color:0xc9cdd0,roughness:.91,metalness:0,side:THREE.DoubleSide}),
  wood:new THREE.MeshStandardMaterial({color:0x525963,roughness:.86,metalness:0,side:THREE.DoubleSide}),
  rope:new THREE.MeshStandardMaterial({color:0x858d96,roughness:.9,metalness:0,side:THREE.DoubleSide}),
  metal:new THREE.MeshStandardMaterial({color:0x747d86,roughness:.73,metalness:.16,side:THREE.DoubleSide})
};

export function makeThreeRig(model){
  const root=new THREE.Group();root.name='ShipRigRoot';
  const groups=new Map([['ShipRigRoot',root]]);
  function makeGroup(group,parent){
    for(const child of group.children||[]){
      if(child.children){const g=new THREE.Group();g.name=child.name;parent.add(g);groups.set(child.name,g);makeGroup(child,g);}
      else if(child.attachment){const p=new THREE.Object3D();p.name=child.name;p.position.set(...child.attachment);p.userData.attachment=true;parent.add(p);}
    }
  }
  makeGroup(model.root,root);
  for(const src of model.meshes){
    const geometry=new THREE.BufferGeometry();
    geometry.setAttribute('position',new THREE.Float32BufferAttribute(src.vertices.flat(),3));
    geometry.setIndex(src.triangles.flat());
    geometry.computeVertexNormals();
    const mesh=new THREE.Mesh(geometry,CLAY_MATERIALS[src.material]);
    mesh.name=src.name;mesh.userData={sail_type:src.sail_type||null,curve:!!src.curve,material:src.material};
    const parent=groups.get(src.parent);
    if(!parent)throw Error(`Missing node ${src.parent} for ${src.name}`);
    parent.add(mesh);
  }
  root.userData={preset:model.id,geometry_hash:model.geometry_hash,masts:model.masts,sails:model.sails};
  return root;
}
export function setHeading(root,direction){
  if(root.name!=='ShipRigRoot')throw Error('Heading must rotate ShipRigRoot only');
  root.rotation.z=headingYaw(direction);
  return root.rotation.z;
}
export function makeCamera(aspect=1,scale=12){
  const camera=new THREE.OrthographicCamera(-scale*aspect/2,scale*aspect/2,scale/2,-scale/2,.01,200);
  const elevation=55*Math.PI/180;
  camera.up.set(0,0,1);
  camera.position.set(0,-25*Math.cos(elevation),2.35+25*Math.sin(elevation));
  camera.lookAt(0,0,2.35);
  camera.updateProjectionMatrix();
  return camera;
}
export function makeLights(scene){
  const hemi=new THREE.HemisphereLight(0xffffff,0x485462,1.9);scene.add(hemi);
  const sun=new THREE.DirectionalLight(0xe6edf5,2.0);sun.position.set(-7,-5,12);scene.add(sun);
  // Global lights are NOT parented under ShipRigRoot and never rotate with it.
}
