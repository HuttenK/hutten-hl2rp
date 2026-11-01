const {run,source,base,finish}=require('./restored-test-runner.cjs');
const server=source(base)+`
 SERVER=true;CLIENT=false;ix.water={};ix.util={Include=function() end};ix.command={commands={},Add=function(name,value) ix.command.commands[name]=value end}
 local saved,writeCount,ignoreMap,globalFlag={},0
 ix.data={Get=function(key,default,global,ignore) eq(key,'foundation_water_models_v1');eq(global,false);eq(ignore,true);return table.Copy(saved) end,
 Set=function(key,data,global,ignore) eq(key,'foundation_water_models_v1');saved=table.Copy(data);writeCount=writeCount+1;ignoreMap=ignore;globalFlag=global end}
 util.IsValidModel=function(model) return not model:find('missing',1,true) end
`+source(['ixhl2rp/plugins/water_sources/sh_plugin.lua','ixhl2rp/plugins/water_sources/sh_water.lua','ixhl2rp/plugins/water_sources/sv_registry.lua'])+`
 local W=ix.water
`;
function test(name,code){run(name,server+code)}
test('SinkAdmin command and every registry mutation reject nonadmins without writes',`
 local p=admin();p.admin=false
 eq(ix.command.commands.SinkAdmin.adminOnly,true);ix.command.commands.SinkAdmin.OnRun(nil,p);eq(writeCount,0)
 for _,action in ipairs({'add','remove','aim'}) do eq(W.ChangeModel(p,action,'models/custom/sink.mdl','sink'),false) end
 eq(W.OpenRegistry(p),false);eq(writeCount,0);eq(next(W.custom),nil)
`);
test('Custom sink/toilet add, update, remove and reload use schema-wide persisted data; builtins remain intact',`
 local p=admin();assert(W.ChangeModel(p,'add',' MODELS/custom/SINK.mdl ','sink'));eq(W.models['models/custom/sink.mdl'],'sink');eq(ignoreMap,true);eq(globalFlag,false)
 assert(W.ChangeModel(p,'add','models/custom/sink.mdl','toilet'));eq(W.models['models/custom/sink.mdl'],'toilet')
 W.custom={};W.LoadModels();eq(W.Source(entity(4,'models/custom/sink.mdl')),'toilet')
 assert(W.ChangeModel(p,'remove','models/custom/sink.mdl'));eq(W.models['models/custom/sink.mdl'],nil)
 eq(W.ChangeModel(p,'remove','models/props_c17/furnituresink001a.mdl'),false);eq(W.models['models/props_c17/furnituresink001a.mdl'],'sink')
 eq(W.models['models/props_c17/furnituretoilet001a.mdl'],'toilet');eq(W.models['models/props_se/propper/toilet05.mdl'],'toilet')
`);
test('Registry rejects traversal, wrong extensions, missing content, oversized data and type forgery',`
 local p=admin()
 for _,value in ipairs({'../cfg/server.cfg','models/../secret.mdl','models//test.mdl','C:/models/test.mdl','models/test.txt',string.rep('x',190),'models/missing.mdl'}) do eq(W.ChangeModel(p,'add',value,'sink'),false) end
 eq(W.ChangeModel(p,'add','models/custom/good.mdl','generator'),false);eq(writeCount,0)
 for i=1,W.modelLimit do W.custom['models/custom/'..i..'.mdl']='sink' end
 eq(W.ChangeModel(p,'add','models/custom/extra.mdl','sink'),false);eq(writeCount,0)
 assert(W.ChangeModel(p,'add','models/custom/1.mdl','toilet'))
`);
test('Add aimed prop resolves actual server trace and rejects distant/non-prop targets',`
 local p=admin();local e=entity(4,'models/custom/aimed.mdl',Vector(10,0,0))
 p.trace={Entity=e,HitPos=p:GetShootPos()+Vector(20,0,0)};assert(W.ChangeModel(p,'aim','models/forged.mdl','sink'));eq(W.models[e:GetModel()],'sink');eq(W.models['models/forged.mdl'],nil)
 p.trace.HitPos=Vector(10000,0,0);eq(W.ChangeModel(p,'aim','','sink'),false)
 p.trace.HitPos=p:GetShootPos();e.class='ix_item';eq(W.ChangeModel(p,'aim','','sink'),false)
`);
test('Initial/reload sync publishes registry; oversized/mutation packets are gated before payload reads',`
 local p=admin();local before=#net.packets;hooks.PlayerInitialSpawn.ixWaterRegistryInitial(p);assert(#net.packets>before)
 p.admin=false;local reads=0;net.ReadUInt=function() return 1 end;net.ReadString=function() reads=reads+1;return 'models/custom/injected.mdl' end
 net.handlers.ixWaterRegistryRequest(100,p);eq(reads,0);eq(writeCount,0)
 clock=clock+1;p.admin=true;net.handlers.ixWaterRegistryRequest(9000,p);eq(reads,0)
 clock=clock+1;net.ReadUInt=function() return 0 end;net.handlers.ixWaterRegistryRequest(2,p);eq(reads,0);eq(net.packets[#net.packets].name,'ixWaterModels')
`);
const ui=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/terminal-preview-fixture.lua','tools/fixtures/device-equipment-ui.lua','ixhl2rp/plugins/water_sources/sh_water.lua','ixhl2rp/plugins/water_sources/cl_water.lua','ixhl2rp/plugins/water_sources/cl_registry.lua']);
run('Client registry sync supports custom source types, removals and immutable defaults',ui+`
 read({2,'models/custom/sink.mdl',false,'models/custom/toilet.mdl',true});net.handlers.ixWaterModels()
 eq(ix.water.models['models/custom/sink.mdl'],'sink');eq(ix.water.models['models/custom/toilet.mdl'],'toilet')
 read({0});net.handlers.ixWaterModels();eq(ix.water.models['models/custom/sink.mdl'],nil);eq(ix.water.models['models/props_c17/furnituretoilet001a.mdl'],'toilet')
 read({1,'models/props_c17/furnituresink001a.mdl',true});net.handlers.ixWaterModels();eq(ix.water.models['models/props_c17/furnituresink001a.mdl'],'sink')
`);
run('Native admin menu denies nonadmin, fits small screen, and sends aimed model action then closes on privilege loss',ui+`
 eq(ix.water.OpenAdmin('Test'),nil);playerMock.admin=true;screenW=640;screenH=480
 ix.water.ApplyModels({['models/custom/very_long_model_path_for_bathroom_and_washing_station.mdl']='sink'})
 local win=ix.water.OpenAdmin('Модель сохранена.');PreviewLayout(win);assert(win:GetWide()<=610 and win:GetTall()<=450)
 local controls=buttons(win);controls[3]:DoClick();local packet=sent[#sent];eq(packet.name,'ixWaterRegistryRequest');eq(packet.values[1][1],2)
 PreviewSVG(win);playerMock.admin=false;win:Think();eq(IsValid(win),false);eq(ix.water.adminMenu,nil)
`);
run('Long registry paths stay in the row; live edits refresh the list without losing a typed draft',ui+`
 playerMock.admin=true;screenW=640;screenH=480
 local long='models/'..string.rep('a',169)..'.mdl';eq(#long,180)
 ix.water.ApplyModels({[long]='sink'});local win=ix.water.OpenAdmin();local svg=PreviewSVG(win)
 assert(svg:find('…',1,true));assert(not svg:find(long,1,true))
 win.modelEntry:SetText('models/my_unsaved_draft.mdl');win.sourceKind='toilet'
 read({1,'models/custom/new_toilet.mdl',true});net.handlers.ixWaterModels()
 eq(IsValid(win),false);eq(ix.water.adminMenu.modelEntry:GetValue(),'models/my_unsaved_draft.mdl');eq(ix.water.adminMenu.sourceKind,'toilet')
 eq(ix.water.models['models/custom/new_toilet.mdl'],'toilet')
`);
finish();
