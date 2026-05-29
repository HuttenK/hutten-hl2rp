local PLUGIN = PLUGIN

PLUGIN.name        = "Cinematic Subtitle Points"
PLUGIN.author      = "Hutten"
PLUGIN.description = "Кинематографические субтитры с поддержкой точек активации в мире."

-- ─────────────────────────────────────────────
-- ЛОКАЛИЗАЦИЯ
-- ─────────────────────────────────────────────

ix.lang.AddTable("en", {
	cmdSubtitleDesc          = "Cinematic subtitle. Usage: /subtitle [all|range] <sec> [sc:COLOR] [tc:COLOR] <Speaker_Name> <text>",
	cmdSubtitleClearDesc     = "Clear all active subtitles from everyone's screen.",
	cmdSubtitlePointDesc     = "Place a subtitle trigger where you are looking. Usage: /subtitlepoint <sec> [dc:COLOR] [sc:COLOR] [tc:COLOR] <Speaker_Name> <text>",
	cmdSubtitlePointRemDesc  = "Remove the nearest subtitle trigger point (look at it, within 200u).",
	cmdSubtitlePointListDesc = "List all active subtitle trigger points.",
	subtitlePointHint        = "Press E to activate",
	subtitlePointRemoved     = "Subtitle point removed.",
	subtitlePointNotFound    = "No subtitle point found nearby.",
	subtitlePointPlaced      = "Subtitle point placed.",
})

ix.lang.AddTable("ru", {
	cmdSubtitleDesc          = "Субтитр. Использование: /subtitle [all|range] <сек> [sc:ЦВЕТ] [tc:ЦВЕТ] <Имя_спикера> <текст>",
	cmdSubtitleClearDesc     = "Убрать все активные субтитры с экранов игроков.",
	cmdSubtitlePointDesc     = "Разместить точку туда, куда смотрит игрок. Использование: /subtitlepoint <сек> [dc:ЦВЕТ] [sc:ЦВЕТ] [tc:ЦВЕТ] <Имя_спикера> <текст>",
	cmdSubtitlePointRemDesc  = "Удалить ближайшую точку субтитра (смотрите на неё, до 200u).",
	cmdSubtitlePointListDesc = "Список всех точек активации субтитров.",
	subtitlePointHint        = "Нажмите E для активации",
	subtitlePointRemoved     = "Точка субтитра удалена.",
	subtitlePointNotFound    = "Рядом нет точки субтитра.",
	subtitlePointPlaced      = "Точка субтитра размещена.",
})

-- ─────────────────────────────────────────────
-- ОБЩЕЕ: ПАРСИНГ ЦВЕТОВ
-- ─────────────────────────────────────────────

local colorAliases = {
	red    = "255,60,60",
	blue   = "80,140,255",
	yellow = "255,220,50",
	black  = "20,20,20",
	white  = "255,255,255",
	green  = "80,210,100",
	orange = "255,150,30",
}

local function parseColor(str)
	str = colorAliases[str:lower()] or str
	local r, g, b = str:match("^(%d+),(%d+),(%d+)$")
	if r then
		return Color(tonumber(r), tonumber(g), tonumber(b))
	end
end

-- Разбирает общую часть аргументов: [sc:X] [tc:X] Speaker Text
-- Возвращает: speakerColor, textColor, speaker, text
local function parseSubtitleArgs(args, offset)
	local speakerColor, textColor

	while args[offset] do
		local prefix, value = args[offset]:match("^(sc):(.+)$")
		if prefix then
			speakerColor = parseColor(value)
			offset = offset + 1
		else
			prefix, value = args[offset]:match("^(tc):(.+)$")
			if prefix then
				textColor = parseColor(value)
				offset    = offset + 1
			else
				break
			end
		end
	end

	local rest          = table.concat(args, " ", offset)
	local speaker, text = rest:match("^(%S+)%s+(.+)$")

	if not speaker or not text then
		speaker = ""
		text    = rest
	end

	speaker = speaker:gsub("_", " ")

	return speakerColor, textColor, speaker, text
end

