local PLUGIN = PLUGIN;

local colours = {
	white = Color(180, 180, 180, 255),
	red = Color(231, 76, 60, 255),
	green = Color(39, 174, 96),
	blue = Color(41, 128, 185, 255),
	yellow = Color(231, 180, 60, 255),
};

-- ===== Стиль терминалов Гражданской Обороны (тёмный + циан) =====
local DF_BG    = Color(8, 12, 15, 252)
local DF_PANEL = Color(14, 20, 24, 255)
local DF_DEEP  = Color(20, 27, 32, 255)
local DF_LINE  = Color(0, 170, 210)
local DF_LINED = Color(0, 90, 115)
local DF_TEXT  = Color(196, 214, 220)
local DF_DIM   = Color(110, 140, 150)
local DF_RED   = Color(210, 60, 50)
local DF_AMBER = Color(235, 170, 50)

surface.CreateFont("ixDfHeader", { font = "Blender Pro Medium", size = 28, weight = 600, extended = true, antialias = true })
surface.CreateFont("ixDfName",   { font = "Blender Pro Medium", size = 34, weight = 700, extended = true, antialias = true })
surface.CreateFont("ixDfLabel",  { font = "Blender Pro Book",   size = 18, weight = 500, extended = true, antialias = true })
surface.CreateFont("ixDfText",   { font = "Consolas",           size = 15, weight = 500, antialias = true })
surface.CreateFont("ixDfSmall",  { font = "Consolas",           size = 13, weight = 500, antialias = true })

local function DfBrackets(x, y, w, h, len, col)
	surface.SetDrawColor(col)
	surface.DrawRect(x, y, len, 2)             surface.DrawRect(x, y, 2, len)
	surface.DrawRect(x + w - len, y, len, 2)   surface.DrawRect(x + w - 2, y, 2, len)
	surface.DrawRect(x, y + h - 2, len, 2)     surface.DrawRect(x, y + h - len, 2, len)
	surface.DrawRect(x + w - len, y + h - 2, len, 2) surface.DrawRect(x + w - 2, y + h - len, 2, len)
end


-- Main datafile panel.
local PANEL = {};

function PANEL:Init()
	self:SetTitle("");

	self:SetSize(950, 570);
	self:SetDeleteOnClose(true);
	self:Center();

	self:MakePopup();
	self.Status = "";

	-- Creation of all elements, text is set in the population functions.
	self.TopPanel = vgui.Create("cwDfPanel", self);

	-- TODO: Add the CID here!
	self.NameLabel = vgui.Create("DLabel", self.TopPanel);
	self.NameLabel:SetTextColor(DF_TEXT);
	self.NameLabel:SetFont("ixDfName");
	self.NameLabel:Dock(TOP);
	self.NameLabel:DockMargin(8, 6, 0, 0);
	self.NameLabel:SizeToContents(true);

	self.InfoPanel = vgui.Create("cwDfInfoPanel", self.TopPanel);

	self.HeaderPanel = vgui.Create("cwDfHeaderPanel", self);
	self.Entries = vgui.Create("cwDfEntriesPanel", self);

	-- Lower button panel.
	self.dButtons = vgui.Create("cwDfPanel", self);
	self.dButtons:Dock(BOTTOM);
	self.dButtons:SetTall(35);

	-- Upper button panel.
	self.uButtons = vgui.Create("cwDfPanel", self);
	self.uButtons:Dock(BOTTOM);
	self.uButtons:SetTall(35);

	-- Upper buttons. Population will be done below.
	self.uLeftButton = vgui.Create("cwDfButton", self.uButtons);
	self.uLeftButton:SetText(L("datafile.addNote"));
	self.uLeftButton:SetMetroColor(colours.blue);
	self.uLeftButton:Dock(LEFT);

	self.uMiddleButton = vgui.Create("cwDfButton", self.uButtons);
	self.uMiddleButton:SetText(L("datafile.addCivilRecord"));
	self.uMiddleButton:SetMetroColor(colours.red);
	self.uMiddleButton:Dock(FILL);

	self.uRightButton = vgui.Create("cwDfButton", self.uButtons);
	self.uRightButton:SetText(L("datafile.addMedicalRecord"));
	self.uRightButton:SetMetroColor(colours.green);
	self.uRightButton:Dock(RIGHT);

	self.uMiddle2Button = vgui.Create("cwDfButton", self.uButtons);
    self.uMiddle2Button:SetText(L("datafile.addRegRecord"));
    self.uMiddle2Button:SetMetroColor(colours.yellow);
    self.uMiddle2Button:Dock(RIGHT);

	-- Bottom buttons.
	self.dLeftButton = vgui.Create("cwDfButton", self.dButtons);
	self.dLeftButton:SetText(L("datafile.updateLastSeen"));
	self.dLeftButton:Dock(LEFT);

	self.dMiddleButton = vgui.Create("cwDfButton", self.dButtons);
	self.dMiddleButton:SetText(L("datafile.changeCivilStatus"));
	self.dMiddleButton:Dock(FILL);

	self.dRightButton = vgui.Create("cwDfButton", self.dButtons);
	self.dRightButton:SetText(L("datafile.addBol"));
	self.dRightButton:Dock(RIGHT);

	self.dMiddle2Button = vgui.Create("cwDfButton", self.dButtons);
    self.dMiddle2Button:SetText(L("datafile.removeRegistration"));
    self.dMiddle2Button:Dock(RIGHT);
