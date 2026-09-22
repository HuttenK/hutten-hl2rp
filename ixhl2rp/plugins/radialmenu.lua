--[[
	Радиальное меню взаимодействия с персонажем.

	При нажатии H, в том числе при наведении на другого игрока вместо стандартного списка опций
	открывается круговое меню с плавной анимацией. Содержит наиболее
	полезные действия: передать деньги (/GiveMoney), обыскать (/CharSearch),
	запомнить (как F3), посмотреть профиль, а также любые контекстные
	опции игрока (Связать/Развязать и т.п.), добавленные другими плагинами
	через хук GetPlayerEntityMenu.
]]

local PLUGIN = PLUGIN

PLUGIN.name = "Радиальное меню"
PLUGIN.author = ""
PLUGIN.description = "Единое меню H: снаряжение, лечение и взаимодействие."

if (!CLIENT) then
	for _,name in ipairs({"hover","select","open"}) do resource.AddFile("sound/ix/ui/radial_"..name..".wav") end
	return
end

-- Русские названия и иконки для контекстных опций из GetPlayerEntityMenu.
-- Ключ — оригинальное имя опции (то, что уходит на сервер), значение —
-- {label, icon}. Неизвестные ключи показываются как есть.
local DYNAMIC_OPTIONS = {
	["Untie"]  = {"Развязать", "icon16/lock_open.png"},
	["Ziptie"] = {"Связать",   "icon16/lock.png"},
	-- "Search" намеренно не дублируем — есть базовая опция «Обыскать».
}
local DYNAMIC_SKIP = {
	["Search"] = true,
}

local function EaseOut(f)
	f = math.Clamp(f, 0, 1)
	return 1 - (1 - f) ^ 5
end

local function NormDiff(a, b)
	local d = (a - b) % 360
	if (d > 180) then d = d - 360 end
	return d
end

