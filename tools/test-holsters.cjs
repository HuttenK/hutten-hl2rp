module.exports = function(suite) {
 const file='ixhl2rp/plugins/holsteredweapons.lua';
 const setup=`
 function Vector(x,y,z) return {x=x,y=y,z=z} end
 function Angle(p,y,r) return {p=p,y=y,r=r} end
 `;
 suite('Holster replication requires owned equipped item/SWEP pair and clears stale eligibility', [file], `
 local p={valid=true,alive=true,items={},weapons={},char={GetID=function() return 12 end}}
 function p:GetCharacter() return self.char end
 function p:Alive() return self.alive end
 function p:GetItems() return self.items end
 function p:GetWeapons() return self.weapons end
 function p:GetWeapon(class) for _,w in ipairs(self.weapons) do if w.class==class then return w end end end
 local item={isWeapon=true,class='arc9_eft_glock17',weaponCategory='sidearm',model='glock.mdl',equipped=true}
 function item:GetData() return self.equipped end
 local w={valid=true,class=item.class,ixItem=item,nw={}}
 function w:GetOwner() return p end
 function w:SetNWString(k,v) self.nw[k]=v end
 w.SetNWBool=w.SetNWString; w.SetNWInt=w.SetNWString; w.SetNWEntity=w.SetNWString
 p.items={item}; p.weapons={w}; player.GetAll=function() return {p} end
 local display=PLUGIN:CollectEquipped(p); eq(display[w].slot,'hip')
 PLUGIN:Think(); eq(w.nw.ixHolsterEquipped,true); eq(w.nw.ixHolsterCharacter,12)
 item.weaponCategory='primary'; eq(PLUGIN:CollectEquipped(p)[w].slot,'back')
 item.equipped=false; eq(next(PLUGIN:CollectEquipped(p)),nil)
 clock=clock+1; PLUGIN:Think(); eq(w.nw.ixHolsterEquipped,false)
 item.equipped=true; p.items={}; eq(next(PLUGIN:CollectEquipped(p)),nil)
 p.items={item}; w.ixItem={}; eq(next(PLUGIN:CollectEquipped(p)),nil)
 w.ixItem=item; item.pacData={}; ix.pac={list={}}
 eq(next(PLUGIN:CollectEquipped(p)),nil)
 ix.pac=nil; assert(PLUGIN:CollectEquipped(p)[w])
 item.holsterDisplay=false; eq(next(PLUGIN:CollectEquipped(p)),nil)
 item.holsterDisplay=nil; item.weaponCategory='grenade'; eq(next(PLUGIN:CollectEquipped(p)),nil)
 item.weaponCategory='sidearm'; p.alive=false; eq(next(PLUGIN:CollectEquipped(p)),nil)
 p.alive=true; p.char=nil; eq(next(PLUGIN:CollectEquipped(p)),nil)
 `, setup+'\nSERVER=true; CLIENT=false\n');
 suite('Client holster cleanup removes cached models and releases references', [file], `
 local removed=0
 local m={valid=true,Remove=function(self) removed=removed+1; self.valid=false end}
 local p={holsteredWeapons={old=m}}
 PLUGIN:ClearHolsters(p); eq(removed,1); eq(p.holsteredWeapons,nil)
 PLUGIN:ClearHolsters(p); eq(removed,1)
 local drawn=0
 local gun={valid=true,nw={ixHolsterEquipped=true,ixHolsterCharacter=12,ixHolsterModel='glock.mdl',ixHolsterSlot='hip'}}
 function gun:GetNWBool(k) return self.nw[k] end
 gun.GetNWString=gun.GetNWBool; gun.GetNWInt=gun.GetNWBool; gun.GetNWEntity=gun.GetNWBool
 function gun:GetClass() return 'test_glock' end
 local person={valid=true,character=12,weapons={gun}}
 gun.nw.ixHolsterOwner=person
 function person:GetCharacter() return {GetID=function() return self.character end} end
 function person:Alive() return true end
 function person:IsDormant() return false end
 function person:GetNoDraw() return false end
 function person:GetColor() return {a=255} end
 function person:GetNetVar() return nil end
 function person:GetPos() return {DistToSqr=function() return 0 end} end
 function person:GetActiveWeapon() return self.active end
 function person:GetWeapons() return self.weapons end
 function person:GetModelScale() return 1 end
 function person:LookupBone() return 0 end
 function person:GetBoneMatrix() return {GetTranslation=function() return 0 end,GetAngles=function()
   return {Right=function() return 1 end,Up=function() return 2 end,Forward=function() return 3 end,RotateAroundAxis=function() end}
 end} end
 function EyePos() return 0 end; function LocalPlayer() return {} end
 util.IsValidModel=function(path) return path=='glock.mdl' end
 function ClientsideModel(path)
  return {valid=true,GetModel=function() return path end,SetNoDraw=function() end,
   SetModelScale=function() end,SetPos=function() end,SetAngles=function() end,SetupBones=function() end,
   DrawModel=function() drawn=drawn+1 end,Remove=function(self) self.valid=false; removed=removed+1 end}
 end
 PLUGIN:PostPlayerDraw(person); eq(drawn,1)
 person.active=gun; PLUGIN:PostPlayerDraw(person); eq(drawn,1); eq(next(person.holsteredWeapons),nil)
 person.active=nil; PLUGIN:PostPlayerDraw(person); eq(drawn,2)
 gun.nw.ixHolsterEquipped=false; PLUGIN:PostPlayerDraw(person); eq(drawn,2); eq(next(person.holsteredWeapons),nil)
 gun.nw.ixHolsterEquipped=true; person.character=13; PLUGIN:PostPlayerDraw(person); eq(drawn,2)
 person.character=12; gun.nw.ixHolsterOwner={}; PLUGIN:PostPlayerDraw(person); eq(drawn,2)
 `,setup+'\nSERVER=false; CLIENT=true; player.GetAll=function() return {} end\n');
};