end;

function PANEL:Rebuild()
	self:SetTitle(Format("Datafile: CitizenID #%s RegID #%s", self.Data[2] or "Unknown", self.Data[3] or "Unknown"));
	self.NameLabel:SetText(self.Data[1] or "Unknown")

	self.Entries.Left:Clear();
	self.Entries.Middle:Clear();
	self.Entries.Middle2:Clear();
	self.Entries.Right:Clear();

	self:PopulateDatafile();
	self:PopulateGenericData();
end;

function PANEL:SetPlayer(player)
	self.Player = player;
end;

-- Populate the datafile with the entries.
function PANEL:PopulateDatafile()
	for _, v in pairs(self.DataFile) do
		local text = v.text;
		local date = os.date("%H:%M:%S - %d/%m/%Y", v.unix_time);
		local poster = v.poster_name;
		local points = tonumber(v.points);
		local color = istable(v.poster_color) and v.poster_color or util.JSONToTable(v.poster_color);

		if (v.category == "union") then
			local entry = vgui.Create("cwDfEntry", self.Entries.Left);

			entry:SetEntryText(text, date, "~ " .. poster, points, color);
		elseif (v.category == "civil") then
			local entry = vgui.Create("cwDfEntry", self.Entries.Middle);

			entry:SetEntryText(text, date, "~ " .. poster, points, color);
		elseif (v.category == "med") then
			local entry = vgui.Create("cwDfEntry", self.Entries.Right);

			entry:SetEntryText(text, date, "~ " .. poster, points, color);
		elseif (v.category == "reg") then
			local entry = vgui.Create("cwDfEntry", self.Entries.Middle2);

			entry:SetEntryText(text, date, "~ " .. poster, points, color);
		end;
	end;
end;

function PANEL:PopulatePoints(points)
	self.InfoPanel.MiddleTextLabel:SetText(points)

	if (tonumber(points) < 0) then
		self.InfoPanel.MiddleTextLabel:SetTextColor(Color(255, 100, 100, 255))
	elseif (tonumber(points) > 0) then
		self.InfoPanel.MiddleTextLabel:SetTextColor(Color(150, 255, 50, 255))
	else
		self.InfoPanel.MiddleTextLabel:SetTextColor(Color(220, 220, 220, 255))
	end
end

