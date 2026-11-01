// Offline rendering of the actual terminal builders, using the existing VGUI adapter.
const fs=require('fs'),path=require('path'),f=require('fengari'),{normalize}=require('./glua.cjs');
const files=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/facility.lua','tools/terminal-preview-fixture.lua','ixhl2rp/plugins/facility_utilities/sh_core.lua','ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/foundation_network/cl_sites.lua','ixhl2rp/plugins/facility_utilities/cl_hardware.lua','ixhl2rp/plugins/facility_utilities/cl_ui.lua','ixhl2rp/plugins/foundation_network/cl_network.lua'];
const pages=['comms','doors','power','jobs'];
for(const page of pages){
 const code=files.map(file=>'do\n'+normalize(fs.readFileSync(file,'utf8'))+'\nend').join('\n')+`
 local user=admin();function LocalPlayer() return user end
 local panel=vgui.Create('ixFoundationNetwork');panel.bootAt=0
 panel:ApplyPage({route='scip://utilities/${page}',token='preview',name='Thomas',level=4,department='Служба безопасности',title='ИНФРАСТРУКТУРА / '..ix.Facility.pages['${page}'],rows={},utility={
 page='${page}',transmitting=1,calls={{id=2,name='Шлюз лаборатории',caller='Алексей Морозов'}},
 circuits={{id=1,name='Тяжёлая зона содержания',powered=true,source='РЕЗЕРВ',load=45,priority=1},{id=2,name='Административный сектор',powered=false,source='СБРОС НАГРУЗКИ',load=30,priority=4}},
 devices={{id=3,kind='generator',name='Дизельный ввод №1',running=true,fuel=265,capacity=60},{id=4,kind='battery',name='Аккумуляторный резерв',charge=4200,capacity=30}},
 doors={{id=5,name='Лаборатория / шлюз 04',status='ЗАКРЫТА / ЗАПЕРТА',level=3,dual=true,camera=1,allowed=true}},
 jobs={{id=6,title='Ремонт камеры: Коридор лабораторий',status='assigned',mine=true,available=true,ownerName='Thomas',position={x=0,y=0,z=0}},{id=7,title='Обслуживание: Блок Д-1',status='open',available=true}}
 }})
 return PreviewSVG(panel)`;
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(page+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const svg=f.to_jsstring(f.lua.lua_tostring(L,-1));
 if(!svg.includes('Системы')||(svg.match(/>Выход</g)||[]).length!==1)throw Error('Incorrect utilities navigation caption');
 fs.writeFileSync('docs/facility-'+page+'.svg',svg);
}
fs.writeFileSync('docs/facility-preview.html',`<!doctype html><meta charset="utf-8"><title>Facility utilities — production Lua preview</title><style>body{margin:0;background:#050a10;color:#cfe5e6;font:14px Tahoma}nav{padding:10px}button{padding:10px 25px;margin-right:8px;background:#142c39;color:#cfe5e6;border:1px solid #437c84}iframe{display:block;width:100%;height:calc(100vh - 65px);border:0}</style><nav>${pages.map(p=>`<button onclick="document.querySelector('iframe').src='facility-${p}.svg'">${p}</button>`).join('')}Offline production Lua layout — not an engine screenshot</nav><iframe src="facility-comms.svg"></iframe>`);
console.log('docs/facility-preview.html');
