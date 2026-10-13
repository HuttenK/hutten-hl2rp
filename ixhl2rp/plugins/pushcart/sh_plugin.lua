--[[
	Грузовая тележка (ix_pushcart).

	Возит до восьми грузовых ящиков (ix_cargo_crate). Вещи хранятся
	в самих ящиках; отдельного инвентаря у тележки нет.

		E на тележку или ящик - открыть список действий;
		поднести ящик к кузову - автоматически закрепить в свободном месте;
		E на закреплённый ящик - отсоединить именно выбранный ящик.
		E на пустую тележку при перетаскивании персонажа - уложить его;
		E на пассажира - осмотр, снять и тащить или положить рядом.
		Персонаж занимает весь кузов. При выздоровлении освобождается
		рядом с тележкой; состояние пациента не сохраняется как груз.

	Сложенная тележка - предмет pushcart (items/pushcart.lua), ставится
	действием «Установить». Сложить можно только пустую свободную тележку.

	Тележку, которую везут, шагает движение толкающего (sh_kinematics.lua -
	поза, sh_drive.lua - хуки хода, предсказание и отрисовка). Кто кого везёт,
	клиенты узнают из снимка: NW2-сущность «ixPushCart» на игроке и Pusher в
	дататейбле тележки, в одном снимке с позой хода. Надёжная сеть приходила
	вразнобой со снимком, и предсказание шага (здесь и в
	!healthsystem/sh_movement.lua) расходилось с сервером на каждом переключении.
]]

local PLUGIN = PLUGIN

PLUGIN.name = "Push Cart"
PLUGIN.author = "Autonomous"
PLUGIN.description = "Грузовая тележка: перевозка ящиков или лежащего персонажа."

ix.PushCart = ix.PushCart or {}

local PushCart = ix.PushCart

-- Model constants and the stable Kin table are created in libs/sh_bootstrap.lua
-- before Helix registers the entity files.
PushCart.GEOMETRY_VERSION = 3
-- Метка версии кода для отладки (ix_pushcart_debug): видно, что сервер крутит свежий файл.
PushCart.BUILD = "foundation-2026-10-13.ep2"
PushCart.ITEM = "pushcart"
PushCart.MAX_CRATES = 8
PushCart.INV_WIDTH = 6
PushCart.INV_HEIGHT = 6

--[[
	ТЯЖЕСТЬ. Всё ниже - от загруженности 0..1 (ENT:UpdateLoad): пустая
	тележка катится легко, гружёная - тяжело.

	Ящик весит в загрузке от половины (пустая тара) до целого (полный, 20 ед.),
	вся загрузка определяется ящиками и их содержимым.
]]
PushCart.CRATE_UNITS_FULL = 20

-- Потолок скорости толкающего (доля шага).
PushCart.SPEED_EMPTY = 0.85
PushCart.SPEED_FULL = 0.5

-- Разгон толкающего, ед/с²: с места гружёную тележку не сорвать сразу.
PushCart.ACCEL_EMPTY = 160
PushCart.ACCEL_FULL = 50
PushCart.START_SPEED = 10

-- Поворот, град/с и град/с²: разворачивают с размаху, а не крутят на месте (Kin.TurnTowards).
PushCart.TURN_RATE_EMPTY = 100
PushCart.TURN_RATE_FULL = 35
PushCart.TURN_ACCEL_EMPTY = 260
PushCart.TURN_ACCEL_FULL = 60

-- Дальность E по тележке и ящикам на ней.
PushCart.USE_RANGE = 110

--[[
	РЕЕСТР ТЕЛЕЖЕК. ents.FindByClass обходит ВСЕ сущности карты, а звали его
	на каждое E любого игрока и несколько раз в секунду на клиенте. Тележки
	сами записываются сюда в Initialize и выписываются в OnRemove (клиент
	ещё и в Think: полное обновление зовёт OnRemove живой сущности).
]]
PushCart.carts = PushCart.carts or {}

function PushCart:Register(cart)
	self.carts[cart] = true
end

function PushCart:Unregister(cart)
	self.carts[cart] = nil
end