-- Update the frame with all the relevant information.
function PANEL:PopulateGenericData()
	--local bIsCombine = self.Player:IsCombine();
	local bIsAntiCitizen = false;
	local bHasBOL = self.GenericData.bol;
	local civilStatus = self.GenericData.status;
	local lastSeen = os.date("%H:%M:%S - %d/%m/%Y", self.GenericData.last_seen);

	-- The logic here can be done far better.
	--if (bIsCombine) then
		--self.InfoPanel.MiddleHeaderLabel:SetText("CREDITS");
	--end;

	self.InfoPanel:SetInfoText(civilStatus, lastSeen, self.GenericData.aparts);

	if (self.GenericData.status == "Anti-Citizen") then
		bIsAntiCitizen = true;
	end;

	if (bHasBOL) then
		self.Status = "yellow";
		self.dRightButton:SetText(L("datafile.removeBol"));
	else
		self.Status = "";
		self.dRightButton:SetText(L("datafile.addBol"))
	end;

	if (bIsAntiCitizen) then
		self.Status = "red";
	--elseif (bIsCombine) then
	--	self.Status = "blue";
	end;

	self.dRightButton.DoClick = function()
		netstream.Start("SetBOL", self.Data[4]);
	end;

	self.dLeftButton.DoClick = function()
		netstream.Start("UpdateLastSeen", self.Data[4]);
	end;

	self.uLeftButton.DoClick = function()
		local entryPanel = vgui.Create("cwDfNoteEntry");
		entryPanel:SendInformation(self.Data[4]);
	end;

	self.uMiddleButton.DoClick = function()
		local entryPanel = vgui.Create("cwDfCivilEntry");
		entryPanel:SendInformation(self.Data[4]);
	end;

	self.uMiddle2Button.DoClick = function()
        local entryPanel = vgui.Create("cwDfRegistryEntry");
        entryPanel:SendInformation(self.Data[4]);
    end;

    self.dMiddle2Button.DoClick = function()
        netstream.Start("SetRegistryEntry", self.Data[4]);
    end;

	self.uRightButton.DoClick = function()
		local entryPanel = vgui.Create("cwDfMedicalEntry");
		entryPanel:SendInformation(self.Data[4]);
	end;

	local CivilStatus = {
		[0] = "Anti-Citizen",
		[1] = "Citizen",
		[2] = "Black",
		[3] = "Brown",
		[4] = "Orange",
		[5] = "Red",
		[6] = "Blue",
		[7] = "Green",
		[8] = "Gold",
		[9] = "Platinum"
	}

	self.dMiddleButton.DoClick = function()
		self.Menu = DermaMenu();

		for k, v in ipairs(CivilStatus) do
			self.Menu:AddOption(v.." ("..(k - 1)..")", function()
				PLUGIN:UpdateCivilStatus(self.Data[4], v);
			end);
		end;

		self.Menu:Open();
	end;
end;

function PANEL:Paint(w, h)
	-- фон + сканлайны
	surface.SetDrawColor(DF_BG)
	surface.DrawRect(0, 0, w, h)
	surface.SetDrawColor(0, 0, 0, 26)
	for y = 0, h, 3 do surface.DrawRect(0, y, w, 1) end

	-- статус-акцент (ориентировка/анти-гражданин) — тонкая мигающая полоса сверху
	local accent = DF_LINE
	if (self.Status == "red") then accent = DF_RED
	elseif (self.Status == "yellow") then accent = DF_AMBER end

	-- рамка + углы
	surface.SetDrawColor(DF_LINED)
	surface.DrawOutlinedRect(0, 0, w, h)
	DfBrackets(0, 0, w, h, 16, accent)

	-- шапка
	surface.SetDrawColor(DF_PANEL)
	surface.DrawRect(2, 2, w - 4, 40)
	if (self.Status == "red" or self.Status == "yellow") then
		local pulse = 0.4 + 0.6 * math.abs(math.sin(RealTime() * 3))
		surface.SetDrawColor(accent.r, accent.g, accent.b, 255 * pulse)
	else
		surface.SetDrawColor(accent)
	end
	surface.DrawRect(2, 42, w - 4, 2)

	draw.SimpleText("ГРАЖДАНСКАЯ ОБОРОНА · ДОСЬЕ", "ixDfHeader", 14, 8, DF_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)
end;

vgui.Register("cwFullDatafile", PANEL, "DFrame");


-- Top panel/darker panel.
PANEL = {};

function PANEL:Init()
	self:Dock(TOP);
	self:SetTall(85);
end;

function PANEL:Paint(w, h)
	surface.SetDrawColor(DF_PANEL);
	surface.DrawRect(0, 0, w, h);
end;

