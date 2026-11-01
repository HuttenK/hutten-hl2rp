module.exports = function(suite) {
 const files=['ixhl2rp/plugins/amputation/sv_plugin.lua'];
 const setup=`
 ix.Amputation={limbs={larm={}},cutTime=60,reattachTime=45,range=96,consentTimeout=30,
 scale=0.01,normal=1,noOffset=0,CollectBones=function() return {0} end,
 HasSkill=function(c) return c~=nil end,Get=function(c) return c and c.missing end,
 IsTool=function(item) return item.tool end}
 ix.Item={instances={}}; timers={}; delayed={}; timer.Simple=function(_,fn) delayed[#delayed+1]=fn end
 timer.Create=function(name,_,_,fn) timers[name]=fn end
 timer.Remove=function(name) timers[name]=nil end; timer.RepsLeft=function() return 1 end
 function person(id)
  local p={valid=true,char={missing='larm'},items={},id=id,alive=true,scales={[0]=1,[1]=2},positions={[0]=0,[1]=4}}
  function p:GetCharacter() return self.char end
  function p:Alive() return self.alive end
  function p:GetItems() return self.items end
  function p:GetNetVar() return false end
  function p:UniqueID() return self.id end
  function p:SetAction() end
  function p:NotifyLocalized() end
  function p:KeyDown() return false end
  function p:Name() return self.id end
  function p:GetModel() return 'same.mdl' end
  function p:GetBoneCount() return 2 end
  function p:GetManipulateBoneScale(i) return self.scales[i] end
  function p:GetManipulateBonePosition(i) return self.positions[i] end
  function p:ManipulateBoneScale(i,v) self.scales[i]=v end
  function p:ManipulateBonePosition(i,v) self.positions[i]=v end
  return p
 end
 surgeon=person('s'); patient=person('p'); surgeon.char.missing=nil
 item={id=1,limb='larm',tool=true}; ix.Item.instances[1]=item; surgeon.items={item}
 ix.Amputation.GetTarget=function() return patient end
 net.Start=function() end; net.WriteUInt=function(v) requestID=v end; net.WriteString=function() end; net.Send=function() end
 net.ReadUInt=function() return replyID or requestID end; net.ReadBool=function() return true end
 `;
 suite('Interrupted amputation operations release both participants on tool loss and character change',files,`
 local A=ix.Amputation
 A.BeginReattach(surgeon,patient,item); eq(surgeon.ixAmputationBusy,true)
 surgeon.items={}; timers.ixAmputationfixs(); eq(surgeon.ixAmputationBusy,nil); eq(patient.ixAmputationBusy,nil)
 surgeon.items={item}; A.BeginReattach(surgeon,patient,item)
 patient.char={missing='larm'}; timers.ixAmputationfixs(); eq(patient.ixAmputationBusy,nil); eq(timers.ixAmputationfixs,nil)
 `,setup);
 suite('Amputation consent expires on the server and stale replies cannot approve a new request',files,`
 local A=ix.Amputation; patient.char.missing=nil
 A.RequestCut(surgeon,patient,'larm',item); local first=requestID
 delayed[1](); A.RequestCut(surgeon,patient,'larm',item); assert(requestID~=first)
 replyID=first; net.handlers.ixAmputationConsent(0,patient); eq(surgeon.ixAmputationBusy,nil)
 replyID=requestID; surgeon.items={}; net.handlers.ixAmputationConsent(0,patient); eq(surgeon.ixAmputationBusy,nil)
 `,setup);
 suite('Amputation restoration preserves unrelated bones and clears same-model character changes',files,`
 local A=ix.Amputation
 A.Refresh(patient); eq(patient.scales[0],0.01); eq(patient.scales[1],2)
 patient.char={}; A.Refresh(patient); eq(patient.scales[0],1); eq(patient.scales[1],2); eq(patient.positions[1],4)
 `,setup);
};
