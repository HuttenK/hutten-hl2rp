module.exports = function(suite) {
 const base=`
 ix.Item={instances={}}
 local char={GetMaxStamina=function() return 100 end}
 wearer={valid=true,alive=true,items={},slot={},vars={},character=char,submerged=0}
 function wearer:GetCharacter() return self.character end
 function wearer:GetInventories() return {mask={GetSlot=function() return self.slot end}} end
 function wearer:GetItems() return self.items end
 function wearer:Alive() return self.alive end
 function wearer:GetViewEntity() return self.view or self end
 function wearer:ShouldDrawLocalPlayer() return false end
 function wearer:GetLocalVar(k,d) return self.vars[k] or d end
 function wearer:GetNWBool(k) return self.vars[k] or false end
 function wearer:WaterLevel() return self.submerged end
 function maskItem(id,name)
  local m={id=id,uniqueID=name or 'gasmask_gp7',isGasmask=true,data={}}
  function m:GetData(k) return self.data[k] end
  ix.Item.instances[id]=m; return m
 end
 function filterItem(id)
  local f={id=id,isFilter=true,equipped=true,filterQuality=100,quality=100}
  function f:IsEquipped() return self.equipped end
  function f:GetFilterQuality() return self.quality end
  ix.Item.instances[id]=f; return f
 end
 `;
 suite('Gas mask integration uses equipment and rejects unequipped, transferred, or missing linked filters',
 ['ixhl2rp/plugins/gasmask_immersion/sh_mask.lua'], `
 local M=ix.GasMask; local m=maskItem(1); local f=filterItem(2)
 wearer.items={m,f}; eq(M.Equipped(wearer),nil)
 wearer.slot={1}; eq(M.Equipped(wearer),m)
 m.data.filter=2; eq(M.Filter(wearer,m),f); eq(M.FilterFraction(wearer,m),1)
 f.equipped=false; eq(M.Filter(wearer,m),nil)
 f.equipped=true; wearer.items={m}; eq(M.Filter(wearer,m),nil)
 wearer.items={m,f}; f.quality=15; near(M.FilterFraction(wearer,m),0.15)
 eq(M.Warning(0.15),'gasmaskFilterLow'); eq(M.Warning(0),'gasmaskFilterEmpty'); eq(M.Warning(1),nil)
 ix.Item.instances[2]=nil; eq(M.FilterFraction(wearer,m),0)
 eq(M.Profile(maskItem(3,'gasmask_early')).visor,false)
 eq(M.Profile(m).visor,true); m.gasMaskVisor=false; eq(M.Profile(m).visor,false)
 `,base);
 const client=base+`
 SERVER=false; CLIENT=true
 function LocalPlayer() return wearer end
 function RealTime() return clock end
 function FrameTime() return 0.1 end
 function math.Approach(v,t,d) if v<t then return math.min(v+d,t) end return math.max(v-d,t) end
 hooks={}; hook.Add=function(event,id,fn) hooks[event]=fn end
 options={}; ix.type={bool=1,number=2}
 ix.option={Add=function(k,t,d) options[k]=d end,Get=function(k,d) if options[k]~=nil then return options[k] end return d end}
 ix.lang={AddTable=function() end}
 file={Exists=function() return not missingAssets end}
 soundCount=0; starts=0; stops=0
 surface={PlaySound=function() soundCount=soundCount+1 end}
 function CreateSound()
  return {PlayEx=function() starts=starts+1 end,Stop=function() stops=stops+1 end,
   ChangeVolume=function() end,ChangePitch=function() end}
 end
 function tick() clock=clock+0.2; ix.GasMask.Update() end
 `;
 suite('Gas mask breathing/visor follows equip, death, water, camera and character lifecycle without duplicated loops',
 ['ixhl2rp/plugins/gasmask_immersion/sh_mask.lua','ixhl2rp/plugins/gasmask_immersion/cl_mask.lua'], `
 local M=ix.GasMask; tick(); local m=maskItem(1); wearer.slot={1}; wearer.items={m}; tick()
 eq(soundCount,1); eq(starts,1); eq(M.Breathing,true); assert(M.State.alpha>0)
 tick(); eq(starts,1)
 wearer.submerged=3; tick(); eq(M.Breathing,false); eq(stops,1)
 wearer.submerged=0; tick(); eq(starts,2)
 wearer.vars.GasMaskIsOn=true; tick(); eq(M.Breathing,false); eq(M.State.visible,false)
 wearer.vars.GasMaskIsOn=false; tick(); eq(starts,3)
 wearer.view={}; tick(); eq(M.Breathing,false)
 wearer.view=nil; wearer.slot={}; tick(); eq(soundCount,2); eq(M.Breathing,false)
 wearer.slot={1}; tick(); wearer.alive=false; tick(); eq(M.State.alpha,0); eq(M.Breathing,false)
 local before=soundCount; wearer.alive=true; tick(); eq(soundCount,before)
 wearer.character=nil; tick(); eq(M.Breathing,false)
 `,client);
 suite('Missing gas mask audio fails quietly without creating sound patches',
 ['ixhl2rp/plugins/gasmask_immersion/sh_mask.lua','ixhl2rp/plugins/gasmask_immersion/cl_mask.lua'], `
 missingAssets=true; tick(); local m=maskItem(1); wearer.slot={1}; tick()
 eq(starts,0); eq(soundCount,0); eq(ix.GasMask.Breathing,false)
 `,client);
 const animation=client+`
 ix.GasMask={Profile=function(item) return {visor=item.visor~=false} end,Visible=function() return visible end}
 visible=true; models={}; currentWeapon={valid=true}; cameraDepth=0; ignored=false
 function wearer:GetActiveWeapon() return currentWeapon end
 function wearer:GetHands() return nil end
 function FrameNumber() return math.floor(clock*100) end
 function ClientsideModel(path)
  local m={valid=true,path=path}
  function m:Remove() self.valid=false end
  function m:SetNoDraw() end; function m:SetParent(p) self.parent=p end
  function m:AddEffects() end; function m:SelectWeightedSequence(act) return badSequence and -1 or act end
  function m:SequenceDuration() return 2 end
  function m:ResetSequence(seq) self.sequence=seq end; function m:SetPlaybackRate() end
  function m:SetCycle(c) self.cycle=c end
  function m:SetPos() end; function m:SetAngles() end; function m:SetupBones() end
  function m:DrawModel() if failDraw then error('draw failure') end end
  models[#models+1]=m; return m
 end
 ACT_VM_DRAW=1; ACT_VM_HOLSTER=2
 function EyePos() return {} end; function EyeAngles() return {} end
 function ScrW() return 1920 end; function ScrH() return 1080 end
 cam={Start3D=function() cameraDepth=cameraDepth+1 end,End3D=function() cameraDepth=cameraDepth-1 end,
 IgnoreZ=function(v) ignored=v end}
 function ErrorNoHalt() reported=true end
 `;
 suite('Mask hand animation waits for inventory close, synchronizes visor, and cleans up after completion or weapon changes',
 ['ixhl2rp/plugins/gasmask_immersion/cl_animation.lua'], `
 local M=ix.GasMask
 eq(M.RequestAnimation(true,{},'on.wav'),true); visible=false; M.UpdateAnimation(wearer,false); eq(#models,0)
 eq(M.AnimationVisor(true),false); visible=true; M.UpdateAnimation(wearer,true); eq(#models,2)
 clock=clock+0.1; M.UpdateAnimation(wearer,true); eq(models[1].sequence,1); eq(soundCount,1)
 clock=clock+1.4; M.UpdateAnimation(wearer,true); eq(M.AnimationVisor(true),true)
 clock=clock+1; M.UpdateAnimation(wearer,true); eq(models[1].valid,false); eq(models[2].valid,false)
 M.RequestAnimation(false,{},'off.wav'); M.UpdateAnimation(wearer,true)
 clock=clock+0.1; M.UpdateAnimation(wearer,true); eq(models[3].sequence,2); eq(M.AnimationVisor(false),true)
 clock=clock+0.6; M.UpdateAnimation(wearer,true); eq(M.AnimationVisor(false),false)
 currentWeapon={valid=true}; M.UpdateAnimation(wearer,true); eq(models[3].valid,false); eq(M.AnimationActive(),false)
 eq(M.RequestAnimation(true,{visor=false},'on.wav'),false)
 `,animation);
 suite('Mask rendering failure restores camera state and releases models; unavailable clips fail safely',
 ['ixhl2rp/plugins/gasmask_immersion/cl_animation.lua'], `
 local M=ix.GasMask
 M.RequestAnimation(true,{},'on.wav'); M.UpdateAnimation(wearer,true)
 clock=clock+0.1; M.UpdateAnimation(wearer,true); failDraw=true; hooks.PostDrawEffects()
 eq(cameraDepth,0); eq(ignored,false); eq(reported,true); eq(models[1].valid,false); eq(M.AnimationActive(),false)
 badSequence=true; M.RequestAnimation(true,{},'on.wav'); M.UpdateAnimation(wearer,true)
 eq(models[3].valid,false); eq(M.AnimationActive(),false)
 `,animation);
};
