// Read actual compiled MDL sequence/include tables, not mocked sequence names.
const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.join(__dirname,'../addons/ix_crawl_animation_content/models');
function read(name){const b=fs.readFileSync(path.join(root,name));assert.equal(b.toString('ascii',0,4),'IDST');return b;}
function strings(b,countOffset,indexOffset,stride,stringOffset){
 const n=b.readInt32LE(countOffset),start=b.readInt32LE(indexOffset),out=[];
 assert(n>=0 && n<10000 && start+n*stride<=b.length);
 for(let i=0;i<n;i++){const base=start+i*stride,pos=base+b.readInt32LE(base+stringOffset);assert(pos>=0 && pos<b.length);const end=b.indexOf(0,pos);assert(end>=pos);out.push(b.toString('utf8',pos,end));}return out;
}
for(const name of ['m_anm.mdl','f_anm.mdl','z_anm.mdl','player/wiltos/anim_extension_prone.mdl']){
 const sequences=strings(read(name),188,192,212,4);
 for(const seq of ['prone_passive','prone_walkpassive']) assert(sequences.includes(seq),name+' missing '+seq);
 console.log('PASS native prone idle/crawl: '+name);
}
for(const name of ['humans/male_postures.mdl','humans/female_postures.mdl','police_ss.mdl']){
 const includes=strings(read(name),336,340,8,4);
 assert(includes.includes('models/player/wiltos/anim_extension_prone.mdl'));
 assert(fs.statSync(path.join(root,name.replace('.mdl','.ani'))).size>0);
 console.log('PASS HL2 include chain and animation block: '+name);
}
