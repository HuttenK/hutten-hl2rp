local PLUGIN = PLUGIN

PLUGIN.name        = "Combine HUD"
PLUGIN.author      = "Elec / ZeMysticalTaco (ported to Helix / Autonomous)"
PLUGIN.description = "Facial recognition HUD for Combine units."

-- ─────────────────────────────────────────────────────────────────────────────
-- CONFIGS & OPTIONS
-- ─────────────────────────────────────────────────────────────────────────────

ix.option.Add("CombineHUD", ix.type.bool, false, {
	category = "Combine HUD"
})

ix.config.Add("code_mpf", "ASSIST, DEFEND", "Assessment code for MPF units.", nil, {
	category = "Combine HUD"
})

ix.config.Add("code_overwatch", "ASSIST, SACRIFICE", "Assessment code for OTA units.", nil, {
	category = "Combine HUD"
})

-- ─────────────────────────────────────────────────────────────────────────────
-- КОМАНДА ДИВИЗИОНА
-- ─────────────────────────────────────────────────────────────────────────────

ix.command.Add("CharSetDivision", {
	description = "Set a player's CP division.",
	adminOnly   = true,
	arguments   = {ix.type.character, ix.type.string},

	OnRun = function(self, client, target, division)
		if CLIENT then return end
		if not target then return end

		target:SetData("mpfdivision", division)

		local ply = target:GetPlayer()
		if IsValid(ply) then
			ply:SetNetVar("mpfdivision", division)
			ix.util.Notify(client:Name() .. " has set " .. ply:Name() .. "'s division to " .. division)
		end
	end
})

-- ─────────────────────────────────────────────────────────────────────────────
-- SERVER — синхронизировать дивизион при loadout
-- ─────────────────────────────────────────────────────────────────────────────

if SERVER then
	-- PlayerLoadout вызывается после загрузки персонажа — GetCharacter() гарантированно есть
	function PLUGIN:PlayerLoadout(client)
		local character = client:GetCharacter()
		if character then
			client:SetNetVar("mpfdivision", character:GetData("mpfdivision", "UNIT"))
		end
	end
end

-- ─────────────────────────────────────────────────────────────────────────────
-- CLIENT
-- ─────────────────────────────────────────────────────────────────────────────

