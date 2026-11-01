const fs=require('fs'),path=require('path'),crypto=require('crypto'),parser=require('luaparse');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..'),runtime=path.join(root,'.runtime/character-height-20261013');
const before=path.join(runtime,'before');
const hash=file=>crypto.createHash('sha256').update(fs.readFileSync(file)).digest('hex');
function walk(folder){return fs.readdirSync(folder,{withFileTypes:true}).flatMap(e=>e.isDirectory()?walk(path.join(folder,e.name)):[path.join(folder,e.name)]);}
const changed=walk(before).map(f=>path.relative(before,f).replaceAll('\\','/'))
 .filter(f=>!f.startsWith('tools/')&&hash(path.join(root,f))!==hash(path.join(before,f)));
changed.push(...walk(path.join(root,'ixhl2rp/plugins/character_height')).map(f=>path.relative(root,f).replaceAll('\\','/')));
const rows=changed.sort().map(file=>{
 const source=fs.readFileSync(path.join(root,file),'utf8');
 parser.parse(normalize(source),{luaVersion:'5.2'});
 return {file,sha256:hash(path.join(root,file)),bytes:Buffer.byteLength(source)};
});
fs.writeFileSync(path.join(runtime,'delivery.json'),JSON.stringify({note:'Normalized Lua syntax and source hashes. Engine rendering is not validated.',files:rows},null,2));
console.log(rows.length+' changed runtime Lua files passed syntax checks. Manifest: '+path.join(runtime,'delivery.json'));
