-- Recovered AUTONOMOUS client/shared source; Foundation integration. See docs/restored-systems-sources.json.
local PLUGIN = PLUGIN

if SERVER then return end

--[[
	РЕДАКТОР ОБУСТРОЙСТВА.

	Два режима:
	  * УСТАНОВКА — из инвентаря («Установить»): под курсором призрак предмета,
	    под ним сетка клеток, зелёные можно, красные нельзя;
	  * ПЕРЕСТАНОВКА — /Furnish: наводишься на свою мебель, ЛКМ берёт её в
	    руки (дальше как установка), R убирает в инвентарь.

	Управление: ЛКМ — поставить/взять, колесо — повернуть на 15°, зажатый
	Shift — свободный поворот мышью (вид при этом стоит) и без привязки к
	сетке, ПКМ — отмена/выход.

	Своя поставленная мебель несёт меню «Переставить / Забрать»: TAB → ПКМ
	по ней или E. Без /Furnish.

	Всё, что здесь зелёное, сервер проверит ещё раз той же функцией
	(ix.furnish.Evaluate) — здесь только вид.
]]

local editor = {}

local CELL_OK = Color(80, 220, 120, 90)
local CELL_BAD = Color(235, 70, 70, 130)
local CELL_EDGE_OK = Color(120, 255, 160, 170)
local CELL_EDGE_BAD = Color(255, 110, 110, 200)
local AREA_EDGE = Color(120, 200, 255, 60)

local function Areas()
	if editor.anywhere then return nil end

	return ix.furnish.ApartmentAreas(editor.home)
end

local function ClearGhost()
	if IsValid(editor.ghost) then
		editor.ghost:Remove()
	end

	editor.ghost = nil
	editor.mins, editor.maxs = nil, nil
	editor.cells, editor.ok, editor.key = nil, false, nil
end

local function SetGhost(model)
	ClearGhost()

	local ghost = ClientsideModel(model, RENDERGROUP_TRANSLUCENT)

	if !IsValid(ghost) then return false end

	ghost:SetNoDraw(true)
	editor.ghost = ghost
	editor.mins, editor.maxs = ghost:GetModelBounds()

	return true
end

local function StopMoving()
	if IsValid(editor.moving) then
		editor.moving:SetNoDraw(false)
	end

	editor.moving = nil
	ClearGhost()
end

local function Stop(bNotify)
	StopMoving()

	if editor.active and bNotify then
		net.Start("furnish.cancel")
		net.SendToServer()
	end

	editor.active = false
	editor.mode = nil
	editor.itemID = nil
	ix.gui.preventSelection = false
end

--- Своя ли это мебель (для подсветки; решает всё равно сервер).
local function IsMine(entity)
	if !IsValid(entity) then return false end

	local apt = entity:GetNetVar("furnApt")

	if apt == nil then return false end
	if LocalPlayer():IsAdmin() then return true end

	local character = LocalPlayer():GetCharacter()

	if character and entity:GetNetVar("furnOwner") == character:GetID() then return true end

	return false
end

-- ─────────────────────────────────────────────────────────────
-- РАСЧЁТ ПОЛОЖЕНИЯ
-- ─────────────────────────────────────────────────────────────

local function UpdatePlacement()
	if !IsValid(editor.ghost) then return end

	local client = LocalPlayer()
	local trace = util.TraceLine({
		start = client:EyePos(),
		endpos = client:EyePos() + client:GetAimVector() * ix.furnish.reach,
		filter = {client, editor.moving},
		mask = MASK_SOLID
	})

	editor.floor = trace.Hit and trace.HitNormal.z >= ix.furnish.floorNormal

	local base = trace.HitPos

	if !input.IsKeyDown(KEY_LSHIFT) then
		base = ix.furnish.Snap(base)
	end

	local ang = Angle(0, editor.yaw, 0)
	local pos = base - Vector(0, 0, editor.mins.z)

	editor.pos, editor.ang = pos, ang

	-- Пересчёт только когда что-то сдвинулось: клеток до сотни, у каждой по две
	-- трассы, и каждый кадр гонять их незачем.
	local key = string.format("%.1f|%.1f|%.1f|%.1f|%s", pos.x, pos.y, pos.z, editor.yaw, tostring(editor.floor))

	if key == editor.key then return end

	editor.key = key

	if !editor.floor then
		editor.cells, editor.ok = ix.furnish.Evaluate(editor.mins, editor.maxs, pos, ang, Areas(), {client, editor.moving})
		editor.ok = false

		for _, cell in ipairs(editor.cells) do
			cell.ok = false
		end

		return
	end

	editor.cells, editor.ok = ix.furnish.Evaluate(editor.mins, editor.maxs, pos, ang, Areas(), {client, editor.moving})

	if editor.ok and client:EyePos():DistToSqr(pos) > ix.furnish.reach ^ 2 then
		editor.ok = false
	end
end

-- ─────────────────────────────────────────────────────────────
-- ОТРИСОВКА
-- ─────────────────────────────────────────────────────────────

