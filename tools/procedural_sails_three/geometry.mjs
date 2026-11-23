/** SeaCraft procedural 3D rigging. World/local: bow +Y, starboard +X, up +Z.
 * Triangles, spars and tubes are real 3D geometry; no textures or canvas drawing.
 * Geometry is created ONCE; heading changes only ShipRigRoot.rotation.z.
 * No dependency on Blender, WebGL, or Three.js for procedural model generation.
 */

export const DIRECTIONS = ['N','NE','E','SE','S','SW','W','NW'];
export const FAMILIES = ['square','gaff','lateen','lug','jib','bermuda'];
const DEG=Math.PI/180, EPS=1e-6;
const add=(a,b)=>a.map((v,i)=>v+b[i]);
const sub=(a,b)=>a.map((v,i)=>v-b[i]);
const mul=(a,s)=>a.map(v=>v*s);
const dot=(a,b)=>a.reduce((s,v,i)=>s+v*b[i],0);
const cross=(a,b)=>[a[1]*b[2]-a[2]*b[1],a[2]*b[0]-a[0]*b[2],a[0]*b[1]-a[1]*b[0]];
const len=a=>Math.sqrt(dot(a,a));
const norm=a=>mul(a,1/Math.max(len(a),EPS));
const mix=(a,b,t)=>add(mul(a,1-t),mul(b,t));
const p3=(x,y,z)=>[x,y,z];
const unique=(prefix,i)=>`${prefix}_${String(i).padStart(2,'0')}`;

export function headingYaw(direction, elevation=55){
  const az={E:0,SE:45,S:90,SW:135,W:180,NW:225,N:270,NE:315}[direction];
  if(az===undefined)throw Error(`unknown heading: ${direction}`);
  const phi=az*DEG;
  return Math.atan2(-Math.cos(phi),-Math.sin(phi)/Math.sin(elevation*DEG));
}

export function validateCatalog(cat){
  if(cat.schema!=='seacraft.procedural_rig.v1')throw Error('Unsupported catalog schema');
  if(JSON.stringify(cat.directions)!==JSON.stringify(DIRECTIONS))throw Error('Directions mismatch');
  for(const [kind,count] of [['primitive',6],['rigs',12],['ships',15]]){
    if(Object.keys(cat[kind]||{}).length!==count)throw Error(`${kind}: count mismatch`);
    for(const [id,p] of Object.entries(cat[kind])){
      if(p.masts.length<1||p.masts.length>4||p.length<=0||p.bow_y<=0)throw Error(`${id}: invalid mast/length`);
      if(new Set(p.masts.map(m=>m.y)).size!==p.masts.length)throw Error(`${id}: overlapping mast feet`);
      if(p.clear_zone && p.masts.some(m=>m.y>=p.clear_zone.center_y[0]&&m.y<=p.clear_zone.center_y[1]))throw Error(`${id}: crane clearance failure`);
      for(const m of p.masts){
        if(!(m.height>0.2))throw Error(`${id}: mast height`);
        if(m.broken&&m.sails.length)throw Error(`${id}: sail on broken mast`);
        for(const s of m.sails)if(!FAMILIES.includes(s.type)||s.billow<0||s.width<=0||s.height<=0)throw Error(`${id}: invalid sail`);
      }
    }
  }
  const counts=[1,1,3,2,1,2,2,3,2,2,2,3,3,4,3];
  const types=[['lug'],['gaff','jib'],['square','square','lateen'],['square','square','square','gaff'],['gaff','square','jib','jib'],['square','square','gaff','square'],['bermuda','jib','bermuda'],['square','square','square','square','square','gaff'],['square','lateen'],['lateen','lateen'],['square','gaff'],['square','square','lateen'],['square','square','square','square','gaff','square'],['square','square','square','gaff'],['square','lateen']];
  for(let i=1;i<=15;i++){
    const k=`SC-${String(i).padStart(2,'0')}`,p=cat.ships[k];
    const actual=p.masts.flatMap(m=>m.sails.map(s=>s.type));
    if(p.masts.length!==counts[i-1]||JSON.stringify(actual)!==JSON.stringify(types[i-1]))throw Error(`${k}: canonical structure mismatch: ${actual}`);
  }
  return true;
}

