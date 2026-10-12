-- Соответствие моделей и энтити или NPC
local PLUGIN = PLUGIN
local modelToEntity = {
	["models/props_combine/combine_barricade_short01a.mdl"] = "ix_combinebarricade",
	["models/combine_turrets/floor_turret.mdl"] = "npc_turret_floor",
	["models/manhack.mdl"] = "npc_manhack",
	["models/props_combine/combine_mine01.mdl"] = "combine_mine"
	-- Добавьте сюда свои соответствия моделей и энтити или NPC
}

local Item = class("ItemBuildable"):implements("Item")

Item.stackable = false

if CLIENT then
	do
		local mat = Material("debug/debugdrawflat")
		local preview = false
		local mdl = NULL
		local angle = Angle()
		local itemPlace

		local origin
		local trace
		local data = {}
		local placeAngle = Angle()    -- Итоговый угол, отправляемый на сервер

		local validPlacement = false  -- Флаг для проверки, можно ли разместить

		local function PostDrawTranslucentRenderables(depth, sky)
			if depth or sky then return end
			if not preview or not IsValid(mdl) then return end

			render.MaterialOverride(mat)

			local eyeTrace = LocalPlayer():GetEyeTraceNoCursor()

			-- Крепление на поверхность (стена/потолок/пол), к которой обращён прицел.
			-- Предмет прижимается к поверхности и ориентируется по её нормали. Колёсико
			-- вращает предмет в плоскости поверхности (удобно для картин, часов, досок).
			if itemPlace and itemPlace.wallMount then
				local normal = eyeTrace.HitNormal
				origin = eyeTrace.HitPos

				local ang = normal:Angle()

				-- Опциональная поправка под конкретную модель (напр. развернуть лицом
				-- от стены): ITEM.wallAngleOffset = Angle(pitch, yaw, roll) в локальных осях.
				local o = itemPlace.wallAngleOffset
				if o then
					ang:RotateAroundAxis(ang:Right(), o.p)
					ang:RotateAroundAxis(ang:Up(), o.y)
					ang:RotateAroundAxis(ang:Forward(), o.r)
				end

				ang:RotateAroundAxis(normal, angle.y) -- прокрутка колёсиком

				placeAngle = ang
				mdl:SetAngles(ang)
				mdl:SetPos(origin)
				mdl.normal = normal

				local customCheck
				if itemPlace.CheckTrace then
					customCheck = itemPlace:CheckTrace(eyeTrace)
				end

				if not eyeTrace.Hit or eyeTrace.HitSky then
					render.SetColorModulation(1, 0, 0, 1)
					validPlacement = false
				else
					render.SetColorModulation(0, 1, 0, 1)
					validPlacement = true
				end

				if customCheck == true or customCheck == false then
					render.SetColorModulation(customCheck and 0 or 1, customCheck and 1 or 0, 0, 1)
					validPlacement = customCheck
				end

				render.SetBlend(0.2)
				mdl:DrawModel()
				render.MaterialOverride(nil)
				return
			end

			trace = eyeTrace
			mdl:SetAngles(angle)

			local mins, maxs = mdl:GetModelBounds()

			data.mins = mins
			data.maxs = maxs
			data.start = trace.StartPos
			data.endpos = trace.StartPos + trace.Normal * 70
			data.filter = LocalPlayer()

			local trace = util.TraceLine(data)

			local sitTrace = util.TraceHull({
				start = trace.HitPos,
				endpos = trace.HitPos - Vector(0, 0, 70),
				mins = mins,
				maxs = maxs,
				filter = LocalPlayer()
			})

			local customCheck

			if itemPlace and itemPlace.CheckTrace then
				customCheck = itemPlace:CheckTrace(sitTrace)
			end

			if sitTrace.AllSolid or not sitTrace.Hit then
				render.SetColorModulation(1, 0, 0, 1)  -- Красный для невалидного места
				validPlacement = false
			else
				render.SetColorModulation(0, 1, 0, 1)  -- Зеленый для валидного места
				validPlacement = true
			end

			if customCheck == true or customCheck == false then
				if customCheck then
					render.SetColorModulation(0, 1, 0, 1)
				else
					render.SetColorModulation(1, 0, 0, 1)
				end

				validPlacement = customCheck
			end

			render.SetBlend(0.2)

			origin = sitTrace.HitPos
			placeAngle = angle
			mdl:SetPos(sitTrace.HitPos)
			mdl.normal = trace.Normal
			mdl:DrawModel()

			render.MaterialOverride(nil)
		end

		local function HUDPaint()
			if not preview then return end
			local text = L("buildHintPlaceCancel")
			draw.DrawText(text, "ixMediumFont", ScrW() * 0.5 + 1, ScrH() * 0.95 + 1, color_black, TEXT_ALIGN_CENTER)
			draw.DrawText(text, "ixMediumFont", ScrW() * 0.5, ScrH() * 0.95, color_white, TEXT_ALIGN_CENTER)
		end

		local buildCallback
		local function PlayerBindPress(player, bind, bPressed)
			if not preview then return end

			if (bind:find("invnext") or bind:find("invprev")) and bPressed then
				return true
			elseif bind:find("attack2") and bPressed then
				net.Start("build.stop")
				net.SendToServer()

				ix.Item:BuildPreview(false)
				return true
			elseif bind:find("attack") and bPressed then
				if validPlacement then  -- Проверка, можно ли разместить
					if buildCallback then
						buildCallback()
					end

					ix.Item:BuildPreview(false)
				else
					chat.AddText(Color(255, 0, 0), L("buildInvalidPlacement"))
				end
				return true
			end
		end

		local function InputMouseApply(cmd)
			if not preview then return end

			local scrollDelta = cmd:GetMouseWheel()
			if scrollDelta == 0 then return end

			local pos = scrollDelta > 0
			angle.y = math.NormalizeAngle(angle.y + (pos and 1 or -1))
		end

		function ix.Item:BuildPreview(enable, path, uniqueID)
			local item = uniqueID and ix.Item:Get(uniqueID)

			if enable and not preview then
				ix.gui.preventSelection = true
				preview = true

				mdl = ClientsideModel(path, RENDERGROUP_OPAQUE)
				mdl:SetNoDraw(true)
				angle = angle_zero
				itemPlace = item

				hook.Add('PostDrawTranslucentRenderables', 'item.preview', PostDrawTranslucentRenderables)
				hook.Add('PlayerBindPress', 'item.preview', PlayerBindPress)
				hook.Add('InputMouseApply', 'item.preview', InputMouseApply)
				hook.Add('HUDPaint', 'item.preview', HUDPaint)
			elseif not enable then
				ix.gui.preventSelection = false

				hook.Remove('PostDrawTranslucentRenderables', 'item.preview')
				hook.Remove('PlayerBindPress', 'item.preview')
				hook.Remove('InputMouseApply', 'item.preview')
				hook.Remove('HUDPaint', 'item.preview')

				preview = false

				if IsValid(mdl) then
					mdl:Remove()
				end
			end
		end

		net.Receive("build.place", function()
			if IsValid(ix.gui.menu) then
				ix.gui.menu:Remove()
			end

			local mdl = net.ReadString()
			local id = net.ReadString()

			ix.Item:BuildPreview(true, mdl, id)

			buildCallback = function()
				net.Start("build.place")
					net.WriteAngle(placeAngle)
					net.WriteVector(origin)
				net.SendToServer()
			end
		end)
	end