local function DrawCell(cell, forward, left, up)
	local hw, hh = cell.w * 0.46, cell.h * 0.46
	local c = cell.pos + up * 0.6

	local a = c - forward * hw - left * hh
	local b = c - forward * hw + left * hh
	local d = c + forward * hw + left * hh
	local e = c + forward * hw - left * hh

	local fill = cell.ok and CELL_OK or CELL_BAD

	render.DrawQuad(a, b, d, e, fill)
	render.DrawQuad(e, d, b, a, fill)

	local edge = cell.ok and CELL_EDGE_OK or CELL_EDGE_BAD

	render.DrawLine(a, b, edge, true)
	render.DrawLine(b, d, edge, true)
	render.DrawLine(d, e, edge, true)
	render.DrawLine(e, a, edge, true)
end

hook.Add("PostDrawTranslucentRenderables", "ixFurnishEditor", function(depth, sky)
	if !editor.active or depth or sky then return end

	-- Контур разрешённой квартиры — чтобы было видно, где кончается «можно».
	local areas = Areas()

	if areas then
		for _, info in ipairs(areas) do
			if isvector(info.startPosition) and isvector(info.endPosition) then
				render.DrawWireframeBox(vector_origin, angle_zero, info.startPosition, info.endPosition, AREA_EDGE, true)
			end
		end
	end

	if !IsValid(editor.ghost) then
		-- Перестановка без предмета в руках: подсветка того, что можно взять.
		local entity = LocalPlayer():GetEyeTrace().Entity

		if IsMine(entity) then
			local mins, maxs = entity:OBBMins(), entity:OBBMaxs()

			render.DrawWireframeBox(entity:GetPos(), entity:GetAngles(), mins, maxs, CELL_EDGE_OK, true)
		end

		return
	end

	UpdatePlacement()

	local ghost = editor.ghost

	ghost:SetPos(editor.pos)
	ghost:SetAngles(editor.ang)

	render.SetColorMaterial()

	local up = editor.ang:Up()
	local forward = editor.ang:Forward()
	local left = -editor.ang:Right()

	for _, cell in ipairs(editor.cells or {}) do
		DrawCell(cell, forward, left, up)
	end

	if editor.ok then
		render.SetColorModulation(0.55, 1, 0.65)
	else
		render.SetColorModulation(1, 0.45, 0.45)
	end

	render.SetBlend(0.6)
	ghost:DrawModel()
	render.SetBlend(1)
	render.SetColorModulation(1, 1, 1)
end)

local function Hint(text, y)
	draw.SimpleTextOutlined(text, "ixMediumFont", ScrW() * 0.5, y, color_white,
		TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, color_black)
end

hook.Add("HUDPaint", "ixFurnishEditor", function()
	if !editor.active then return end

	local y = ScrH() * 0.86

	if IsValid(editor.ghost) then
		Hint(editor.ok and "ЛКМ — поставить" or (editor.floor and "Сюда нельзя" or "Нужен пол"), y)
		Hint("Колесо — повернуть · Shift + мышь — вращать свободно, без сетки · ПКМ — отмена", y + 26)
	else
		Hint("РЕЖИМ ОБУСТРОЙСТВА", y)
		Hint("ЛКМ по своей мебели — переставить · R — забрать · ПКМ — выйти", y + 26)
	end
end)

-- ─────────────────────────────────────────────────────────────
-- УПРАВЛЕНИЕ
-- ─────────────────────────────────────────────────────────────

local function Confirm()
	if !IsValid(editor.ghost) then
		-- Перестановка: взять наведённую мебель в руки.
		local entity = LocalPlayer():GetEyeTrace().Entity

		if IsMine(entity) and SetGhost(entity:GetModel()) then
			editor.moving = entity
			editor.yaw = entity:GetAngles().y
			entity:SetNoDraw(true)
		end

		return
	end

	if !editor.ok then
		surface.PlaySound("buttons/button10.wav")

		return
	end

	if editor.mode == FURNISH_MODE_PLACE then
		net.Start("furnish.place")
			net.WriteUInt(editor.itemID or 0, 32)
			net.WriteVector(editor.pos)
			net.WriteAngle(editor.ang)
		net.SendToServer()

		Stop(false)
	elseif IsValid(editor.moving) then
		net.Start("furnish.move")
			net.WriteEntity(editor.moving)
			net.WriteVector(editor.pos)
			net.WriteAngle(editor.ang)
		net.SendToServer()

		StopMoving()
	end

	surface.PlaySound("buttons/lightswitch2.wav")
end

hook.Add("PlayerBindPress", "ixFurnishEditor", function(client, bind, pressed)
	if !editor.active or !pressed then return end

	if bind:find("invnext") or bind:find("invprev") then
		if IsValid(editor.ghost) then
			local step = ix.furnish.rotateStep

			editor.yaw = math.NormalizeAngle(editor.yaw + (bind:find("invnext") and -step or step))
		end

		return true
	elseif bind:find("+attack2") then
		if IsValid(editor.moving) then
			StopMoving()
		else
			Stop(true)
		end

		return true
	elseif bind:find("+attack") then
		Confirm()

		return true
	elseif bind:find("+reload") and !IsValid(editor.ghost) then
		local entity = client:GetEyeTrace().Entity

		if IsMine(entity) then
			net.Start("furnish.pickup")
				net.WriteEntity(entity)
			net.SendToServer()
		end

		return true
	end
end)

