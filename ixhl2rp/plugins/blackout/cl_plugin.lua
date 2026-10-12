local PLUGIN = PLUGIN

PLUGIN.zones    = PLUGIN.zones    or {} -- list of { min = Vector, max = Vector }
PLUGIN.darkness = 0 -- clear the old full-screen veil on auto-refresh

net.Receive("ixBlackoutSync3", function()
	local count = net.ReadUInt(16)
	local zones = {}

	for i = 1, count do
		local mn = net.ReadVector()
		local mx = net.ReadVector()
		zones[i] = { min = mn, max = mx, darkness = net.ReadUInt(7), softness = net.ReadUInt(8),
            fadeMin = net.ReadVector(), fadeMax = net.ReadVector() }
	end

	PLUGIN.zones = zones
end)

-- Two stencil bits: bit 0 is one box's depth parity; bit 1 is the union.
-- Z-fail parity also works with the camera inside the box: only scene surfaces
-- inside it are shaded. Never darken the entire view based on the eye position.
-- Submit a closed volume once with an explicitly two-sided material. Parity
-- needs every boundary exactly once; two DrawBox calls with global cull state
-- leave that dependent on the helper/material's own culling behaviour.
local volumeMaterial=CreateMaterial("ixBlackoutVolume_v1","UnlitGeneric",{
 ["$basetexture"]="color/white",["$nocull"]="1",["$ignorez"]="0",
 ["$translucent"]="0",["$vertexcolor"]="0",["$vertexalpha"]="0"})
if PLUGIN.boxVolume then PLUGIN.boxVolume:Destroy();PLUGIN.boxVolume=nil end
local function boxVolume()
 if PLUGIN.boxVolume then return PLUGIN.boxVolume end
 local points={Vector(0,0,0),Vector(1,0,0),Vector(1,1,0),Vector(0,1,0),
  Vector(0,0,1),Vector(1,0,1),Vector(1,1,1),Vector(0,1,1)}
 local vertices={}
 for _,face in ipairs({{1,4,3,2},{5,6,7,8},{1,2,6,5},{4,8,7,3},{1,5,8,4},{2,3,7,6}}) do
  for _,i in ipairs({1,2,3,1,3,4}) do
   vertices[#vertices+1]={pos=points[face[i]],normal=Vector(0,0,1),u=0,v=0}
  end
 end
 local mesh=Mesh();mesh:BuildFromTriangles(vertices);PLUGIN.boxVolume=mesh
 return mesh
end
local function screenRect()
 cam.Start2D()
  surface.DrawRect(0, 0, ScrW(), ScrH())
 cam.End2D()
end
local function markBox(mn, mx)
 render.SetStencilWriteMask(1)
 render.SetStencilTestMask(1)
 render.SetStencilReferenceValue(0)
 render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
 render.SetStencilPassOperation(STENCILOPERATION_KEEP)
 render.SetStencilZFailOperation(STENCILOPERATION_INVERT)
 render.OverrideDepthEnable(true, false)
 render.SetMaterial(volumeMaterial)
 local matrix=Matrix();matrix:SetTranslation(mn);matrix:SetScale(mx-mn)
 cam.PushModelMatrix(matrix)
 boxVolume():Draw()
 cam.PopModelMatrix()
 render.OverrideDepthEnable(false)

 -- Copy parity into the union, preserving already marked overlapping zones.
 render.SetStencilWriteMask(2)
 render.SetStencilReferenceValue(3)
 render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
 render.SetStencilPassOperation(STENCILOPERATION_REPLACE)
 render.SetStencilZFailOperation(STENCILOPERATION_KEEP)
 screenRect()
 -- Clear only the temporary bit for the next zone; retain the union.
 render.SetStencilWriteMask(1)
 render.SetStencilReferenceValue(0)
 render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_ALWAYS)
 screenRect()
end

