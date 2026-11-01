const {run,source,native,finish}=require('./restored-test-runner.cjs');
const base=source(['tools/fixtures/sharedposes.lua','tools/fixtures/pose-gizmo.lua','tools/fixtures/tv.lua','tools/fixtures/cctv.lua','tools/fixtures/bodycams.lua','ixhl2rp/plugins/bodycams/sh_bodycams.lua'])+`
 SERVER=true;CLIENT=false;NULL={};ix.util={Include=function() end}
 local listeners,timers={},{}
 function hook.Add(event,id,fn) listeners[event..':'..id]=fn end
 function hook.Remove(event,id) listeners[event..':'..id]=nil end
 function hook.Run(event,...) for name,fn in pairs(listeners) do if name:sub(1,#event+1)==event..':' then fn(...) end end end
 function timer.Create(name,delay,count,fn) timers[name]=fn end
 function timer.Remove(name) timers[name]=nil end
 function SortedPairs(t) local keys={};for k in pairs(t) do keys[#keys+1]=k end;table.sort(keys);local i=0;return function() i=i+1;local k=keys[i];if k then return k,t[k] end end end
 net.ChooseOptimalBits=function() return 3 end
 local Item=ix.Item
 ${native('helix/gamemode/game/items/sh_item.lua','function Item:Register(uniqueID, item)','function Item:Load(path, uniqueID, baseID)')}
 ${native('helix/gamemode/game/items/sh_item.lua','function Item:PerformInventoryCombineAction(client, item, targetItem, action_id, data, item_count)',"net.Receive('item.action'")}
 ITEM=ix.Item.stored.helmet_bodycam
`+source(['ixhl2rp/plugins/bodycams/items/helmet_bodycam.lua'])+`
 ix.Item:Register('helmet_bodycam',ITEM);ix.bodycams.RegisterHelmets()
 ix.Inventory={Get=function(_,id) if not id then return end;return {OnCheckAccess=function() return true end} end}
 local original=wearer
 function wearer()
  local p=original();p.character={};p.netvars={};p.inventory=true
  function p:GetCharacter() return self.character end
  function p:InVehicle() return self.vehicle end
  function p:GetNetVar(k,d) if self.netvars[k]~=nil then return self.netvars[k] end;return d end
  function p:GetNW2String(k,d) return self.vars[k] or d end
  function p:GetNW2Float(k,d) return self.vars[k] or d end
  function p:GetNW2Entity(k) return self.vars[k] or NULL end
  function p:SetNW2String(k,v) self.vars[k]=v end
  function p:SetNW2Entity(k,v) self.vars[k]=v end
  function p:SetNW2Float(k,v) self.vars[k]=v end
  function p:IsWepRaised() return self.raised end
  function p:GetActiveWeapon() return nil end
  function p:LookupBone(name) if not self.unsupported then return 0 end end
  return p
 end
 PLUGIN=bodyPlugin
`+source(['ixhl2rp/plugins/bodycams/sv_bodycams.lua'])+`
 ix.bodycams.Refresh=function() end
 PLUGIN={}
`+source(['ixhl2rp/plugins/action_animations/sh_plugin.lua','ixhl2rp/plugins/action_animations/sv_actions.lua'])+`
 local B,A=ix.bodycams,ix.ActionAnimations
 function camera(p) local i=ix.Item:Instance('helmet_bodycam');p:AddItem(i);i.inventory_id=1;return i end
 function attached()
  local p=wearer();local h=giveHelmet(p);h.inventory_id=2;local c=camera(p)
  assert(B.Change(p,h,'attach',c));tick();return p,h
 end
 function combine(p,c,h)
  ix.Item:PerformInventoryCombineAction(p,c,h,c.combine.attachBodycam.index,{},0)
 end
`;
function test(name,code){run(name,base+code)}
test('Actual native item registration/combine attaches exactly the dragged camera once',`
 local p=wearer();local h=giveHelmet(p);h.inventory_id=2
 local first,chosen=camera(p),camera(p);eq(chosen.combine_id[1],'attachBodycam')
 combine(p,chosen,h);eq(chosen.removed,true);eq(first.removed,nil);eq(B.Attached(h),true);eq(B.Enabled(h),false)
 tick();combine(p,chosen,h);eq(first.removed,nil);eq(table.Count(ix.Item.instances),2)
 eq(chosen.player,nil);eq(h.player,nil)
`);
test('Native drag combine rejects foreign camera/helmet, world item, incompatible or already occupied mount',`
 for _,mode in ipairs({'cameraOwner','helmetOwner','world','incompatible','occupied','dead'}) do
  local p,other=wearer(),wearer();local h=giveHelmet(mode=='helmetOwner' and other or p,mode=='incompatible' and 'baseball_cap' or nil);h.inventory_id=2
  local c=camera(mode=='cameraOwner' and other or p)
  if mode=='world' then c.entity={valid=true} elseif mode=='occupied' then h:SetData('helmetCamera',true) elseif mode=='dead' then p.dead=true end
  combine(p,c,h);eq(c.removed,nil)
  if mode~='occupied' then eq(B.Attached(h),false) end
 end
`);
test('Failed removal keeps both items; specific camera and helmet action routes remain compatible',`
 local p=wearer();local h=giveHelmet(p);h.inventory_id=2;local c=camera(p);c.failRemove=true
 combine(p,c,h);eq(B.Attached(h),false);eq(c.removed,nil)
 c.failRemove=false;tick();c.player=p;c.functions.attach.OnRun(c);eq(c.removed,true);eq(B.Attached(h),true)
 tick();h.player=p;h.functions.bodycamOn.OnRun(h);eq(B.Enabled(h),true);eq(A.Select(p),'bodycam')
 tick();h.functions.bodycamOff.OnRun(h);eq(B.Enabled(h),false);eq(p.ixActionBodycam.enabled,false)
`);
test('Camera transitions dispatch one reach, repeated ON no-ops do not restart and toggle restarts after real OFF',`
 local p,h=attached();assert(B.Change(p,h,'on'));eq(A.Select(p),'bodycam');eq(p.vars.ixContextAction,'bodycam')
 local first=p.ixActionBodycam;local started=p.vars.ixContextActionStarted
 tick();assert(B.Change(p,h,'on'));eq(p.ixActionBodycam,first);eq(p.vars.ixContextActionStarted,started)
 tick();assert(B.Change(p,h,'toggle'));eq(B.Enabled(h),false);assert(p.ixActionBodycam~=first);assert(p.vars.ixContextActionStarted>started)
 clock=clock+2;allPlayers={p};timers.ixContextActionSessions();eq(p.ixActionBodycam,nil);eq(p.vars.ixContextAction,'')
`);
test('Camera still switches but no reach on unsupported rig, unwearing, busy actions or raised weapon',`
 for _,mode in ipairs({'rig','unworn','raised','pose','bed','medical','water','radio'}) do
  local p,h=attached()
  if mode=='rig' then p.unsupported=true elseif mode=='unworn' then p.head=nil;h.inventory_type='main'
  elseif mode=='raised' then p.raised=true elseif mode=='pose' then p.vars.ixPoseStudioPlaying=true
  elseif mode=='bed' then p.netvars.bedRestAngle=Angle()
  elseif mode=='medical' then ix.Medicine={ValidSession=function() return true end};p.ixMedicalSession={emoteStarted=true,character=p.character,target=p}
  elseif mode=='water' then ix.water={Source=function() return 'sink' end,Near=function() return true end,actions={[p]={character=p.character,entity={valid=true},anchor=Vector(),source='sink',started=clock,finish=clock+2,kind='drink'}}}
  elseif mode=='radio' then p.ixActionRadio={character=p.character,finish=clock+3} end
  assert(B.Change(p,h,'on'));eq(B.Enabled(h),true);eq(p.ixActionBodycam,nil)
 end
`);
test('Accepted higher-priority action cancels reach permanently; unequip, death, swap and unload clean up',`
 local p,h=attached();assert(B.Change(p,h,'on'));allPlayers={p}
 p.ixActionRadio={character=p.character,finish=clock+.2};timers.ixContextActionSessions();eq(p.ixActionBodycam,nil);eq(p.vars.ixContextAction,'radio')
 clock=clock+.25;timers.ixContextActionSessions();eq(A.Select(p),'')
 tick();assert(B.Change(p,h,'off'));p.head=nil;timers.ixContextActionSessions();eq(p.ixActionBodycam,nil)
 p.head=h.id;tick();assert(B.Change(p,h,'on'));p.character={};timers.ixContextActionSessions();eq(p.ixActionBodycam,nil)
 tick();assert(B.Change(p,h,'off'));hook.Run('PlayerDeath',p);eq(p.ixActionBodycam,nil);eq(p.vars.ixContextAction,'')
 tick();assert(B.Change(p,h,'on'));A.Unload();eq(p.ixActionBodycam,nil);eq(p.vars.ixContextAction,'');eq(listeners['BodycamStateChanged:ixActionBodycamSwitch'],nil)
`);
finish();