else
	util.AddNetworkString("build.place")
	util.AddNetworkString("build.stop")


 local function clearBuild(client)
  local item=client.build_item
  if item and item.user==client then item.user=nil end
  client.build_item=nil;client.buildCharacter=nil;client.buildExpires=nil
 end
 net.Receive("build.stop",function(_,client) clearBuild(client) end)
 hook.Add("PlayerDisconnected","ixBuildableCleanup",clearBuild)
 hook.Add("PlayerLoadedCharacter","ixBuildableCleanup",clearBuild)
 hook.Add("PlayerDeath","ixBuildableCleanup",clearBuild)
 timer.Create("ixBuildableExpiry",1,0,function()
  for _,client in ipairs(player.GetAll()) do if client.buildExpires and client.buildExpires<=CurTime() then clearBuild(client) end end
 end)
 net.Receive("build.place",function(length,client)
  if length>256 or (client.ixBuildNext or 0)>CurTime() then return end
  client.ixBuildNext=CurTime()+.2
  local item=client.build_item;local character=client:GetCharacter()
  if not item or item.user~=client or not character or not client:Alive() or client:IsRestricted() or client:InVehicle()
   or client.buildCharacter~=character:GetID() or (client.buildExpires or 0)<=CurTime()
   or item:GetOwner()~=client or IsValid(item:GetEntity()) or (item.factionLock and not item.factionLock[client:Team()])
   or (ix.Inventory.pendingTransfers and ix.Inventory.pendingTransfers['item_'..item.id]) then clearBuild(client);return end
  local ang,pos=net.ReadAngle(),net.ReadVector()
  local function finite(v) return isnumber(v) and v==v and math.abs(v)<1000000 end
  if not isangle(ang) or not isvector(pos) or not finite(pos.x) or not finite(pos.y) or not finite(pos.z)
   or not finite(ang.p) or not finite(ang.y) or not finite(ang.r) or not util.IsInWorld(pos)
   or client:GetShootPos():DistToSqr(pos)>220^2 then return end
  local line=util.TraceLine({start=client:GetShootPos(),endpos=pos,filter=client,mask=MASK_SOLID})
  if line.Hit and line.HitPos:DistToSqr(pos)>100 then return end
  local probe=ents.Create("prop_physics");if not IsValid(probe) then return end
  probe:SetModel(item.preview_model);local mins,maxs=probe:GetModelBounds();probe:Remove()
  local tr
  if item.wallMount then
   tr=client:GetEyeTrace()
   if not tr.Hit or tr.HitSky or tr.HitPos:DistToSqr(pos)>(maxs-mins):Length()^2+64 then return end
  else
   if math.abs(ang.p)>.01 or math.abs(ang.r)>.01 then return end
   tr=util.TraceHull({start=pos+Vector(0,0,3),endpos=pos-Vector(0,0,8),mins=mins,maxs=maxs,filter=client,mask=MASK_SOLID})
   if not tr.Hit or tr.AllSolid or tr.HitSky or tr.HitNormal.z<.7 then return end
  end
  if item.CheckTrace and item:CheckTrace(tr)==false then return end
  local entity=item:OnPlace(client,pos,ang)
  if not IsValid(entity) then return end
  clearBuild(client);item:Remove(true)
 end)

