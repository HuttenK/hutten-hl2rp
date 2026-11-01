// Production server page payload -> production Derma builders -> offline SVG.
const fs=require('fs'),path=require('path');const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..'),base='ixhl2rp/plugins/foundation_network/';
const files=['tools/fixture.lua','tools/terminal-preview-fixture.lua',base+'sh_webstyles.lua',base+'sv_catalog.lua',base+'cl_design.lua',base+'cl_sites.lua',base+'cl_catalog.lua',base+'cl_network.lua'];
const code=files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,f),'utf8'))+'\nend').join('\n');
const names=['research','security','medical','engineering','logistics','records','scp-939','scp-173','scp-096','scp-3114','scp-079','scp-106','scp-049','directory','editor','picker'];
fs.mkdirSync(path.join(root,'docs/catalog-preview'),{recursive:true});
let sections='';
for(const name of names){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 let action=`local d=table.Copy(PLUGIN.webCatalog['${name}']);d.revision=1`;
 if(name==='engineering')action=`local d={title='Инженерная служба',summary='Диагностика, эксплуатация и технические инструкции.',image='facility',template='engineering',theme='cyan',level=1,revision=1,body='# Неисправности\\nУкажите место, симптомы и срочность в технической заявке.\\n# Электроснабжение\\nИзоляция отключает цепь, но не чинит щитки. Перед изоляцией убедитесь, что другой терминал останется запитанным.',links={{title='Диагностика питания',url='scip://power'}}}`;
 let build=`${action};p:ApplyPage({route='scip://web/${name}',name='Thomas',level=4,token='preview',department='Служба безопасности',webAdmin=true,webDesign=d})`;
 if(name==='directory')build=`local rows={};for id,v in pairs(PLUGIN.webCatalog) do rows[#rows+1]={title=v.title,detail=v.summary,url='scip://web/'..id,image=v.image,category=v.category,level=v.level} end;table.sort(rows,function(a,b) return a.url<b.url end);p:ApplyPage({route='scip://web',name='Thomas',level=4,token='preview',department='Служба безопасности',webAdmin=true,title='Внутренние сайты',body='Департаменты и досье, доступные вашей карте.',rows=rows})`;
 if(name==='editor'||name==='picker')build=`local d=table.Copy(PLUGIN.webCatalog['scp-079']);d.slug='scp-079';d.revision=1;d.minimum=3;p:ApplyPage({route='scip://editor/scp-079',name='Thomas',level=4,token='preview',department='Служба безопасности',webAdmin=true,title='Редактор сайтов',body='Оформление и содержание',webEdit=d});${name==='picker'?`local children=p.body.canvas.children;for _,v in ipairs(children) do if v.class=='DButton' then v:DoClick();break end end`:''}`;
 for(const offset of (names.indexOf(name)<13?[0,600]:[0])){
  const script=code+`\nlocal p=vgui.Create('ixFoundationNetwork');p.bootAt=0;${build};p.body:GetVBar():SetScroll(${offset});return PreviewSVG(p)`;
  if(lauxlib.luaL_dostring(L,to_luastring(script))!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
  const svg=to_jsstring(lua.lua_tostring(L,-1));
  const fixed=svg.replaceAll('../addons/','../../addons/');
  fs.writeFileSync(path.join(root,`docs/catalog-preview/${name}-${offset}.svg`),fixed);
  if(!offset)sections+=`<section id="${name}" hidden><h2>${name}</h2><img src="catalog-preview/${name}-0.svg">${names.indexOf(name)<13?`<img src="catalog-preview/${name}-600.svg">`:''}</section>`;
 }
}
fs.writeFileSync(path.join(root,'docs/catalog-preview.html'),`<!doctype html><meta charset="utf-8"><title>SCiPNET catalogue — production Lua preview</title><style>body{margin:0;background:#071116;color:#b9d8d9;font:14px Consolas}nav{display:flex;flex-wrap:wrap;gap:8px;padding:10px}button{background:#1d343d;color:#d9eee7;padding:9px 14px;border:1px solid #496069;cursor:pointer}img{width:100%;display:block}h2{padding:0 20px}small{display:block;padding:10px}section[hidden]{display:none}</style><small>Production Lua panels / offline paint preview, not Source rendering. Each article shows the top and a scrolled view.</small><nav>${names.map(n=>`<button onclick="document.querySelectorAll('section').forEach(s=>s.hidden=s.id!=='${n}')">${n}</button>`).join('')}</nav>${sections}<script>document.getElementById('research').hidden=false</script>`);
console.log('Rendered 13 page designs + directory, editor and picker. docs/catalog-preview.html');
