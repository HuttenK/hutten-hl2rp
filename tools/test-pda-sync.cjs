module.exports = function(suite) {
suite('PDA sync survives joining players and partial inventories, then discovers ready contacts', [
  'helix/gamemode/game/inventory/sh_player.lua',
  'ixhl2rp/schema/meta/sh_player.lua',
  'ixhl2rp/plugins/site_pda/sh_fieldlink.lua',
  'ixhl2rp/plugins/site_pda/sh_identity.lua',
  'ixhl2rp/plugins/site_pda/sv_records.lua',
  'ixhl2rp/plugins/site_pda/sv_fieldlink.lua',
  'ixhl2rp/plugins/site_pda/sv_media.lua'
], `
 local F=ix.Fieldlink
 local holder=user(1); equip(holder,101,102)
 local joining=user(2); joining.GetCharacter=function() return nil end
 local loading=user(3)
 local partial=user(4); equip(partial,401,402); partial.inventories.cid=nil
 local online=user(5); equip(online,501,502)
 allPlayers={holder,joining,loading,partial,online}
 -- Exercise the real request -> Send -> Snapshot -> MediaSnapshot -> ID-card path.
 local function sync()
  clock=clock+1; reads={'sync',util.TableToJSON({})}
  net.handlers.ixFieldlinkRequest(100,holder)
  eq(packet.name,'ixFieldlinkSnapshot'); eq(packet.player,holder)
  return util.JSONToTable(packet.bytes)
 end
 local data=sync()
 eq(data.error,nil); eq(data.registered,true); eq(data.device,101)
 eq(#data.contacts,1); eq(data.contacts[1].device,501)
 eq(joining:GetInventory('cid'),nil); eq(loading:GetIDCard(),nil)
 eq(partial:GetIDCard(),nil); eq(F.Identity(partial),nil); eq(F.Clearance(partial),0)
 -- The same player becomes visible after their inventory finishes loading.
 equip(loading,301,302)
 data=sync(); eq(#data.contacts,2); eq(data.contacts[1].device,301)
 online.inventories=nil
 data=sync(); eq(#data.contacts,1); eq(data.contacts[1].device,301)
 -- Missing, revoked, or mismatched cards must never grant identity/clearance.
 holder.inventories.cid=nil
 data=sync(); eq(data.registered,false); eq(data.clearance,0); eq(#data.records,0)
 eq(PLUGIN:Handle(holder,'notes',{device=101,text='forbidden'}),false)
 equip(holder,101,102); ix.Item.instances[102].data.revoked=true
 data=sync(); eq(data.registered,false)
 ix.Item.instances[102].data.revoked=nil; ix.Item.instances[102].data.number='different'
 data=sync(); eq(data.registered,false)
 equip(holder,101,102)
 -- A future snapshot failure yields an explicit error and recovers next sync.
 local snapshot=PLUGIN.Snapshot
 PLUGIN.Snapshot=function() error('injected snapshot failure') end
 data=sync(); assert(isstring(data.error)); eq(data.recipient,1); eq(data.device,101)
 eq(data.registered,nil); eq(errors,1)
 PLUGIN.Snapshot=snapshot
 data=sync(); eq(data.error,nil); eq(data.registered,true)
 -- Failed readiness still cannot disclose another device's data.
 packet=nil; holder.weapon.ixFieldlinkItem=999
 clock=clock+1; reads={'sync',util.TableToJSON({})}; net.handlers.ixFieldlinkRequest(100,holder)
 eq(packet,nil)
 `, `
 ix.Item={instances={}}; ix.command={Add=function() end}; ix.type={character=1,number=2}
 game={GetMap=function() return 'test_map' end}
 file={CreateDir=function() end,Read=function() end,Write=function() end}
 local values={}
 util.TableToJSON=function(value) values[#values+1]=table.Copy(value); return tostring(#values) end
 util.JSONToTable=function(value) return values[tonumber(value)] end
 util.Compress=function(value) return value end
 errors=0; function ErrorNoHalt(message) assert(message:find('injected snapshot failure',1,true)); errors=errors+1 end
 net.Start=function(name) packet={name=name} end
 net.WriteUInt=function(value) packet.length=value end
 net.WriteData=function(value,length) eq(#value,length); packet.bytes=value end
 net.Send=function(p) packet.player=p end
 net.ReadString=function() return table.remove(reads,1) end
 function user(id)
  local c=character(1,0,0); c.id=id; c.data.fieldlinkEnabled=true
  local p=setmetatable(c.player,{__index=FindMetaTable('Player')})
  p.weapon={valid=true,ixFieldlinkCharacter=id,GetClass=function() return 'pdaremake1' end,GetPDAEquipped=function() return true end}
  p.GetActiveWeapon=function(self) return self.weapon end
  p.GetLocalVar=function(_,_,default) return default end
  return p
 end
 local function item(id,kind,data)
  local value={id=id,uniqueID=kind,data=data,GetID=function(self) return self.id end,
   GetData=function(self,key,default) if self.data[key]~=nil then return self.data[key] end return default end}
  ix.Item.instances[id]=value; return value
 end
 local function inventory(value)
  return {HasItemByID=function(_,id) return id==value.id,id==value.id and value or nil end,
   HasItem=function(_,kind) return kind==value.uniqueID,kind==value.uniqueID and value or nil end,
   GetFirstAtSlot=function() return value.id end}
 end
 function equip(p,device,cardID)
  local serial=tostring(cardID)
  local card=item(cardID,'card',{name='Contact '..serial,cid='12345',number=serial})
  card.isKeycard=true; card.clearanceLevel=3
  local pda=item(device,'pda',{fieldlinkIdentity={id='cid:'..serial,name='Contact '..serial,cid='12345'}})
  p.inventories={main=inventory(pda),cid=inventory(card)}
  p:GetCharacter().data.fieldlinkDevice=device; p.weapon.ixFieldlinkItem=device
 end
 `);
suite('PDA client displays sync failures without opening a session and rejects stale-device replies', [
 'ixhl2rp/plugins/site_pda/cl_fieldlink.lua'
], `
 local panel=setmetatable({valid=true,born=0,bootDuration=0,page='overview',
  body={GetVBar=function() return {GetScroll=function() return 0 end} end},
  BuildPage=function(self) self.built=(self.built or 0)+1 end}, {__index=PDA_PANEL})
 ix.gui.fieldlink=panel
 local function receive(data)
  incoming=data; net.handlers.ixFieldlinkSnapshot()
 end
 ix.Fieldlink.pendingAt=clock
 receive({recipient=1,device=101,error='Retrying sync'})
 eq(panel.syncError,'Retrying sync'); eq(panel.data,nil); eq(ix.Fieldlink.pendingAt,nil)
 eq(panel:IsDeviceReady(),false)
 receive({recipient=99,device=101,registered=true})
 eq(panel.data,nil)
 receive({recipient=1,device=999,error='Stale error'})
 eq(panel.syncError,'Retrying sync')
 receive({recipient=1,device=101,registered=true,character='cid:102',clearance=3})
 eq(panel.syncError,nil); eq(panel.toast,nil); eq(panel.data.device,101)
 eq(panel:IsDeviceReady(),true); eq(panel.built,1)
 `, `
 SERVER=false; CLIENT=true; ix.Fieldlink={}; ix.gui={}
 function RealTime() return clock end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 surface={CreateFont=function() end}; hook.Add=function() end
 vgui={Register=function(_,definition) PDA_PANEL=definition end}
 local c=character(1,0,0); c.data.fieldlinkDevice=101
 function LocalPlayer() return c.player end
 net.ReadUInt=function() return 4 end; net.ReadData=function() return 'data' end
 util.Decompress=function(value) return value end
 util.JSONToTable=function() return incoming end
 `);
};
