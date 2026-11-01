// Runs the production native Lua builders/paints via the existing SVG adapter.
// These are offline previews, not GMod captures.
const fs=require('fs'),path=require('path'),f=require('fengari'),{normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');process.chdir(root);
const files=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/terminal-preview-fixture.lua','tools/fixtures/device-equipment-ui.lua','ixhl2rp/plugins/water_sources/sh_water.lua','ixhl2rp/plugins/water_sources/cl_water.lua','ixhl2rp/plugins/water_sources/cl_registry.lua','ixhl2rp/plugins/field_equipment/cl_equipment.lua','ixhl2rp/plugins/decontamination/sh_plugin.lua','ixhl2rp/plugins/decontamination/cl_decon.lua'];
const common=files.map(file=>'do\n'+normalize(fs.readFileSync(file,'utf8'))+'\nend').join('\n');
const cases={
 sink:`return ix.water.OpenMenu(equipment('sink'),false,{{id=1,name='Фляга',volume=20,capacity=750}})`,
 containers:`local w=ix.water.OpenMenu(equipment('sink'),false,{{id=1,name='Фляга сотрудника',volume=20,capacity=750},{id=2,name='Большая хозяйственная канистра для воды',volume=0,capacity=2000}});buttons(w)[3]:DoClick();return w`,
 sink_small:`screenW=640;screenH=480;return ix.water.OpenMenu(equipment('sink'),false,{})`,
 toilet:`return ix.water.OpenMenu(equipment('toilet'),true,{{id=1,name='Фляга',volume=20,capacity=750}})`,
 sink_admin:`playerMock.admin=true;ix.water.ApplyModels({['models/custom/medical_sink.mdl']='sink'});return ix.water.OpenAdmin()`,
 sink_admin_small:`screenW=640;screenH=480;playerMock.admin=true;return ix.water.OpenAdmin()`,
 sink_admin_long_row:`screenW=640;screenH=480;playerMock.admin=true;ix.water.ApplyModels({['models/'..string.rep('a',169)..'.mdl']='sink'});local win=ix.water.OpenAdmin();PreviewLayout(win);local scroll=win.children[2];for _,p in ipairs(scroll.canvas.children) do if p.class=='DPanel' then p.x=0;p.y=0;p.parent=nil;return p end end`,
 armor:`return plate(42,{1,.63,-1})`,
 armor_small:`screenW=640;screenH=480;return plate(42,{1,.63,-1})`,
 decon:`local w=vgui.Create('DPanel');w:SetSize(460,174);w.Paint=function(_,width,height) ix.Decon.PaintReadout(0,0,width,height,'Датчик биологической опасности','ОБНАРУЖЕНА БИОУГРОЗА','ЗОНЫ 1 / SCP 2 / ФЛОРА 0 / ОСТАНКИ 1 / ТОКСИНЫ 0','E · проверить показания',true) end;return w`
};
const out=path.join(root,'docs/device-ui-previews');fs.mkdirSync(out,{recursive:true});
const sharp=require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
(async()=>{for(const [name,code] of Object.entries(cases)){
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 const script=common+`\nlocal p=(function() ${code} end)();local svg=PreviewSVG(p);return svg,p:GetWide(),p:GetTall()`;
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(script))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const w=f.lua.lua_tonumber(L,-2),h=f.lua.lua_tonumber(L,-1);
 const svg=f.to_jsstring(f.lua.lua_tostring(L,-3)).replace('width="1920" height="1120"',`width="${w}" height="${h}"`).replace('viewBox="0 0 1920 1120"',`viewBox="0 0 ${w} ${h}"`);
 fs.writeFileSync(path.join(out,'equipment-'+name+'.svg'),svg);await sharp(Buffer.from(svg)).png().toFile(path.join(out,'equipment-'+name+'.png'));
 f.lua.lua_close(L);console.log('Painted '+name+' '+w+'x'+h);
}})().catch(e=>{console.error(e);process.exitCode=1});
