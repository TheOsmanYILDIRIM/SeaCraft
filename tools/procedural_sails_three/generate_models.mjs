import fs from 'node:fs';
import path from 'node:path';
import {fileURLToPath} from 'node:url';
import crypto from 'node:crypto';
import {buildRig,verifyRig,catalogs,validateCatalog,DIRECTIONS} from './geometry.mjs';
const here=path.dirname(fileURLToPath(import.meta.url));
const cat=JSON.parse(fs.readFileSync(process.argv[2]||path.join(here,'catalog.json'),'utf8'));
validateCatalog(cat);
const output=process.argv[3]||path.join(here,'output','scene_data');fs.mkdirSync(output,{recursive:true});
const result={schema:'seacraft.procedural_rig.three.v1',camera:cat.camera,generated:{primitive:{},rigs:{},ships:{}}};
for(const {group,id,preset} of catalogs(cat)){
  const model=buildRig(preset,id);
  model.geometry_hash=crypto.createHash('sha256').update(JSON.stringify({meshes:model.meshes,attachments:model.attachments,masts:model.masts,sails:model.sails,curves:model.curves})).digest('hex');
  const verification=verifyRig(model,preset);
  const dest=path.join(output,group);fs.mkdirSync(dest,{recursive:true});
  fs.writeFileSync(path.join(dest,`${id}.json`),JSON.stringify(model));
  result.generated[group][id]=verification;
  console.log(`GEOMETRY_OK ${group} ${id} ${verification.mast_count}m/${verification.sail_count}s ${verification.triangle_count}tri`);
}
fs.writeFileSync(path.join(path.dirname(output),'validation.json'),JSON.stringify(result,null,2)+'\n');
