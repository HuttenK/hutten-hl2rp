const fs=require('fs'),path=require('path'),assert=require('assert/strict'),parser=require('luaparse');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..'),read=f=>fs.readFileSync(path.join(root,f),'utf8');
const config=JSON.parse(read('tools/item-model-replacements.json'));
function files(dir){return fs.readdirSync(path.join(root,dir),{withFileTypes:true}).flatMap(e=>e.isDirectory()?files(dir+'/'+e.name):e.name.endsWith('.lua')?[dir+'/'+e.name]:[]);}
function visit(node,fn){if(!node||typeof node!=='object')return;fn(node);for(const [k,v] of Object.entries(node))if(k!=='range')Array.isArray(v)?v.forEach(x=>visit(x,fn)):visit(v,fn);}
function literal(n){if(!n)return undefined;if(n.type==='StringLiteral')return n.raw[0]==='"'?JSON.parse(n.raw):n.raw.slice(1,-1);return n.value;}
function member(n){if(n?.type==='Identifier')return n.name;if(n?.type==='MemberExpression')return member(n.base)+'.'+n.identifier.name;}
function assignments(ast){const out={};visit(ast,n=>{if(n.type==='AssignmentStatement')n.variables.forEach((v,i)=>{const key=member(v);if(key&&!(key in out))out[key]=n.init[i];});});return out;}
function parse(source){return parser.parse(normalize(source),{luaVersion:'5.2',ranges:true});}
function itemFiles(){return files('ixhl2rp').filter(f=>f.includes('/items/')&&!f.includes('/_old/')&&!f.includes('/base/'));}
function validate(){
 const catalog=new Map();for(const f of itemFiles()){const id=path.basename(f,'.lua').replace(/^(sh_|cl_|sv_)/,'');catalog.set(id,f);}
 const changed=JSON.parse(read('.runtime/item-models-20261013/changes.json'));
 let syntax=0,recipes=0;
 for(const [file,action] of Object.entries(changed)){
  if(action==='removed'){assert(!fs.existsSync(path.join(root,file)),file+' was not removed');continue;}
  const source=read(file),ast=parse(source);syntax++;
  if(file.includes('/languages/')||file.endsWith('/sh_legacy_items.lua'))continue;
  visit(ast,n=>{if(n.type==='StringLiteral')assert(!config.retired[literal(n)],file+' refers to retired '+literal(n));
   if(n.type==='TableKeyString')assert(!config.retired[n.key.name],file+' uses retired key '+n.key.name);});
  if(!file.includes('/recipes_'))continue;
  const values=assignments(ast);recipes++;
  if(literal(values['RECIPE.disabled'])===true)continue;
  for(const key of ['requirements','results','tools','tool_durability']){
   const node=values['RECIPE.'+key];if(!node)continue;
   if(node.type==='StringLiteral'){assert(catalog.has(literal(node)),file+' missing item '+literal(node));continue;}
   assert.equal(node.type,'TableConstructorExpression',file+' unknown recipe shape');
   const seen=new Set();
   for(const field of node.fields){const id=field.type==='TableKeyString'?field.key.name:literal(field.value);
    assert(catalog.has(id),file+' missing item '+id);assert(!seen.has(id),file+' duplicate '+key+' '+id);seen.add(id);}
  }
 }
 for(const [id,model] of Object.entries(config.models)){
  const file=catalog.get(id);assert(file,'missing '+id);const values=assignments(parse(read(file)));
  assert.equal(literal(values['ITEM.model']),model,id+' model');
  assert.equal(literal(values['ITEM.skin'])||0,config.skins[id]||0,id+' skin');
  assert(!values['ITEM.iconCam'],id+' retained obsolete camera');assert(!values['ITEM.icon_model'],id+' retains separate icon model');
 }
 const books=files('ixhl2rp/plugins/skill_books/items/skillbook');
 for(const file of [...books,'ixhl2rp/plugins/languages/sh_plugin.lua']){
  const values=assignments(parse(read(file)));assert.equal(literal(values['ITEM.model']),config.learningBookModel,file);
  assert(!values['ITEM.skin'],file+' old cover skin');assert(!values['ITEM.iconCam'],file+' old camera');
 }
 const bench=assignments(parse(read('ixhl2rp/plugins/arccw_item_atts/entities/entities/ix_gunsmith.lua')));
 assert.equal(literal(bench['ENT.Model']),config.models.gunsmith_bench);
 const salad=assignments(parse(read(catalog.get('canned_squash'))));
 assert.equal(literal(salad['ITEM.stats.container']),false,'Salad must not need a can opener');
 assert(!salad['ITEM.junk'],'Salad must not produce an empty tin');
 for(const [id,target] of Object.entries(config.retired)){assert(!catalog.has(id),'Retired definition still present: '+id);assert(catalog.has(target),'Missing replacement '+target);}
 const locales=JSON.parse(read('tools/item-model-locales.json'));
 for(const [id,languages] of Object.entries(locales))for(const [language,text] of Object.entries(languages)){
  let f=catalog.get(id).split('/items/')[0]+'/languages/'+language+'.lua';
  if(!fs.existsSync(path.join(root,f)))f='ixhl2rp/schema/languages/'+language+'.lua';
  for(const [i,suffix] of ['', '.desc'].entries())assert(read(f).includes('item.'+id+suffix+' = '+JSON.stringify(text[i])),f+' missing localized '+id+suffix);
 }
 console.log(`PASS item catalog: ${config.models&&Object.keys(config.models).length} models, ${books.length} skill books plus generated language books, ${Object.keys(config.retired).length} retired IDs, ${recipes} affected recipes, ${syntax} Lua syntax checks`);
 return {models:Object.keys(config.models).length,books:books.length,retired:Object.keys(config.retired).length,recipes,syntax};
}
module.exports=function(suite){
 const common=`ix.util={Lib=function(name,value) ix[name]=ix[name] or value;return ix[name] end};ix.transmit={all=1};ITEM={functions={},AddData=function() end,GetData=function(self) return self.title end}`;
 suite('Untitled book spawn logging uses server translation without a client and preserves custom titles',
  ['helix/gamemode/core/libs/sh_language.lua','ixhl2rp/plugins/paperwork/items/book.lua'],`
   ix.Locale.stored.en['item.book']='Book';eq(ITEM:GetName(),'Book')
   local logged;ix.log.Add=function(client,kind,name,itemName,id) logged=itemName end
   ix.log.Add(nil,'inventoryAdd','Tester',ITEM:GetName(),42);eq(logged,'Book')
   ITEM.title='Progress 50%';eq(ITEM:GetName(),'"Progress 50%"')
  `,common);
 suite('Client book names still use the selected language and custom titles',
  ['helix/gamemode/core/libs/sh_language.lua','ixhl2rp/plugins/paperwork/items/book.lua'],`
   ix.Locale.stored.ru={['item.book']='Книга'};eq(ITEM:GetName(),'Книга')
   ITEM.title='Field notes';eq(ITEM:GetName(),'"Field notes"')
  `,common+`;SERVER=false;CLIENT=true;GetConVar=function() return {GetString=function() return 'ru' end} end;cvars={AddChangeCallback=function() end}`);
 suite('All retired tools and weapon components resolve directly to their maintained saved-item replacements',
  ['ixhl2rp/plugins/ammo_cringe/sh_legacy_items.lua'],Object.entries(config.retired).map(([id,target])=>`eq(ix.Item.legacyIDs[${JSON.stringify(id)}],${JSON.stringify(target)})`).join('\n'),`ix.Item={legacyIDs={}}`);
};
module.exports.validate=validate;
if(require.main===module)validate();
