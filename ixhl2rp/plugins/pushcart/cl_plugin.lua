local PushCart = ix.PushCart

local CART_REFRESH = 0.5
local NEAR_RANGE = 250
local HINT_TEXT = "ГРУЗОВОЙ ЯЩИК · E — ДЕЙСТВИЯ"
local HINT_COLOR = Color(220, 220, 220, 230)
local HINT_SHADOW = Color(0, 0, 0, 200)

local nearbyCarts = {}
local nextRefresh = 0

-- Луч к ящикам пересчитывается не каждый кадр, а с этой частотой.
local AIM_REFRESH = 0.1
local nextAim = 0
local aimingAtCrate = false

local function RefreshCarts(client)
	nearbyCarts = PushCart:FindCartsNear(client:GetPos(), NEAR_RANGE)
end

-- Share the same non-solid crate selection as the server menu.
local function IsAimingAtCrate(client)
	local target = PushCart:InteractionTarget(client)
	return IsValid(target) and target.isCargoCrate and IsValid(target:GetParent())
end

hook.Add("HUDPaint", "ixPushCartHint", function()
	local client = LocalPlayer()

	if !IsValid(client) or !client:GetCharacter() or PushCart:IsPushing(client) then
		return
	end

	if CurTime() >= nextRefresh then
		nextRefresh = CurTime() + CART_REFRESH
		RefreshCarts(client)
	end

	if #nearbyCarts == 0 then
		return
	end

	if CurTime() >= nextAim then
		nextAim = CurTime() + AIM_REFRESH
		aimingAtCrate = IsAimingAtCrate(client)
	end

	if !aimingAtCrate then
		return
	end

	draw.SimpleTextOutlined(HINT_TEXT, "ixSmallFont", ScrW() * 0.5, ScrH() * 0.5 + ScrH() * 0.04,
		HINT_COLOR, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, HINT_SHADOW)
end)

--[[
	ЗАПИСЬ КАДРОВ: ix_pushcart_trace [секунды] - пока везёшь тележку (или стоишь рядом), каждый кадр
	пишется, где движок держит тело толкающего (в Think и в PreRender), где сущность тележки и где её
	нарисовали, номер снимка хода, по какому отрезку снимков её поставили, сколько раз за кадр
	спрашивали позу и сколько из них - до PreRender. Файл - data/pushcart_trace.txt, в консоль -
	короткая сводка. По нему видно, что именно идёт рывками: тело, сущность или отрисовка.
]]
local TRACE_FILE = "pushcart_trace.txt"
local TRACE_MAX = 30

local trace

local function Num(value)
	return string.format("%.3f", value or 0)
end

local function TraceCart(client)
	local cart = PushCart:GetPushedCart(client)

	if IsValid(cart) then
		return cart
	end

	return PushCart:FindCartsNear(client:GetPos(), NEAR_RANGE)[1]
end