function cleanMesh(verts, faces){
  const used=new Set(faces.flat());
  const map=new Map(), kept=[];
  for(let i=0;i<verts.length;i++)if(used.has(i)){map.set(i,kept.length);kept.push(verts[i]);}
  return {vertices:kept, triangles:faces.map(f=>f.map(i=>map.get(i)))};
}
function makeTube(points,radius=0.02,sides=8){
  const rings=[],faces=[];
  for(let k=0;k<points.length;k++){
    const t=norm(sub(points[Math.min(points.length-1,k+1)],points[Math.max(0,k-1)]));
    let u=norm(cross(t,Math.abs(t[2])<.92?[0,0,1]:[0,1,0]));
    if(len(u)<EPS)u=[1,0,0];
    const v=norm(cross(t,u));
    for(let i=0;i<sides;i++){
      const theta=2*Math.PI*i/sides;
      rings.push(add(points[k],add(mul(u,radius*Math.cos(theta)),mul(v,radius*Math.sin(theta)))));
    }
    if(k)for(let i=0;i<sides;i++){
      const a=(k-1)*sides+i,b=(k-1)*sides+(i+1)%sides,c=k*sides+(i+1)%sides,d=k*sides+i;
      faces.push([a,b,c],[a,c,d]);
    }
  }
  const start=rings.length,end=start+1;
  rings.push(points[0],points.at(-1));
  for(let i=0;i<sides;i++){
    faces.push([start,(i+1)%sides,i]);
    faces.push([end,(points.length-1)*sides+i,(points.length-1)*sides+(i+1)%sides]);
  }
  return cleanMesh(rings,faces);
}
function bezier(a,b,sag=.06,steps=10){
  const p1=mix(a,b,1/3),p2=mix(a,b,2/3);p1[2]-=sag;p2[2]-=sag;
  const pts=[];
  for(let i=0;i<=steps;i++){
    const t=i/steps,s=1-t;
    pts.push(add(add(mul(a,s*s*s),mul(p1,3*s*s*t)),add(mul(p2,3*s*t*t),mul(b,t*t*t))));
  }
  pts[0]=[...a];pts[steps]=[...b];return pts;
}
function makeCloth(corners,billow=.2,tension=.55,damaged=false){
  const n=14, triangle=corners.length===3,vertices=[],faces=[];
  if(!triangle){
    const [a,b,c,d]=corners;
    const normal=norm(cross(sub(b,a),sub(d,a)));
    for(let j=0;j<=n;j++)for(let i=0;i<=n;i++){
      const u=i/n,v=j/n;
      const p=add(add(mul(a,(1-u)*(1-v)),mul(b,u*(1-v))),add(mul(c,u*v),mul(d,(1-u)*v)));
      const depth=billow*Math.sin(Math.PI*u)*Math.sin(Math.PI*v)*(1-.32*tension);
      vertices.push(add(p,mul(normal,depth)));
    }
    for(let j=0;j<n;j++)for(let i=0;i<n;i++){
      const torn=damaged && i>=n-3 && j>=3 && j<=n-4 && ((j+2*i)%5!==0);
      if(torn)continue;
      const a=j*(n+1)+i,b=a+1,c=b+n+1,d=a+n+1;
      faces.push([a,b,c],[a,c,d]);
    }
  }else{
    const [a,b,c]=corners;const normal=norm(cross(sub(b,a),sub(c,a)));
    const row=j=>j*(n+1)-j*(j-1)/2;
    for(let j=0;j<=n;j++)for(let i=0;i<=n-j;i++){
      const u=i/n,v=j/n,w=1-u-v;
      const p=add(add(mul(a,w),mul(b,u)),mul(c,v));
      vertices.push(add(p,mul(normal,billow*9*u*v*w*(1-.32*tension))));
    }
    for(let j=0;j<n;j++)for(let i=0;i<n-j;i++){
      const torn=damaged && j>n/3 && j<n-2 && i>=n-j-3 && (i+j)%4!==0;
      if(torn)continue;
      const a=row(j)+i,b=a+1,c=row(j+1)+i;
      faces.push([a,b,c]);
      if(i<n-j-1 && !(damaged && j>n/3 && j<n-2 && i>=n-j-4 && (i+j)%3===0))faces.push([b,row(j+1)+i+1,c]);
    }
  }
  return cleanMesh(vertices,faces);
}

