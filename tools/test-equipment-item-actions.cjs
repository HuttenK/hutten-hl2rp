const {run,source,base,read,finish}=require('./restored-test-runner.cjs');
const parser=require('luaparse'),{normalize}=require('./glua.cjs');
const runtime=[...['cl_contextual','cl_devices','cl_ui','sv_devices'].map(n=>'ixhl2rp/plugins/facility_utilities/'+n+'.lua'),
 'ixhl2rp/plugins/water_sources/cl_water.lua',...['sh_beds','sv_sleep','cl_sleep'].map(n=>'ixhl2rp/plugins/sleep/'+n+'.lua')];
for(const file of runtime) parser.parse(normalize(read(file)),{luaVersion:'5.2'});
console.log('PASS normalized Lua syntax: eight changed interaction and bed files');
const {client}=require('./test-contextual-equipment-use.cjs');
function suite(name,body){run(name,client+body)}
suite('Production item menu remains interactive with its own cursor and sends one exact click intent',`
 aimed=fixture('sink');bottle(75,'Фляга');Q.Input(command(true));local m=Q.menu
 assert(cursor);assert(Q.MenuSpec(m));local option=menuOption(m,'Набрать: Фляга')
 assert(option.tooltip:find('20 / 600',1,true));option.DoClick();eq(#net.packets,1);option.DoClick();eq(#net.packets,1)
 eq(net.packets[1].integers[2],75);eq(Q.menu,nil)
`);
suite('A pending equipment snapshot populates an already opened menu without a second Use or closing admin windows',`
 aimed=fixture('generator');Q.Input(command(true));local m=Q.menu
 eq(menuOption(m,'Проверка состояния…'):IsEnabled(),false)
 F.OpenDevice({device={entity=aimed:EntIndex(),id=700,kind='generator',fault=false,fuel=300,canStart=true,hasFuel=true,links={}}})
 m:Think();eq(Q.menu,m);assert(menuOption(m,'Запустить двигатель'):IsEnabled())
 menuOption(m,'Запустить двигатель').DoClick();eq(#requests,1);eq(requests[1][2],'generator')
`);
suite('No disabled, expired or newly faulty operation can be replayed from an old menu row',`
 aimed=fixture('generator');F.OpenDevice({device={entity=aimed:EntIndex(),id=700,kind='generator',fault=false,fuel=300,canStart=true,links={}}})
 Q.Input(command(true));local option=menuOption(Q.menu,'Запустить двигатель')
 aimed.ixFacilityFault=true;option.DoClick();eq(requests,nil)
 Q.Input(command(false));aimed.ixFacilityFault=false;Q.Input(command(true));option=menuOption(Q.menu,'Запустить двигатель')
 clock=clock+5;option.DoClick();eq(requests,nil)
`);
suite('Start does not become Stop, and a shifted same-name cable does not change the clicked target',`
 aimed=fixture('generator');local data={entity=aimed:EntIndex(),id=700,kind='generator',fault=false,fuel=300,canStart=true,links={{index=1,name='Щиток',token=100}}}
 F.OpenDevice({device=data});Q.Input(command(true));local start=menuOption(Q.menu,'Запустить двигатель')
 data.running=true;start.DoClick();eq(requests,nil)
 Q.Input(command(false));Q.Input(command(true));local disconnect=menuOption(Q.menu,'Отсоединить: Щиток')
 data.links={{index=1,name='Щиток',token=101}};disconnect.DoClick();eq(requests,nil)
 Q.Input(command(false));Q.Input(command(true));menuOption(Q.menu,'Отсоединить: Щиток').DoClick();eq(requests[1][3].expectedLink,101)
`);
suite('An unrelated entity menu or keyboard input owns focus and retires the equipment menu',`
 for _,set in ipairs({function() mainMenu=true;ix.menu.panel={valid=true} end,function() focus={valid=true} end}) do
  mainMenu=false;focus=nil;aimed=fixture('sink');Q.Input(command(false));Q.Input(command(true));local m=Q.menu
  set();m:Think();eq(IsValid(m),false);eq(#net.packets,0)
 end
`);
suite('Changing character, leaving reach or blocking the use ray closes options without submitting',`
 for _,change in ipairs({function() p.character={} end,function() aimed=nil end,function() gameMenu=true end}) do
  p.character={};gameMenu=false;aimed=fixture('sink');Q.Input(command(false));Q.Input(command(true));local m=Q.menu
  change();m:Think();eq(IsValid(m),false);eq(#net.packets,0)
 end
`);
suite('Long Cyrillic names and many containers retain native scrolling in a bounded 640 by 480 menu',`
 screenW=640;screenH=480;aimed=fixture('sink')
 for i=1,30 do bottle(i,string.rep('Длинное название ёмкости ',7)..i) end
 Q.Input(command(true));local m=Q.menu
 assert(m:GetWide()<ScrW());assert(m:GetTall()<=ScrH()*.9);assert(m.y>=1);assert(m.y+m:GetTall()<=ScrH())
 local rows=m:GetCanvas():GetChildren();eq(#rows,33);assert(rows[2].text:find('…',1,true));assert(#rows[2].tooltip>#rows[2].text)
`);
suite('Bed uses the real item menu at screen center and retires a click once; stale characters cannot sleep',`
 ix.sleep={USE_RANGE=96,IsBed=function(e) return e==aimed end,IsResting=function() return false end,
 IsSleeping=function() return false end,CanReach=function(p,e) return e==aimed end}
 ${source(['ixhl2rp/plugins/sleep/cl_sleep.lua'])}
 aimed=fixture('bed');net.ReadEntity=function() return aimed end
 net.handlers.ixBedRestMenu();local current
 -- Native registration captures the opened menu through its own constructor.
 cursor=false;local original=ix.SimpleMenu;ix.SimpleMenu=function(...) current=original(...);return current end
 net.handlers.ixBedRestMenu();eq(current.class,'simple.option');eq(current.x,640);eq(current.y,360)
 local sleep=menuOption(current,'Лечь спать');sleep.DoClick();sleep.DoClick();eq(#net.packets,1);eq(net.packets[1].name,'ixBedRestRequest');eq(net.packets[1].integers[1],2)
 cursor=false;net.handlers.ixBedRestMenu();local rest=menuOption(current,'Лечь отдохнуть');p.character={};rest.DoClick();eq(#net.packets,1)
`);
const server=source([...base,...['sh_core','sh_repair','sv_store','sv_connections','sv_power','sv_doors','sv_comms','sv_jobs','sv_repair','sv_devices','sv_network'].map(v=>'ixhl2rp/plugins/facility_utilities/'+v+'.lua')]);
run('Server rejects a stale generator toggle and shifted cable index even before the client receives a newer snapshot',server+`
 local P=PLUGIN;local p=admin();local g=device('generator');g.fuel=300;g.running=true
 local ok=P:DeviceAction(p,{id=g.id,command='generator',expectedRunning=false});eq(ok,false);eq(g.running,true)
 local first=device('terminal');local second=device('terminal')
 local a,b={kind='device',id=first.id,name='Same'},{kind='device',id=second.id,name='Same'}
 g.links={a,b};local data=P:DeviceSnapshot(p,g);local tokenA=data.device.links[1].token;local tokenB=data.device.links[2].token
 assert(tokenA and tokenB and tokenA~=tokenB);table.remove(g.links,1)
 ok=P:DeviceAction(p,{id=g.id,command='disconnect',index=1,expectedLink=tokenA});eq(ok,false);eq(g.links[1],b)
 assert(P:DeviceAction(p,{id=g.id,command='disconnect',index=1,expectedLink=tokenB}));eq(#g.links,0)
`);
finish();