vgui.Register("cwDfPanel", PANEL, "DPanel");


-- Header panel. Shows what category each tab is in.
PANEL = {};

function PANEL:Init()
	self:Dock(TOP);
	self:DockMargin(0, 3, 0, 0);
	self:SetTall(35);

	self.Header1 = vgui.Create("DLabel", self);
	self.Header1:SetText(L("datafile.notes"));
	self.Header1:SetTextColor(colours.blue);
	self.Header1:SetFont("MiddleLabels");
	self.Header1:Dock(FILL);
	self.Header1:DockMargin(7, 0, 0, 0);
	self.Header1:SetContentAlignment(4);

	self.Header2 = vgui.Create("DLabel", self);
	self.Header2:SetText(L("datafile.civilRecord"));
	self.Header2:SetTextColor(colours.red);
	self.Header2:SetFont("MiddleLabels");
	self.Header2:Dock(FILL);
	self.Header2:DockMargin(0, 0, 245, 0);
	self.Header2:SetContentAlignment(5);

	self.Header3 = vgui.Create("DLabel", self);
    self.Header3:SetText(L("datafile.registryRecord"));
    self.Header3:SetTextColor(colours.yellow);
    self.Header3:SetFont("MiddleLabels");
    self.Header3:Dock(FILL);
    self.Header3:DockMargin(0, 0, -245, 0);
    self.Header3:SetContentAlignment(5);

	self.Header4 = vgui.Create("DLabel", self);
	self.Header4:SetText(L("datafile.medicalRecord"));
	self.Header4:SetTextColor(colours.green);
	self.Header4:SetFont("MiddleLabels");
	self.Header4:Dock(FILL);
	self.Header4:DockMargin(0, 0, 7, 0);
	self.Header4:SetContentAlignment(6);
end;

function PANEL:MakeRestricted(bRestrict)
	if (bRestrict) then
		self.Header2:Remove();
	end;
end;

function PANEL:Paint(w, h)
	surface.SetDrawColor(DF_PANEL);
	surface.DrawRect(0, 0, w, h);
end;

vgui.Register("cwDfHeaderPanel", PANEL, "DPanel");

-- Panel that will contain the entries & the 3 scroll bars.
PANEL = {};

function PANEL:Init()
	self:Dock(FILL);

	self.Left = vgui.Create("cwDfScrollPanel", self);
	self.Left:Dock(LEFT);

	self.Middle = vgui.Create("cwDfScrollPanel", self);
	self.Middle:Dock(FILL);

	self.Right = vgui.Create("cwDfScrollPanel", self);
	self.Right:Dock(RIGHT);

	self.Middle2 = vgui.Create("cwDfScrollPanel", self);
    self.Middle2:SetWide(222)
    self.Middle2:Dock(RIGHT);
end;

function PANEL:MakeRestricted(bRestrict)
	if (bRestrict) then
		self.Middle:Remove();
	end;
end;

function PANEL:Paint(w, h)
	surface.SetDrawColor(DF_PANEL);
	surface.DrawRect(0, 0, w, h);
end;

vgui.Register("cwDfEntriesPanel", PANEL, "DPanel");

-- Darker scroll panel.
PANEL = {};

function PANEL:Init()
	self:SetWide(225);
	self:DockMargin(5, 0, 5, 0)

	self.SBar = self:GetVBar();

	self.SBar.Paint = function(panel, w, h)
		surface.SetDrawColor(Color(38, 38, 38, 255));
		surface.DrawRect(0, 0, w, h);
	end;

	self.SBar.btnGrip.Paint = function(panel, w, h)
		surface.SetDrawColor(Color(47, 47, 47, 255));
		surface.DrawRect(0, 0, w, h);
	end;

	self.SBar.btnUp.Paint = function(panel, w, h)
		surface.SetDrawColor(Color(30, 30, 30, 255));
		surface.DrawRect(0, 0, w, h);
	end;

	self.SBar.btnDown.Paint = function(panel, w, h)
		surface.SetDrawColor(Color(30, 30, 30, 255));
		surface.DrawRect(0, 0, w, h);
	end;
end;

vgui.Register("cwDfScrollPanel", PANEL, "DScrollPanel");

