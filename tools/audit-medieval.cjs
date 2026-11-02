const fs=require('fs'),path=require('path'),parser=require('luaparse');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');
const files=[];
function walk(dir){for(const e of fs.readdirSync(dir,{withFileTypes:true})){const f=path.join(dir,e.name);if(e.isDirectory())walk(f);else if(e.name.endsWith('.lua'))files.push(f)}}
for(const dir of ['helix','ixhl2rp','addons'])walk(path.join(root,dir));
const rel=f=>path.relative(root,f).replaceAll('\\','/');
const issues=[],items=new Map(),bases=new Set(),trees=new Map(),sources=new Map(),recipes=[];
for(const f of files){const source=fs.readFileSync(f,'utf8');sources.set(f,source);trees.set(f,parser.parse(normalize(source),{luaVersion:'5.2'}));
 const p=rel(f);if(!p.includes('/items/'))continue;
 const id=path.basename(f,'.lua').replace(/^sh_/,'');if(p.includes('/items/base/'))bases.add(id);
 else if(!id.startsWith('!'))items.set(id,{f,source});
}
function visit(n,fn){if(!n||typeof n!=='object')return;fn(n);for(const v of Object.values(n))if(Array.isArray(v))v.forEach(x=>visit(x,fn));else if(v&&typeof v==='object')visit(v,fn)}
function name(n){if(!n)return '';if(n.type==='Identifier')return n.name;if(n.type==='MemberExpression')return name(n.base)+n.indexer+n.identifier.name;return ''}
function literal(n){if(n?.type==='StringLiteral')return n.value??n.raw.slice(1,-1);return null}
function value(n){
 if(n?.type==='StringLiteral')return literal(n);
 if(['NumericLiteral','BooleanLiteral'].includes(n?.type))return n.value;
 if(n?.type==='TableConstructorExpression'){
  const fields=n.fields;
  if(fields.every(f=>f.type==='TableValue'))return fields.map(f=>value(f.value));
  return Object.fromEntries(fields.map(f=>[f.key?.name||literal(f.key),value(f.value)]));
 }
 return null;
}
function check(id,where){if(id&&!items.has(id))issues.push(`${where}: unknown item '${id}'`)}
for(const [id,{f,source}] of items){const p=rel(f),after=p.split('/items/')[1].split('/');
 if(after.length===2&&!bases.has(after[0]))issues.push(`${p}: missing item base '${after[0]}'`);
 visit(trees.get(f),n=>{if(n.type==='AssignmentStatement')n.variables.forEach((v,i)=>{const k=name(v);const value=literal(n.init[i]);if(k==='ITEM.junk')check(value,p);if(k==='ITEM.base'&&value&&!bases.has(value))issues.push(`${p}: missing explicit base '${value}'`)})});
}
const stations=new Set(files.filter(f=>rel(f).includes('/stations/')).map(f=>path.basename(f,'.lua')));
for(const f of files){const p=rel(f);const tree=trees.get(f);
 const recipe=p.includes('/recipes/')?{id:path.basename(f,'.lua'),file:p}:null;
 visit(tree,n=>{
  if(n.type==='CallExpression'&&name(n.base)==='ix.util.Include'){
   const value=literal(n.arguments[0]);if(!value||!value.endsWith('.lua'))return;
   const candidates=[path.join(root,value),path.resolve(path.dirname(f),value),path.join(root,'helix/gamemode',value),path.join(root,'ixhl2rp',value),path.join(root,'ixhl2rp/schema',value)];
   if(!candidates.some(x=>fs.existsSync(x))&&!files.some(x=>rel(x).endsWith('/'+value)))issues.push(`${p}: missing include '${value}'`);
  }
  if(p.includes('/recipes/')&&n.type==='AssignmentStatement')n.variables.forEach((v,i)=>{
   const k=name(v),t=n.init[i];
   if(k.startsWith('RECIPE.'))recipe[k.slice(7)]=value(t);
   if(k==='RECIPE.station'&&literal(t)&&!stations.has(literal(t)))issues.push(`${p}: missing crafting station '${literal(t)}'`);
   if(t?.type!=='TableConstructorExpression')return;
   if(['RECIPE.requirements','RECIPE.results'].includes(k))for(const field of t.fields)check(field.key?.name||literal(field.key),p);
   if(k==='RECIPE.tools')for(const field of t.fields)check(literal(field.value),p);
  });
  if(n.type==='CallExpression'&&['ITEM:Base','Item:Base'].includes(name(n.base))){const id=literal(n.arguments[0]);if(id&&!bases.has(id))issues.push(`${p}: missing generated base '${id}'`)}
 });
 if(recipe)recipes.push(recipe);
 if(!/\/(languages|lang)\//.test(p)){
  const code=normalize(sources.get(f)).replace(/--\[\[[\s\S]*?\]\]/g,'').replace(/--[^\n]*/g,'');
  if(/:(GetSkill|GetSpecial|GetLevel|AddLevelXP|RewardXP|GetLearningLanguages|SetLearningLanguages)\s*\(/.test(code))issues.push(`${p}: progression dependency`);
 }
}
const report={note:'Static dependency checks, not engine validation.',luaFiles:files.length,itemDefinitions:items.size,itemBases:bases.size,recipes:recipes.length,stations:stations.size,issues};
fs.mkdirSync(path.join(root,'docs/medieval-cleanup'),{recursive:true});
fs.writeFileSync(path.join(root,'docs/medieval-cleanup/dependencies.json'),JSON.stringify(report,null,2)+'\n');
fs.writeFileSync(path.join(root,'docs/medieval-cleanup/recipes.json'),JSON.stringify(recipes,null,2)+'\n');
console.log(JSON.stringify(report,null,2));if(issues.length)process.exitCode=1;
