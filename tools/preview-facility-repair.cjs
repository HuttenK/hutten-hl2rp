// Actual Lua calibration window rendered by the offline VGUI adapter.
const fs=require('fs'),f=require('fengari'),{normalize}=require('./glua.cjs');
const files=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/facility.lua','tools/terminal-preview-fixture.lua','ixhl2rp/plugins/facility_utilities/sh_core.lua','ixhl2rp/plugins/facility_utilities/sh_repair.lua','ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/facility_utilities/cl_hardware.lua','ixhl2rp/plugins/facility_utilities/cl_ui.lua','ixhl2rp/plugins/facility_utilities/cl_repair.lua'];
const code=files.map(file=>'do\n'+normalize(fs.readFileSync(file,'utf8'))+'\nend').join('\n')+`
 function ScrW() return 1920 end;function ScrH() return 1080 end
 input={IsKeyDown=function() return false end};gui={IsGameUIVisible=function() return false end}
 vgui.GetKeyboardFocus=function() return ix.Facility.repairWindow end;surface.PlaySound=function() end
 clock=12.088
 ix.Facility.OpenRepair({token=1,round=2,stage=2,started=10,target=.58,period=6.3,width=.18,title='Ремонт: Генератор / Восточное крыло',result='hit',message='Контакт восстановлен. Следующий контакт.'})
 return PreviewSVG(ix.Facility.repairWindow)`;
const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(f.to_jsstring(f.lua.lua_tostring(L,-1)));
const svg=f.to_jsstring(f.lua.lua_tostring(L,-1)).replace(/width="1920" height="1120"/,'width="760" height="610"').replace(/viewBox="0 0 1920 1120"/,'viewBox="0 0 760 610"');
fs.writeFileSync('docs/facility-device-calibration.svg',svg);console.log('docs/facility-device-calibration.svg');