local function FinishTrace()
	local data = trace

	trace = nil
	hook.Remove("Think", "ixPushCartTrace")
	hook.Remove("PreRender", "ixPushCartTrace")
	hook.Remove("PostRender", "ixPushCartTrace")

	if IsValid(data.cart) then
		data.cart.GetDrawPose = nil
	end

	local rows = data.rows
	local stuck, moving, early = 0, 0, 0

	for i = 2, #rows do
		local a, b = rows[i - 1], rows[i]

		-- Тело сдвинулось, а нарисованная тележка - нет: шаг «по кадрам».
		if b.bodyMoved > 0.01 then
			moving = moving + 1

			if b.drawMoved < 0.001 then
				stuck = stuck + 1
			end
		end

		early = early + (b.early > 0 and 1 or 0)
	end

	local lines = {data.header, "frame,systime,frametime,curtime,tick,think_x,think_y,pre_x,pre_y,pre_z,eye_x,eye_y,"
		.. "ent_x,ent_y,ent_z,ent_yaw,draw_x,draw_y,draw_z,draw_yaw,source,push_cmd,samples,segment,t,body_delay,"
		.. "calls,early"}

	for _, row in ipairs(rows) do
		lines[#lines + 1] = row.line
	end

	file.Write(TRACE_FILE, table.concat(lines, "\n"))

	MsgN(string.format("[тележка %s] записано кадров: %d в data/%s. Тело шло, а тележка стояла: %d из %d; "
		.. "поза спрошена до PreRender: %d кадров.", PushCart.BUILD, #rows, TRACE_FILE, stuck, moving, early))
end

concommand.Add("ix_pushcart_trace", function(_, _, arguments)
	local client = LocalPlayer()

	if trace or !IsValid(client) then
		return
	end

	local cart = TraceCart(client)

	if !IsValid(cart) or !cart.GetDrawPose then
		MsgN("[тележка] рядом нет тележки")

		return
	end

	local seconds = math.Clamp(tonumber(arguments[1]) or 5, 1, TRACE_MAX)
	local classDrawPose = cart.GetDrawPose
	local convar = function(name)
		local value = GetConVar(name)

		return value and value:GetString() or "-"
	end

	trace = {
		cart = cart,
		rows = {},
		finish = SysTime() + seconds,
		header = string.format("# build %s singleplayer %s tick %.4f cl_interp %s cl_interp_ratio %s cl_updaterate %s "
			.. "cl_cmdrate %s fps_max %s host_timescale %s", PushCart.BUILD, tostring(game.SinglePlayer()),
			engine.TickInterval(), convar("cl_interp"), convar("cl_interp_ratio"), convar("cl_updaterate"),
			convar("cl_cmdrate"), convar("fps_max"), convar("host_timescale")),
		calls = 0,
		early = 0,
		rendering = false
	}

	-- Сколько раз за кадр спросили позу и сколько - до PreRender (кости собрали раньше отрисовки).
	cart.GetDrawPose = function(self)
		if trace then
			trace.calls = trace.calls + 1

			if !trace.rendering then
				trace.early = trace.early + 1
			end
		end

		return classDrawPose(self)
	end

	hook.Add("Think", "ixPushCartTrace", function()
		if !trace then
			return
		end

		trace.rendering = false
		trace.thinkPos = IsValid(client) and client:GetPos() or Vector()
	end)

	hook.Add("PreRender", "ixPushCartTrace", function()
		if !trace then
			return
		end

		trace.rendering = true
		trace.prePos = IsValid(client) and client:GetPos() or Vector()
	end)

	hook.Add("PostRender", "ixPushCartTrace", function()
		if !trace then
			return
		end

		local target = trace.cart

		if !IsValid(target) or !IsValid(client) or SysTime() > trace.finish then
			FinishTrace()

			return
		end

		local thinkPos, prePos, eye = trace.thinkPos or Vector(), trace.prePos or Vector(), EyePos()
		-- Не GetPos: при подмене отрисовки он отдаёт нарисованную позу, а не сущность.
		local entPos, entAng = PushCart:RealPose(target)
		local drawPos, drawAng = classDrawPose(target)
		local state = target.drawState
		local samples = target.ixSamples
		local last = trace.last
		local row = {
			bodyMoved = last and (prePos - last.prePos):Length2D() or 0,
			drawMoved = last and (drawPos - last.drawPos):Length() or 0,
			early = trace.early,
			prePos = prePos,
			drawPos = drawPos
		}

		row.line = table.concat({
			FrameNumber(), string.format("%.5f", SysTime()), string.format("%.5f", FrameTime()), Num(CurTime()),
			engine.TickCount(), Num(thinkPos.x), Num(thinkPos.y), Num(prePos.x), Num(prePos.y), Num(prePos.z),
			Num(eye.x), Num(eye.y), Num(entPos.x), Num(entPos.y), Num(entPos.z), Num(entAng.y), Num(drawPos.x),
			Num(drawPos.y), Num(drawPos.z), Num(drawAng.y), state and state.source or "-",
			target.GetPushCmd and target:GetPushCmd() or 0, samples and #samples or 0, target.ixAlongSegment or 0,
			Num(target.ixAlongT or -1), Num(target.ixBodyDelay or -1), trace.calls, trace.early
		}, ",")

		trace.rows[#trace.rows + 1] = row
		trace.last = row
		trace.calls, trace.early = 0, 0
	end)

	MsgN(string.format("[тележка %s] пишу кадры %d с...", PushCart.BUILD, seconds))
end)
