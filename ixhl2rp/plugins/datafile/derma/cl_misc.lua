-- ===== Стиль терминалов ГО для окон ввода записей =====
-- Крупный размер (950x570) — окна рендерятся на экране устройства почти 1:1 и не «мылятся».
local M_BG    = Color(8, 12, 15, 255)
local M_DEEP  = Color(4, 8, 11, 255)
local M_LINE  = Color(0, 170, 210)
local M_LINED = Color(0, 90, 115)
local M_TEXT  = Color(200, 235, 245)

surface.CreateFont("ixDfEntryFont", { font = "Consolas",           size = 30, weight = 600, antialias = true })
surface.CreateFont("ixDfEntryHdr",  { font = "Blender Pro Medium", size = 34, weight = 600, extended = true, antialias = true })

local function MBrackets(x, y, w, h, len, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, len, 2)             surface.DrawRect(x, y, 2, len)
	surface.DrawRect(x + w - len, y, len, 2)   surface.DrawRect(x + w - 2, y, 2, len)
	surface.DrawRect(x, y + h - 2, len, 2)     surface.DrawRect(x, y + h - len, 2, len)
	surface.DrawRect(x + w - len, y + h - 2, len, 2) surface.DrawRect(x + w - 2, y + h - len, 2, len)
end

-- Общая отрисовка окна записи (тёмный фон + рамка + углы + шапка-заголовок).
-- Шапка опущена (hy): верх RT уходит за край экрана устройства.
local M_HY = 90

