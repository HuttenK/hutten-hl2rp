// Production catalogue and panel code, with actual source-image dimensions.
const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..'),base='ixhl2rp/plugins/foundation_network/';
const manifest=JSON.parse(fs.readFileSync(path.join(root,'docs/funclub-catalog-manifest.json'),'utf8'));
const files=['tools/fixture.lua','tools/terminal-preview-fixture.lua',base+'sh_webstyles.lua',base+'sv_catalog.lua',base+'cl_design.lua',base+'cl_sites.lua',base+'cl_catalog.lua',base+'cl_network.lua'];
const dimensions=manifest.pages.filter(p=>p.image).map(p=>`[${JSON.stringify(p.image)}]={${p.imageDimensions.join(',')}}`).join(',');
const code=files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,f),'utf8'))+'\nend').join('\n')+`\nlocal dims={${dimensions}};local oldMaterial=Material;function Material(path) local m=oldMaterial(path);local d=dims[path];if d then m.Width=function() return d[1] end;m.Height=function() return d[2] end end;return m end\n`;
const out=path.join(root,'docs/funclub-preview');fs.mkdirSync(out,{recursive:true});
const names=['welcome','research','scp-939-f','scp-079','scp-507-f','site-19f','security-codes','class-d','directory','editor','public-directory','public-class-d','management'];
for(const name of names){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 let build=`local d=table.Copy(PLUGIN.webCatalog['${name}']);d.revision=1;p:ApplyPage({route='scip://web/${name}',name='Thomas',department='Служба безопасности',level=4,token='preview',webAdmin=true,webDesign=d})`;
 if(name==='directory')build=`local rows={};for id,v in pairs(PLUGIN.webCatalog) do rows[#rows+1]={title=v.title,detail=v.summary,url='scip://web/'..id,image=v.image~='none' and v.image or nil,category=v.category,level=v.level} end;table.sort(rows,function(a,b) return a.url<b.url end);p:ApplyPage({route='scip://web',name='Thomas',department='Служба безопасности',level=4,token='preview',webAdmin=true,title='БИБЛИОТЕКА УВС-19F',body='Служебная документация',rows=rows})`;
 if(name==='editor')build=`local d=table.Copy(PLUGIN.webCatalog['scp-079']);d.slug='scp-079';d.revision=1;d.minimum=3;p:ApplyPage({route='scip://editor/scp-079',name='Thomas',department='Служба безопасности',level=4,token='preview',webAdmin=true,title='РЕДАКТОР САЙТОВ',webEdit=d})`;
 if(name==='public-directory')build=`local rows={};for _,id in ipairs({'class-d','janitor','d-charter','d-contract','d-housing','d-orientation'}) do local v=PLUGIN.webCatalog[id];rows[#rows+1]={title=v.title,detail=v.summary,url='scip://web/'..id,image=v.image~='none' and v.image or nil} end;p:ApplyPage({route='scip://web',name='Открытый доступ',department='Библиотека класса D',level=0,token='preview',publicAccess=true,title='БИБЛИОТЕКА КЛАССА D',body='Должностные инструкции, устав, контракт, жилищные правила и ориентировочные материалы. Ключ-карта не требуется.',rows=rows})`;
 if(name==='public-class-d')build=`local d=table.Copy(PLUGIN.webCatalog['class-d']);d.revision=1;d.publicAccess=true;d.level=0;p:ApplyPage({route='scip://web/class-d',name='Открытый доступ',department='Библиотека класса D',level=0,token='preview',publicAccess=true,webDesign=d})`;
 if(name==='management')build=`local d=table.Copy(PLUGIN.webCatalog.management);d.revision=1;d.accessLabel='L3 / Научный отдел';p:ApplyPage({route='scip://web/management',name='Thomas',department='Научный отдел',level=3,token='preview',webDesign=d})`;
 const script=code+`\nlocal p=vgui.Create('ixFoundationNetwork');p.bootAt=0;${build};return PreviewSVG(p)`;
 if(lauxlib.luaL_dostring(L,to_luastring(script))!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 let svg=to_jsstring(lua.lua_tostring(L,-1));
 svg=svg.replace(/href="\.\.\/addons\/([^\"]+)"/g,(_,rel)=>`href="data:image/png;base64,${fs.readFileSync(path.join(root,'addons',rel)).toString('base64')}"`);
 fs.writeFileSync(path.join(out,name+'.svg'),svg);
}
console.log(`Rendered ${names.length} production views to docs/funclub-preview.`);