export function buildRig(preset, id='anonymous'){
  const root={name:'ShipRigRoot',id,ship:preset.name,yaw:0,children:[]};
  const model={id,name:preset.name,length:preset.length,bow_y:preset.bow_y,root,
    meshes:[],attachments:[],masts:[],sails:[],curves:[],group:preset.group||null};
  const node=(parent,name)=>{const entry={name,children:[]};parent.children.push(entry);return entry;};
  const attach=(parent,name,p,kind)=>{
    const data={name,parent:parent.name,kind,point:p.map(v=>+v.toFixed(7))};model.attachments.push(data);
    parent.children.push({name,attachment:data.point});return p;
  };
  const mesh=(parent,name,part,material,extra={})=>{
    if(!part.triangles.length||!part.vertices.length)throw Error(`${id}/${name}: empty mesh`);
    const item={name,parent:parent.name,material,...part,...extra};model.meshes.push(item);
    parent.children.push({name,mesh:true});return item;
  };
  const rod=(parent,name,a,b,r=.04,material='wood')=>{
    if(len(sub(b,a))<.015)throw Error(`${id}/${name}: degenerate spar`);
    return mesh(parent,name,makeTube([a,b],r,10),material,{spar:[a,b]});
  };
  const rope=(parent,name,a,b,r=.012)=>{
    if(len(sub(b,a))<.025)throw Error(`${id}/${name}: degenerate rope`);
    const points=bezier(a,b,Math.min(.11,len(sub(b,a))*.025));
    model.curves.push({name,parent:parent.name,points,radius:r,endpoints:[a,b]});
    return mesh(parent,name,makeTube(points,r,6),'rope',{endpoints:[a,b],curve:true});
  };
  for(let i=0;i<preset.masts.length;i++){
    const m=preset.masts[i],tag=unique('Mast',i+1),mast=node(root,tag);
    const y=m.y,h=m.height,lean=(m.lean||0)*DEG;
    const local=(x,Y,z)=>[x,y+Y*Math.cos(lean)-z*Math.sin(lean),z*Math.cos(lean)+Y*Math.sin(lean)];
    const M=(x,z)=>local(x,0,z);
    rod(mast,unique('MastMesh',i+1),M(0,0),M(0,h),m.broken?.099:.069,'wood');
    const base=attach(mast,unique('MastBase',i+1),M(0,0),'mast_foot');
    const top=attach(mast,unique('MastTop',i+1),M(0,h),'mast_top');
    model.masts.push({id:tag,height:h,base,top,lean_deg:m.lean||0,broken:!!m.broken,sail_types:m.sails.map(s=>s.type),deck_points:[]});
    if(m.broken){
      // Jagged cap / fractured spar bracket. No intact sails on this mast.
      rod(mast,unique('BrokenBrace',i+1),M(0,h-.18),local(.16,.07,h-.04),.037,'metal');
    }else{
      for(const [sign,side] of [[-1,'Port'],[1,'Starboard']]){
        const foot=local(sign*.72,-.2,.02),tie=M(0,h*.75);
        attach(mast,`ShroudFoot_${i+1}_${side}`,foot,'shroud_foot');
        model.masts.at(-1).deck_points.push(foot);
        rope(mast,`Shroud_${i+1}_${side}`,tie,foot,.014);
      }
    }
    for(let j=0;j<m.sails.length;j++){
      const s=m.sails[j],t=s.type,key=`${t.toUpperCase()}_${String(i+1).padStart(2,'0')}_${String(j+1).padStart(2,'0')}`;
      const assembly=node(mast,`SailAssembly_${key}`);
      const z=Math.max(.62,Math.min(h-.09,h*(s.level??.77)));
      const billow=s.billow??.21,tension=s.tension??.55;
      let corners=[],names=[],supports=[],tacks=[];
      if(t==='square'){
        const w=s.width??h*.65,sh=s.height??h*.36,turn=(s.yard_rotation??0)*DEG;
        const cx=Math.cos(turn),cy=Math.sin(turn);
        const left=local(-cx*w/2,-cy*w/2,z),right=local(cx*w/2,cy*w/2,z);
        const lowleft=local(-cx*w/2,-cy*w/2,Math.max(.20,z-sh));
        const lowright=local(cx*w/2,cy*w/2,Math.max(.20,z-sh));
        rod(assembly,`Yard_${key}`,left,right,.045);
        corners=[left,right,lowright,lowleft];names=['head_port','head_starboard','clew_starboard','clew_port'];
        supports=[['yard',left,right]];
        rope(assembly,`Sheet_Port_${key}`,lowleft,local(-w*.34,-.18,.06));
        rope(assembly,`Sheet_Starboard_${key}`,lowright,local(w*.34,-.18,.06));
      }else if(t==='gaff'){
        const sh=s.sail_height??h*.60,foot=Math.max(.27,z-sh),gl=s.gaff_length??h*.55,bl=s.boom_length??h*.57,a=(s.gaff_angle??24)*DEG;
        const throat=M(0,z),peak=local(0,-gl*Math.cos(a),z+gl*Math.sin(a)),tack=M(0,foot),clew=local(0,-bl,foot);
        rod(assembly,`GaffSpar_${key}`,throat,peak,.044);
        rod(assembly,`Boom_${key}`,tack,clew,.049);
        rope(assembly,`PeakHalyard_${key}`,peak,M(0,h-.035));
        corners=[throat,peak,clew,tack];names=['throat','peak','clew','tack'];supports=[['gaff',throat,peak],['boom',tack,clew]];
      }else if(t==='lateen'){
        const yl=s.yard_length??h*1.04;
        const heel=local(0,-yl*.35,z-yl*.17),tip=local(0,yl*.65,z+yl*.27),tack=local(0,-yl*.25,Math.max(.13,z-yl*.69));
        rod(assembly,`LateenYard_${key}`,heel,tip,.044);
        rope(assembly,`LateenHalyard_${key}`,M(0,z),M(0,Math.min(h-.04,z+.6)));
        rope(assembly,`LateenSheet_${key}`,tack,local(0,-yl*.35,.05));
        corners=[tip,heel,tack];names=['yard_tip','yard_heel','tack'];supports=[['lateen_yard',heel,tip]];
      }else if(t==='lug'){
        const yl=s.yard_length??h*.96;
        const aft=local(0,-yl*.44,z-yl*.13),fore=local(0,yl*.56,z+yl*.2),footA=local(0,-yl*.49,Math.max(.2,z-h*.58)),footF=local(0,yl*.40,Math.max(.2,z-h*.59));
        rod(assembly,`LugYard_${key}`,aft,fore,.049);
        rope(assembly,`LugHalyard_${key}`,M(0,z),M(0,h-.04));
        rope(assembly,`LugSheetAft_${key}`,footA,local(0,-yl*.53,.04));
        rope(assembly,`LugSheetFore_${key}`,footF,local(0,yl*.47,.04));
        corners=[aft,fore,footF,footA];names=['yard_aft','yard_fore','foot_fore','foot_aft'];supports=[['lug_yard',aft,fore]];
      }else if(t==='jib'){
        const head=M(0,Math.min(h-.06,h*(s.head_level??.83)));
        const tack=p3(0,s.anchor_y??preset.bow_y,.22),clew=p3(.027,y+(tack[1]-y)*.46,.51);
        rope(assembly,`Forestay_${key}`,head,tack,.023);
        rope(assembly,`JibSheet_${key}`,clew,p3(0,y-.6,.08),.012);
        corners=[head,tack,clew];names=['stay_head','foredeck_tack','sheet_clew'];supports=[['forestay',head,tack]];
      }else if(t==='bermuda'){
        const tack=M(0,s.foot_height??.34),head=M(0,h-.09),clew=local(0,-(s.boom_length??h*.64),s.foot_height??.34);
        rod(assembly,`BermudaBoom_${key}`,tack,clew,.048);
        rope(assembly,`BermudaHalyard_${key}`,head,M(0,h-.005),.01);
        corners=[head,tack,clew];names=['mast_head','mast_tack','boom_clew'];supports=[['boom',tack,clew]];
      }else throw Error(`unsupported sail type ${t}`);
      for(let k=0;k<corners.length;k++)attach(assembly,`Attachment_${key}_${names[k]}`,corners[k],'sail_corner');
      mesh(assembly,`Sail_${key}`,makeCloth(corners,billow,tension,!!s.damaged),'cloth', {sail_type:t,damaged:!!s.damaged,corner_world:corners});
      model.sails.push({name:`Sail_${key}`,mast:tag,type:t,damaged:!!s.damaged,corners,names,supports,billow,tension});
    }
  }
  model.root.children.length>0||(()=>{throw Error('Missing mast hierarchy')})();
  // Identity covers geometry and local attachments, not heading/root transform.
  model.geometry_hash=null; // Generated by generate_models.mjs SHA-256; browser geometry is otherwise identical.
  return model;
}