if CLIENT then

	local alphas   = {}
	local sizes    = {}
	local str_lens = {}

	local function MatrixText(text, font, x, y, color, scale, rotation)
		surface.SetFont(font)
		local matrix = Matrix()
		matrix:Translate(Vector(x, y, 1))
		matrix:Scale(scale or Vector(1, 1, 1))
		matrix:Rotate(rotation or Angle(0, 0, 0))
		cam.PushModelMatrix(matrix)
			surface.SetTextPos(0, 0)
			surface.SetTextColor(color.r, color.g, color.b, color.a)
			surface.DrawText(text)
		cam.PopModelMatrix()
	end

	function PLUGIN:LoadFonts(font, genericFont)
		surface.CreateFont("FaceRecog", {
			font      = "Roboto",
			size      = 120,
			antialias = true,
		})
	end

	function PLUGIN:HUDPaint()
		local lp = LocalPlayer()

		if not lp:IsCombine() then return end
		if not ix.option.Get("CombineHUD", false) then return end

		local lpPos = lp:GetPos()
		local RANGE = 512

		for _, v in ipairs(player.GetAll()) do
			if v == lp                               then continue end
			if not v:IsCombine()                     then continue end
			if not v:Alive()                         then continue end
			if v:GetMoveType() == MOVETYPE_NOCLIP    then continue end

			local idx = v:EntIndex()

			alphas[idx]   = alphas[idx]   or 0
			sizes[idx]    = sizes[idx]    or 100
			str_lens[idx] = str_lens[idx] or 0

			-- Позиция головы
			local head    = v:LookupBone("ValveBiped.Bip01_Head1")
			local headposW = head and v:GetBonePosition(head) or v:EyePos()
			local headposS = headposW:ToScreen()

			-- Масштаб по расстоянию
			local distScale = v:GetPos():Distance(lpPos) / 384
			local size      = sizes[idx] / distScale

			surface.SetFont("FaceRecog")
			local ns_x = select(1, surface.GetTextSize(v:Name()))

			-- Трассировка видимости
			local tr = util.TraceLine({
				start  = EyePos(),
				endpos = headposW,
				mask   = MASK_VISIBLE_AND_NPCS,
				filter = {lp, v},
			})

			local inRange = v:GetPos():Distance(lpPos) <= RANGE
			local visible = not tr.Hit

			if inRange and visible then
				alphas[idx]   = Lerp(FrameTime() * 5,  alphas[idx],   255)
				sizes[idx]    = Lerp(FrameTime() * 5,  sizes[idx],    20)
				local mul     = sizes[idx] < 40 and 50 or 6
				str_lens[idx] = Lerp(FrameTime() * mul, str_lens[idx], ns_x)
			else
				alphas[idx]   = Lerp(FrameTime() * 10, alphas[idx],   0)
				sizes[idx]    = Lerp(FrameTime() * 10, sizes[idx],    80)
				str_lens[idx] = Lerp(FrameTime() * 10, str_lens[idx], 0)
			end

			local alpha = alphas[idx]
			if alpha < 1 then continue end

			-- ── Данные юнита ─────────────────────────────────────────────────

			local teamColor  = team.GetColor(v:Team())
			local sc         = Vector(0.05 / distScale, 0.05 / distScale, 1)
			local nameSc     = Vector(0.075 / distScale, 0.075 / distScale, 1)

			-- Assessment по фракции
			local assessment = v:IsOTA()
				and ix.config.Get("code_overwatch", "ASSIST, SACRIFICE")
				or  ix.config.Get("code_mpf",       "ASSIST, DEFEND")

			-- Дивизион (синхронизирован через NetVar в PlayerLoadout)
			local division = v:GetNetVar("mpfdivision", "UNIT")

			-- Ранг из системы рангов сборки
			local rankData = Schema:GetPlayerCombineRank(v)
			local rankStr  = rankData and L(rankData.name) or ""

			-- Спец-звания (может быть несколько)
			local specials = Schema:GetPlayerCombineSpecials(v)

			-- Является ли Dispatch/Overseer
			local isDispatch = v:IsDispatch()

			-- Совпадает ли squad (через NetVar "squad")
			local mySquad    = lp:GetNetVar("squad", "")
			local theirSquad = v:GetNetVar("squad", "NONE")
			local sameSquad  = mySquad != "" and mySquad == theirSquad

			-- ── Отрисовка ────────────────────────────────────────────────────

			local hx = headposS.x + size / 1.9
			local hy = headposS.y

			-- Дивизион + звание
			local nameText = division
			if rankStr != "" then
				nameText = division .. "  " .. rankStr
			end

			MatrixText(
				nameText,
				"FaceRecog",
				hx, hy - size * 0.9,
				Color(teamColor.r, teamColor.g, teamColor.b, alpha),
				nameSc
			)

			-- Assessment
			MatrixText(
				"ASSESSMENT: " .. assessment,
				"FaceRecog",
				hx, hy - size / 4,
				Color(255, 255, 255, alpha),
				sc
			)

			-- Патруль (squad NetVar)
			MatrixText(
				"PATROL TEAM: " .. theirSquad,
				"FaceRecog",
				hx, hy - size * 1.1,
				Color(
					math.max(teamColor.r - 50, 0),
					math.max(teamColor.g - 50, 0),
					math.max(teamColor.b - 50, 0),
					alpha
				),
				sc
			)

			-- Dispatch/Overseer вместо IsSquadLeader
			if isDispatch then
				MatrixText(
					"DISPATCH / OVERSEER",
					"FaceRecog",
					hx, hy - size * 1.6,
					Color(220, 255, 100, alpha),
					sc
				)
			end

			-- Спец-звания (USF:D → Strike Force Delta и т.д.)
			local specY = hy - size * 1.3
			for i, spec in ipairs(specials) do
				MatrixText(
					L(spec.name):upper(),
					"FaceRecog",
					hx, specY - (i - 1) * size * 0.3,
					Color(200, 0, 0, alpha),
					sc
				)
			end

			-- Одно патрульное звено
			if sameSquad then
				MatrixText(
					"SQUAD ASSET",
					"FaceRecog",
					hx, hy - size / 16 + 16,
					Color(255, 255, 255, alpha),
					sc
				)
			end

			-- Горизонтальная линия под именем
			local lineMatrix = Matrix()
			lineMatrix:Translate(Vector(hx, hy - size / 2, 0))
			lineMatrix:Scale(Vector(0.075 / distScale, 1, 1))
			cam.PushModelMatrix(lineMatrix)
				surface.SetDrawColor(255, 255, 255, alpha)
				surface.DrawOutlinedRect(0, 0, str_lens[idx], 1)
			cam.PopModelMatrix()
		end
	end

	-- Очистка при выходе игрока
	hook.Add("EntityRemoved", "ixCombineHUDCleanup", function(ent)
		if ent:IsPlayer() then
			local idx = ent:EntIndex()
			alphas[idx]   = nil
			sizes[idx]    = nil
			str_lens[idx] = nil
		end
	end)

end