-- Equal opacity increments avoid the three conspicuous wide bands used before.
-- Cache the world-space fade geometry on sync; every camera uses its own depth.
local cacheZones,cacheCount,cacheQuality,cacheDefault,fadeLayers
local function inverseSmooth(t)
 local low,high=0,1
 for _=1,12 do
  local x=(low+high)*.5
  if x*x*(3-2*x)<t then low=x else high=x end
 end
 return (low+high)*.5
end
function PLUGIN:BuildFadeLayers()
 local layers=math.Clamp(math.floor(self.maskLayers or 48),1,64)
 local maxOpacity=0
 for _,zone in ipairs(self.zones) do maxOpacity=math.max(maxOpacity,math.Clamp(zone.darkness or (self.maskDarkness or 220)/2.55,0,100)/100) end
 local result={};if maxOpacity<=0 then return result end
 local previous=0
 for layer=1,layers do
  local target=maxOpacity*layer/layers
  local opacity=math.Clamp(math.Round(255*(target-previous)/math.max(1-previous,.000001)),0,255)
  previous=previous+(1-previous)*opacity/255
  local row={alpha=opacity,boxes={}}
  for index,zone in ipairs(self.zones) do
   local strength=math.Clamp(zone.darkness or (self.maskDarkness or 220)/2.55,0,100)/100
   if strength>=target-.000001 then
    local mn,mx=zone.fadeMin or zone.min,zone.fadeMax or zone.max
    local size=mx-mn
    local width=zone.softness or self.maskSoftness or 24
    local frac=layers==1 and 0 or inverseSmooth(math.Clamp(target/math.max(strength,.000001),0,1))
    local side=math.Clamp(width,0,math.max(math.min(size.x,size.y)*.5-1,0))*frac
    local top=math.Clamp(width,0,math.max(size.z-1,0))*frac
    -- Keep the floor solid. Fading up from the bottom would brighten every floor
    -- when the selected volume ends just below it. Fragment joins do not feather.
    local low=Vector(math.max(zone.min.x,mn.x+side),math.max(zone.min.y,mn.y+side),zone.min.z)
    local high=Vector(math.min(zone.max.x,mx.x-side),math.min(zone.max.y,mx.y-side),math.min(zone.max.z,mx.z-top))
    if low.x<high.x and low.y<high.y and low.z<high.z then row.boxes[#row.boxes+1]={min=low,max=high,index=index} end
   end
  end
  if #row.boxes>0 and opacity>0 then result[#result+1]=row end
 end
 return result
end

function PLUGIN:FadeVisible(zone,view)
 if not view or not view.origin or not view.angles or view.ortho or view.offcenter then return true end
 local center=(zone.min+zone.max)*.5
 local radius=(zone.max-zone.min):Length()*.5
 local delta=center-view.origin
 local depth=delta:Dot(view.angles:Forward())
 local far=tonumber(view.zfar) or 0
 if depth+radius<0 or (far>0 and depth-radius>far) then return false end
 local horizontal=math.tan(math.rad(math.Clamp(view.fov or 100,1,179)*.5))
 local vertical=horizontal/math.max(view.aspect or 1,.01)
 return math.abs(delta:Dot(view.angles:Right()))<=depth*horizontal+radius*math.sqrt(1+horizontal*horizontal)
  and math.abs(delta:Dot(view.angles:Up()))<=depth*vertical+radius*math.sqrt(1+vertical*vertical)
end

local function drawBlackout(depth, sky, sky3D)
 -- The main world can have sky=true when a 2D skybox is visible. Only the
 -- separate 3D-skybox pass uses a different space and must be excluded.
 if depth or sky3D then return end
 -- Draw physical addon geometry once, before sampling/shading the world. This
 -- explicit phase avoids undefined ordering between PostDrawOpaque hooks.
 hook.Run("ixBlackoutWorldGeometry", depth, sky, sky3D)
 if #PLUGIN.zones == 0 then return end
 if cacheZones~=PLUGIN.zones or cacheCount~=#PLUGIN.zones or cacheQuality~=PLUGIN.maskLayers or cacheDefault~=PLUGIN.maskDarkness then
  fadeLayers=PLUGIN:BuildFadeLayers();cacheZones=PLUGIN.zones;cacheCount=#PLUGIN.zones
  cacheQuality=PLUGIN.maskLayers;cacheDefault=PLUGIN.maskDarkness
 end
 local visible,any={},false
 -- RenderView can leave the generic setup pointing at an auxiliary camera.
 -- Use the player setup for the main framebuffer, and the current setup only
 -- while drawing an auxiliary target such as a CCTV feed.
 local target=render.GetRenderTarget and render.GetRenderTarget()
 local auxiliary=target and not string.StartWith(target:GetName():lower(),"_rt_fullframefb") or false
 local view=render.GetViewSetup and render.GetViewSetup(auxiliary)
 for index,zone in ipairs(PLUGIN.zones) do
  visible[index]=PLUGIN:FadeVisible(zone,view)
  any=any or visible[index]
 end
 if not any or #fadeLayers==0 then return end
 local beam=PLUGIN.CaptureFlashlight and PLUGIN:CaptureFlashlight(view)
 local col=PLUGIN.maskColor or color_black
 render.SetStencilEnable(true)
 render.SetStencilFailOperation(STENCILOPERATION_KEEP)
 for _,layer in ipairs(fadeLayers) do
  render.SetStencilWriteMask(255)
  render.ClearStencil()
  render.OverrideColorWriteEnable(true,false)
  render.OverrideAlphaWriteEnable(true,false)
  surface.SetDrawColor(255,255,255,255)
  for _,box in ipairs(layer.boxes) do if visible[box.index] then markBox(box.min,box.max) end end
  render.OverrideColorWriteEnable(false)
  render.OverrideAlphaWriteEnable(false)
  render.SetStencilWriteMask(0)
  render.SetStencilTestMask(2)
  render.SetStencilReferenceValue(2)
  render.SetStencilCompareFunction(STENCILCOMPARISONFUNCTION_EQUAL)
  render.SetStencilPassOperation(STENCILOPERATION_KEEP)
  surface.SetDrawColor(col.r,col.g,col.b,layer.alpha)
  screenRect()
 end
 render.SetStencilWriteMask(255)
 render.SetStencilTestMask(255)
 render.SetStencilEnable(false)
 if beam then PLUGIN:RestoreFlashlight(beam) end
end

-- Apply darkness before additive particles (fire, sparks and muzzle flashes).
-- Ordinary late-rendered prop models and viewmodels are handled separately.
hook.Remove("PostDrawTranslucentRenderables", "ixBlackoutStencil")
hook.Remove("PostDrawOpaqueRenderables", "ixBlackoutStencilFallback")
PLUGIN.drawsWorldGeometry = true
hook.Add("PostDrawOpaqueRenderables", "ixBlackoutStencil", drawBlackout)

-- Обесточенное оборудование не открывает своё меню. Сервер всё равно отклонит
-- взаимодействие в PlayerUse, но без этого игрок увидел бы меню на долю секунды.
function PLUGIN:ShowEntityMenu(entity)
	if (self:IsEntityBlackedOut(entity)) then
		return true -- «меню показано» — Helix не открывает своё
	end
end

function PLUGIN:OnUnload()
 if self.boxVolume then self.boxVolume:Destroy();self.boxVolume=nil end
 self.drawsWorldGeometry = false
 if self.ClearLighting then self:ClearLighting() end
 if IsValid(self.heightEditor) then self.heightEditor:Remove() end
 hook.Remove("PostDrawOpaqueRenderables", "ixBlackoutStencil")
 hook.Remove("PostDrawOpaqueRenderables", "ixBlackoutStencilFallback")
 hook.Remove("PostDrawTranslucentRenderables", "ixBlackoutStencil")
 self.zones = {}; self.darkness = 0
 net.Receive("ixBlackoutSync3", function() end)
end