-- Darker buttons.
PANEL = {};

function PANEL:Init()
	self:SetTextColor(DF_TEXT);
	self:SetFont("ixDfLabel");
	self:SetWide(225);
	self:DockMargin(5, 2.5, 5, 2.5);

	-- Reason why I'm doing the colours this way is because I don't want any filthy logic in my Paint function.
	self.MetroColor = colours.white;
	self.ButtonColor = DF_PANEL;
end;

function PANEL:SetMetroColor(color)
	self.MetroColor = color;
end;

function PANEL:Paint(w, h)
	surface.SetDrawColor(self.ButtonColor);
	surface.DrawRect(0, 0, w, h);

	surface.SetDrawColor(self.MetroColor);
	surface.DrawRect(0, h - 2, w, 2);
end;

function PANEL:OnCursorEntered(w, h)
	self.ButtonColor = Color(26, 38, 46, 255);
end;

function PANEL:OnCursorExited(w, h)
	self.ButtonColor = DF_PANEL;
end;

vgui.Register("cwDfButton", PANEL, "DButton");

-- Entry for one of the scroll panels.
PANEL = {};

function PANEL:Init()
	self:SetZPos(1);
	self:SetTall(50);
	self:Dock(TOP);
	self:DockMargin(0, 5, 5, 0);

	self.PosterColor = Color(180, 180, 180, 255);

	self.Text = vgui.Create("DLabel", self);
	self.Text:SetTextColor(DF_TEXT)
	self.Text:SetFont("ixDfText");
	self.Text:SetText("");
	self.Text:SetWrap(true);
	self.Text:Dock(FILL);
	self.Text:DockMargin(8, 0, 4, 0);
	self.Text:SetContentAlignment(5);

	self.Date = vgui.Create("DLabel", self);
	self.Date:SetTextColor(DF_DIM);
	self.Date:SetFont("ixDfSmall");
	self.Date:SetText("");
	self.Date:SetWrap(true);
	self.Date:Dock(TOP);
	self.Date:DockMargin(8, 5, 0, 0);
	self.Date:SetContentAlignment(7);

	self.Poster = vgui.Create("DLabel", self);
	self.Poster:SetWrap(true);
	self.Poster:SetFont("ixDfSmall");
	self.Poster:SetTextColor(self.PosterColor);
	self.Poster:Dock(BOTTOM);
	self.Poster:DockMargin(8, 0, 0, 5);
	self.Poster:SetContentAlignment(1);

	self.Points = vgui.Create("DLabel", self.Date);
	self.Points:SetWrap(true);
	self.Points:SetWide(20)
	self.Points:Dock(RIGHT);
	self.Points:DockMargin(0, 0, 0, 0);
	self.Points:SetContentAlignment(9);
end;

function PANEL:Paint(w, h)
	surface.SetDrawColor(DF_DEEP);
	surface.DrawRect(0, 0, w, h);

	-- левый цветной акцент (как в терминальном досье) + нижняя линия
	surface.SetDrawColor(self.PosterColor);
	surface.DrawRect(0, 0, 3, h);
	surface.DrawRect(0, h - 1, w, 1);
end;

function PANEL:SetEntryText(noteText, dateText, posterText, pointsText, posterColor)
	if (posterColor) then
		self.PosterColor = posterColor;
		self.Poster:SetTextColor(self.PosterColor);
	end;

	self.Text:SetText(noteText);
	self.Date:SetText(dateText);
	self.Poster:SetText(posterText);
	self.Points:SetText(pointsText);

	if (pointsText < 0) then
		self.Points:SetTextColor(Color(255, 100, 100, 255))
	elseif (pointsText > 0) then
		self.Points:SetTextColor(Color(150, 255, 50, 255))
	else
		self.Points:SetText("");
		self.Points:SetTextColor(Color(220, 220, 220, 255))
	end;

	self:SetTall(60 + (string.len(self.Text:GetText()) / 28) * 11);
end;

vgui.Register("cwDfEntry", PANEL, "DPanel");

-- Info panel. Panel below the name of the player.
PANEL = {};