-- UTF-8-безопасный перенос по словам (только по пробелам). Штатный ix.util.WrapText
-- при длинном слове режет его «посимвольно» через байтовую индексацию word[i]
-- (sh_util.lua), что рвёт многобайтовую кириллицу и рисует «?». Здесь слова не
-- разбиваем — длинное слово просто остаётся целой строкой.
local function WrapTextSafe(text, maxW, font)
	surface.SetFont(font)

	if (surface.GetTextSize(text) <= maxW) then
		return {text}
	end

	local lines = {}
	local line = ""

	for _, word in ipairs(string.Explode(" ", text)) do
		local try = (line == "") and word or (line .. " " .. word)

		if (line != "" and surface.GetTextSize(try) > maxW) then
			lines[#lines + 1] = line
			line = word
		else
			line = try
		end
	end

	if (line != "") then
		lines[#lines + 1] = line
	end

	return lines
end

-- Повтор стандартного потока «запомнить» (recognition.lua), но нацеленный
-- на конкретного игрока, а не на тех, на кого смотрит прицел.
local function DoRecognize(target)
	if (!IsValid(target) or !target:IsPlayer()) then return end
	if (ix.gui.recognize) then return end

	local client = LocalPlayer()
	local character = client:GetCharacter()
	local targetCharacter = target:GetCharacter()

	if (!character or !targetCharacter) then return end
	if (target:GetNetVar("hide", 0) == targetCharacter:GetID()) then return end
	if (target:Team() == FACTION_MPF or target:Team() == FACTION_OTA) then return end

	ix.gui.recognize = true

	local name = hook.Run("GetCharacterName", target, "ic")

	Derma_StringRequest(L("recognition.rememberTitle"), L("recognition.rememberPrompt", name), "", function(text)
		ix.gui.recognize = nil

		client.recognize = client.recognize or {}
		client.recognize[targetCharacter:GetID()] = text

		local id = character:GetID()
		ix.recognize = ix.recognize or {}
		ix.recognize[id] = table.Copy(client.recognize)

		ix.data.Set("recognition", ix.recognize, false, true)

		surface.PlaySound("buttons/button17.wav")
	end, function()
		ix.gui.recognize = nil
	end)
end

local function DoGiveMoney(target)
	Derma_StringRequest("Передать деньги", "Введите сумму для передачи:", "", function(text)
		local amount = math.floor(tonumber(text) or 0)

		if (amount > 0) then
			-- Команда трассирует прицел на 96 ед.; курсор меню не меняет
			-- угол обзора, поэтому цель остаётся под прицелом.
			ix.command.Send("GiveMoney", amount)
		end
	end)
end

-- Запуск функции предмета на клиенте через штатное сетевое сообщение инвентаря
-- Helix (item.action). Сервер сам выполнит OnRun: каст-бар (SetAction), модификатор
-- навыка медицины и расход использований. У функции inject цель определяется по
-- прицелу (трасса 96 ед.); курсор меню не меняет угол обзора, поэтому персонаж,
-- на которого смотрит игрок, остаётся под прицелом.
local function RunItemFunction(item, key, data)
	local func = item and item.functions and item.functions[key]
	if (!func or func.index == nil or !item.id) then return end

	net.Start("item.action")
		net.WriteUInt(item.id, 32)
		net.WriteUInt(item.inventory_id or 0, 32)
		net.WriteUInt(func.index, item.functions_bits)
		net.WriteTable(data or {})
		net.WriteBool(false) -- без разбиения стака
	net.SendToServer()
end

-- Подменю ампутации: показывается, только если у игрока есть подходящий клинок
-- и навык медицины 5. Согласие цели спрашивает сервер.
local function BuildAmputationOptions(target)
	local client = LocalPlayer()

	if (!ix.Amputation or !client.GetItems) then return {} end
	if (!ix.Amputation.HasSkill(client:GetCharacter())) then return {} end

	local tool

	for _, item in ipairs(client:GetItems()) do
		if (istable(item) and ix.Amputation.IsTool(item)) then
			tool = item
			break
		end
	end

	if (!tool) then return {} end

	local options = {}

	for _, key in ipairs({"larm", "rarm", "lleg", "rleg"}) do
		options[#options + 1] = {
			label = L(ix.Amputation.limbs[key].phrase),
			icon = "icon16/cut.png",
			callback = function()
				if (IsValid(target)) then
					RunItemFunction(tool, "amputate", {limb = key})
				end
			end
		}
	end

	return options
end

-- Подменю пришивания: по одной опции на каждую носимую отрезанную конечность.
-- Совпадение конечности с недостающей проверяет сервер (functions.reattach).
local function BuildReattachOptions(target)
	local client = LocalPlayer()

	if (!ix.Amputation or !client.GetItems) then return {} end
	if (!ix.Amputation.HasSkill(client:GetCharacter())) then return {} end

	local options = {}

	for _, item in ipairs(client:GetItems()) do
		if (!istable(item) or !item.limb or !item.functions or !item.functions.reattach) then continue end

		options[#options + 1] = {
			label = (item.GetName and item:GetName()) or item.name or item.uniqueID,
			icon = "icon16/user_add.png",
			callback = function()
				if (IsValid(target)) then
					RunItemFunction(item, "reattach")
				end
			end
		}
	end

	return options
end

-- Подменю медикаментов: по одной опции на КАЖДЫЙ вид носимого медицинского
-- предмета (бинт, аптечка, пакет крови и т.п.). Радиальное меню открывается
-- только при взгляде на другого персонажа, поэтому применение всегда идёт на
-- цель — через функцию inject базового предмета medical.
local limbNames = {"Голова", "Торс", "Живот", "Левая рука", "Правая рука", "Левая нога", "Правая нога"}
-- Строит список опций для радиального меню по цели.
--  target     — игрок (для живого — он сам, для лежачего — владелец prop_ragdoll).
--  menuEntity — сущность для контекстных опций и проверок валидности
--               (живой игрок либо его prop_ragdoll).
--  isRagdoll  — цель в нокдауне/лежачем состоянии (взаимодействие через рэгдолл).
local function BuildOptions(target, menuEntity, isRagdoll)
	local options = {}

	if (!isRagdoll) then
		options[#options + 1] = {
			label = "Передать деньги",
			icon = "icon16/money_add.png",
			callback = function() DoGiveMoney(target) end
		}
		options[#options + 1] = {
			label = "Обыскать",
			icon = "icon16/magnifier.png",
			callback = function() ix.command.Send("CharSearch") end
		}
	else
		-- Лежачего обыскиваем через систему searchragdoll: серверный обработчик
		-- rp.search.ragdoll трассирует прицел и открывает инвентарь рэгдолла.
		options[#options + 1] = {
			label = "Обыскать",
			icon = "icon16/magnifier.png",
			callback = function()
				if (IsValid(menuEntity)) then
					net.Start("rp.search.ragdoll")
						net.WriteEntity(menuEntity)
					net.SendToServer()
				end
			end
		}
	end

	options[#options + 1] = {
		label = "Запомнить",
		icon = "icon16/user_comment.png",
		callback = function() DoRecognize(target) end
	}

	-- Уколоть транквилизатором — только по стоящему игроку (инъектор не берёт
	-- лежачего) и только если он есть в инвентаре. Применение делает серверный
	-- обработчик OnPlayerOptionSelected в плагине transvil.
	if (!isRagdoll and LocalPlayer():HasItem("tranq_injector")) then
		options[#options + 1] = {
			label = "Усыпить",
			callback = function()
				if (IsValid(target)) then
					ix.menu.NetworkChoice(target, "TranqInject")
				end
			end
		}
	end

	-- Медикаменты — применить носимый медпрепарат на цель. Работает и по лежачему:
	-- функция inject на сервере резолвит prop_ragdoll → игрока по прицелу.
	-- Ампутация и пришивание — это тоже медицина, поэтому лежат внутри «Лечить».
	local medical = {{label="Осмотр и лечение",callback=function() ix.Medicine.OpenExamination(target) end}}

	-- Резать и шить можно только стоящего: серверные проверки всё равно
	-- трассируют прицел в живого игрока, а не в его рэгдолл.
	if (!isRagdoll) then
		local amputation = BuildAmputationOptions(target)

		if (#amputation > 0) then
			medical[#medical + 1] = {
				label = L("amputation.cut"),
				icon = "icon16/cut.png",
				children = amputation
			}
		end

		local reattach = BuildReattachOptions(target)

		if (#reattach > 0) then
			medical[#medical + 1] = {
				label = L("amputation.reattach"),
				icon = "icon16/user_add.png",
				children = reattach
			}
		end
	end

	if (#medical > 0) then
		options[#options + 1] = {
			label = "Лечить",
			icon = "icon16/heart.png",
			children = medical
		}
	end

	-- Контекстные опции от плагинов: GetPlayerEntityMenu у живого игрока либо меню
	-- рэгдолла. У prop_ragdoll метод может отсутствовать — поэтому проверяем.
	local dynamic = isfunction(menuEntity.GetEntityMenu) and menuEntity:GetEntityMenu(LocalPlayer())

	if (istable(dynamic)) then
		for key, value in pairs(dynamic) do
			if (DYNAMIC_SKIP[key]) then continue end

			local info = DYNAMIC_OPTIONS[key]
			local label = info and info[1] or key
			local icon = info and info[2] or "icon16/bullet_go.png"

			options[#options + 1] = {
				label = label,
				icon = icon,
				callback = function()
					-- Точное повторение поведения стандартного меню Helix:
					-- функция-значение вызывается на клиенте; иначе выбор
					-- уходит на сервер через NetworkChoice.
					local status = true

					if (isfunction(value)) then
						status = value()
					elseif (istable(value) and isfunction(value[2])) then
						status = value[2]()
					end

					if (status != false and IsValid(menuEntity)) then
						ix.menu.NetworkChoice(menuEntity, key, status)
					end
				end
			}
		end
	end

	return options
end

-- Stable geometry: hover changes light and contrast, never the clickable position.
local function EquipmentOptions(headOnly)
 local result={}
 for _, item in pairs(LocalPlayer():GetItems()) do
  local head=({head=true,mask=true,glasses=true,ears=true})[item.equip_inv or item.equip_slot]
  if (headOnly and head) or (not headOnly and item.isWeapon) then
   local equipped=item.IsEquipped and item:IsEquipped() or item:GetData("equip",false)
   local key=equipped and "unequip" or "equip"
   if item.functions and item.functions[key] then
    result[#result+1]={label=item:GetName(), detail=equipped and "Убрать / снять" or "Экипировать",
     callback=function() RunItemFunction(item,key) end}
   end
  end
 end
 table.sort(result,function(a,b) return a.label<b.label end)
 return result
end
local function Category(label, children, detail)
 return {label=label,children=#children>0 and children or nil,disabled=#children==0,
  detail=#children>0 and detail or "Нет подходящих предметов"}
end
local function PersonalOptions(target, entity, ragdoll)
 local options={
  Category("Оружие",EquipmentOptions(false),"Экипировать / убрать"),
  {label="Лечение себя",detail="Осмотреть тело и выбрать лечение",callback=function() ix.Medicine.OpenExamination(LocalPlayer()) end},
  Category("Голова и лицо",EquipmentOptions(true),"Надеть / снять снаряжение")
 }
 if IsValid(target) and target~=LocalPlayer() then
  options[#options+1]=Category("Взаимодействие",BuildOptions(target,entity,ragdoll),"Персонаж перед вами")
 end
 return options
end
surface.CreateFont("ixRadialLabel",{font="Consolas",size=18,weight=500,extended=true})
surface.CreateFont("ixRadialSmall",{font="Consolas",size=14,weight=400,extended=true})
local red=Color(246,83,99)
local pale=Color(220,195,194)
local PANEL={}
function PANEL:Init()
 self:SetSize(ScrW(),ScrH()); self:SetPos(0,0)
 self.options={}; self.menuStack={}; self.hovered=0; self.openFrac=0
 self:MakePopup()
 self.centerName="БЫСТРЫЕ ДЕЙСТВИЯ"
 self.started=SysTime()
 self.hoverFade={}
 self:SetAlpha(0); self:AlphaTo(255,.2,0)
 surface.PlaySound("ix/ui/radial_open.wav")
end
function PANEL:SetTarget(target,entity,ragdoll,personal)
 self.character=LocalPlayer():GetCharacter()
 self.target=target or LocalPlayer(); self.menuEntity=entity or self.target; self.isRagdoll=ragdoll
 self.personal=personal
 self.fullOptions=personal and PersonalOptions(target,entity,ragdoll) or BuildOptions(target,entity,ragdoll)
 self.centerName=personal and "БЫСТРЫЕ ДЕЙСТВИЯ" or "ВЗАИМОДЕЙСТВИЕ"
 self.page=1; self:PageOptions()
end
function PANEL:PageOptions()
 self.options={}
 local count=#self.fullOptions
 local size=count>6 and 4 or 6
 local pages=math.max(1,math.ceil(count/size))
 self.page=math.Clamp(self.page or 1,1,pages)
 for i=(self.page-1)*size+1,math.min(self.page*size,count) do self.options[#self.options+1]=self.fullOptions[i] end
 if pages>1 then
  self.options[#self.options+1]={label="Предыдущие",pageDelta=-1,disabled=self.page==1,detail=self.page.." / "..pages}
  self.options[#self.options+1]={label="Следующие",pageDelta=1,disabled=self.page==pages,detail=self.page.." / "..pages}
 end
 if #self.menuStack>0 then self.options[#self.options+1]={label="Назад",isBack=true} end
 self.hovered=0; self.hoverFade={}
 self:SetAlpha(145); self:AlphaTo(255,.14,0)
end
function PANEL:PushOptions(options,name)
 self.menuStack[#self.menuStack+1]={options=self.fullOptions,name=self.centerName,page=self.page}
 self.fullOptions=options; self.centerName=name; self.page=1; self:PageOptions()
end
function PANEL:PopOptions()
 local entry=table.remove(self.menuStack)
 if not entry then return false end
 self.fullOptions=entry.options; self.centerName=entry.name; self.page=entry.page; self:PageOptions()
 return true
end
function PANEL:Geometry()
 local r=math.min(ScrH()*.29,310)
 return ScrW()*.5,ScrH()*.5,r,r*.43
end
function PANEL:Think()
 if not IsValid(LocalPlayer()) or not LocalPlayer():Alive() or not self.character or LocalPlayer():GetCharacter()~=self.character then self:Remove() return end
 if not self.personal and (not IsValid(self.target) or not IsValid(self.menuEntity)) then self:Remove() return end
 if input.IsKeyDown(KEY_ESCAPE) then self:Remove() return end
 self.openFrac=EaseOut((SysTime()-self.started)/.24)
 local cx,cy,r,inner=self:Geometry()
 local mx,my=gui.MousePos(); local dx,dy=mx-cx,my-cy
 local distance=math.sqrt(dx*dx+dy*dy)
 local hover=0
 if #self.options>0 and distance>=inner and distance<=r then
  local angle=math.deg(math.atan2(dy,dx))
  for i=1,#self.options do
   if math.abs(NormDiff(angle,-90+(i-1)*360/#self.options))<=180/#self.options then hover=i break end
  end
 end
 if hover~=self.hovered and hover>0 then surface.PlaySound("ix/ui/radial_hover.wav") end
 self.hovered=hover
 for i=1,#self.options do self.hoverFade[i]=Lerp(math.min(FrameTime()*12,1),self.hoverFade[i] or 0,i==hover and 1 or 0) end
end
local function Arc(cx,cy,inner,outer,start,finish)
 for i=0,23 do
  local a,b=math.rad(Lerp(i/24,start,finish)),math.rad(Lerp((i+1)/24,start,finish))
  surface.DrawPoly({{x=cx+math.cos(a)*inner,y=cy+math.sin(a)*inner},
   {x=cx+math.cos(a)*outer,y=cy+math.sin(a)*outer},
   {x=cx+math.cos(b)*outer,y=cy+math.sin(b)*outer},
   {x=cx+math.cos(b)*inner,y=cy+math.sin(b)*inner}})
 end
end
function PANEL:Paint(w,h)
 local cx,cy,r,inner=self:Geometry()
 local a=self.openFrac
 surface.SetDrawColor(4,3,6,90*a); surface.DrawRect(0,0,w,h)
 draw.NoTexture()
 local count=#self.options
 for i,opt in ipairs(self.options) do
  local center=-90+(i-1)*360/count
  local from,to=center-180/count+1.2,center+180/count-1.2
  local selected=i==self.hovered and not opt.disabled
  local glow=opt.disabled and 0 or (self.hoverFade[i] or 0)
  surface.SetDrawColor(0,0,0,110*a); Arc(cx,cy+4,inner-5,r+6,from,to)
  surface.SetDrawColor(14+44*glow,10,13+7*glow,235*a)
  Arc(cx,cy,inner,r,from,to)
  surface.SetDrawColor(246,83,99,(55+175*glow)*a); Arc(cx,cy,r-2,r,from,to)
  if glow>.01 then
   surface.SetDrawColor(246,83,99,24*a*glow); Arc(cx,cy,r+2,r+8,from,to)
  end
  local angle=math.rad(center); local mid=(inner+r)*.5
  local x,y=cx+math.cos(angle)*mid,cy+math.sin(angle)*mid
  local lines=WrapTextSafe(opt.label,math.min(r*.48,150),"ixRadialLabel")
  local color=opt.disabled and Color(115,98,100) or (selected and red or pale)
  for n,line in ipairs(lines) do
   draw.SimpleTextOutlined(line,"ixRadialLabel",x,y+(n-(#lines+1)*.5)*20,color,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(0,0,0,220))
  end
  draw.SimpleText(string.format("%02d",i),"ixRadialSmall",x,y-(#lines*10)-12,Color(170,78,91),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 end
 surface.SetDrawColor(8,5,8,230*a); Arc(cx,cy,0,inner-8,0,360)
 surface.SetDrawColor(246,83,99,90*a); Arc(cx,cy,inner-9,inner-8,0,360)
 local selected=self.options[self.hovered]
 local label=selected and selected.label or self.centerName
 local lines=WrapTextSafe(label,inner*1.5,"ixRadialLabel")
 for i,line in ipairs(lines) do draw.SimpleText(line,"ixRadialLabel",cx,cy+(i-(#lines+1)*.5)*20-8,red,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER) end
 draw.SimpleText(selected and selected.disabled and "НЕДОСТУПНО" or "ВЫБРАТЬ", "ixRadialSmall",cx,cy+inner*.5,pale,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 draw.SimpleText(selected and selected.detail or "", "ixRadialLabel",cx,cy+r+30,pale,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
 draw.SimpleText("ЛКМ — ВЫБОР    /    ПКМ — НАЗАД    /    ESC — ЗАКРЫТЬ", "ixRadialSmall",cx,cy+r+58,Color(160,136,139),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER)
end
function PANEL:OnMousePressed(code)
 if code==MOUSE_RIGHT then if not self:PopOptions() then self:Remove() end return end
 if code~=MOUSE_LEFT then return end
 local opt=self.options[self.hovered]
 if not opt or opt.disabled then return end
 surface.PlaySound("ix/ui/radial_select.wav")
 if opt.isBack then self:PopOptions()
 elseif opt.pageDelta then self.page=self.page+opt.pageDelta; self:PageOptions()
 elseif opt.children then self:PushOptions(opt.children,opt.label)
 else
  local callback=opt.callback
  self:Remove()
  if callback then callback() end
 end
end
function PANEL:CloseMenu() self:Remove() end
function PANEL:OnKeyCodePressed(code)
 if code==KEY_ESCAPE then self:Remove() end
end
function PANEL:OnRemove() if ix.gui.charRadial==self then ix.gui.charRadial=nil end end
vgui.Register("ixCharRadialMenu",PANEL,"EditablePanel")

-- По сущности под прицелом возвращает (target, menuEntity, isRagdoll) либо nil.
-- Живой игрок — он сам. prop_ragdoll лежачего/мертвого игрока — резолвим владельца
-- по сетевой переменной "doll" (ставится в !healthsystem на нокдаун, networked всем).
local function ResolveTarget(entity)
	if (!IsValid(entity)) then return end

	if (entity:IsPlayer()) then
		if (entity == LocalPlayer() or !entity:GetCharacter()) then return end
		return entity, entity, false
	end

	if (entity:GetClass() == "prop_ragdoll") then
		local ply = IsValid(entity.ixPlayer) and entity.ixPlayer or nil

		if (!IsValid(ply)) then
			for _, p in ipairs(player.GetAll()) do
				local doll = p:GetNetVar("doll")

				if (doll and Entity(doll) == entity) then
					ply = p
					break
				end
			end
		end

		if (IsValid(ply) and ply != LocalPlayer() and ply:GetCharacter()) then
			return ply, entity, true
		end
	end
end

-- Открыть радиальное меню по сущности (игрок или его рэгдолл). true — если открыли
-- (либо меню уже открыто), чтобы подавить стандартный список опций Helix.
function PLUGIN:OpenRadialOn(entity)
	local target, menuEntity, isRagdoll = ResolveTarget(entity)
	if (!target) then return end

	if (IsValid(ix.gui.charRadial)) then
		return true
	end

	local panel = vgui.Create("ixCharRadialMenu")
	panel:SetTarget(target, menuEntity, isRagdoll, true)

	ix.gui.charRadial = panel

	return true
end

-- Перехват стандартного меню сущности (живые персонажи + рэгдоллы, которым плагины
-- выдали GetEntityMenu).
function PLUGIN:ShowEntityMenu(entity)
 -- Character interactions now share H with self actions. Keep E for world use.
 if ResolveTarget(entity) then return true end
end
hook.Remove("KeyRelease", "ixRadialRagdoll")
hook.Remove("PlayerButtonDown", "ixRadialHotkey")

-- H is a default convenience key; +ix_radial can be rebound independently.
concommand.Add("ix_radial",function()
 local client=LocalPlayer()
 if not IsValid(client) or not client:GetCharacter() or not client:Alive() then return end
 if IsValid(ix.gui.charRadial) then ix.gui.charRadial:Remove() return end
 if ix.Medicine and IsValid(ix.Medicine.examination) then ix.Medicine.examination:Remove() end
 if ix.menu.IsOpen() or gui.IsGameUIVisible() then return end
 local focus=vgui.GetKeyboardFocus()
 if IsValid(focus) and (focus:GetClassName()=="TextEntry" or focus:GetName()=="DTextEntry") then return end
 local tr=util.TraceLine({start=client:GetShootPos(),endpos=client:GetShootPos()+client:GetAimVector()*96,filter=client})
 local target,entity,ragdoll=ResolveTarget(tr.Entity)
 local panel=vgui.Create("ixCharRadialMenu")
 panel:SetTarget(target,entity,ragdoll,true)
 ix.gui.charRadial=panel
end)
concommand.Add("+ix_radial",function() RunConsoleCommand("ix_radial") end)
concommand.Add("-ix_radial",function() end)
local defaultKey=CreateClientConVar("ix_radial_default_h","1",true,false,"Open quick actions with H; disable to use your own bind.")
-- Client polling also works in single-player, where predicted PlayerButtonDown
-- does not run clientside. One edge per press; the panel never closes on that
-- same key event. An explicit H bind owns input to avoid toggling twice.
local wasDown=input.IsKeyDown(KEY_H)
hook.Add("Think","ixRadialHotkey",function()
 local down=input.IsKeyDown(KEY_H)
 local pressed=down and not wasDown
 wasDown=down
 if not pressed or not defaultKey:GetBool() then return end
 local binding=input.LookupKeyBinding and input.LookupKeyBinding(KEY_H)
 if binding and binding:find("ix_radial",1,true) then return end
 RunConsoleCommand("ix_radial")
end)