--- Тележки не дальше range от точки. Невалидные выписываются по ходу.
function PushCart:FindCartsNear(position, range)
	local found = {}
	local maxDistance = range * range

	for cart in pairs(self.carts) do
		if !IsValid(cart) then
			self.carts[cart] = nil
		elseif cart:GetPos():DistToSqr(position) <= maxDistance then
			found[#found + 1] = cart
		end
	end

	return found
end

function PushCart:IsLoadable(entity)
	return IsValid(entity) and entity.isCargoCrate == true
end

--[[
	Тележка, которую везёт игрок. Ссылка на игроке и Pusher тележки обязаны
	совпасть: одна без другой - это переключение, пришедшее наполовину (или
	устаревшая ссылка), и шагать по ней нельзя. На клиенте так же видно и
	чужих толкающих - по ним руки ложатся на ручку (cl_ik.lua).
]]
function PushCart:GetPushedCart(client)
	-- Ссылка может прийти до SetupDataTables; NetworkVar ещё не создал GetPusher.
	-- Пока обе стороны связи не готовы, игрок не считается толкающим.
	if SERVER then
		local cart = client.ixPushCart

		return IsValid(cart) and cart.GetPusher and cart:GetPusher() == client and cart or nil
	end

	local cart = client:GetNW2Entity("ixPushCart")

	return IsValid(cart) and cart:GetClass() == "ix_pushcart" and cart.GetPusher and cart:GetPusher() == client and cart or nil
end

function PushCart:IsPushing(client)
	return self:GetPushedCart(client) != nil
end

function PushCart:GetLoad(client)
	local cart = self:GetPushedCart(client)

	return IsValid(cart) and cart.GetCargoLoad and cart:GetCargoLoad() or 0
end

function PushCart:GetSpeedFactor(client)
	return Lerp(self:GetLoad(client), self.SPEED_EMPTY, self.SPEED_FULL)
end

--[[
	Разгон без накопленного состояния: потолок скорости - текущая скорость
	плюс прибавка за тик. Скорость предсказывается движком, значит клиент и
	сервер считают одно и то же; счётчик «сколько уже разгоняемся» дал бы
	резину на повторных прогонах SetupMove - так её уже ловили в
	sh_movement.lua (накопительный Lerp разгона бега).
	В тележку толкающего не пускает не этот потолок, а шаг тележки: он
	подрезает ход в той же команде (sh_drive.lua, FinishMove).
]]
function PushCart:CapAcceleration(client, mv)
	local accel = Lerp(self:GetLoad(client), self.ACCEL_EMPTY, self.ACCEL_FULL)
	local speed = mv:GetVelocity():Length2D()
	local cap = math.max(speed, self.START_SPEED) + accel * engine.TickInterval()

	if cap < mv:GetMaxClientSpeed() then
		mv:SetMaxClientSpeed(cap)
		mv:SetMaxSpeed(cap)
	end
end

-- Руки заняты ручкой: ни бега, ни прыжка, ни приседа, ни ударов.
local BLOCKED_KEYS = bit.bor(IN_SPEED, IN_JUMP, IN_DUCK, IN_ATTACK, IN_ATTACK2)

function PLUGIN:StartCommand(client, cmd)
	if PushCart:IsPushing(client) then
		cmd:RemoveKey(BLOCKED_KEYS)
	end
end

hook.Add("prone.CanEnter", "ixPushCart", function(client)
	if PushCart:IsPushing(client) then
		return false
	end
end)

--[[
	МЕЛОЧЬ ТЕЛЕЖКУ НЕ ОСТАНАВЛИВАЕТ. Банка или бутылка под колесом поднимала
	его, и тележку валило набок. Сквозь мелкие пропы и брошенные предметы она
	проезжает; ящики груза, мебель и всё крупное по-прежнему упирается.

	Само правило - PushCart:CartIgnores (sh_drive.lua): по нему же трассы хода
	решают, во что тележка упирается, так что физика отпущенной и ход везомой
	не расходятся. Оно зависит только от модели и класса - одинаково на
	клиенте и сервере и не меняется за жизнь сущности (иначе понадобился бы
	CollisionRulesChanged).
]]
PushCart.SMALL_PROP_RADIUS = 20

hook.Add("ShouldCollide", "ixPushCart", function(a, b)
	local other

	if a.ixIsPushCart then
		other = b
	elseif b.ixIsPushCart then
		other = a
	else
		return
	end

	if PushCart:CartIgnores(other) then
		return false
	end
end)

-- The recovered economy/lathe catalogue is not part of Foundation. Native
-- deployable items and the admin spawn menu provide carts and cargo crates.
PushCart.FALLBACK_MODEL = "models/hunter/plates/plate1x1.mdl"
PushCart.CRATE_MODEL = "models/props_junk/wood_crate001a.mdl"
PushCart.crates = PushCart.crates or {}
PushCart.plugin = PLUGIN

function PushCart:CanOperate(client)
	return IsValid(client) and client:IsPlayer() and client:Alive() and client:GetCharacter()
		and client:GetMoveType() == MOVETYPE_WALK and !client:InVehicle()
		and !client:GetNetVar("restricted", false) and !client:GetNetVar("brth", false)
		and !(client.IsProne and client:IsProne())
		and !(ix.Downed and ix.Downed.Active and ix.Downed.Active(client))
end

-- Shared cap called by health movement after injury modifiers. Its early
-- return resets stale sprint state and makes plugin hook order irrelevant.
function PushCart:LimitMovement(client, mv, baseSpeed)
	if !self:IsPushing(client) then return false end
	if client.SetSprintMove then client:SetSprintMove(false) end
	if client.SetSprintSpeed then client:SetSprintSpeed(0) end
	if client.SetRunFading then client:SetRunFading(false) end
	mv:SetButtons(bit.band(mv:GetButtons(), bit.bnot(BLOCKED_KEYS)))
	local limit = baseSpeed * self:GetSpeedFactor(client)
	mv:SetMaxClientSpeed(limit)
	mv:SetMaxSpeed(limit)
	self:CapAcceleration(client, mv)
	return true
end

ix.util.Include("sh_kinematics.lua")
ix.util.Include("sh_drive.lua")
ix.util.Include("sh_patient.lua")
ix.util.Include("sh_interaction.lua")
ix.util.Include("sv_plugin.lua")
ix.util.Include("sv_interaction.lua")
ix.util.Include("sv_patient.lua")
ix.util.Include("sv_legacy.lua")
ix.util.Include("cl_plugin.lua")
ix.util.Include("cl_interaction.lua")
ix.util.Include("cl_ik.lua")
