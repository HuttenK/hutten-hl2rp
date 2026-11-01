// Rebuild from installed original content; never feed previously patched MDLs in.
// studiohdr_t / mstudiomodelgroup_t layout: Valve Source SDK 2013, public/studio.h.
const fs=require('fs'),path=require('path'),assert=require('assert'),crypto=require('crypto');
const [workshop,prone,output]=process.argv.slice(2);
assert(workshop&&prone&&output,'Usage: node tools/build-cellar-bridge.cjs WORKSHOP_ROOT ORIGINAL_PRONE_ROOT OUTPUT_ADDON');
const sources=new Map(), manifest=[];
const norm=s=>s.replaceAll('\\','/').toLowerCase();
const privateName=s=>'models/ix_cellar/'+norm(s).replace(/^models\//,'');
function cstr(b,o){assert(o>=0&&o<b.length);const end=b.indexOf(0,o);assert(end>=o);return b.toString('utf8',o,end);}
for(const id of ['1773817848','3743836507']){
 const dir=path.join(workshop,id),gma=path.join(dir,fs.readdirSync(dir).find(n=>n.endsWith('.gma')));
 const fd=fs.openSync(gma,'r'),b=Buffer.alloc(4*1024*1024);fs.readSync(fd,b,0,b.length,0);
 assert.equal(b.toString('ascii',0,4),'GMAD');let o=21;
 const str=()=>{const s=cstr(b,o);o+=Buffer.byteLength(s)+1;return s;};
 while(str()!==''){} const title=str();str();str();o+=4;
 const files=[];let offset=0;
 while(b.readUInt32LE(o)){o+=4;const name=norm(str()),size=Number(b.readBigUInt64LE(o));o+=12;files.push({name,size,offset});offset+=size;}
 o+=4;
 for(const f of files)if(f.name.startsWith('models/')&&!sources.has(f.name))sources.set(f.name,{...f,start:o+f.offset,gma,title,id});
 fs.closeSync(fd);
}
function read(name){const s=sources.get(norm(name));assert(s,'Missing source '+name);const fd=fs.openSync(s.gma,'r'),b=Buffer.alloc(s.size);assert.equal(fs.readSync(fd,b,0,b.length,s.start),b.length);fs.closeSync(fd);manifest.push({name,workshop:s.id,title:s.title,sha256:crypto.createHash('sha256').update(b).digest('hex')});return b;}
function includes(b){const n=b.readInt32LE(336),o=b.readInt32LE(340);assert(n>=0&&o+n*8<=b.length);return Array.from({length:n},(_,i)=>{const base=o+i*8;return {label:cstr(b,base+b.readInt32LE(base)),name:norm(cstr(b,base+b.readInt32LE(base+4)))};});}
function patch(b,name,inc,ani){
 assert.equal(b.toString('ascii',0,4),'IDST');assert([48,49].includes(b.readInt32LE(4)));assert.equal(b.readInt32LE(76),b.length);
 const start=(b.length+3)&~3,table=Buffer.alloc(inc.length*8),chunks=[b,Buffer.alloc(start-b.length),table];let cursor=start+table.length;
 for(let i=0;i<inc.length;i++)for(const [field,value]of [[0,inc[i].label],[4,inc[i].name]]){const s=Buffer.from(value+'\0');table.writeInt32LE(cursor-(start+i*8),i*8+field);chunks.push(s);cursor+=s.length;}
 let aniOffset=0;if(ani){aniOffset=cursor;chunks.push(Buffer.from(ani+'\0'));}
 const out=Buffer.concat(chunks);out.writeInt32LE(out.length,76);out.writeInt32LE(inc.length,336);out.writeInt32LE(start,340);
 if(aniOffset)out.writeInt32LE(aniOffset,348);
 const internal=name.replace(/^models\//,'');assert(Buffer.byteLength(internal)<64);out.fill(0,12,76);out.write(internal,12,'utf8');
 // Bone, sequence, compressed animation and checksum bytes remain untouched.
 assert(out.subarray(80,336).equals(b.subarray(80,336)));
 assert(out.subarray(352,b.length).equals(b.subarray(352,b.length)));
 return out;
}
function write(name,b){const dest=path.join(output,name);fs.mkdirSync(path.dirname(dest),{recursive:true});fs.writeFileSync(dest,b);}
const visited=new Set(),active=new Set();
function copyPrivate(name){
 name=norm(name);assert(!active.has(name),'Include cycle '+name);if(visited.has(name))return privateName(name);active.add(name);
 const b=read(name),inc=includes(b).map(x=>({...x,name:copyPrivate(x.name)}));
 let ani;if(b.readInt32LE(352)>1){const original=norm(cstr(b,b.readInt32LE(348)));ani=privateName(original);write(ani,read(original));}
 write(privateName(name),patch(b,privateName(name),inc,ani));active.delete(name);visited.add(name);return privateName(name);
}
const families={male:copyPrivate('models/cellar/male_anims.mdl'),female:copyPrivate('models/cellar/female_anims.mdl'),police:copyPrivate('models/cellar/police_anims.mdl'),combine:copyPrivate('models/cellar/combine_anims.mdl')};
for(const [file,family]of Object.entries({'humans/male_postures.mdl':'male','humans/female_postures.mdl':'female','police_ss.mdl':'police','m_anm.mdl':'male','f_anm.mdl':'female','z_anm.mdl':'male'})){
 const name='models/'+file,b=fs.readFileSync(path.join(prone,name));
 write(name,patch(b,name,[...includes(b),{label:'ix_cellar',name:families[family]}]));
 const ani=name.replace(/\.mdl$/,'.ani');if(fs.existsSync(path.join(prone,ani)))write(ani,fs.readFileSync(path.join(prone,ani)));
}
// Keep original Combine animations first, add Cellar sequences through an include.
const base=read('models/combine_soldier_anims_old.mdl');
write('models/combine_soldier_anims.mdl',patch(base,'models/combine_soldier_anims.mdl',[...includes(base),{label:'ix_cellar',name:families.combine}],privateName(cstr(base,base.readInt32LE(348)))));
fs.writeFileSync(path.join(output,'cellar-sources.json'),JSON.stringify(manifest,null,2)+'\n');
console.log('Built Cellar bridge with '+visited.size+' private model libraries.');
