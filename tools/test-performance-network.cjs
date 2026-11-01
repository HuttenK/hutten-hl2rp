const {source}=require('./restored-test-runner.cjs');
module.exports=suite=>{
 const cctv=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','helix/gamemode/core/libs/sh_propscreens.lua','tools/fixtures/cctv.lua','ixhl2rp/plugins/cctv/sh_state.lua','ixhl2rp/plugins/cctv/sh_surfaces.lua','ixhl2rp/plugins/cctv/entities/entities/ix_cctv_device.lua','ixhl2rp/plugins/cctv/sv_devices.lua','ixhl2rp/plugins/cctv/sv_surfaces.lua','ixhl2rp/plugins/cctv/sv_network.lua']);
 suite('CCTV initial subscriptions target nearby viewers and remote linked cameras; moving away removes state and a returning viewer resynchronizes',cctv+`
 local P=PLUGIN;P:LoadData();P:PostLoadData()
 local camera=makeDevice('camera',Vector(5000,0,64));local unrelated=makeDevice('camera',Vector(9000,0,64))
 local monitor=makeDevice('monitor',Vector(50,0,64));monitor.camera=camera.id
 local near=admin();near.admin=false;near.pos=Vector(0,0,64);local far=admin();far.admin=false;far.pos=Vector(15000,0,64)
 P:Sync(near);P:Sync(far);assert(P.subscribers[near].known[monitor.id]);assert(P.subscribers[near].known[camera.id]);eq(P.subscribers[near].known[unrelated.id],nil);eq(next(P.subscribers[far].known),nil)
 net.packets={};camera.name='Changed';local old=P.DeviceInterest;P.DeviceInterest=function() error('single update must not scan registry') end
 P:SendDevice(camera);eq(#net.packets,1);eq(net.packets[1].target,near);P.DeviceInterest=old
 near.pos=Vector(15000,0,64);P:RefreshSubscriber(near);eq(next(P.subscribers[near].known),nil)
 near.pos=Vector(0,0,64);P:RefreshSubscriber(near);assert(P.subscribers[near].known[camera.id])
 P:DeleteRecord(camera.id);eq(P.subscribers[near].known[camera.id],nil);eq(monitor.camera,0)
 P:PlayerDisconnected(near);eq(P.subscribers[near],nil)
 `);
 suite('CCTV terminal access and admin leases are revalidated, while explicit distant console previews remain available',cctv+`
 local P=PLUGIN;P:LoadData();P:PostLoadData()
 local terminal=makeDevice('terminal',Vector(50,0,64));local remote=makeDevice('camera',Vector(9000,0,64))
 local p=admin();p.pos=Vector(0,0,64);p.admin=false;P:Sync(p);assert(P.subscribers[p].known[remote.id])
 local original=P.CanOperate;P.CanOperate=function() return false end;P:RefreshSubscriber(p);eq(P.subscribers[p].known[remote.id],nil)
 p.admin=true;P:OpenAdmin(p);assert(P.subscribers[p].known[remote.id]);p.admin=false;P:RefreshSubscriber(p);eq(P.subscribers[p].known[remote.id],nil)
 p.admin=true;P:OpenAdmin(p);clock=clock+4;P:RefreshSubscriber(p);eq(P.subscribers[p].known[remote.id],nil)
 p.admin=false;ix.plugin.list.facility_utilities={CameraPreviewAllowed=function(_,client,id) return client==p and id==remote.id end}
 P.watchers[p]={expires=clock+1,grants={{camera=remote.id,monitor=0}}};P:RefreshSubscriber(p);assert(P.subscribers[p].known[remote.id]);P:SendDevice(remote);assert(P.subscribers[p].known[remote.id])
 ix.plugin.list.facility_utilities.CameraPreviewAllowed=function() return false end;P:RefreshSubscriber(p);eq(P.subscribers[p].known[remote.id],nil)
 P.CanOperate=original
 `);
 const setup=`
 at=0;function SysTime() return at end;collectgarbage=function() return 1 end
 ix.util={Include=function() end};ix.plugin.list={};GetConVar=function() end
 local events={};hook.GetTable=function() return events end
 hook.Add=function(event,id,fn) events[event]=events[event] or {};events[event][id]=fn end
 hook.Remove=function(event,id) if events[event] then events[event][id]=nil end end
 concommand={Add=function() end};game={GetMap=function() return 'test' end};engine={TickInterval=function() return .015 end}
 ents.GetCount=function() return 0 end;file={CreateDir=function() end,Write=function() end};util.TableToJSON=function() return '{}' end
 local h1={valid=true,IsPlayer=function() return true end};local h2={valid=true,IsPlayer=function() return true end}
 player.GetAll=function() return {h1,h2} end;player.GetHumans=player.GetAll
 net.Start=function(name,unreliable) buffer=name;bytes=3;return nil,true,nil end;net.BytesWritten=function() return bytes end
 net.Send=function(...) sendArity=select('#',...);return nil,false,nil end
 net.Broadcast=net.Send;net.SendOmit=net.Send;net.SendPVS=net.Send;net.SendPAS=net.Send;net.Abort=function() buffer=nil end
 net.Receivers={};sql={Query=function(q) at=at+.003;sqlCalls=(sqlCalls or 0)+1;return q=='bad' and false or nil end}
 `;
 const profiler=source(['ixhl2rp/plugins/performance_monitor/sh_plugin.lua','ixhl2rp/plugins/performance_monitor/sh_instrument.lua']);
 suite('Profiler scopes preserve nil-bearing returns, error identity, nested self/inclusive time, Helix dispatch and later replacements',setup+`
 local plugin={};local token={}
 function plugin:Child(...) at=at+.003;eq(select('#',...),3);return nil,false,nil end
 function plugin:Parent() at=at+.002;return self:Child(1,nil,3) end
 function plugin:Broken() at=at+.001;error(token) end
 local originalParent=plugin.Parent;local originalChild=plugin.Child;ix.plugin.list.test=plugin
 HOOKS_CACHE={Think={[plugin]=plugin.Parent}};local eventFn=function() at=at+.004;return 'sound' end;hook.Add('EntityEmitSound','SCP',eventFn)
 `+profiler+`
 local P=ix.performance;assert(P.Start(30));local c=P.capture
 local result={n=select('#',plugin:Parent()),plugin:Parent()};eq(result.n,3);eq(result[2],false)
 local failed,value=pcall(function() plugin:Broken() end);eq(failed,false);eq(value,token);eq(#c.stack,0)
 HOOKS_CACHE.Think[plugin](plugin);eq(hook.GetTable().EntityEmitSound.SCP(),'sound')
 near(c.timings['plugin:test:Parent'].totalMs,15);near(c.timings['plugin:test:Parent'].selfMs,6)
 near(c.timings['hook:EntityEmitSound:SCP'].totalMs,4);eq(c.timings['plugin:test:Broken'].errors,1)
 local replacement=function() return 'new' end;plugin.Child=replacement;P.Stop()
 eq(plugin.Parent,originalParent);eq(plugin.Child,replacement);eq(HOOKS_CACHE.Think[plugin],originalParent);eq(hook.GetTable().EntityEmitSound.SCP,eventFn)
 `);
 suite('Capture counts Lua net sizes and recipients without changing varargs, abort behavior or PVS delivery',setup+profiler+`
 local P=ix.performance;local oldStart,oldSend=net.Start,net.Send;P.Start(30);local c=P.capture
 net.Start('single');bytes=20;eq(select('#',net.Send(player.GetAll()[1])),3);eq(sendArity,1)
 net.Start('all');bytes=30;net.Broadcast();eq(sendArity,0)
 net.Start('many');bytes=10;net.Send(player.GetAll())
 net.Start('omit');bytes=12;net.SendOmit(player.GetAll()[1])
 net.Start('pvs');bytes=8;net.SendPVS({})
 net.Start('aborted');net.Abort();eq(buffer,nil)
 eq(c.network.single.bytes,20);eq(c.network.single.recipients,1);eq(c.network.all.recipientBytes,60);eq(c.network.many.recipients,2);eq(c.network.omit.recipients,1);eq(c.network.pvs.unknownRecipientCalls,1);eq(c.network.aborted,nil)
 P.Stop();eq(net.Start,oldStart);eq(net.Send,oldSend)
 `);
 suite('Database instrumentation preserves synchronous work, async arguments and callbacks, failures and pending completion after stop',setup+`
 mysql={module='sqlite'}
 function mysql:RawQuery(q,callback,flags,...)
  eq(flags,'flags');eq(select('#',...),3);eq(select(2,...),nil)
  if q=='throw' then error('db error') end
  if self.module=='sqlite' then
   sql.Query(q);if callback then sql.Query('SELECT last_insert_rowid()');return callback(nil,false,17) end
  else completion=callback;return nil,'queued',nil end
 end
 `+profiler+`
 local P=ix.performance;local original=mysql.RawQuery;P.Start(30);local c=P.capture
 mysql:RawQuery('INSERT x',nil,'flags',1,nil,3);eq(sqlCalls,1);eq(c.database['issue:sqlite:INSERT'].pending,0)
 local called=0;mysql:RawQuery('SELECT x',function(...) called=called+1;eq(select('#',...),3);eq(select(1,...),nil);eq(select(2,...),false) end,'flags',1,nil,3);eq(called,1);eq(sqlCalls,3)
 eq(pcall(function() mysql:RawQuery('throw',nil,'flags',1,nil,3) end),false);eq(c.database['issue:sqlite:THROW'].pending,0)
 mysql.module='mysqloo';eq(select('#',mysql:RawQuery('SELECT async',function(...) called=called+1;eq(select('#',...),3) end,'flags',1,nil,3)),3)
 at=at+.2;completion({},true,4);eq(c.database['completion:mysqloo:SELECT'].calls,1);eq(called,2)
 mysql:RawQuery('SELECT pending',function() called=called+1 end,'flags',1,nil,3);eq(c.database['issue:mysqloo:SELECT'].pending,1)
 P.Stop();eq(mysql.RawQuery,original);completion({},true,5);eq(called,3);eq(c.database['issue:mysqloo:SELECT'].pending,1)
 `);
 suite('Partial profiler setup failures restore previous functions and repeated capture/unload leaves no wrappers',setup+`
 local plugin={Think=function() return 7 end};local original=plugin.Think;ix.plugin.list.sample=plugin
 local getTable=hook.GetTable;hook.GetTable=function() error('setup failure') end
 `+profiler+`
 local P=ix.performance;eq(P.Start(30),false);eq(P.capture,nil);eq(plugin.Think,original)
 hook.GetTable=getTable
 for i=1,2 do assert(P.Start(30));assert(plugin.Think~=original);PLUGIN:OnUnload();eq(P.capture,nil);eq(plugin.Think,original) end
 `);
};
