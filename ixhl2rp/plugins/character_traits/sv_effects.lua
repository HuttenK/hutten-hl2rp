local T=ix.Traits
hook.Add("OnCharacterCreated","ixTraitsInitialSave",function(client,character)
 -- Helix's initial INSERT only contains the built-in columns. Flush custom
 -- variables before the first logout/restart, even if the character isn't used.
 character:Save()
end)
function T.Refresh(character)
 local health=character.Health and character:Health()
 if health then health.cachedParts=nil;health:OnUpdateDiffs() end
 local genetic=character.Genetic and character:Genetic()
 if genetic then genetic.cachedDesc=nil end
 local client=character:GetPlayer()
 if IsValid(client) and client:GetCharacter()==character then
  client.recalculateSpeed=true
  if ix.CharacterHeight then ix.CharacterHeight.Apply(client,true) end
 end
end
hook.Add("CharacterVarChanged","ixTraitsRefresh",function(character,key)
 if key=="traits" then T.Refresh(character) end
end)
function T.AcquireEye(character)
 if T.Has(character,"one_eyed") then return false end
 local selected=table.Copy(T.Selection(character))
 selected.one_eyed=math.random(1,2)==1 and "left" or "right"
 character:SetTraits(selected);character:Save()
 local client=character:GetPlayer()
 if IsValid(client) then client:Notify("Тяжёлая травма лишила вас глаза. Повреждение необратимо.") end
 return true
end
function T.HeadInjury(health,hitgroup,damageClass,severity)
 if hitgroup~=HITGROUP_HEAD or severity<8 or T.Has(health.character,"one_eyed") then return end
 if not ({slash=true,club=true,bullet=true,buckshot=true,explosive=true,physics=true})[damageClass] then return end
 if math.random(1,100)<=2 then T.AcquireEye(health.character) end
end
function T.SyncLeg(character,key)
 local selected=table.Copy(T.Selection(character))
 local side=key=="lleg" and "left" or key=="rleg" and "right" or nil
 if selected.one_legged==side then return end
 selected.one_legged=side
 character:SetTraits(selected)
end
hook.Add("PlayerLoadedCharacter","ixTraitsLoaded",function(client,character)
 timer.Simple(0,function()
  if not IsValid(client) or client:GetCharacter()~=character then return end
  local selected=T.Selection(character)
  if ix.Amputation then
   local key=ix.Amputation.Get(character)
   if selected.one_legged and not key then ix.Amputation.Amputate(client,selected.one_legged=="right" and "rleg" or "lleg",true)
   elseif key then T.SyncLeg(character,key) end
  end
  T.Refresh(character)
 end)
end)
hook.Add("AdjustStaminaOffset","ixTraitsBreathing",function(client,offset)
 if offset>=0 or not T.Has(client:GetCharacter(),"wheezing") then return end
 if client:GetLocalVar("stm",100)>25 or CurTime()<(client.ixTraitBreathAt or 0) then return end
 client.ixTraitBreathAt=CurTime()+12
 client:EmitSound("player/breathe1.wav",55,100,.35)
end)

-- AoC's optional HEV stamina is separate from Helix's running stamina.
hook.Add("FinishMove","ixTraitsSuitCapacity",function(client)
 if CurTime()<(client.ixTraitSuitAt or 0) then return end
 client.ixTraitSuitAt=CurTime()+.25
 if T.Has(client:GetCharacter(),"wheezing") and client:GetSuitPower()>85 then client:SetSuitPower(85) end
end)

function T.CraftDuration(character,recipe)
 return math.max(.5,(tonumber(recipe.time) or 5)*T.Modifier(character,"craft"))
end
function T.BeginCraft(craft,client,recipe)
 if client.ixTraitCraft or client:IsRestricted() or client.bUsingMedical or client.ixAmputationOperation then return false end
 local character=client:GetCharacter()
 local session={character=character,station=client.ixStation,hadStation=IsValid(client.ixStation),position=client:GetPos()}
 client.ixTraitCraft=session
 local duration=T.CraftDuration(character,recipe)
 session.text="Изготовление: "..recipe:GetName()
 client:SetAction(session.text,duration)
 timer.Simple(duration,function()
  if not IsValid(client) or client.ixTraitCraft~=session then return end
  client.ixTraitCraft=nil
  if client:GetCharacter()~=character then return end
  client:SetAction()
  if not client:Alive() or client:IsRestricted() or client:GetPos():DistToSqr(session.position)>128*128 or client.ixStation~=session.station then return end
  if session.hadStation and not IsValid(session.station) then return end
  local result={craft:AttemptCraft(recipe,client)}
  if not result[1] then client:NotifyLocalized(result[2],unpack(result,3));return end
  local success=craft:OnCraft(recipe,client)
  if success then hook.Run("CharacterCraftedRecipe",client,character,recipe) end
 end)
 return true
end
hook.Add("PlayerActionChanged","ixTraitsCancelCraft",function(client,text)
 local session=client.ixTraitCraft
 if session and text~=session.text then client.ixTraitCraft=nil end
end)