function PANEL:Init()
	self:Dock(TOP);
	self:SetTall(50);

	self.LeftHeaderLabel = vgui.Create("DLabel", self);
	self.LeftHeaderLabel:SetText(L("datafile.civilStatus"));
	self.LeftHeaderLabel:SetContentAlignment(4)
	self.LeftHeaderLabel:SetTextColor(Color(0, 150, 150, 255));
	self.LeftHeaderLabel:SetFont("TopBoldLabel");
	self.LeftHeaderLabel:Dock(FILL);
	self.LeftHeaderLabel:DockMargin(5, 5, 0, 0);

	self.MiddleHeaderLabel = vgui.Create("DLabel", self);
	self.MiddleHeaderLabel:SetText(L("datafile.points"));
	self.MiddleHeaderLabel:SetContentAlignment(5)
	self.MiddleHeaderLabel:SetTextColor(Color(231, 76, 60, 255));
	self.MiddleHeaderLabel:SetFont("TopBoldLabel");
	self.MiddleHeaderLabel:Dock(FILL);
	self.MiddleHeaderLabel:DockMargin(5, 5, 250, 0);

	self.MiddleHeader2Label = vgui.Create("DLabel", self);
    self.MiddleHeader2Label:SetText(L("datafile.registeredAt"));
    self.MiddleHeader2Label:SetContentAlignment(5)
    self.MiddleHeader2Label:SetTextColor(Color(231, 180, 60, 255));
    self.MiddleHeader2Label:SetFont("TopBoldLabel");
    self.MiddleHeader2Label:Dock(FILL);
    self.MiddleHeader2Label:DockMargin(5, 5, -235, 0);

	self.RightHeaderLabel = vgui.Create("DLabel", self);
	self.RightHeaderLabel:SetText(L("datafile.lastSeen"));
	self.RightHeaderLabel:SetContentAlignment(6)
	self.RightHeaderLabel:SetTextColor(Color(150, 150, 96, 255));
	self.RightHeaderLabel:SetFont("TopBoldLabel");
	self.RightHeaderLabel:Dock(FILL);
	self.RightHeaderLabel:DockMargin(0, 5, 5, 0);

	self.TextPanel = vgui.Create("DPanel", self);
	self.TextPanel:Dock(BOTTOM);
	self.TextPanel:SetTall(25)
	self.TextPanel.Paint = function() return false end;

	self.LeftTextLabel = vgui.Create("DLabel", self.TextPanel);
	self.LeftTextLabel:SetTextColor(Color(220, 220, 220, 255));
	self.LeftTextLabel:SetContentAlignment(4)
	self.LeftTextLabel:Dock(FILL);
	self.LeftTextLabel:DockMargin(5, 5, 5, 5);

	self.MiddleTextLabel = vgui.Create("DLabel", self.TextPanel);
	self.MiddleTextLabel:SetText("");
	self.MiddleTextLabel:SetTextColor(Color(0, 0, 0, 255));
	self.MiddleTextLabel:SetContentAlignment(5)
	self.MiddleTextLabel:Dock(FILL);
	self.MiddleTextLabel:DockMargin(5, 5, 225, 5);

	self.Middle2TextLabel = vgui.Create("DLabel", self.TextPanel);
    self.Middle2TextLabel:SetTextColor(Color(255, 255, 255, 255));
    self.Middle2TextLabel:SetContentAlignment(5)
    self.Middle2TextLabel:Dock(FILL);
    self.Middle2TextLabel:DockMargin(5, 5, -220, 5);

	self.RightTextLabel = vgui.Create("DLabel", self.TextPanel);
	self.RightTextLabel:SetTextColor(Color(220, 220, 220, 255));
	self.RightTextLabel:SetContentAlignment(6)
	self.RightTextLabel:Dock(FILL);
	self.RightTextLabel:DockMargin(5, 5, 5, 5);
end;

function PANEL:SetInfoText(civilStatus, lastSeen, reg)
	self.LeftTextLabel:SetText(civilStatus);
	self.RightTextLabel:SetText(lastSeen);
	self.Middle2TextLabel:SetText(reg or "");
end;

function PANEL:Paint()
	return false;
end;

vgui.Register("cwDfInfoPanel", PANEL, "DPanel");
