-- called when a markup object should paint its text
local function PaintMarkupOverride(text, font, x, y, color, alignX, alignY, alpha)
	alpha = alpha or 255

	if (ix.option.Get("chatOutline", false)) then
		-- outlined background for even more visibility
		draw.SimpleTextOutlined(text, font, x, y, ColorAlpha(color, alpha), alignX, alignY, 1, Color(0, 0, 0, alpha))
	else
		-- background for easier reading
		--surface.SetTextPos(x + 1, y + 1)
		--surface.SetTextColor(0, 0, 0, alpha)
		--surface.SetFont(font)
		--surface.DrawText(text)

		surface.SetTextPos(x, y)
		surface.SetTextColor(color.r, color.g, color.b, alpha)
		surface.SetFont(font)
		surface.DrawText(text)
	end
end

-- chat message
local PANEL = {}

AccessorFunc(PANEL, "fadeDelay", "FadeDelay", FORCE_NUMBER)
AccessorFunc(PANEL, "fadeDuration", "FadeDuration", FORCE_NUMBER)

function PANEL:Init()
	self.text = ""
	self.alpha = 255
	self.fadeDelay = 30
	self.fadeDuration = 5
end

function PANEL:SetMarkup(text, immediately)
	self.text = text

	self.markup = ix.markup.Parse(self.text, self:GetWide())
	self.markup.onDrawText = PaintMarkupOverride

	self:SetTall(self.markup:GetHeight())

	-- Сбрасываем состояние при новом/обновлённом сообщении
	self.fadeStartTime = nil
	self.alpha = 255
	self.faded = false

	if immediately then
		self.fadeDelay = 0
	end
end

function PANEL:Think()
	if not (self.fadeDelay and self.fadeDuration) then return end

	-- Пока чат открыт — показываем все сообщения
	if IsValid(ix.gui.chat) and ix.gui.chat:GetActive() then
		if self.faded then
			-- Восстанавливаем, помечаем: при закрытии чата угаснет сразу
			self.faded = false
			self.wasRestored = true
		end
		self.fadeStartTime = nil
		self.alpha = 255
		return
	end

	-- Чат закрыт
	if self.faded then return end

	-- Сообщение было восстановлено при открытии чата — прячем его сразу
	if self.wasRestored then
		self.wasRestored = false
		self.faded = true
		self.alpha = 0
		return
	end

	-- Обычное угасание: запускаем отсчёт, если ещё не начали
	if not self.fadeStartTime then
		self.fadeStartTime = CurTime() + self.fadeDelay
		return
	end

	local now = CurTime()

	if now < self.fadeStartTime then return end

	local fadeEnd = self.fadeStartTime + self.fadeDuration
	if now >= fadeEnd then
		self.alpha = 0
		self.faded = true
		return
	end

	self.alpha = Lerp(math.TimeFraction(self.fadeStartTime, fadeEnd, now), 255, 0)
end

function PANEL:PerformLayout(width, height)
	if ((IsValid(ix.gui.chat) and ix.gui.chat.bSizing) or width == self.markup:GetWidth()) then
		return
	end

	self.markup = ix.markup.Parse(self.text, width)
	self.markup.onDrawText = PaintMarkupOverride

	self:SetTall(self.markup:GetHeight())
end

function PANEL:Paint(width, height)
	local newAlpha

	-- we'll want to hide the chat while some important menus are open
	if (IsValid(ix.gui.characterMenu)) then
		newAlpha = math.min(255 - ix.gui.characterMenu.currentAlpha, self.alpha)
	elseif (ix.gui.chat:GetActive()) then
		newAlpha = math.max(ix.gui.chat.alpha, self.alpha)
	else
		newAlpha = self.alpha
	end

	if (newAlpha < 1) then
		return
	end

	self.markup:draw(0, 0, nil, nil, newAlpha)
end

vgui.Register("ixChatMessage", PANEL, "Panel")