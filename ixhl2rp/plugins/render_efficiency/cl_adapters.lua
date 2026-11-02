local P=PLUGIN
if P.OnUnload then P:OnUnload() end
local entities=setmetatable({}, {__mode="k"})
local sdEntities=setmetatable({}, {__mode="k"})
local stopped=false
local tracked=false
local function seed()
 if tracked then return end
 tracked=true
 for _,e in ipairs(ents.GetAll()) do entities[e]=true end
end
hook.Add("OnEntityCreated","ixEfficientRenderEntities",function(e) entities[e]=true end)
hook.Add("EntityRemoved","ixEfficientRenderEntities",function(e) entities[e]=nil;sdEntities[e]=nil end)
hook.Add("PostCleanupMap","ixEfficientRenderEntities",function() tracked=false end)

local sdOriginal,sdWrapper,sdTimer
local states=setmetatable({}, {__mode="k"})
local sdSlots={}
for _,name in ipairs({"city_top3","city_top","hlvr_armor_security","combine_captain_body_gear","combine_captain_legs_gear","metropolice_body"}) do
 sdSlots["models/sectorialdistrict/citizens/"..name]=true
end
local function supported(e)
 local model=string.lower(e:GetModel() or "")
 return model:match("^models/sd/citizens/citizen_male_") or model:match("^models/sd/citizens/citizen_female_")
end
local function installSD()
 if sdWrapper or not SDDClass or not SDDClass.Apply then return end
 sdOriginal=SDDClass.Apply
 sdWrapper=function(e)
  if not IsValid(e) then return end
  local state=states[e]
  if not supported(e) then
   sdEntities[e]=nil
   states[e]=nil
   -- The addon may own overrides applied before this adapter loaded.
   sdOriginal(e)
   return
  end
  sdEntities[e]=true
  local model=e:GetModel()
  if not state or state.model~=model then
   state={model=model,groups={},slots={},values={},nextApply=0}
   for _,group in ipairs(e:GetBodyGroups()) do
    local name=string.lower(group.name or "")
    if name=="torso" or name=="legs" then state.groups[#state.groups+1]=group end
   end
   for index,material in ipairs(e:GetMaterials()) do
    if sdSlots[string.lower(material:gsub("\\","/"))] then state.slots[#state.slots+1]=index-1 end
   end
   states[e]=state
  end
  local dirty=RealTime()>=state.nextApply
  for _,group in ipairs(state.groups) do
   local value=e:GetBodygroup(group.id)
   if state.values[group.id]~=value then dirty=true;state.values[group.id]=value end
  end
  for _,i in ipairs(state.slots) do
   if not state.materials or state.materials[i]~=e:GetSubMaterial(i) then dirty=true;break end
  end
  if not dirty then return end
  -- Original implementation still owns slot choices, restoration and asset readiness.
  sdOriginal(e)
  state.materials={}
  for _,i in ipairs(state.slots) do state.materials[i]=e:GetSubMaterial(i) end
  state.nextApply=RealTime()+2
 end
 SDDClass.Apply=sdWrapper
 sdTimer=timer.Exists("SDDClass.Entities")
 if sdTimer then timer.Remove("SDDClass.Entities") end
end
local function install()
 if stopped then return end
 installSD()
 if sdWrapper then
  seed()
  for e in pairs(entities) do
   if IsValid(e) and supported(e) then sdEntities[e]=true end
  end
 end
end
timer.Simple(0,install)
hook.Add("InitPostEntity","ixEfficientRenderAdapters",install)
timer.Create("ixEfficientRenderAdapters",2,0,install)
timer.Create("ixEfficientSDMaterials",.25,0,function()
 if not sdWrapper then return end
 seed()
 for e in pairs(sdEntities) do
  if not IsValid(e) then sdEntities[e]=nil
  else sdWrapper(e) end
 end
end)
function P:OnUnload()
 stopped=true
 if SDDClass and SDDClass.Apply==sdWrapper then SDDClass.Apply=sdOriginal end
 if sdTimer and sdOriginal then
  timer.Create("SDDClass.Entities",.25,0,function()
   for _,e in ipairs(ents.GetAll()) do SDDClass.Apply(e) end
  end)
 end
 for _,name in ipairs({"ixEfficientRenderAdapters","ixEfficientSDMaterials"}) do timer.Remove(name) end
 for _,event in ipairs({"OnEntityCreated","EntityRemoved","PostCleanupMap"}) do hook.Remove(event,"ixEfficientRenderEntities") end
 hook.Remove("InitPostEntity","ixEfficientRenderAdapters")
end
