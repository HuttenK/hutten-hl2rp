const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
const {normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..');
const files=['tools/fixture.lua','tools/status-preview-fixture.lua','ixhl2rp/plugins/status_display/sh_plugin.lua','ixhl2rp/plugins/status_display/cl_status.lua'];
const metrics=JSON.parse(fs.readFileSync(path.join(root,'tools/status-font-metrics.json'),'utf8'));
const luaMetrics='STATUS_FONT_METRICS={'+Object.entries(metrics).map(([k,v])=>'['+JSON.stringify(k)+']={'+Object.entries(v).map(([k,n])=>'['+JSON.stringify(k)+']='+n).join(',')+'}').join(',')+'}\n';
const source=luaMetrics+files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,f),'utf8'))+'\nend').join('\n')+`
statusText='Внимание всем сотрудникам МОГ\\nОбнаружено нарушение содержания SCP-610\\nОжидайте дальнейших указаний.'
net.handlers.ixStatusHUD();clock=22;PLUGIN:HUDPaint();return StatusSVG()`;
const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
if(lauxlib.luaL_dostring(L,to_luastring(source))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
fs.writeFileSync(path.join(root,'docs/status-hud-preview.svg'),to_jsstring(lua.lua_tostring(L,-1)));