local function packPayload(duration, speakerColor, textColor, speaker, text)
	return {
		speaker      = speaker,
		text         = text,
		duration     = duration,
		speakerColor = speakerColor and {speakerColor.r, speakerColor.g, speakerColor.b} or nil,
		textColor    = textColor    and {textColor.r,    textColor.g,    textColor.b}    or nil,
	}
end

-- ─────────────────────────────────────────────
-- КОМАНДЫ  (shared — обязательно вне if SERVER)
-- ─────────────────────────────────────────────

-- /subtitle [all|range] <sec> [sc:COLOR] [tc:COLOR] <Speaker_Name> <text>
ix.command.Add("Subtitle", {
	description = "@cmdSubtitleDesc",
	adminOnly   = true,
	arguments   = ix.type.text,

	OnRun = function(self, client, rawArgs)
		if CLIENT then return end

		local args   = string.Explode(" ", rawArgs)
		local mode   = "range"
		local offset = 1

		if args[1] == "all" or args[1] == "range" then
			mode   = args[1]
			offset = 2
		end

		local duration = tonumber(args[offset])
		if not duration then
			client:Notify("Usage: /subtitle [all|range] <sec> [sc:COLOR] [tc:COLOR] <Speaker_Name> <text>")
			return
		end
		duration = math.Clamp(duration, 1, 30)

		local sc, tc, speaker, text = parseSubtitleArgs(args, offset + 1)
		local payload = packPayload(duration, sc, tc, speaker, text)

		if mode == "all" then
			netstream.Start(nil, "ixSubtitleShow", payload)
		else
			local senderPos = client:GetPos()
			local receivers = {}
			for _, ply in ipairs(player.GetAll()) do
				if ply:GetPos():DistToSqr(senderPos) <= (1500 * 1500) then
					receivers[#receivers + 1] = ply
				end
			end
			if #receivers > 0 then
				netstream.Start(receivers, "ixSubtitleShow", payload)
			end
		end
	end
})

ix.command.Add("SubtitleClear", {
	description = "@cmdSubtitleClearDesc",
	adminOnly   = true,

	OnRun = function(self, client)
		if CLIENT then return end
		netstream.Start(nil, "ixSubtitleClear")
	end
})

-- /subtitlepoint <sec> [dc:COLOR] [sc:COLOR] [tc:COLOR] <Speaker_Name> <text>
-- dc = dot color (цвет точки в мире), sc = speaker color, tc = text color
ix.command.Add("SubtitlePoint", {
	description = "@cmdSubtitlePointDesc",
	adminOnly   = true,
	arguments   = ix.type.text,

	OnRun = function(self, client, rawArgs)
		if CLIENT then return end

		local args     = string.Explode(" ", rawArgs)
		local duration = tonumber(args[1])

		if not duration then
			client:Notify("Usage: /subtitlepoint <sec> [dc:COLOR] [sc:COLOR] [tc:COLOR] <Speaker_Name> <text>")
			return
		end
		duration = math.Clamp(duration, 1, 30)

		-- Парсим dc: отдельно перед общими цветами
		local offset   = 2
		local dotColor = nil

		while args[offset] do
			local prefix, value = args[offset]:match("^(dc):(.+)$")
			if prefix then
				dotColor = parseColor(value)
				offset   = offset + 1
			else
				break
			end
		end

		local sc, tc, speaker, text = parseSubtitleArgs(args, offset)
		local payload = packPayload(duration, sc, tc, speaker, text)

		-- Цвет точки передаём в payload
		payload.dotColor = dotColor and {dotColor.r, dotColor.g, dotColor.b} or nil

		-- Позиция — куда смотрит игрок (трассировка взгляда)
		local tr = util.TraceLine({
			start  = client:GetShootPos(),
			endpos = client:GetShootPos() + client:GetAimVector() * 512,
			filter = client,
			mask   = MASK_SOLID,
		})
		local spawnPos = tr.Hit and tr.HitPos or client:GetPos()

		-- Привязка к пропу: если трассировка попала в физический объект
		local attachEnt    = nil
		local attachOffset = nil
		local hitEnt = tr.Entity

		if IsValid(hitEnt) and !hitEnt:IsPlayer() and !hitEnt:IsWorld() then
			attachEnt    = hitEnt:EntIndex()
			attachOffset = hitEnt:WorldToLocal(spawnPos)  -- смещение в локальных координатах пропа
			payload.attachEnt    = attachEnt
			payload.attachOffset = {attachOffset.x, attachOffset.y, attachOffset.z}
			client:Notify("Subtitle point attached to prop " .. hitEnt:GetClass())
		end

		PLUGIN:CreateSubtitlePoint(spawnPos, payload)
		client:NotifyLocalized("subtitlePointPlaced")
	end
})

-- /subtitlepointremove
ix.command.Add("SubtitlePointRemove", {
	description = "@cmdSubtitlePointRemDesc",
	adminOnly   = true,

	OnRun = function(self, client)
		if CLIENT then return end

		local eyePos = client:EyePos()
		local tr     = util.TraceLine({
			start  = eyePos,
			endpos = eyePos + client:GetAimVector() * 200,
			filter = client,
		})

		local hitPos  = tr.HitPos
		local closest = nil
		local bestDist = 90000 -- 300u^2

		for i, point in ipairs(PLUGIN.subtitlePoints) do
			local d = point.pos:DistToSqr(hitPos)
			if d < bestDist then
				bestDist = d
				closest  = i
			end
		end

		if closest then
			PLUGIN:RemoveSubtitlePoint(closest)
			client:NotifyLocalized("subtitlePointRemoved")
		else
			client:NotifyLocalized("subtitlePointNotFound")
		end
	end
})

-- /subtitlepointlist
ix.command.Add("SubtitlePointList", {
	description = "@cmdSubtitlePointListDesc",
	adminOnly   = true,

	OnRun = function(self, client)
		if CLIENT then return end

		if #PLUGIN.subtitlePoints == 0 then
			client:Notify("No subtitle points.")
			return
		end

		for i, point in ipairs(PLUGIN.subtitlePoints) do
			local p = point.pos
			client:Notify(string.format("[%d] %q — %q @ %.0f %.0f %.0f",
				i, point.payload.speaker, point.payload.text, p.x, p.y, p.z))
		end
	end
})

-- ─────────────────────────────────────────────
-- SERVER
-- ─────────────────────────────────────────────

if SERVER then
	util.AddNetworkString("ixSubtitleShow")
	util.AddNetworkString("ixSubtitleClear")
	util.AddNetworkString("ixSubtitlePointSync")
	util.AddNetworkString("ixSubtitlePointActivate")

	PLUGIN.subtitlePoints = PLUGIN.subtitlePoints or {}

	-- Сериализует точки для netstream/SaveData
	-- attachEnt — прямая ссылка на Entity, не сохраняется
	local function serializePoints(points)
		local out = {}
		for _, point in ipairs(points) do
			out[#out + 1] = {
				pos          = {point.pos.x, point.pos.y, point.pos.z},
				payload      = point.payload,
				-- attachOffset сохраняем чтобы знать что точка была привязана
				-- но при загрузке attachEnt = nil, точка становится статичной
				attachOffset = point.attachOffset or nil,
			}
		end
		return out
	end

	-- Создать точку
	function PLUGIN:CreateSubtitlePoint(pos, payload)
		-- Извлекаем данные привязки из payload и убираем их оттуда
		local entIndex   = payload.attachEnt
		local offset     = payload.attachOffset
		payload.attachEnt    = nil
		payload.attachOffset = nil

		local point = {
			pos          = pos,
			payload      = payload,
			attachEnt    = nil,   -- прямая ссылка на Entity (не EntIndex)
			attachOffset = offset,
		}

		-- Получаем прямую ссылку на Entity прямо сейчас пока она точно живая
		if entIndex then
			local ent = ents.GetByIndex(entIndex)
			if IsValid(ent) then
				point.attachEnt = ent  -- сохраняем саму Entity, а не числовой индекс
			end
		end

		self.subtitlePoints[#self.subtitlePoints + 1] = point
		self:SaveData()
		netstream.Start(nil, "ixSubtitlePointSync", serializePoints(self.subtitlePoints))
	end

	-- Удалить точку по индексу
	function PLUGIN:RemoveSubtitlePoint(index)
		table.remove(self.subtitlePoints, index)
		self:SaveData()
		netstream.Start(nil, "ixSubtitlePointSync", serializePoints(self.subtitlePoints))
	end

	-- Сохранение
	function PLUGIN:SaveData()
		ix.data.Set("subtitlepoints", serializePoints(self.subtitlePoints))
	end

	-- Загрузка — привязка к пропу после рестарта не восстанавливается,
	-- точка остаётся статичной на последней позиции
	function PLUGIN:LoadData()
		local saved = ix.data.Get("subtitlepoints", {})
		self.subtitlePoints = {}
		for _, entry in ipairs(saved) do
			local p = entry.pos
			self.subtitlePoints[#self.subtitlePoints + 1] = {
				pos          = Vector(p[1], p[2], p[3]),
				payload      = entry.payload,
				attachEnt    = nil,
				attachOffset = entry.attachOffset or nil,
			}
		end
	end

	-- Синхронизировать точки новому игроку при заходе
	function PLUGIN:PlayerInitialSpawn(client)
		timer.Simple(2, function()
			if IsValid(client) then
				netstream.Start(client, "ixSubtitlePointSync", serializePoints(self.subtitlePoints))
			end
		end)
	end

	-- Обновление позиций точек привязанных к пропам
	local lastPropSync = 0
	hook.Add("Think", "ixSubtitlePointPropUpdate", function()
		local now = CurTime()
		if now - lastPropSync < 0.1 then return end
		lastPropSync = now

		local changed = false

		for _, point in ipairs(PLUGIN.subtitlePoints) do
			if not point.attachEnt then continue end
			-- IsValid проверяет что Entity существует и не удалена
			if not IsValid(point.attachEnt) then continue end

			local off    = point.attachOffset
			local newPos = point.attachEnt:LocalToWorld(Vector(off[1], off[2], off[3]))

			if newPos:DistToSqr(point.pos) > 1 then
				point.pos = newPos
				changed   = true
			end
		end

		if changed then
			netstream.Start(nil, "ixSubtitlePointSync", serializePoints(PLUGIN.subtitlePoints))
		end
	end)

	-- Когда проп удаляется — удаляем все привязанные к нему точки
	hook.Add("EntityRemoved", "ixSubtitlePointEntityRemoved", function(ent)
		local toRemove = {}

		for i, point in ipairs(PLUGIN.subtitlePoints) do
			if point.attachEnt == ent then
				toRemove[#toRemove + 1] = i
			end
		end

		if #toRemove == 0 then return end

		-- Удаляем с конца чтобы не сдвигать индексы
		for i = #toRemove, 1, -1 do
			table.remove(PLUGIN.subtitlePoints, toRemove[i])
		end

		-- Не вызываем SaveData здесь — при остановке сервера/смене карты EntityRemoved
		-- срабатывает ПОСЛЕ того как ShutDown/PreCleanupMap уже сохранил корректные данные,
		-- из-за чего файл перезаписывается неполным списком. Сохранение происходит
		-- автоматически через хуки ShutDown, PreCleanupMap и таймер каждые 10 минут.
		netstream.Start(nil, "ixSubtitlePointSync", serializePoints(PLUGIN.subtitlePoints))
	end)

	-- Игрок нажал E рядом с точкой
	netstream.Hook("ixSubtitlePointActivate", function(client, index)
		local point = PLUGIN.subtitlePoints[index]
		if not point then return end

		if client:GetPos():DistToSqr(point.pos) > (150 * 150) then return end

		netstream.Start(client, "ixSubtitleShow", point.payload)
	end)
end

-- ─────────────────────────────────────────────
-- CLIENT
-- ─────────────────────────────────────────────

if CLIENT then

	-- ── Состояние субтитра ───────────────────

	local subtitle = {
		speaker      = "",
		text         = "",
		expireAt     = 0,
		fadeIn       = 0,
		fadeOut      = 0,
		speakerColor = Color(200, 200, 200),
		textColor    = Color(255, 255, 255),
	}

	local FADE_TIME = 0.4
	local FONT_MAIN = "ixMediumFont"
	local FONT_SPKR = "ixGenericFont"

	-- ── Точки активации (клиентская копия) ───

	local subtitlePoints = {}

	-- ── Netstream ────────────────────────────

	netstream.Hook("ixSubtitleShow", function(payload)
		local now         = CurTime()
		subtitle.speaker  = payload.speaker or ""
		subtitle.text     = payload.text    or ""
		subtitle.fadeIn   = now
		subtitle.expireAt = now + payload.duration
		subtitle.fadeOut  = now + payload.duration - FADE_TIME

		local sc = payload.speakerColor
		local tc = payload.textColor
		subtitle.speakerColor = sc and Color(sc[1], sc[2], sc[3]) or Color(200, 200, 200)
		subtitle.textColor    = tc and Color(tc[1], tc[2], tc[3]) or Color(255, 255, 255)
	end)

	netstream.Hook("ixSubtitleClear", function()
		subtitle.expireAt = 0
	end)

	netstream.Hook("ixSubtitlePointSync", function(points)
		subtitlePoints = {}
		for _, entry in ipairs(points) do
			local p = entry.pos
			subtitlePoints[#subtitlePoints + 1] = {
				pos          = isvector(p) and p or Vector(p[1], p[2], p[3]),
				payload      = entry.payload,
				isAttached   = (entry.attachOffset ~= nil),  -- для визуальной пометки
			}
		end
	end)

	-- ── Нажатие E рядом с точкой ─────────────
	-- PlayerButtonDown не работает на клиенте — используем Think

	local lastUse    = 0
	local wasEDown   = false

	hook.Add("Think", "ixSubtitlePointUse", function()
		local eDown = input.IsKeyDown(KEY_E)

		-- Только на момент нажатия (не удержания)
		if eDown and not wasEDown then
			if CurTime() - lastUse >= 1 then
				local lp      = LocalPlayer()
				local eyePos  = lp:EyePos()
				local RANGE_SQ = 100 * 100

				for i, point in ipairs(subtitlePoints) do
					if point.pos:DistToSqr(eyePos) <= RANGE_SQ then
						netstream.Start("ixSubtitlePointActivate", i)
						lastUse = CurTime()
						break
					end
				end
			end
		end

		wasEDown = eDown
	end)

	-- ── Рендер точек активации в мире ────────

	local RANGE_VISIBLE = 400
	local RANGE_HINT    = 100

	local matGlow   = Material("sprites/light_glow02_add")
	local matGlow02 = Material("sprites/glow04_noz")   -- круглый спрайт без z-clip

	local function isVisible(eyePos, pos)
		local tr = util.TraceLine({
			start  = eyePos,
			endpos = pos,
			mask   = MASK_SOLID_BRUSHONLY,
		})
		return !tr.Hit
	end

	-- Точка рисуется в 3D с отключённым depth test → не клипается геометрией
	hook.Add("PostDrawTranslucentRenderables", "ixSubtitlePointDraw3D", function()
		if #subtitlePoints == 0 then return end

		local now    = CurTime()
		local pulse  = (math.sin(now * 2.5) + 1) * 0.5  -- 0..1
		local lp     = LocalPlayer()
		local eyePos = lp:EyePos()

		render.DepthRange(0, 0)   -- рисуем поверх всей геометрии

		for i, point in ipairs(subtitlePoints) do
			local pos  = point.pos
			local dist = eyePos:Distance(pos)

			if dist > RANGE_VISIBLE then continue end
			if !isVisible(eyePos, pos) then continue end

			local distFade = 1 - math.Clamp(dist / RANGE_VISIBLE, 0, 1)

			local dc   = point.payload.dotColor
			local dotR = dc and dc[1] or 160
			local dotG = dc and dc[2] or 210
			local dotB = dc and dc[3] or 255

			-- Мягкий пульс размера: 6..8 ед.
			local coreSize = 6  + pulse * 2
			local glowSize = 18 + pulse * 6

			local coreAlpha = distFade * (180 + pulse * 50)
			local glowAlpha = distFade * (60  + pulse * 30)

			-- Привязанные к пропу точки: чуть жёлтый оттенок внешнего свечения
			local glowR, glowG, glowB = dotR, dotG, dotB
			if point.isAttached then
				glowR = math.min(255, dotR + 40)
				glowG = math.min(255, dotG + 30)
				glowB = math.max(0,   dotB - 30)
			end

			-- Внешнее мягкое свечение
			render.SetMaterial(matGlow)
			render.DrawSprite(pos, glowSize, glowSize,
				Color(glowR, glowG, glowB, glowAlpha))

			-- Яркое ядро — круглый спрайт
			render.SetMaterial(matGlow02)
			render.DrawSprite(pos, coreSize, coreSize,
				Color(dotR, dotG, dotB, coreAlpha))
		end

		render.DepthRange(0, 1)   -- восстанавливаем depth range
	end)

	-- Текст-подсказка рисуется в 2D поверх всего (HUDPaint)
	hook.Add("HUDPaint", "ixSubtitlePointHint", function()
		if #subtitlePoints == 0 then return end

		local lp     = LocalPlayer()
		local eyePos = lp:EyePos()

		for i, point in ipairs(subtitlePoints) do
			local pos  = point.pos
			local dist = eyePos:Distance(pos)

			if dist > RANGE_HINT then continue end
			if !isVisible(eyePos, pos) then continue end

			local hintFade  = 1 - math.Clamp(dist / RANGE_HINT, 0, 1)
			local hintAlpha = math.floor(hintFade * 220)

			local screen = pos:ToScreen()
			if !screen.visible then continue end

			local sx   = screen.x
			local sy   = screen.y
			local hint = L("subtitlePointHint")

			surface.SetFont("ixGenericFont")
			local tw, th = surface.GetTextSize(hint)
			local ty = sy - th - 14

			-- Свечение (смещённые копии)
			draw.SimpleText(hint, "ixGenericFont", sx + 1, ty + 1,
				Color(160, 200, 255, hintAlpha * 0.35),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			draw.SimpleText(hint, "ixGenericFont", sx - 1, ty - 1,
				Color(160, 200, 255, hintAlpha * 0.35),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)

			-- Белый текст
			draw.SimpleText(hint, "ixGenericFont", sx, ty,
				Color(255, 255, 255, hintAlpha),
				TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
		end
	end)

	-- ── Отрисовка самого субтитра ─────────────

	hook.Add("HUDPaint", "ixCinematicSubtitles", function()
		local now = CurTime()
		if now > subtitle.expireAt then return end

		local fadeInProg  = math.Clamp((now - subtitle.fadeIn)  / FADE_TIME, 0, 1)
		local fadeOutProg = math.Clamp((now - subtitle.fadeOut) / FADE_TIME, 0, 1)
		local alpha       = 255 * math.min(fadeInProg, 1 - fadeOutProg)
		if alpha <= 0 then return end

		local sw, sh  = ScrW(), ScrH()
		local centerX = sw * 0.5
		local bottomY = sh * 0.82

		surface.SetFont(FONT_MAIN)
		local textW, textH = surface.GetTextSize(subtitle.text)

		local speakerH = 0
		if subtitle.speaker != "" then
			surface.SetFont(FONT_SPKR)
			local _, h = surface.GetTextSize(subtitle.speaker)
			speakerH = h + 4
		end

		local padX = 24
		local padY = 12
		local boxW = textW + padX * 2
		local boxH = textH + speakerH + padY * 2
		local boxX = centerX - boxW * 0.5
		local boxY = bottomY - boxH

		draw.RoundedBox(6, boxX, boxY, boxW, boxH, Color(0, 0, 0, alpha * 0.6))

		surface.SetDrawColor(200, 200, 200, alpha * 0.8)
		surface.DrawRect(boxX, boxY + padY, 2, boxH - padY * 2)

		local textY = boxY + padY

		if subtitle.speaker != "" then
			local sc = subtitle.speakerColor
			draw.SimpleText(subtitle.speaker, FONT_SPKR, centerX, textY,
				Color(sc.r, sc.g, sc.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
			textY = textY + speakerH
		end

		local tc = subtitle.textColor
		draw.SimpleText(subtitle.text, FONT_MAIN, centerX, textY,
			Color(tc.r, tc.g, tc.b, alpha), TEXT_ALIGN_CENTER, TEXT_ALIGN_TOP)
	end)

end
