// Export the actual production bone callback on the archived Sectorial rig.
const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');const root=path.join(__dirname,'..');
require('./test-terminal-v6.cjs')((name,files,assertions,setup)=>{
 if(!name.startsWith('PDA full bone'))return;
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const exportCode=`local rows={}
 for id,m in pairs(bones) do
 local p,x,y,z=m:GetTranslation(),m:GetForward(),-m:GetRight(),m:GetUp()
 rows[#rows+1]=table.concat({id,p.x,p.y,p.z,x.x,x.y,x.z,y.x,y.y,y.z,z.x,z.y,z.z},',')
 end
 local center,ang=F.PDADeviceFromHand(p,bones[ids[prefix..'R_Hand']]:GetTranslation())
 local x,y,z=ang:Forward(),-ang:Right(),ang:Up()
 rows[#rows+1]=table.concat({-1,center.x,center.y,center.z,x.x,x.y,x.z,y.x,y.y,y.z,z.x,z.y,z.z},',')
 return table.concat(rows,'\\n')`;
 const code=[fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8'),setup,...files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,f),'utf8'))+'\nend'),assertions.split('weapon.GetClass=function()')[0],exportCode].join('\n');
 if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
 fs.writeFileSync(path.join(root,'docs/pda-pose-matrices.csv'),to_jsstring(lua.lua_tostring(L,-1)));
 console.log('Exported Sectorial District posed bone matrices.');
});
