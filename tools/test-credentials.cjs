module.exports=suite=>{
const fs=require('fs'),path=require('path');
const base='ixhl2rp/plugins/citizenids/items/base/cidcard.lua';
const setup=`
function implements() end
ix.transmit={owner=1}; ix.meta.ItemEquipable={Init=function(item) item.functions={equip={},unequip={}} end}
function template(baseName)
 local item=setmetatable({data={},functions={},combine={}},{__index=ix.meta[baseName or "ItemIdentityDocument"]})
 function item:AddData() end
 function item:GetData(k,d) if self.data[k]==nil then return d end return self.data[k] end
 function item:SetData(k,v) self.data[k]=v end
 function item:GetID() return 501 end
 function item:GetEntity() return nil end
 return item
end
`;
for(const [dept,start] of [['security',15],['military',11],['science',7]]) for(let level=1;level<=4;level++){
 const p=`ixhl2rp/plugins/citizenids/items/keycard/keycard_${dept}_${level}.lua`;
 const source=fs.readFileSync(path.join(__dirname,'..',p),'utf8');
 suite(`SCP ${dept} ${level}: template registration, skin, actions and hierarchical grants`,['ixhl2rp/plugins/citizenids/items/base/keycard.lua'],`
 ITEM=template("ItemKeycard"); ITEM:Init()
 ${source}
 ITEM:OnRegistered()
 eq(ITEM.skin,${start+level-1}); eq(ITEM.clearanceLevel,${level}); eq(ITEM.department,'${dept}')
 assert(ITEM.functions.equip); assert(ITEM.functions.unequip); assert(ITEM.combine.fieldlinkRegister)
 eq(ITEM.functions.inspectDocument,nil); eq(ITEM.functions.showDocument,nil)
 for i=1,${level} do eq(ITEM.access['SCP_${dept.toUpperCase()}_'..i],true) end
 eq(ITEM.access['SCP_${dept.toUpperCase()}_${level+1}'],nil)
 `,setup);
}
suite('Universal papers have physical inspection only and no access or PDA registration',[base],`
 local doc=template(); doc:Init(); doc:OnRegistered()
 eq(doc.skin,19); eq(doc.functions.equip,nil); eq(doc.combine.fieldlinkRegister,nil)
 assert(doc.functions.inspectDocument); assert(doc.functions.showDocument)
 doc.data.access={DATAFILE_ELEVATED=true}; doc:OnInstanced(false); eq(doc.data.access,nil); eq(doc.data.datafileID,nil); eq(doc.data.cid,nil)
`,setup);
suite('PDA rejects papers and revoked cards; live equipped card controls access, not cached clearance',
 ['ixhl2rp/plugins/site_pda/sh_fieldlink.lua','ixhl2rp/plugins/site_pda/sh_identity.lua'],`
 local F=ix.Fieldlink
 local card={isKeycard=true,clearanceLevel=2,data={name='Scientist',cid='12001',number='SC001'}}
 function card:GetID() return 7 end
 function card:GetData(k,d) if self.data[k]==nil then return d end return self.data[k] end
 local device={uniqueID='pda',GetData=function() return {id='cid:SC001',clearance=4} end}
 local p={valid=true,GetCharacter=function() return {GetData=function() return 8 end} end,
 HasItemByID=function() return true,device end,GetIDCard=function() return card end}
 eq(F.Clearance(p),2)
 card.isKeycard=false; eq(F.CardIdentity(card),nil); eq(F.Clearance(p),0)
 card.isKeycard=true; card.data.revoked=true; eq(F.Clearance(p),0)
 card.data.revoked=nil; card.data.cid='000-00'; eq(F.CardIdentity(card),nil)
 card.data.cid='12001'; p.GetIDCard=function() return nil end; eq(F.Clearance(p),0)
 `);

suite('Terminal reads physical keycards only; archive access requires proximity and clearance',
 ['ixhl2rp/plugins/citizenids/sh_portrait.lua','ixhl2rp/plugins/datafileterminal/sv_hooks.lua'],`
 local paper={GetData=function() return 'private' end}
 eq(PLUGIN:CardSnapshot(paper),nil)
 local card={isKeycard=true,clearanceLevel=2,departmentLabel='Science',GetData=function(self,k,d) return k=='name' and 'Researcher' or d end}
 local snap=PLUGIN:CardSnapshot(card); eq(snap.level,2); eq(snap.name,'Researcher'); eq(snap.birthDate,nil)
 local p={valid=true,GetPos=function() return {} end,GetCharacter=function() return {ReturnDatafilePermission=function() return 0 end} end,
 GetItems=function() return {paper,card} end,GetEyeTraceNoCursor=function() return {} end}
 local sent=0; netstream.Start=function(_,name,payload) sent=sent+1; eq(name,'ixDfBrowserOpen'); eq(#payload.cards,1); eq(#payload.records,0) end
 nearby={}; PLUGIN:OpenBrowser(p); eq(sent,0)
 nearby={{valid=true,GetClass=function() return 'ix_datafile_terminal' end}}
 PLUGIN:OpenBrowser(p); eq(sent,1)
 `,`Schema={}`);

suite('Card imprint hydrates existing SQL history, handles duplicate-create races and coalesces async requests',
 ['ixhl2rp/plugins/citizenids/sh_portrait.lua','ixhl2rp/plugins/datafile/sv_hooks.lua'],`
 local card={isKeycard=true,access={DATAFILE_ELEVATED=true},data={datafileID=1,name='New name',cid='019-74',number='new-serial'}}
 function card:GetData(k,d) if self.data[k]==nil then return d end return self.data[k] end
 db[1]={datafile_id=1,character_name='Old',genericdata={bol=true,points=55},datafile={{text='KEEP HISTORY'}},access={}}
 PLUGIN.stored[1]={'Fake','','',{bol=false},{},{}} -- cache left by the failed INSERT
 PLUGIN:OnIDCardUpdated(card); eq(#queue,1)
 PLUGIN:OnIDCardUpdated(card); eq(#queue,1)
 flush(); eq(inserts,0); eq(db[1].datafile[1].text,'KEEP HISTORY'); eq(db[1].genericdata.points,55)
 eq(db[1].genericdata.credential.number,'new-serial'); eq(db[1].genericdata.credential.name,'New name')
 eq(PLUGIN.stored[1][4].bol,true); eq(PLUGIN.stored[1][5][1].text,'KEEP HISTORY'); eq(db[1].character_name,'New name')
 card.data.datafileID=2; race=true; PLUGIN:OnIDCardUpdated(card); flush()
 eq(inserts,1); eq(db[2].datafile[1].text,'RACE WINNER'); eq(PLUGIN.stored[2][5][1].text,'RACE WINNER')
 card.data.datafileID=3; PLUGIN:OnIDCardUpdated(card); flush(); eq(inserts,2); eq(db[3].character_name,'New name')
 eq(#PLUGIN.stored[3][5],0)
 PLUGIN.stored[1][5][2]={text='UNSAVED'}; PLUGIN.datafiles_save={1}; card.data.datafileID=1
 PLUGIN:OnIDCardUpdated(card); flush(); eq(PLUGIN.stored[1][5][2].text,'UNSAVED')
 eq(#db[1].datafile,1) -- issuance only writes identity, not history
 `,`
 Schema={}
 db={}; queue={}; inserts=0; race=false
 util.TableToJSON=function(v) return table.Copy(v) end
 util.JSONToTable=function(v) return type(v)=='table' and table.Copy(v) or {} end
 mysql={}
 local function query(kind)
  local q={values={}}
  function q:Select() end
  function q:Where(_,id) self.id=id end
  function q:Insert(k,v) self.values[k]=v end
  function q:Update(k,v) assert(k~='datafile','Imprinting cannot rewrite history'); self.values[k]=v end
  function q:Callback(fn) self.cb=fn end
  function q:Execute()
   queue[#queue+1]=function()
    if kind=='select' then self.cb(db[self.id] and {table.Copy(db[self.id])} or {},true)
    elseif kind=='ignore' then
     inserts=inserts+1; local id=self.values.datafile_id
     if race then db[id]={datafile_id=id,genericdata={bol=true},datafile={{text='RACE WINNER'}}}; race=false end
     db[id]=db[id] or table.Copy(self.values)
     if self.cb then self.cb(nil,true) end
    else for k,v in pairs(self.values) do db[self.id][k]=v end end
   end
  end
  return q
 end
 function mysql:Select() return query('select') end
 function mysql:InsertIgnore() return query('ignore') end
 function mysql:Insert() error('Unsafe plain INSERT') end
 function mysql:Update() return query('update') end
 function flush() while #queue>0 do local f=table.remove(queue,1); f() end end
 `);

suite('Credential portrait freezes visible model, skin and bodygroups until explicit re-registration',
 ['ixhl2rp/plugins/citizenids/sh_portrait.lua'],`
 local appearance={model='models/player/original.mdl',skin=3,groups={[0]=2,[1]=4,[2]=1}}
 local character={}; local player={valid=true}
 function character:GetPlayer() return player end
 function player:GetCharacter() return character end
 function player:GetModel() return appearance.model end
 function player:GetSkin() return appearance.skin end
 function player:GetNumBodyGroups() return 3 end
 function player:GetBodygroup(i) return appearance.groups[i] end
 local item={data={}}
 function item:GetData(k) return self.data[k] end
 function item:SetData(k,v) self.data[k]=v end
 eq(Schema:GetIdentityPortrait(item),nil)
 eq(Schema:CaptureIdentityPortrait(item,character),true)
 appearance.model='models/player/replacement.mdl'; appearance.skin=0; appearance.groups[1]=0
 local photo=Schema:GetIdentityPortrait(item)
 eq(photo.model,'models/player/original.mdl'); eq(photo.skin,3); eq(photo.bodygroups['1'],4); eq(photo.bodygroups['0'],2)
 photo.bodygroups['1']=99; eq(Schema:GetIdentityPortrait(item).bodygroups['1'],4)
 item:SetData('name','Edited text'); eq(Schema:GetIdentityPortrait(item).model,'models/player/original.mdl')
 eq(Schema:CaptureIdentityPortrait(item,character),true)
 eq(Schema:GetIdentityPortrait(item).model,appearance.model); eq(Schema:GetIdentityPortrait(item).bodygroups['1'],0)
 player.valid=false; eq(Schema:CaptureIdentityPortrait(item,character),false)
 eq(Schema:GetIdentityPortrait(item).model,appearance.model)
 `,`Schema={}`);
};
