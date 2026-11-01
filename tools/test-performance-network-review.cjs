const {source}=require('./restored-test-runner.cjs');
module.exports=suite=>{
 const recordStub=`
 local saved,loadError,writes
 game=game or {GetMap=function() return 'test' end};ix.data=ix.data or {}
 writes=0;ix.recordStore={Load=function() return saved,loadError end,Join=function(records) return records end,
 Split=function(records) return records end,Save=function() writes=writes+1;return true end}
 local staleReads=0;ix.data.Get=function(_,default) staleReads=staleReads+1;return default end
 `;
 suite('Initialized Foundation schemas fail closed without replacing working state; repaired data can load and save',[],source(['ixhl2rp/plugins/foundation_network/sv_network.lua'])+recordStub+`
 local P=PLUGIN;local live=P.store;P.GetData=function() error('stale legacy fallback') end
 saved={nextID=1,accounts={},documents={}};eq(pcall(P.LoadData,P),false);eq(P.store,live);eq(pcall(P.SaveData,P),false);eq(writes,0)
 saved={nextID=4,accounts={},documents={[1]={id=1},[3]={id=3}},tickets={}};eq(pcall(P.LoadData,P),false);eq(P.store,live)
 saved={nextID=2,accounts={},documents={{id=1}},tickets={{id=1}}};eq(pcall(P.LoadData,P),false)
 saved={nextID=3,accounts={user={name='A'}},documents={{id=1,title='A'}},tickets={{id=2,title='B'}}}
 P:LoadData();P:SaveData();eq(P.store,saved);eq(writes,1);eq(staleReads,0)
 `);
 const cctv=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_network.lua']);
 suite('CCTV committed corruption does not remove live equipment or overwrite records, and complete array or keyed snapshots restore',[],cctv+`
 local P=PLUGIN;P:LoadData();P:PostLoadData();local d,e=makeDevice('camera',Vector(32,0,64));local row=P:Snapshot(d)
 `+recordStub+`
 saved={nextID=2};eq(pcall(P.LoadData,P),false);assert(IsValid(e));eq(P.devices[d.id],d);eq(pcall(P.SaveData,P),false);eq(writes,0)
 saved={nextID=2,devices={{id=1,kind='camera',pos={x=1},ang={p=0,y=0,r=0}}}}
 eq(pcall(P.LoadData,P),false);assert(IsValid(e));eq(staleReads,0)
 saved={nextID=2,devices={row}};P:LoadData();assert(P.devices[1]);P:SaveData();eq(writes,1)
 saved={nextID=3,devices={[2]=table.Copy(row)}};saved.devices[2].id=2;P:LoadData();assert(P.devices[2]);eq(P.devices[1],nil)
 `);
 const facility=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','tools/fixtures/facility.lua','ixhl2rp/plugins/facility_utilities/sh_core.lua','ixhl2rp/plugins/facility_utilities/sv_store.lua']);
 suite('Facility initialized schemas reject missing, duplicate or malformed device rows before power teardown and recover after repair',[],facility+recordStub+`
 local P=PLUGIN;local cleared,spawned=0,0
 P.ClearGeneratorPower=function() cleared=cleared+1 end;P.RecomputePower=function() end;P.cableModes={}
 P.SpawnDevice=function(_,row) spawned=spawned+1 end
 local live=entity(600,'generator',Vector());P.store.devices[1]={id=1,entity=live};P.loaded=true
 saved={nextID=2,devices={}};eq(pcall(P.LoadData,P),false);eq(cleared,0);assert(IsValid(live));eq(pcall(P.SaveData,P),false);eq(writes,0)
 saved={nextID=2,circuits={},devices={{id=1,name='Generator',kind='generator',pos=Vector(),ang=Angle(),binding={}}},doors={},jobs={}}
 eq(pcall(P.LoadData,P),false);eq(cleared,0);assert(IsValid(live))
 saved.devices[1].binding=nil;saved.circuits[1]={id=1,name='Duplicate'};eq(pcall(P.LoadData,P),false)
 saved.circuits={};P:LoadData();eq(cleared,1);eq(spawned,1);eq(P.store.devices[1].id,1);P:SaveData();eq(writes,1);eq(staleReads,0)
 `);
 suite('World committed rows require canonical identity and valid transforms, validate atomically and recover after a failed read',[],source(['tools/geometry-fixture.lua'])+`
 function isangle(v) return type(v)=='table' and getmetatable(v)==getmetatable(Angle()) end
 ix.util={Include=function() end};game={GetMap=function() return 'test' end}
 `+source(['ixhl2rp/plugins/world_persistence/sh_plugin.lua','ixhl2rp/plugins/world_persistence/sv_store.lua'])+recordStub+`
 local P=PLUGIN;P.GetData=function() error('stale legacy fallback') end;P.Restore=function() end
 local original={sentinel=true};P.records=original
 local row={id=1,class='ix_foundation_terminal',pos=Vector(2,3,4),ang=Angle(0,90,0)}
 saved={metadata={version=1,nextID=2},bad=row};eq(pcall(P.LoadData,P),false);eq(P.records,original);P:SaveData();eq(writes,0)
 saved={metadata={version=1,nextID=3},['entity:1']=row,['entity:2']={id=2,class=row.class,pos='broken',ang=Angle()}}
 eq(pcall(P.LoadData,P),false);eq(P.records,original);eq(P.loaded,nil);eq(writes,0)
 saved['entity:2'].pos=Vector();P:LoadData();eq(P.loaded,true);eq(P.storageFault,nil);eq(P.records[1].data.pos.y,3)
 P:SaveData();eq(writes,1);eq(staleReads,0)
 `);
 suite('CCTV targeted updates invalidate cached record identities and immediately subscribe switched distant feeds without whole-registry scans',[],cctv+`
 local P=PLUGIN;P:LoadData();P:PostLoadData()
 local first=makeDevice('camera',Vector(5000,0,64));local second=makeDevice('camera',Vector(6000,0,64))
 local monitor=makeDevice('monitor',Vector(60,0,64));monitor.camera=first.id
 local p=admin();p.admin=false;p.pos=Vector(0,0,64);P:Sync(p)
 local old=P.DeviceInterest;P.DeviceInterest=function() error('registry scan during mutation') end
 monitor.camera=second.id;P:SendDevice(monitor);assert(P.subscribers[p].known[second.id])
 local replacement={};for key,value in pairs(second) do replacement[key]=value end;replacement.name='Replacement';P.devices[second.id]=replacement;P:SendDevice(replacement)
 eq(P.networkSnapshots[second.id].record,replacement)
 P.DeviceInterest=old;P:RefreshSubscriber(p);eq(P.subscribers[p].known[first.id],nil)
 P.devices[second.id].entity:SetPos(Vector(7000,0,64));P:PhysgunDrop(nil,P.devices[second.id].entity)
 eq(util.JSONToTable(P.networkSnapshots[second.id].payload).pos.x,7000)
 `);
};