end

function Item:Init(uniqueID)
	ix.meta.Item.Init(self,uniqueID or self.uniqueID)
	self.category = "item.category.construction"
	self.preview_model = self.preview_model or ""
	self.isEntity = self.isEntity or false

	self.functions.place = {
		name = "use.place",
		OnRun = function(item)
			if item.factionLock then
				local client = item.player

				if !item.factionLock[client:Team()] then
					client:NotifyLocalized("buildable.cantUse")
					return
				end
			end
			
			if ix.furnish and ix.furnish.Supported and ix.furnish.Supported(item) then
				ix.furnish.BeginPlace(item.player, item)
				return false
			end
			if item.preview_model then
				net.Start("build.place")
					net.WriteString(item.preview_model)
					net.WriteString(item.uniqueID)
				net.Send(item.player)

				if item.player.build_item then item.player.build_item.user=nil end
				item.player.buildCharacter=item.player:GetCharacter():GetID()
				item.player.buildExpires=CurTime()+180
				item.player.build_item = item
				item.user = item.player
			end
		end,
		OnCanRun = function(item)
			return IsValid(item.player) and item.player:GetCharacter() and item.player:Alive() and not item.player:InVehicle() and item:GetOwner()==item.player and not IsValid(item:GetEntity()) and not item.player:IsRestricted() and not IsValid(item.user) and (not item.factionLock or item.factionLock[item.player:Team()]==true)
		end
	}
end

function Item:OnPlace(client,pos,ang)
 if not isstring(self.preview_model) or not util.IsValidModel(self.preview_model) then return end
 local data=ix.container.stored[self.preview_model:lower()]
 local entityClass=modelToEntity[self.preview_model]
 local entity=ents.Create(data and "ix_container" or entityClass or "prop_physics")
 if not IsValid(entity) then return end
 if not entityClass or data then entity:SetModel(self.preview_model) end
 entity:SetPos(pos);entity:SetAngles(ang);entity:Spawn()
 if not IsValid(entity) then return end
 entity:SetNetVar("owner",client:GetCharacter():GetID())
 if entity:GetClass()~="combine_mine" and not entity:IsNPC() then
  local phys=entity:GetPhysicsObject();if IsValid(phys) then phys:EnableMotion(false) end
 else entity:SetKeyValue("spawnflags",8192) end
 if data then entity:CreateInventory(data) else PLUGIN:AddConstructionToSave(entity) end
 return entity
end

if CLIENT then
	function Item:PopulateTooltip(tooltip)
		local data = ix.container.stored[self.preview_model:lower()]
		if data then
			local size = tooltip:AddRowAfter("name")
			size:SetBackgroundColor(derma.GetColor("Success", tooltip))
			size:SetText(L("containerCapacityLabel", tostring(data.width).."x"..tostring(data.height)))
		end
	end
end

return Item