local function MPaint(self, w, h, accent, title)
	surface.SetDrawColor(M_BG) surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(0, 0, 0, 24)
	for y = 0, h, 4 do surface.DrawRect(0, y, w, 1) end
	surface.SetDrawColor(M_LINED) surface.DrawOutlinedRect(0, 0, w, h)
	MBrackets(0, 0, w, h, 24, accent)
	surface.SetDrawColor(14, 20, 24, 255) surface.DrawRect(3, M_HY, w - 6, 64)
	surface.SetDrawColor(accent) surface.DrawRect(3, M_HY + 64, w - 6, 3)
	draw.SimpleText(title, "ixDfEntryHdr", 24, M_HY + 13, M_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- штатную кнопку закрытия переносим в видимую зону (в шапку справа)
	if IsValid(self.btnClose) then
		self.btnClose:SetSize(40, 40)
		self.btnClose:SetPos(w - 52, M_HY + 12)
	end
end

-- Civil Record panel.
local PANEL = {};

function PANEL:Init()
	self:SetTitle("");
	self:MakePopup();

	self:SetSize(950, 570);
	self:Center();

	self.Restricted = false;

	self.Entry = vgui.Create("cwDfDTextEntry", self);
	self.Entry:Dock(FILL);
	self.Entry:SetMultiline(true);
	self.Entry:DockMargin(18, 168, 18, 8);

	self.Number = vgui.Create("DNumberWang", self)
	self.Number:Dock(BOTTOM);
	self.Number:DockMargin(0, 2.5, 0, 2.5);
	self.Number:SetMinMax(-10, 10);

	self.Submit = vgui.Create("cwDfButton", self);
	self.Submit:SetText(L("datafile.submit"))
	self.Submit:SetZPos(-1)
	self.Submit:Dock(BOTTOM);
	self.Submit:SetTall(64);
	self.Submit:DockMargin(18, 10, 18, 16);
	self.Submit:SetMetroColor(Color(231, 76, 60, 100));
end;

function PANEL:SendInformation(target)
	self.Submit.DoClick = function()
		local category = "civil";
		local text = self.Entry:GetText();
		local points = self.Number:GetValue();

		netstream.Start("AddDatafileEntry", target, category, text, points);

		self:Close();
	end;
end;

function PANEL:Paint(w, h)
	MPaint(self, w, h, Color(231, 76, 60), "ГРАЖДАНСКАЯ ЗАПИСЬ")
end;

vgui.Register("cwDfCivilEntry", PANEL, "DFrame");

-- Medical record panel.
PANEL = {};

function PANEL:Init()
	self:SetTitle("");
	self:MakePopup();

	self:SetSize(950, 570);
	self:Center();

	self.Restricted = false;

	self.Entry = vgui.Create("cwDfDTextEntry", self);
	self.Entry:Dock(FILL);
	self.Entry:SetMultiline(true);
	self.Entry:DockMargin(18, 168, 18, 8);

	self.Submit = vgui.Create("cwDfButton", self);
	self.Submit:SetText(L("datafile.submit"))
	self.Submit:Dock(BOTTOM);
	self.Submit:SetTall(64);
	self.Submit:DockMargin(18, 10, 18, 16);
	self.Submit:SetMetroColor(Color(39, 174, 96, 100));
end;

function PANEL:SendInformation(target)
	self.Submit.DoClick = function()
		local category = "med";
		local text = self.Entry:GetText();

		netstream.Start("AddDatafileEntry", target, category, text, 0);

		self:Close();
	end;
end;

function PANEL:Paint(w, h)
	MPaint(self, w, h, Color(39, 174, 96), "МЕДИЦИНСКАЯ ЗАПИСЬ")
end;

vgui.Register("cwDfMedicalEntry", PANEL, "DFrame");

-- Note entry panel.
PANEL = {};

function PANEL:Init()
	self:SetTitle("");
	self:MakePopup();

	self:SetSize(950, 570);
	self:Center();

	self.Restricted = false;

	self.Entry = vgui.Create("cwDfDTextEntry", self);
	self.Entry:Dock(FILL);
	self.Entry:SetMultiline(true);
	self.Entry:DockMargin(18, 168, 18, 8);

	self.Submit = vgui.Create("cwDfButton", self);
	self.Submit:SetText(L("datafile.submit"))
	self.Submit:Dock(BOTTOM);
	self.Submit:SetTall(64);
	self.Submit:DockMargin(18, 10, 18, 16);
	self.Submit:SetMetroColor(Color(41, 128, 185, 100));
end;

function PANEL:SendInformation(target)
	self.Submit.DoClick = function()
		local category = "union";
		local text = self.Entry:GetText();

		netstream.Start("AddDatafileEntry", target, category, text, 0);

		self:Close();
	end;
end;

function PANEL:Paint(w, h)
	MPaint(self, w, h, Color(41, 128, 185), "ЗАМЕТКА")
end;

vgui.Register("cwDfNoteEntry", PANEL, "DFrame");

-- Registry entry panel.
PANEL = {};

function PANEL:Init()
	self:SetTitle("");
	self:MakePopup();

	self:SetSize(950, 570);
	self:Center();

	self.Restricted = false;

	self.Entry = vgui.Create("cwDfDTextEntry", self);
	self.Entry:Dock(FILL);
	self.Entry:SetMultiline(false);
	self.Entry:DockMargin(18, 168, 18, 8);

	self.Submit = vgui.Create("cwDfButton", self);
	self.Submit:SetText(L("datafile.submit"))
	self.Submit:Dock(BOTTOM);
	self.Submit:SetTall(64);
	self.Submit:DockMargin(18, 10, 18, 16);
	self.Submit:SetMetroColor(Color(231, 180, 60, 100));
end;

function PANEL:SendInformation(target)
	self.Submit.DoClick = function()
		local text = self.Entry:GetText();

		if #text > 0 then
			netstream.Start("SetRegistryEntry", target, text);
		end

		self:Close();
	end;
end;

function PANEL:Paint(w, h)
	MPaint(self, w, h, Color(231, 180, 60), "РЕГИСТРАЦИЯ")
end;

vgui.Register("cwDfRegistryEntry", PANEL, "DFrame");

-- Текстовое поле (стиль терминала ГО).
PANEL = {};

function PANEL:Init()
	self:SetFont("ixDfEntryFont");
	self:SetMultiline(true);
end;

function PANEL:Paint(w, h)
	surface.SetDrawColor(M_DEEP);
	surface.DrawRect(0, 0, w, h);

	surface.SetDrawColor(M_LINE);
	surface.DrawOutlinedRect(0, 0, w, h);
	surface.SetDrawColor(M_LINE);
	surface.DrawRect(0, 0, 4, h);

	self:DrawTextEntryText(M_TEXT, M_LINE, M_TEXT);
end;

vgui.Register("cwDfDTextEntry", PANEL, "DTextEntry");