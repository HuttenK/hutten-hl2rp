-- ============================================================
--  terminal.page.datafile — контейнер вкладок личного кабинета.
--  Собирает страницы через хук TerminalAddDatafilePage, строит
--  навигацию и маршрутизирует ответы civil.terminal.request.
-- ============================================================

-- Контракт сервера (sv_hooks): page 3 = кредиты, page 6 = сообщения.
local REQUEST_BY_TITLE = {
	["КРЕДИТЫ"]   = 3,
	["СООБЩЕНИЯ"] = 6,
}

local PANEL = {}

function PANEL:Init()
	self.nav = self:Add("Panel")
	self.nav:Dock(TOP)
	self.nav:SetTall(34)

	self.content = self:Add("Panel")
	self.content:Dock(FILL)
	self.content:DockMargin(0, 6, 0, 0)

	self.pages = {}

	ix.gui.civilDatafilePage = self
end

function PANEL:CreateTabs()
	local pages = {}
	hook.Run("TerminalAddDatafilePage", pages)

	self.pages = pages

	for _, page in ipairs(pages) do
		if !page.noRequest then
			page.request = REQUEST_BY_TITLE[page.title]
		end
	end

	for i, page in ipairs(pages) do
		local btn = self.nav:Add("terminal.button.nav")
		btn:Dock(LEFT)
		btn:SetWide(150)
		btn:DockMargin(0, 0, 4, 0)
		btn:SetText(page.title)
		btn.OnClick = function()
			self:ShowPage(i)
		end
		page.button = btn
	end

	-- принудительная раскладка, чтобы content получил размеры до построения страниц
	self:InvalidateLayout(true)
	self.content:InvalidateLayout(true)

	if #pages > 0 then
		self:ShowPage(1)
	end
end

function PANEL:ShowPage(index)
	local page = self.pages[index]
	if !page then return end

	for _, p in ipairs(self.pages) do
		if IsValid(p.button) then
			p.button.active = (p == page)
			if p.button.UpdateColors then p.button:UpdateColors(false) end
		end
	end

	self.activePage = page
	self.content:Clear()
	self.content.currentPanel = nil
	self.content:InvalidateLayout(true)

	local result = page.frame(self, self.content)
	self.content.currentPanel = result
	self.content:InvalidateLayout(true)

	if page.request and !page.noRequest then
		netstream.Start("civil.terminal.request", page.request)
	end
end

-- Ответ сервера с данными страницы -> вызываем её receive
function PANEL:Receive(data)
	local reqID = data and data[1]
	if !reqID then return end

	for _, page in ipairs(self.pages) do
		if page.request == reqID and page.receive then
			page.receive(self, self.content, data)
			return
		end
	end
end

vgui.Register("terminal.page.datafile", PANEL, "Panel")
