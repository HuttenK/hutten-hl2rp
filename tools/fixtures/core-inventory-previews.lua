-- Engine rendering is mocked; the registered production item panel is executed.
local function noop() end
function eq(a, b) assert(a == b, tostring(a) .. " ~= " .. tostring(b)) end
function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
function Vector(x,y,z) return {x=x,y=y,z=z} end
function Angle(p,y,r) return {p=p,y=y,r=r} end
function IsValid(value) return type(value) == "table" and value.valid ~= false end
function istable(value) return type(value) == "table" end
function isnumber(value) return type(value) == "number" end
function table.Copy(value)
 if type(value) ~= "table" then return value end
 local copy={}; for k,v in pairs(value) do copy[k]=table.Copy(v) end; return copy
end
math.scale=function(x) return x end
surface=setmetatable({CreateFont=noop,GetAlphaMultiplier=function() return 1 end}, {__index=function() return noop end})
render=setmetatable({}, {__index=function() return noop end})
draw={SimpleText=noop, RoundedBox=noop}
color_white=Color(255,255,255)
RENDERGROUP_OTHER=1; FILL=5; BOX_TOP=0; BOX_LEFT=1; ACT_IDLE=1
ix={meta={Item={}}, Item={instances={}}, hud={PopulateItemTooltip=noop}, CustomItem={stored={}}}
local base=ix.meta.Item
function base:GetData(key) return (self.data or {})[key] end
function base:GetRarity() return 0 end
local entityMethods={SetNoDraw=noop,SetIK=noop,DrawModel=noop}
function entityMethods:Remove() self.valid=false; removedModels=removedModels+1 end
function entityMethods:SetSkin(value) self.skin=value end
function entityMethods:SetMaterial(value) self.material=value end
function entityMethods:GetModel() return self.model end
function entityMethods:GetSkin() return self.skin end
function entityMethods:GetMaterial() return self.material end
function entityMethods:GetPos() return Vector(0,0,0) end
function entityMethods:SetSequence(value) self.sequence=value end
createdModels=0; removedModels=0; createdPanels=0; renderedModels=0; cameraCalls=0
function ClientsideModel(model)
 createdModels=createdModels+1
 if failModel then return nil end
 return setmetatable({model=errorModel and "models/error.mdl" or string.lower(model),skin=0,material=""}, {__index=entityMethods})
end
function PositionSpawnIcon(entity)
 cameraCalls=cameraCalls+1
 return {fov=45,origin=Vector(2,3,4),angles=Angle(5,6,7)}
end
local childMethods={Dock=noop,DockMargin=noop,SetMouseInputEnabled=noop,SetAnimated=noop,
 SetAmbientLight=noop,SetDirectionalLight=noop,SetPaintedManually=noop}
function childMethods:GetEntity() return self.Entity end
function childMethods:Remove()
 self.valid=false
 if IsValid(self.Entity) then self.Entity:Remove() end
end
function childMethods:SetCamPos(value) self.camPos=value end
function childMethods:SetFOV(value) self.fov=value end
function childMethods:SetLookAng(value) self.lookAng=value end
function childMethods:PaintManual() renderedModels=renderedModels+1; self:LayoutEntity(self.Entity) end
local classes={}
vgui={Register=function(name,panel) classes[name]=panel end}
function vgui.Create(class,parent)
 createdPanels=createdPanels+1
 local child={class=class,parent=parent}
 if class == "ixARC9ItemIcon" then
  child.Dock=noop; child.SetPaintedManually=noop
  child.Remove=function(self) self.valid=false end
  return child -- Intentionally no GetEntity, as on the real ARC9 DPanel.
 end
 return setmetatable(child,{__index=childMethods})
end
function newItem(fields)
 local item={width=2,height=1,model="models/test.mdl",uniqueID="test",data={}}
 for k,v in pairs(fields or {}) do item[k]=v end
 return setmetatable(item,{__index=base})
end
local slotMethods={}
function slotMethods:Droppable() self.dropUpdates=(self.dropUpdates or 0)+1 end
function slotMethods:SetHelixTooltip(callback) self.tooltipUpdates=(self.tooltipUpdates or 0)+1; self.tooltip=callback end
function slotMethods:GetSize() return self.w,self.h end
function slotMethods:SetWidth(w) self.w=w end
function slotMethods:SetHeight(h) self.h=h end
function slotMethods:IsDragging() return false end
function newSlot(item)
 return setmetatable({item_data=item,instance_ids={},item_count=1,rotated=false,w=64,h=32},
 {__index=function(_,key) return slotMethods[key] or classes['ui.inv.item'][key] end})
end
