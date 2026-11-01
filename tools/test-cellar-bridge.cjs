const fs=require('fs'),path=require('path'),assert=require('assert');
const root=path.join(__dirname,'../addons/ix_crawl_animation_content');
const cache=new Map(),active=new Set();
function str(b,o){assert(o>=0&&o<b.length);const end=b.indexOf(0,o);assert(end>=o);return b.toString('utf8',o,end).replaceAll('\\','/').toLowerCase();}
function load(name){
 assert(!active.has(name),'Cyclic include: '+name);if(cache.has(name))return cache.get(name);active.add(name);
 const b=fs.readFileSync(path.join(root,name));assert.equal(b.toString('ascii',0,4),'IDST');assert.equal(b.readInt32LE(76),b.length);
 const result=new Set();let n=b.readInt32LE(188),o=b.readInt32LE(192);assert(n>=0&&o+n*212<=b.length);
 for(let i=0;i<n;i++){const base=o+i*212;result.add(str(b,base+b.readInt32LE(base+4)));}
 n=b.readInt32LE(336);o=b.readInt32LE(340);assert(n>=0&&o+n*8<=b.length);
 for(let i=0;i<n;i++){const base=o+i*8,inc=str(b,base+b.readInt32LE(base+4));for(const s of load(inc))result.add(s);}
 n=b.readInt32LE(352);o=b.readInt32LE(356);
 if(n>1){assert(o+n*8<=b.length);const ani=fs.readFileSync(path.join(root,str(b,b.readInt32LE(348))));for(let i=1;i<n;i++){const start=b.readInt32LE(o+i*8),end=b.readInt32LE(o+i*8+4);assert(start>=0&&end>=start&&end<=ani.length,'Animation block outside ANI: '+name);}}
 active.delete(name);cache.set(name,result);return result;
}
for(const name of ['humans/male_postures.mdl','humans/female_postures.mdl','police_ss.mdl','combine_soldier_anims.mdl','m_anm.mdl','f_anm.mdl','z_anm.mdl']){
 const sequences=load('models/'+name);
 for(const s of ['cidle_normal','cwalk_normal','pwalk_all','pidle_normal','jump_normal'])assert(sequences.has(s),name+' missing '+s);
 console.log('PASS Cellar dependency closure, crawl and movement: '+name+' ('+sequences.size+' sequences)');
}
console.log('PASS '+cache.size+' model libraries: acyclic includes and complete animation blocks');
