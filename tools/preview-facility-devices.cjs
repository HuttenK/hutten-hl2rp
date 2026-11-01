// Render the real native equipment builder; no engine screenshots are claimed.
const fs=require('fs'),f=require('fengari'),{normalize}=require('./glua.cjs');
const files=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/facility.lua','tools/terminal-preview-fixture.lua','ixhl2rp/plugins/facility_utilities/sh_core.lua','ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/facility_utilities/cl_hardware.lua','ixhl2rp/plugins/facility_utilities/cl_ui.lua','ixhl2rp/plugins/facility_utilities/cl_devices.lua'];
const scenarios={generator:`name='Резервный генератор',kind='generator',fuel=300,running=false,canStart=true,hasFuel=true,circuits=2`,repair:`name='Генератор / восточное крыло',kind='generator',fault=true,repairAllowed=true,hasTool=true,hasParts=true`,battery:`name='Аккумуляторный блок',kind='battery',charge=4200`};
for(const [name,fields] of Object.entries(scenarios)){
 const code=files.map(file=>'do\n'+normalize(fs.readFileSync(file,'utf8'))+'\nend').join('\n')+`
 function ScrW() return 1920 end;function ScrH() return 1080 end
 input={IsMouseDown=function() return false end};ix.Facility.OpenDevice({device={id=1,${fields}}})
 return PreviewSVG(ix.Facility.window)`;
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 let svg=f.to_jsstring(f.lua.lua_tostring(L,-1));
 svg=svg.replace(/width="1920" height="1120"/,'width="790" height="790"').replace(/viewBox="0 0 1920 1120"/,'viewBox="0 0 790 790"');
 fs.writeFileSync('docs/facility-device-'+name+'.svg',svg);
}
console.log('Generated 3 production equipment UI previews.');
