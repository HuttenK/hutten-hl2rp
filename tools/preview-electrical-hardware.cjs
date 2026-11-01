// Native Lua paint/layout output. This does not simulate Source engine rendering.
const fs=require('fs'),path=require('path'),f=require('fengari'),{normalize}=require('./glua.cjs');
const files=['tools/fixture.lua','tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/facility.lua','tools/terminal-preview-fixture.lua','tools/fixtures/electrical-hardware.lua',...['sh_core','sh_repair','sh_engineering_games','sh_engineering'].map(v=>'ixhl2rp/plugins/facility_utilities/'+v+'.lua'),'ixhl2rp/plugins/foundation_network/cl_design.lua',...['cl_hardware','cl_ui','cl_devices','cl_repair','cl_engineering'].map(v=>'ixhl2rp/plugins/facility_utilities/'+v+'.lua')];
const native=files.map(p=>'do\n'+normalize(fs.readFileSync(p,'utf8'))+'\nend').join('\n');
const scenarios={
 generator:`ix.Facility.OpenDevice({device={id=1,name='Резервный генератор',kind='generator',fuel=346,running=false,canStart=true,hasFuel=true,capacity=60,portable=true,links={{index=1,name='Электрощит · восточное крыло',connected=true},{index=2,name='Монитор поста охраны',connected=true}}}})`,
 battery:`ix.Facility.OpenDevice({device={id=2,name='Аккумуляторный блок',kind='battery',charge=4260,powered=true}})`,
 probe:`ix.Facility.OpenEngineering({token=1,round=3,kind='probe',stage=3,title='Ремонт электрощита',noParts=true,expires=100,entity=4,message='closed',state={count=6,budget=3,possible={true,true,false,false,true,true},probes={{a=2,b=4,result='closed'}}}})`,
 pressure:`ix.Facility.OpenEngineering({token=1,round=3,kind='pressure',stage=2,title='Ремонт резервного генератора',expires=100,entity=4,message='near',state={lo=64,hi=72,reading=59,runs=5,valves={1,3,2},history={{valves={1,3,2},reading=59,verdict='belownear'}}}})`,
 jobs:`local root=vgui.Create('DFrame');root:SetSize(math.min(900,ScrW()-40),ScrH()-40);ix.Facility.Hardware.Frame(root,'workorder','СЛУЖБА ЭКСПЛУАТАЦИИ','ЖУРНАЛ РАБОТ');local body=root:Add('DScrollPanel');body:Dock(FILL);ix.Facility.RenderJobs(body,{{id=17,title='Ремонт электрощита · сектор Д-1',ownerName='Алексей Морозов',mine=true,available=true,status='assigned'},{id=23,title='Обслуживание станции обеззараживания',available=true,status='open'}},function() end)`,
 comms:`local root=vgui.Create('DFrame');root:SetSize(math.min(1100,ScrW()-40),ScrH()-40);ix.Facility.Hardware.Frame(root,'comms','ДИСПЕТЧЕРСКИЙ ПОСТ','СВЯЗЬ ОБЪЕКТА');root.body=root:Add('DScrollPanel');root.body:Dock(FILL);ix.Facility.RenderTerminal(root,{page='comms',transmitting=1,calls={{id=3,name='Шлюз лаборатории',caller='Алексей Морозов',operator='Thomas',mine=true}},circuits={{id=1,name='Научный сектор',powered=true}}})`,
 power:`local root=vgui.Create('DFrame');root:SetSize(math.min(1100,ScrW()-40),ScrH()-40);ix.Facility.Hardware.Frame(root,'power','ЭНЕРГОСНАБЖЕНИЕ','ДИСПЕТЧЕРСКИЙ ПОСТ');root.body=root:Add('DScrollPanel');root.body:Dock(FILL);ix.Facility.RenderTerminal(root,{page='power',circuits={{id=1,name='Тяжёлая зона содержания',powered=true,load=40,priority=1,source='РЕЗЕРВ'},{id=2,name='Административный сектор',powered=false,isolated=true,load=20,priority=3,source='ИЗОЛЯЦИЯ'}},devices={}})`
};
const out=path.resolve('.runtime/device-ui-redesign-20261009/previews');fs.mkdirSync(out,{recursive:true});
for(const size of [[1280,900],[1024,768]])for(const [name,scenario]of Object.entries(scenarios)){
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 const code=native+`\nfunction ScrW() return ${size[0]} end;function ScrH() return ${size[1]} end;local p=admin();function LocalPlayer() return p end\n`+scenario+`\nlocal root=hardwarePreviewFrame;return root:GetWide()..':'..root:GetTall()..':'..PreviewSVG(root)`;
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const raw=f.to_jsstring(f.lua.lua_tostring(L,-1)),match=raw.match(/^(\d+):(\d+):([\s\S]*)$/);f.lua.lua_close(L);
 const svg=match[3].replace('width="1920" height="1120"',`width="${match[1]}" height="${match[2]}"`).replace('viewBox="0 0 1920 1120"',`viewBox="0 0 ${match[1]} ${match[2]}"`);
 fs.writeFileSync(path.join(out,`${name}-${size[0]}.svg`),svg);
}
console.log('Generated 14 production Lua previews in '+out);
