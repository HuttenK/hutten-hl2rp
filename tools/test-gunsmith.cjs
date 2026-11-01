module.exports = function(suite) {
 suite('Native ARC9 UI is blocked before drawing without touching preview carriers',
 ['ixhl2rp/plugins/arccw_item_atts/sh_nativeblock.lua'], `
 local w={valid=true,ARC9=true,custom=true,CustomizeDelta=1,IsWeapon=function() return true end}
 function w:GetCustomize() return self.custom end
 function w:SetCustomize(v) self.custom=v end
 function w:CreateCustomizeHUD() error('native HUD opened') end
 function w:DrawCustomizeHUD() error('native HUD drawn') end
 w.CustomizeHUD={valid=true,SetVisible=function(self,v) self.visible=v end}
 function w:RemoveCustomizeHUD() self.removed=true; self.CustomizeHUD.valid=false end
 PLUGIN:PreDrawViewModel(nil,nil,w)
 eq(w.custom,false); eq(w.CustomizeDelta,0); eq(w.removed,true); eq(w.CustomizeHUD.visible,false)
 w:ToggleCustomize(true); w:CreateCustomizeHUD(); w:DrawCustomizeHUD(); eq(w.custom,false)
 w.custom=true; w:DrawCustomizeHUD(); eq(w.custom,false)
 local preview={valid=true,ARC9=true,custom=true,IsWeapon=function() return false end}
 PLUGIN:BlockNativeCustomization(preview); eq(preview.custom,true); eq(preview.ToggleCustomize,nil)
 `,'CLIENT=true; SERVER=false');

 const files=['ixhl2rp/plugins/arccw_item_atts/sv_plugin.lua'];
 suite('Workbench point projection uses panel dimensions and rejects points behind the camera',
 ['ixhl2rp/plugins/arccw_item_atts/cl_preview.lua'],`
  local eye=vec(0,0,0)
  local angle={Forward=function() return vec(1,0,0) end,Right=function() return vec(0,-1,0) end,Up=function() return vec(0,0,1) end}
  local x,y=PLUGIN:ProjectPreviewPoint(vec(10,0,0),eye,angle,200,100,90)
  eq(x,100); eq(y,50)
  x,y=PLUGIN:ProjectPreviewPoint(vec(10,-5,2),eye,angle,200,100,90)
  assert(math.abs(x-150)<.001); assert(math.abs(y-30)<.001)
  x,y=PLUGIN:ProjectPreviewPoint(vec(10,-5,2),eye,angle,400,200,90)
  assert(math.abs(x-300)<.001); assert(math.abs(y-60)<.001)
  eq(PLUGIN:ProjectPreviewPoint(vec(-10,0,0),eye,angle,400,200,90),nil)
 `,`Color=function() return {} end; vgui={Register=function() end}
 local mt={}; mt.__index=mt
 function vec(x,y,z) return setmetatable({x=x,y=y,z=z},mt) end
 mt.__sub=function(a,b) return vec(a.x-b.x,a.y-b.y,a.z-b.z) end
 function mt:Dot(b) return self.x*b.x+self.y*b.y+self.z*b.z end
 `);
 const setup=`
 PLUGIN.range=200; PLUGIN.cost=5; PLUGIN.pageSize=24
 local delayed={}
 timer.Simple=function(_,fn) delayed[#delayed+1]=fn end
 function flush() local q=delayed; delayed={} for _,fn in ipairs(q) do fn() end end
 local flags={}
 GetConVar=function(key) return {GetBool=function() return flags[key] or false end} end
 function config(key,value) flags[key]=value end
 concommand={commands={},GetTable=function() return concommand.commands end,Add=function(k,v) concommand.commands[k]=v end}
 ErrorNoHalt=function() end
 util.TraceLine=function() return {Hit=wall or false,Entity=nil} end
 -- Stable serialization is sufficient for fixed-point comparison in this fixture.
 util.TableToJSON=function(t)
  local function encode(v) if type(v)~='table' then return tostring(v) end local s='' for _,k in ipairs({'Installed','ToggleNum','SubAttachments'}) do if v[k]~=nil then s=s..k..encode(v[k]) end end for i,x in ipairs(v) do s=s..i..encode(x) end return s end
  return encode(t)
 end
 local char={id=1,GetID=function(self) return self.id end}
 local resin={uniqueID='resin',count=12,GetData=function(self) return self.count end,SetData=function(self,_,v) self.count=v end,Remove=function(self,consume) assert(consume); self.count=0 end}
 local pos={DistToSqr=function() return distance or 0 end}
 p={valid=true,alive=true,restricted=false,items={},GetCharacter=function() return char end,Alive=function(self) return self.alive end,
 IsRestricted=function(self) return self.restricted end,GetPos=function() return pos end,EyePos=function() return pos end,
 GetInventory=function() return {GetItems=function() return {resin} end} end,GetItems=function(self) return self.items end,IsAdmin=function() return false end,
 GetActiveWeapon=function(self) return self.weapon end,GetWeapon=function(self) return self.weapon end}
 bench={valid=true,GetClass=function() return 'ix_gunsmith' end,NearestPoint=function() return pos end,WorldSpaceCenter=function() return pos end,EntIndex=function() return 4 end}
 item={isWeapon=true,class='arc9_test',equip=true,GetData=function(self) return self.equip end}
 local defs={old={Category='barrel',PrintName='Old barrel'},new={Category='barrel',PrintName='New barrel'},child={Category='optic',PrintName='Child'},unknowncaliber={Category='barrel'},bad={Category='barrel'},admin={AdminOnly=true}}
 ARC9={GetAttTable=function(id) return defs[id] end,GetAttsForCats=function() return {'new','bad','admin','old'} end}
 w={valid=true,ARC9=true,ixItem=item,ixInventoryReady=true,clip1=7,clip2=0,modified=0,sent=0,Attachments={{Installed='old',Address=1,PrintName='Barrel',Category='barrel'}}}
 function w:GetOwner() return p end
 function w:EntIndex() return 7 end
 function w:GetClass() return 'arc9_test' end
 function w:GetValue(key) if key=='Ammo' then return self.Attachments[1].Installed=='unknowncaliber' and 'unsupported' or 'pistol' elseif key=='ClipSize' then return 17 elseif key=='UBGL' then return false end end
 function w:GetProcessedValue(key) return self:GetValue(key) end
 function w:GetCapacity(second) if second then return 0 end return self.Attachments[1].Installed=='new' and 10 or 17 end
 function w:Clip1() return self.clip1 end
 function w:Clip2() return self.clip2 end
 function w:SetClip1(v) self.clip1=v end
 function w:SetClip2(v) self.clip2=v end
 function w:SetLoadedRounds(v) end
 function w:LocateSlotFromAddress(addr) for _,s in ipairs(self:GetSubSlotList()) do if s.Address==addr then return s end end end
 function w:GetSubSlotList() local r={} local function add(slots) for _,s in ipairs(slots or {}) do r[#r+1]=s; add(s.SubAttachments) end end add(self.Attachments); return r end
 function w:CanAttach(addr,att) return att~='bad' and defs[att]~=nil end
 function w:CanDetach(addr) return not self:LocateSlotFromAddress(addr).Integral end
 function w:BuildSubAttachments(tree)
  self.Attachments=table.Copy(tree)
  local i=0
  local function addresses(slots) for _,s in ipairs(slots or {}) do i=i+1;s.Address=i; s.Category='barrel'; s.PrintName='Barrel'; addresses(s.SubAttachments) end end
  addresses(self.Attachments)
 end
 function w:DoInvalidateCache() end
 function w:PruneAttachments() if self.reject then self.Attachments[1].Installed=nil end end
 function w:FillIntegralSlots() end
 function w:SendWeapon() self.sent=self.sent+1 end
 function w:PostModify() self.modified=self.modified+1 end
 function w:ToggleCustomize(v) self.customize=v end
 p.items={item}; p.weapon=w
 local saves=0; local refunds=0
 ix.arc9Inventory={AttachmentTree=function(slots)
  local function tree(t) local r={} for i,s in ipairs(t or {}) do r[i]={Installed=s.Installed,ToggleNum=s.ToggleNum,SubAttachments=tree(s.SubAttachments)} end return r end
  return tree(slots)
 end,Save=function() saves=saves+1 end,AmmoItem=function(ammo) if ammo=='pistol' then return 'ammo_pistol' end end,
 ReturnAmmo=function(_,ammo,count) if failRefund then return false end refunds=refunds+count; return true end}
 function state() return resin.count,saves,refunds end
 function resetResin(value) resin.count=value end
 function characterID(value) char.id=value end
 Entity=function(id) return id==7 and w or {} end
 function p:HasWeapon() return true end
 function p:Notify() end
 function request(action,revision,address,value)
  local ints={1,revision or 0,action,7,address or 1,1}; local i=0
  net.ReadUInt=function() i=i+1; return ints[i] end
  net.ReadString=function() return value or '' end
  net.handlers.ixGunsmithRequest(200,p)
 end
 `;
 suite('Gunsmith lists identical equipped items separately and validates slot selection before materializing a weapon',files,`
  item.id=11;function item:GetName() return 'First AK' end
  local second={id=22,isWeapon=true,class=item.class,equip=true,GetData=item.GetData,GetName=function() return 'Second AK' end}
  p.items={item,second};local equipped={item,second};local activates=0
  ix.arc9Inventory.IsClass=function() return true end
  ix.WeaponSlots={count=3,Item=function(_,slot) return equipped[slot] end,
   Accepts=function(_,slot) return slot~=3 end,
   Live=function(_,candidate) if w.ixItem==candidate then return w end end,
   Activate=function(_,candidate) activates=activates+1;w.ixItem=candidate;return w end}
  PLUGIN.Send=function(self,client,data) latest=data end
  PLUGIN:Open(p,bench);eq(#latest.weapons,2);eq(latest.weapons[1].item,11);eq(latest.weapons[2].item,22)
  eq(latest.weapons[2].id,0);eq(latest.item,11)
  equipped[3]={id=33,class=item.class};PLUGIN:Snapshot(p,{bench=bench,token=latest.token,revision=0},w);eq(#latest.weapons,2)
  request(0,0,0,'slot:2:999');eq(activates,0)
  clock=clock+1;request(0,0,0,'slot:2:22');eq(activates,1);eq(latest.item,22);eq(w.ixItem,second)
  p.restricted=true;clock=clock+1;request(0,1,0,'slot:1:11');eq(activates,1)
 `,setup);
 suite('Gunsmith signatures ignore ARC9 defaults and rail expansion includes empty nested sockets',files,`
  eq(PLUGIN:TreeSignature({{Installed='old',SubAttachments={{}}}}),
     PLUGIN:TreeSignature({{ToggleNum=1,Installed='old',SubAttachments={{Installed=false,ToggleNum=1}}}}))
  assert(PLUGIN:TreeSignature({{Installed='old'}})~=PLUGIN:TreeSignature({{Installed='new'}}))
  local original=ARC9.GetAttTable
  ARC9.GetAttTable=function(id)
   if id=='rail' then return {Attachments={{},{},{}}} end
   if id=='adapter' then return {Attachments={{},{}}} end
   return original(id)
  end
  local tree=PLUGIN:ExpandTree({{Installed='rail',SubAttachments={{Installed='adapter'}}}})
  eq(#tree[1].SubAttachments,3); eq(#tree[1].SubAttachments[1].SubAttachments,2)
  eq(tree[1].SubAttachments[2].Installed,nil)
  eq(tree[1].SubAttachments[1].Installed,'adapter')
 `,setup);
 suite('Gunsmith sessions reject walls, range, dead/restricted users, wrong items, tokens, character changes and stale revisions',files,`
  PLUGIN.Send=function(self,client,data) latest=data end
  PLUGIN:Open(p,bench); eq(latest.token,1); eq(latest.weapon,7)
  assert(PLUGIN:Validate(p,1,0,w)); eq(PLUGIN:Validate(p,2,0,w),nil); eq(PLUGIN:Validate(p,1,1,w),nil)
  w.ixItem={}; eq(PLUGIN:Validate(p,1,0,w),nil); w.ixItem=item
  item.equip=false; eq(PLUGIN:Validate(p,1,0,w),nil); item.equip=true
  p.items={}; eq(PLUGIN:Validate(p,1,0,w),nil); p.items={item}
  p.restricted=true; eq(PLUGIN:Nearby(p,bench),false); p.restricted=false
  p.alive=false; eq(PLUGIN:Nearby(p,bench),false); p.alive=true
  wall=true; eq(PLUGIN:Nearby(p,bench),false); wall=false
  distance=40001; eq(PLUGIN:Validate(p,1,0,w),nil); assert(latest.closed); distance=0
  PLUGIN:Open(p,bench); characterID(2); eq(PLUGIN:Validate(p,2,0,w),nil); assert(latest.closed)
 `,setup);
 suite('Gunsmith transactions charge once, preserve item persistence, return old magazines and reject incompatible or failed changes',files,`
  local ok=PLUGIN:Change(p,w,1,'bad'); eq(ok,false); eq(state(),12); eq(w.modified,0)
  ok=PLUGIN:Change(p,w,1,'old'); eq(ok,false); eq(state(),12)
  ok=PLUGIN:Change(p,w,1,'new'); eq(ok,true); eq(state(),7); eq(w.Attachments[1].Installed,'new'); eq(w.clip1,0)
  local balance,saves,refunds=state(); eq(refunds,7); eq(saves,1); eq(w.modified,1)
  ok=PLUGIN:Change(p,w,1,'new'); eq(ok,false); eq(state(),7)
  w.reject=true; ok=PLUGIN:Change(p,w,1,'old'); eq(ok,false); eq(state(),7); eq(w.Attachments[1].Installed,'new')
  w.reject=false; resetResin(4); ok=PLUGIN:Change(p,w,1,'old'); eq(ok,false); eq(state(),4)
  resetResin(7); config('arc9_atts_anarchy',true); ok=PLUGIN:Change(p,w,1,'old'); eq(ok,false); eq(state(),7)
  config('arc9_atts_anarchy',false); config('arc9_atts_nocustomize',true); eq(PLUGIN:Change(p,w,1,'old'),false)
  config('arc9_atts_nocustomize',false); eq(PLUGIN:Change(p,w,1,'admin'),false)
  eq(PLUGIN.stockClient,nil); eq(PLUGIN:ARC9_PlayerGetAtts(p),nil)
 `,setup);
 suite('Gunsmith failures cannot convert rounds, debit resin, grant ARC9 stock or leave service scope active',files,`
  failRefund=true; eq(PLUGIN:Change(p,w,1,'new'),false); eq(state(),12); eq(w.clip1,7); eq(w.Attachments[1].Installed,'old'); eq(w.modified,0)
  failRefund=false
  ix.arc9Inventory.AmmoItem=function() return nil end
  eq(PLUGIN:Change(p,w,1,'unknowncaliber'),false); eq(w.clip1,7); eq(w.Attachments[1].Installed,'old'); eq(state(),12)
  local ok=PLUGIN:Stock(p,function() eq(PLUGIN:ARC9_PlayerGetAtts(p),999); eq(PLUGIN:ARC9_PlayerGiveAtt(p),false); eq(PLUGIN:ARC9_PlayerTakeAtt(p),true); error('broken attachment') end)
  eq(ok,false); eq(PLUGIN.stockClient,nil)
 `,setup);
 suite('Gunsmith network revalidates paid operations, rejects replay, pages parts and restores authoritative native state',files,`
  PLUGIN.Send=function(self,client,data) latest=data end
  PLUGIN:Open(p,bench); request(1,0,1,'New'); eq(latest.total,1); eq(latest.parts[1],'new')
  clock=clock+1; request(2,0,1,'new'); eq(latest.message,'installed'); eq(latest.revision,1); eq(state(),7)
  clock=clock+1; request(2,0,1,'old'); eq(state(),7); eq(w.Attachments[1].Installed,'new')
  clock=clock+1; request(2,1,1,'bad'); eq(latest.message,'rejected'); eq(latest.revision,2); eq(state(),7)
  PLUGIN:InstallGates(); local sent=w.sent
  net.ReadEntity=function() return w end; net.handlers.arc9_networkweapon(32,p); eq(w.sent,sent+1)
  local receiver=false; w.ReceiveWeapon=function() receiver=true end
  clock=clock+1; net.handlers.arc9_networkweapon(32,p); eq(receiver,false)
  local owner=w.GetOwner; w.GetOwner=function() return {} end; sent=w.sent; net.handlers.arc9_networkweapon(32,p); eq(w.sent,sent); w.GetOwner=owner
  w.customize=true; net.handlers.arc9_togglecustomize(1,p); eq(w.customize,false)
  clock=clock+601; PLUGIN:Think(); assert(latest.closed); eq(PLUGIN:IsUsingBench(p),false)
 `,setup);
 suite('Gunsmith stale slot trees cannot target a different component; read-only refresh recovers revision drift',files,`
  PLUGIN.Send=function(self,client,data) latest=data end
  PLUGIN:Open(p,bench)
  w.Attachments[1].Installed='child'
  request(2,0,1,'new'); eq(latest.message,'slot'); eq(latest.revision,1); eq(state(),12)
  clock=clock+1; request(0,0); eq(latest.revision,2); eq(latest.slots[1].installed,'child')
 `,setup);
 suite('First bench visit refreshes detached address caches before preview and first paid installation',files,`
  local stale=table.Copy(w.Attachments)
  w.cachedSlots=stale; w.addresses=stale
  local originalBuild=w.BuildSubAttachments
  local originalList=w.GetSubSlotList
  function w:GetSubSlotList() return self.cachedSlots or originalList(self) end
  function w:DoInvalidateCache() self.cachedSlots=nil end
  function w:LocateSlotFromAddress(addr) return self.addresses[addr] end
  function w:BuildSubAttachments(tree)
   originalBuild(self,tree)
   self.addresses=self:GetSubSlotList()
   self.cachedSlots=self.addresses
  end
  PLUGIN.Send=function(self,client,data) latest=data end
  PLUGIN:Open(p,bench)
  eq(w:LocateSlotFromAddress(1),w.Attachments[1])
  request(3,0,1,'new'); assert(latest.preview); eq(latest.tree[1].Installed,'new')
  eq(w.Attachments[1].Installed,'old'); eq(state(),12)
  clock=clock+1; request(2,0,1,'new')
  eq(latest.message,'installed'); eq(w.Attachments[1].Installed,'new'); eq(state(),7)
 `,setup);
 suite('Gunsmith preview is free, restores attachments and ammo, and does not save or replicate a trial',files,`
  PLUGIN.Send=function(self,client,data) latest=data end
  PLUGIN:Open(p,bench)
  request(3,0,1,'new')
  assert(latest.preview); eq(latest.tree[1].Installed,'new')
  eq(w.Attachments[1].Installed,'old'); eq(w:Clip1(),7)
  local resin,saved,refunds=state(); eq(resin,12); eq(saved,0); eq(refunds,0)
  eq(w.sent,0); eq(w.modified,0)
  clock=clock+1; request(3,0,1,'bad'); eq(latest.tree,nil)
  eq(w.Attachments[1].Installed,'old'); eq(w:Clip1(),7)
  resetResin(0); clock=clock+1; request(3,0,1,'new'); assert(latest.tree)
  eq(state(),0)
 `,setup);
 suite('Gunsmith renderer owns independent models, tables and data accessors; cleanup also covers failed assembly',
 ['ixhl2rp/plugins/arccw_item_atts/cl_preview.lua'],`
  local tree={{Installed='old'}}
  local ghost=PLUGIN:CreatePreviewWeapon(source,tree)
  assert(IsValid(ghost)); eq(ghost:GetLoadedRounds(),7); eq(ghost:GetCustomize(),true)
  ghost:SetLoadedRounds(0); ghost.Attachments[1].Installed='trial'
  eq(source:Clip1(),7); eq(tree[1].Installed,'old'); eq(def.Attachments[1].Installed,'default')
  eq(ghost.dt.LoadedRounds,0); eq(#ARC9.CSModelPile,1)
  PLUGIN:RemovePreviewWeapon(ghost); eq(#ARC9.CSModelPile,0); eq(ghost.valid,false); eq(lastModel.valid,false)
  failBuild=true; eq(PLUGIN:CreatePreviewWeapon(source,tree),nil)
  eq(#ARC9.CSModelPile,0); eq(lastCarrier.valid,false); eq(lastModel.valid,false)
 `,`
  CLIENT=true; SERVER=false
  function Color(...) return {} end
  function LocalPlayer() return {} end
  vgui={Register=function() end}; ErrorNoHalt=function() end
  ARC9={CSModelPile={}}
  function SafeRemoveEntity(e) if IsValid(e) then e:Remove() end end
  def={WorldModel='test.mdl',Attachments={{Installed='default'}},ModelVersion=0}
  function def:DoInvalidateCache() self.cache={} end
  function def:BuildSubAttachments(tree) self.Attachments=tree end
  function def:SetupModel()
   local m={valid=true,Remove=function(s) s.valid=false end}; lastModel=m
   self.CModel={m}; table.insert(ARC9.CSModelPile,{Weapon=self,Model=m})
   if failBuild then error('bad asset') end
  end
  weapons={Get=function() return def end,GetStored=function() return {SetupDataTables=function(s)
   s:NetworkVar('Int','LoadedRounds'); s:NetworkVar('Bool','Customize')
  end} end}
  function ClientsideModel()
   local e={valid=true,GetTable=function(s) return s end,SetNoDraw=function() end,Remove=function(s) s.valid=false end}
   lastCarrier=e; return e
  end
  source={GetClass=function() return 'arc9_test' end,Clip1=function() return 7 end,Clip2=function() return 0 end}
  table.Merge=function(target,data) for k,v in pairs(data) do target[k]=v end end
 `);
 suite('Gunsmith client rejects stale part lists, retains selection, disables double submission and fits supported windows',
 ['ixhl2rp/plugins/arccw_item_atts/cl_plugin.lua'],`
  local panel=newPanel(); setmetatable(panel,{__index=function(_,k) return registered[k] or base[k] end})
  panel:Init(); eq(panel.width,1280); eq(panel.height,800); panel:PerformLayout(1240,760)
  assert(panel.left.width+panel.detail.width<1240-200)
  panel:Receive({token=1,revision=0,weapon=7,bench=4,resin=12,cost=5,weapons={{id=7,name='Glock'}},slots={{address=1,name='Barrel',installed='old',children=0,removable=true}}})
  eq(panel.slot.address,1); assert(panel.pending)
  panel:Think(); assert(panel.busy); eq(sent,1)
  panel:Receive({parts={'new'},token=1,revision=0,weapon=7,address=99,search='',page=1,total=1}); eq(#panel.parts.children,0)
  panel:Receive({parts={'new'},token=1,revision=0,weapon=7,address=1,search='',page=1,total=1}); eq(#panel.parts.children,2)
  panel:Describe('new'); clock=clock+1; panel:Think(); eq(panel.apply.enabled,false)
  panel:Receive({preview=true,token=1,revision=0,weapon=7,address=1,value='old',tree={}})
  assert(panel.busy); eq(panel.preview.selection.tree,nil)
  panel:Receive({preview=true,token=1,revision=0,weapon=7,address=1,value='new',tree={}})
  panel:Think(); eq(panel.apply.enabled,true)
  panel:Request(2,7,1,'new'); panel:Request(2,7,1,''); eq(panel.pending.value,'new')
  clock=clock+1; panel:Think(); eq(panel.apply.enabled,false); eq(sent,3)
  panel:Receive({token=1,revision=1,weapon=7,bench=4,resin=7,cost=5,message='installed',weapons={{id=7,name='Glock'}},slots={{address=1,name='Barrel',installed='new',children=0,removable=true}}})
  eq(panel.chosen,nil); eq(panel.slot.installed,'new'); eq(panel.data.revision,1)
  panel:PerformLayout(760,560); assert(panel.left.width>=170); assert(panel.detail.width>=250)
  -- Switching parts while a preview is in flight must not leave transport stuck.
  panel.pending=nil; panel.busy=clock; panel.inflight={action=3,weapon=7,address=1,value='old'}
  panel.chosen='new'; panel:Request(3,7,1,'new')
  panel:Receive({preview=true,token=1,revision=1,weapon=7,address=1,value='old',tree={}})
  eq(panel.busy,nil); eq(panel.pending.value,'new'); eq(panel.chosen,'new')
  clock=clock+1; panel:Think(); assert(panel.busy)
  panel:Receive({preview=true,token=1,revision=1,weapon=7,address=1,value='new',tree={}})
  eq(panel.busy,nil)
  local created=0; vgui.Create=function() created=created+1; return panel end
  net.ReadUInt=function() return 100 end; net.ReadData=function() return '' end
  util.Decompress=function() return '{}' end
  util.JSONToTable=function() return {token=1,revision=2,weapons={},slots={}} end
  PLUGIN.window=nil; net.handlers.ixGunsmithState(); eq(created,0)
  local removed=false; panel.Remove=function() removed=true end; PLUGIN.window=panel
  util.JSONToTable=function() return {closed=true,token=99} end
  net.handlers.ixGunsmithState(); eq(removed,false)
  util.JSONToTable=function() return {closed=true,token=1} end
  net.handlers.ixGunsmithState(); eq(removed,true)
 `,`
 SERVER=false; CLIENT=true; PLUGIN.pageSize=24; ix.Locale={lang='en'}
 TOP=1; LEFT=2; RIGHT=3; FILL=4; BOTTOM=5; KEY_ESCAPE=27
 TEXT_ALIGN_LEFT=0;TEXT_ALIGN_CENTER=1;TEXT_ALIGN_TOP=0
 function Color(...) return {} end
 function ScrH() return 800 end; function ScrW() return 1280 end
 input={IsKeyDown=function() return false end}
 surface={CreateFont=function() end,PlaySound=function() end}
 ARC9={GetPhrase=function(self,v) assert(self==ARC9); return nil end,
 GetPhraseForAtt=function(self,id,field) assert(self==ARC9); if field=='PrintName' then return id end end,
 GetAttTable=function(id) return {PrintName=id,Description='Details'} end}
 base={}
 for _,name in ipairs({'SetTitle','ShowCloseButton','SetDraggable','DockPadding','SetDeleteOnClose','MakePopup','SetAlpha','AlphaTo','Dock','DockMargin','Center','SetTooltip','SetFont','SetTextColor','SetWrap','SetAutoStretchVertical','SetContentAlignment','SetPlaceholderText','SetUpdateOnType','SetCursorColor','SetHighlightColor'}) do base[name]=function() end end
 function base:SetText(v) assert(v~=nil); self.text=v end
 function base:SetValue(v) self.value=v end
 function base:GetValue() return self.value or '' end
 function base:SetEnabled(v) self.enabled=v end
 function base:IsEnabled() return self.enabled end
 function base:SetSize(w,h) self.width=w; self.height=h end
 function base:SetTall(h) self.height=h end
 function base:SetWide(w) self.width=w end
 function base:Select(address,id,tree) self.selection={address=address,id=id,tree=tree} end
 function base:SetWeapon(data) self.previewData=data end
 function base:Clear() self.children={} end
 function base:AddChoice(label,id,selected) assert(label~=nil); if selected and self.OnSelect then self:OnSelect(1,label,id) end end
 function newPanel() return setmetatable({valid=true,children={},enabled=true},{__index=base}) end
 function base:Add(class) local p=newPanel(); self.children[#self.children+1]=p; return p end
 vgui={Register=function(_,p) registered=p end}
 sent=0
 net.Start=function() end; net.WriteUInt=function() end; net.WriteString=function() end; net.SendToServer=function() sent=sent+1 end
 `);
};