export function verifyRig(model,preset){
  const assert=(x,s)=>{if(!x)throw Error(`${model.id}: ${s}`);};
  assert(model.root.name==='ShipRigRoot','missing root');
  assert(model.masts.length===preset.masts.length,'mast count mismatch');
  assert(model.sails.length===preset.masts.flatMap(m=>m.sails).length,'sail count mismatch');
  assert(JSON.stringify(model.sails.map(s=>s.type))===JSON.stringify(preset.masts.flatMap(m=>m.sails.map(s=>s.type))),'sail type/order mismatch');
  assert(model.attachments.filter(a=>a.kind==='mast_foot').length===model.masts.length,'missing mast foot');
  assert(model.attachments.filter(a=>a.kind==='sail_corner').length===model.sails.reduce((n,s)=>n+s.corners.length,0),'missing sail corner');
  for(const mesh of model.meshes){
    assert(mesh.vertices.length>3&&mesh.triangles.length>1,`empty mesh ${mesh.name}`);
    assert(mesh.triangles.every(t=>t.length===3&&t.every(i=>Number.isInteger(i)&&i>=0&&i<mesh.vertices.length)),`invalid triangles ${mesh.name}`);
    const used=new Set(mesh.triangles.flat());assert(used.size===mesh.vertices.length,`orphan vertices ${mesh.name}`);
    assert(mesh.vertices.flat().every(Number.isFinite),`NaN geometry ${mesh.name}`);
    assert(mesh.triangles.every(t=>len(cross(sub(mesh.vertices[t[1]],mesh.vertices[t[0]]),sub(mesh.vertices[t[2]],mesh.vertices[t[0]])))>1e-11),`degenerate triangle ${mesh.name}`);
  }
  for(const s of model.sails){
    const mesh=model.meshes.find(m=>m.name===s.name);assert(mesh?.material==='cloth','missing cloth mesh');
    for(const corner of s.corners)assert(mesh.vertices.some(v=>len(sub(v,corner))<1e-5),`sail corner unattached ${s.name}`);
    // Render cloth cannot be entirely flat: a real 3D belly is required.
    const a=s.corners[0],b=s.corners[1],c=s.corners.at(-1);
    const n=norm(cross(sub(b,a),sub(c,a)));
    assert(mesh.vertices.some(v=>Math.abs(dot(n,sub(v,a)))>.006),`sail flat ${s.name}`);
    for(const [kind,a,b] of s.supports){
      assert(model.meshes.some(m=>m.name!=='Sail_'+s.name&&m.spar&&[a,b].every(p=>m.spar.some(end=>len(sub(end,p))<1e-5)) || m.curve&&m.endpoints&&[a,b].every(p=>m.endpoints.some(end=>len(sub(end,p))<1e-5))),`no support ${kind} ${s.name}`);
    }
  }
  for(const m of model.masts)if(m.broken)assert(m.sail_types.length===0,'broken mast carries sail');
  for(const c of model.curves)assert(c.points.length>=3&&len(sub(c.points[0],c.endpoints[0]))<1e-6&&len(sub(c.points.at(-1),c.endpoints[1]))<1e-6,'loose rope');
  assert(model.meshes.every(m=>m.parent&&m.parent!=='ShipRigRoot'), 'unparented model mesh');
  return {id:model.id,mesh_count:model.meshes.length,vertex_count:model.meshes.reduce((n,m)=>n+m.vertices.length,0),triangle_count:model.meshes.reduce((n,m)=>n+m.triangles.length,0),mast_count:model.masts.length,sail_count:model.sails.length,sail_types:model.sails.map(s=>s.type),curve_count:model.curves.length,geometry_hash:model.geometry_hash, mast_anchors:model.masts.map(m=>({id:m.id,base_local:m.base,deck_points:m.deck_points,lean_deg:m.lean_deg,broken:m.broken})), headings:Object.fromEntries(DIRECTIONS.map(d=>[d,{root_yaw_rad:headingYaw(d),geometry_hash:model.geometry_hash}]))};
}

export function catalogs(cat){return ['primitive','rigs','ships'].flatMap(group=>Object.entries(cat[group]).map(([id,preset])=>({group,id,preset})));}

