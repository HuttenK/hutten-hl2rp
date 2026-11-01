// Production item menu constructors, layout and Paint under a Derma base adapter.
// This is an offline callback preview, not an engine or browser screenshot.
const fs=require('fs'),path=require('path'),f=require('fengari');
const {client}=require('./test-contextual-equipment-use.cjs');
const {read,source}=require('./restored-test-runner.cjs');
const sharp=require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out=path.resolve(__dirname,'../.runtime/equipment-model-actions-20261009/previews');fs.mkdirSync(out,{recursive:true});
const cases={
 sink:`aimed=fixture('sink');bottle(1,'Фляга');Q.Input(command(true));previewMenu=Q.menu`,
 toilet:`aimed=fixture('toilet');bottle(1,'Фляга');Q.Input(command(true));previewMenu=Q.menu`,
 generator:`aimed=fixture('generator');F.OpenDevice({device={entity=aimed:EntIndex(),id=700,kind='generator',fault=false,fuel=300,portable=true,canStart=true,hasFuel=true,links={}}});Q.Input(command(true));previewMenu=Q.menu`,
 bed:`ix.sleep={USE_RANGE=96,IsBed=function() return true end,IsResting=function() return false end,CanReach=function() return true end}
 ${source(['ixhl2rp/plugins/sleep/cl_sleep.lua'])}
 local original=ix.SimpleMenu;ix.SimpleMenu=function(...) previewMenu=original(...);return previewMenu end
 aimed=fixture('bed');net.ReadEntity=function() return aimed end;net.handlers.ixBedRestMenu()`
};
(async()=>{for(const [name,body]of Object.entries(cases)){
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 const script=read('tools/fixture.lua')+'\nunpack=table.unpack\n'+client+`\nscreenW=800;screenH=600\n`+body+`
 local panel=vgui.Create('DPanel');panel:SetSize(ScrW(),ScrH());panel.children[#panel.children+1]=previewMenu;previewMenu.parent=panel
 panel.Paint=function(_,w,h) surface.SetDrawColor(42,45,45);surface.DrawRect(0,0,w,h) end
 return PreviewSVG(panel)
 `;
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(script))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const svg=f.to_jsstring(f.lua.lua_tostring(L,-1)).replace('width="1920" height="1120"','width="800" height="600"').replace('viewBox="0 0 1920 1120"','viewBox="0 0 800 600"');
 fs.writeFileSync(path.join(out,name+'-native-menu.svg'),svg);await sharp(Buffer.from(svg)).png().toFile(path.join(out,name+'-native-menu.png'));
 f.lua.lua_close(L);console.log('Painted native '+name+' menu 800x600');
}})().catch(e=>{console.error(e);process.exitCode=1});