hook.Add("Think", "ixFurnishEditor", function()
	if !editor.active then return end

	local client = LocalPlayer()

	--[[
		Меню, которое ЗАКРЫВАЕТСЯ, открытым не считается. «Установить» жмут в
		инвентаре, и furnish.begin закрывает меню сам, но tabmenu уходит с
		затуханием и всё это время остаётся валидным (bClosing): проверка
		видела «меню открыто» в первом же кадре и гасила редактор — установка
		закрывалась сразу после нажатия.
	]]
	local menu = ix.gui.menu
	local menuOpen = IsValid(menu) and !menu.bClosing

	if !IsValid(client) or !client:Alive() or !client:GetCharacter() or menuOpen then
		Stop(true)
	end
end)

net.Receive("furnish.begin", function()
	local mode = net.ReadUInt(2)
	local model = net.ReadString()
	local itemID = net.ReadUInt(32)
	local home = net.ReadString()
	local anywhere = net.ReadBool()
	local grab = net.ReadEntity()

	Stop(false)

	if IsValid(ix.gui.menu) then
		ix.gui.menu:Remove()
	end

	editor.active = true
	editor.mode = mode
	editor.itemID = itemID
	editor.home = home
	editor.anywhere = anywhere
	editor.yaw = math.NormalizeAngle(LocalPlayer():EyeAngles().y + 180)
	ix.gui.preventSelection = true

	if mode == FURNISH_MODE_PLACE and !SetGhost(model) then
		Stop(true)

		return
	end

	-- «Переставить» из меню мебели: вещь сразу в руках.
	if mode == FURNISH_MODE_EDIT and IsValid(grab) and SetGhost(grab:GetModel()) then
		editor.moving = grab
		editor.yaw = grab:GetAngles().y
		grab:SetNoDraw(true)
	end
end)

--[[
	СВОБОДНЫЙ ПОВОРОТ. Пока зажат Shift и вещь в руках, движение мыши по
	горизонтали крутит её вокруг вертикали, а взгляд стоит на месте — вещь
	разворачивается целиком одним движением, а не по градусу на щелчок колеса.
]]
local MOUSE_YAW = 0.3

hook.Add("InputMouseApply", "ixFurnishEditor", function(cmd, x, y, angle)
	if !editor.active or !IsValid(editor.ghost) or !input.IsKeyDown(KEY_LSHIFT) then return end

	editor.yaw = math.NormalizeAngle(editor.yaw - x * MOUSE_YAW)

	cmd:SetMouseX(0)
	cmd:SetMouseY(0)

	return true
end)

-- ─────────────────────────────────────────────────────────────
-- МЕНЮ НА САМОЙ МЕБЕЛИ
-- ─────────────────────────────────────────────────────────────

--[[
	«ПЕРЕСТАВИТЬ / ЗАБРАТЬ» НА СВОЕЙ ПОСТАВЛЕННОЙ МЕБЕЛИ.

	Чья вещь — помнит сама сущность (furnOwner — персонаж, поставивший её; так
	же сохраняется и поднимается после рестарта, sv_furnish.lua). Меню
	показывается владельцу и суперадмину; права всё равно решает сервер.

	Меню вешается ТОЛЬКО НА КЛИЕНТЕ и на экземпляр, а не на класс: серверное
	GetEntityMenu глушит у сущности E (GM:PlayerUse), а мебелью бывает и
	ix_television со своим меню — оно не заменяется, а дополняется.
]]
local function OwnsFurniture(entity)
	if LocalPlayer():IsAdmin() then return true end

	local character = LocalPlayer():GetCharacter()

	return character != nil and entity:GetNetVar("furnOwner") == character:GetID()
end

local function AttachMenu(entity)
	if entity.ixFurnishMenu then return end

	local base = entity.GetEntityMenu

	entity.ixFurnishMenu = true
	entity.GetEntityMenu = function(this, client)
		local options = base and base(this, client) or {}

		if !istable(options) then
			options = {}
		end

		if !editor.active and OwnsFurniture(this) then
			options["Переставить"] = function()
				net.Start("furnish.grab")
					net.WriteEntity(this)
				net.SendToServer()
			end

			options["Забрать"] = function()
				net.Start("furnish.pickup")
					net.WriteEntity(this)
				net.SendToServer()
			end
		end

		return options
	end
end

-- Сетевая переменная приходит позже создания сущности, поэтому мебель ищется
-- обходом раз в секунду: по furnApt, которую ставит только обустройство.
timer.Create("ixFurnishMenus", 1, 0, function()
	for _, entity in ents.Iterator() do
		if !entity.ixFurnishMenu and IsValid(entity) and entity:GetNetVar("furnApt") != nil then
			AttachMenu(entity)
		end
	end
end)

net.Receive("furnish.stop", function() Stop(false) end)
hook.Add("ShutDown", "ixFurnishCleanup", function() Stop(false) end)
