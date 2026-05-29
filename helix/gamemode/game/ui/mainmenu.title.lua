local scale = ix.UI.Scale

surface.CreateFont("cellar.main.warn", {
	font = "Blender Pro Medium",
	extended = true,
	size = 16,
	weight = 500,
	blursize = 0,
	scanlines = 0,
	antialias = true,
})

local clrConsole = Color(190, 102, 102, 10)
local console = Material("cellar/main/console")
local warning = Material("cellar/main/warning.png")
local tex = GetRenderTargetEx("ui_mainmenu_glow_rt", ScrW(), ScrH(), RT_SIZE_OFFSCREEN, MATERIAL_RT_DEPTH_SHARED, 0, 0, IMAGE_FORMAT_RGBA8888)
local rt_mat = CreateMaterial("ui_mainmenu_glow","UnlitGeneric",{
	["$basetexture"] = "ui_mainmenu_glow_rt",
	["$translucent"] = 1,
	["$vertexcolor"] = 1,
	["$vertexalpha"] = 1,
	["$additive"] = 1,
})
rt_mat:Recompute()

local PANEL = {}
PANEL.css = [[
#sidebar {
	position: absolute;
	left: 0;
	top: 0;
	bottom: 0;
	width: 13.5rem;
	background: rgba(22, 7, 7, 0.88);
	border-left: 3px solid #f84040;
	display: flex;
	flex-direction: column;
	padding: 1.75rem 0.85rem 1.25rem 0.85rem;
	box-sizing: border-box;
	animation: sidebar-in 0.5s ease forwards;
}
@keyframes sidebar-in {
	0% { opacity: 0; transform: translateX(-8%); }
	100% { opacity: 1; transform: translateX(0); }
}
#sidebar-logo {
	position: relative;
	border: 1px solid rgba(248,64,64,0.45);
	padding: 0.55rem 0.4rem;
	margin-bottom: 1.2rem;
}
#sidebar-logo::before, #sidebar-logo::after {
	display: none;
}
.logo-corner {
	position: absolute;
	width: 0.6rem;
	height: 0.6rem;
	background: rgba(22, 7, 7, 0.88);
	z-index: 1;
}
.logo-corner.tl { top: -1px; left: -1px; }
.logo-corner.tr { top: -1px; right: -1px; }
.logo-corner.bl { bottom: -1px; left: -1px; }
.logo-corner.br { bottom: -1px; right: -1px; }
#logo-text {
	font-family: "BlenderProBold";
	font-size: 1.15rem;
	letter-spacing: 0.3rem;
	text-align: center;
	display: block;
	padding: 0.28rem 0;
	-webkit-background-clip: text;
	-webkit-text-fill-color: transparent;
	background-image: repeating-linear-gradient(
		180deg,
		#f84040 0px,
		#f84040 3px,
		rgba(22, 7, 7, 0.88) 3px,
		rgba(22, 7, 7, 0.88) 4px
	);
	filter: drop-shadow(0 0 5px rgba(255,0,0,0.5));
}
.logo-sub {
	display: block;
	text-align: center;
	font-family: "BlenderProMedium";
	font-size: 0.44rem;
	letter-spacing: 0.14rem;
	color: rgba(248,64,64,0.32);
	margin-top: -0.1rem;
}
#sidebar-nav {
	flex: 1;
	display: flex;
	flex-direction: column;
}
.side-btn {
	display: flex;
	align-items: center;
	height: 1.72rem;
	margin-bottom: 0.12rem;
	border-left: 2px solid transparent;
	padding-left: 0.5rem;
	transition: background 80ms, border-color 80ms;
	animation: btn-in 0.4s ease forwards;
	opacity: 0;
}
.side-btn:nth-child(1) { animation-delay: 400ms; }
.side-btn:nth-child(2) { animation-delay: 300ms; }
.side-btn:nth-child(3) { animation-delay: 200ms; }
.side-btn:nth-child(4) { animation-delay: 100ms; }
.side-btn:nth-child(5) { animation-delay: 0ms; margin-top: auto; }
@keyframes btn-in {
	0% { opacity: 0; transform: translateX(-8px); }
	100% { opacity: 1; transform: translateX(0); }
}
.side-btn:hover {
	background: rgba(248,64,64,0.1);
	border-left-color: #f84040;
}
.side-btn a {
	color: rgba(248,64,64,0.75);
	font-family: "BlenderProBook";
	font-size: 0.7rem;
	letter-spacing: 0.1rem;
	text-shadow: 0 0 0.4rem rgba(255,0,0,0.25);
	line-height: 1.72rem;
	display: block;
	width: 100%;
}
.side-btn:hover a {
	color: #f84040;
	text-shadow: 0 0 0.5rem #f00;
}
.side-btn-dot {
	width: 0.22rem;
	height: 0.22rem;
	background: rgba(248,64,64,0.55);
	margin-right: 0.45rem;
	flex-shrink: 0;
}
.side-btn:hover .side-btn-dot {
	background: #f84040;
}
#sidebar-info {
	padding-top: 0.25rem;
	margin-top: 0.5rem;
}
.sinfo-line {
	font-family: "BlenderProMedium";
	font-size: 0.5rem;
	color: rgba(248,64,64,0.38);
	letter-spacing: 0.05rem;
	line-height: 1.3;
}
#footer-rule {
	position: absolute;
	bottom: 3rem;
	left: 0;
	right: 0;
	height: 1px;
	background: linear-gradient(90deg,
		rgba(248,64,64,0.35) 0,
		rgba(248,64,64,0.35) 13.5rem,
		rgba(248,64,64,0.12) 13.5rem,
		rgba(248,64,64,0.12) 55%,
		transparent 80%
	);
}

.hint-container {
	position: absolute;
	font-family: "BlenderProMedium";
	width: 50%;
	height: auto;
	right: 7.5%;
	bottom: 7.5%;
	color: #f84040;
	opacity: 0;
	font-size: 1.05rem;
}
.hint-anim-down {
	animation-name: fx-opacity-down;
}
.hint-anim-right {
	animation-name: fx-opacity-right;
}
.hint-fx-container {
	position: relative;
}
.hint-footer {
	position: relative;
}
.hint-footer.news {
	font-size: 1rem;
}
.hint-content {
	margin-top: -0.1rem;
	padding-left: 2.17rem;
	position: relative;
}
.hint-textbox {
	font-family: "BlenderProMedium";
	font-size: 0.675rem;
	font-weight: 500;
	padding: 0.75rem;
	background: linear-gradient(90deg, rgba(248,64,64,0.1) 0%, rgba(0,0,0,0) 100%);
}
.hint-textbox.news {
	font-size: 0.65rem;
	font-weight: 500;
	color: rgba(248, 64, 64, 0.75);
	background: rgba(248,64,64,0.1);
}
.hint-textbox.news strong {
	font-size: 0.75rem;
	font-weight: 500;
	color: #f84040;
}
.hint-textbox.news ul {
	margin-top: 0.1rem;
	margin-bottom: 0.5rem;
	padding-left: 1rem;
}
.hint-content:before, .hint-content:after {
    content: "";
    position: absolute;
    height: 100%;
    width: 0.1rem;
    top: 0px;
    background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' viewBox='0 0 1 1'%3E%3Cpath fill-rule='evenodd' fill='rgb(248, 64, 64)' d='M0.0,0.0 L1.0,0.0 L1.0,1.0 L0.0,1.0 L0.0,0.0 Z'/%3E%3C/svg%3E"), url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' viewBox='0 0 1 1'%3E%3Cpath fill-rule='evenodd' fill='rgb(248, 64, 64)' d='M0.0,0.0 L1.0,0.0 L1.0,1.0 L0.0,1.0 L0.0,0.0 Z'/%3E%3C/svg%3E");
    background-size: 0.1rem 0.1rem;
    background-position: top right, bottom right;
    background-repeat: no-repeat;
}
.hint-content:before {
    left: 2.17rem;
}
.hint-content:after {
    right: 0px;
}
span.hint-footer {
	display: inline-block;
	line-height: 2.17rem;
	width: 100%;
	padding-left: calc(2.17rem + 0.68rem);
}
span.hint-footer:before {
	content: "";
	background-image: url("asset://garrysmod/materials/ui/hint-ico.png");
	background-size: 2rem 2rem;
	width: 2rem;
	height: 2rem;
	position: absolute;
	left: 0;
}
span.hint-footer.news:before {
	background-image: none;
}
.hint-fx-top {
	position: absolute;
	border-bottom: 0.1rem solid rgba(248, 64, 64, 0.25);
	top: 0px;
	left: 0px;
	bottom: 0px;
	right: 0px;
	width: 0%;
	animation-name: fx-top;
}
@keyframes fx-top {
	2.5% {
		width: 0%;
	}
	7.5% {
		width: calc(100% + 0.34rem);
	}
	100% {
		width: calc(100% + 0.34rem);
	}
}
.hint-fx-left {
	position: absolute;
	border-right: 0.1rem solid rgba(248, 64, 64, 0.25);
	top: 0px;
	left: 0px;
	bottom: 0px;
	width: 2.17rem;
	height: 0%;
	animation-name: fx-left;
}
@keyframes fx-left {
	2.5% {
		height: 0%;
	}
	7.5% {
		height: calc(100% + 0.34rem);
	}
	100% {
		height: calc(100% + 0.34rem);
	}
}
.hint-fx-bottom {
	position: absolute;
	border-bottom: 0.1rem solid rgba(248, 64, 64, 0.25);
	top: 0px;
	left: calc(2.17rem - 0.34rem);
	bottom: 0px;
	width: 0%;
	animation-name: fx-bottom;
}
@keyframes fx-bottom {
	7.5% {
		width: 0%;
	}
	14% {
		width: calc(100% - calc(2.17rem - 0.34rem) + 0.34rem);
	}
	100% {
		width: calc(100% - calc(2.17rem - 0.34rem) + 0.34rem);
	}
}
.hint-fx-right {
	position: absolute;
	border-right: 0.1rem solid rgba(248, 64, 64, 0.25);
	top: -0.34rem;
	right: 0px;
	height: 0%;
	animation-name: fx-right;
}
@keyframes fx-right {
	7.5% {
		height: 0%;
	}
	14% {
		height: calc(100% + 0.68rem);
	}
	100% {
		height: calc(100% + 0.68rem);
	}
}
@keyframes fx-opacity-down {
	0% {
		opacity: 0;
		transform: translateY(50%);
	}
	5% {
		opacity: 1;
		transform: translateY(0px);
	}
	100% {
		opacity: 1;
	}
}
@keyframes fx-opacity-right {
	0% {
		opacity: 0;
		transform: translateX(50%);
	}
	5% {
		opacity: 1;
		transform: translateX(0px);
	}
	100% {
		opacity: 1;
	}
}
.hint-fx {  
	animation-duration: 15s;
	animation-timing-function: ease;
	animation-fill-mode: forwards;
}

html, body {
	height: 100%;
	padding: 0;
	margin: 0;
	font-size: 2.22vh;
	overflow: hidden;
	user-select: none;
	opacity: 0;
	animation: all-opacity 10s ease forwards;
}
@keyframes all-opacity {
	0% {
		opacity: 0;
	}
	3% {
		opacity: 0.3;
	}
	4% {
		opacity: 0.7;
	}
	5% {
		opacity: 0.4;
	}
	9% {
		opacity: 1;
	}
	100% {
		opacity: 1;
	}
}
#fx-border {
	background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' xmlns:xlink='http://www.w3.org/1999/xlink' width='1876.5px' height='1003.5px'%3E%3Cpath fill-rule='evenodd' stroke='rgb(248, 64, 64)' stroke-width='3px' stroke-linecap='butt' stroke-linejoin='miter' opacity='0.251' fill='none' d='M1873.499,889.499 L1855.499,889.499 L1746.500,998.500 L865.499,998.500 L850.500,983.500 L36.500,983.500 L3.500,950.500 L3.500,84.500 L84.499,3.499 L1213.500,3.499 L1236.499,26.499 L1873.499,26.499 '/%3E%3C/svg%3E");
	background-size: 100% 92.91%;
	background-repeat: no-repeat;
	background-position: center;
	position: absolute;
	width: 97.734375%;
	height: 100%;
	right: -1px;
}
a:link, a:visited, a:hover, a:active {
	text-decoration: none;
}
.warning {
	font-family: "BlenderProMedium";
	font-weight: 600;
	font-size: 0.65rem;
	color: #f83838;
	display: flex;
	align-items: center;
	position: absolute;
	top: 50vh;
	left: 11.2vh;
	animation: warning 1.25s ease-in-out infinite;
	text-shadow: 0 0 0.75em rgba(255, 0, 0, 0.75);
}
@keyframes warning {
	0% {
		opacity: 1;
	}
	50% {
		opacity: 0.75;
	}
	100% {
		opacity: 1;
	}
}
.warning-ico {
	background-image: url("asset://garrysmod/materials/ui/warning.png");
	background-size: 1.34rem 1.17rem;
	width: 1.34rem;
	height: 1.17rem;
	margin-right: 0.25rem;
}
.credits {
	font-family: "BlenderProBook";
	font-weight: 100;
	font-size: 0.62rem;
	color: rgba(200, 100, 100, 0.3);
	display: flex;
	align-items: center;
	justify-content: center;
	position: absolute;
	bottom: 0;
	left: 13.5rem;
	height: 3rem;
	width: calc(55% - 13.5rem);
	letter-spacing: 0.06rem;
}
]]

function PANEL:BuildPatchHTML()
	return [[
<strong>]] .. L("mainmenu.patchTitle") .. [[</strong>
<ul style="list-style: none;">
</ul>
<strong>]] .. L("mainmenu.patchCore") .. [[</strong>
<ul style="list-style: none;">
	<li>— ]] .. L("mainmenu.patchCoreText") .. [[</li>
</ul>
<strong>]] .. L("mainmenu.patchDate") .. [[</strong>
<ul style="list-style: none;">
</ul>
<strong>]] .. L("mainmenu.patchNew") .. [[</strong>
<ul style="list-style: none;">
	<li>— ]] .. L("mainmenu.patchNewText") .. [[</li>
</ul>
]]
end

function PANEL:BuildBodyHTML()
	return [[
<div id="fx-border"></div>
<div id="footer-rule"></div>
<div class="credits">DEVELOPED BY SCHWARZ KRUPPZO · MODIFIED BY HUTTEN</div>

<div class="hint-container hint-fx hint-anim-down">
	<div class="hint-fx-container">
		<div class="hint-footer">
			<span class="hint-footer">]] .. L("mainmenu.hintTitle") .. [[</span>
			<div class="hint-fx-top hint-fx"></div>
		</div>
		<div class="hint-content">
			<div class="hint-textbox">]] .. L("mainmenu.hintText") .. [[</div>
			<div class="hint-fx-bottom hint-fx"></div>
			<div class="hint-fx-right hint-fx"></div>
		</div>
		<div class="hint-fx-left hint-fx"></div>
	</div>
</div>

<div class="hint-container hint-fx hint-anim-right" style="top: 25%; right: 1%; width: 27.5%;">
	<div class="hint-fx-container">
		<div class="hint-footer ">
			<span class="hint-footer news">]] .. L("mainmenu.versionLabel") .. [[</span>
			<div class="hint-fx-top hint-fx"></div>
		</div>
		<div class="hint-content">
			<div class="hint-textbox news">
]] .. self:BuildPatchHTML() .. [[
			</div>
			<div class="hint-fx-bottom hint-fx"></div>
			<div class="hint-fx-right hint-fx"></div>
		</div>
		<div class="hint-fx-left hint-fx"></div>
	</div>
</div>

<div id="sidebar">
	<div id="sidebar-logo">
		<span class="logo-corner tl"></span>
		<span class="logo-corner tr"></span>
		<span id="logo-text">LEGENDS</span>
		<span class="logo-sub">HALF-LIFE 2 ROLEPLAY</span>
		<span class="logo-corner bl"></span>
		<span class="logo-corner br"></span>
	</div>
	<div id="sidebar-nav">
		<div class="side-btn">
			<div class="side-btn-dot"></div>
			<a href="#" onclick="menu.Button(1);">]] .. L("mainmenu.btnNewArrival") .. [[</a>
		</div>
		<div class="side-btn">
			<div class="side-btn-dot"></div>
			<a href="#" onclick="menu.Button(2);">]] .. L("mainmenu.btnCharacters") .. [[</a>
		</div>
		<div class="side-btn">
			<div class="side-btn-dot"></div>
			<a href="#" onclick="menu.Button(3);">]] .. L("mainmenu.btnContent") .. [[</a>
		</div>
		<div class="side-btn">
			<div class="side-btn-dot"></div>
			<a href="#" onclick="menu.Button(4);">]] .. L("mainmenu.btnInfo") .. [[</a>
		</div>
		<div class="side-btn">
			<div class="side-btn-dot"></div>
			<a href="#" onclick="menu.Button(5);">]] .. L("mainmenu.btnClose") .. [[</a>
		</div>
	</div>
	<div id="sidebar-info">
		<div class="sinfo-line">]] .. L("mainmenu.versionLabel") .. [[</div>
		<div class="sinfo-line">]] .. L("mainmenu.warningText") .. [[</div>
	</div>
</div>]]
end
PANEL.java = [[
const restart_anim = ($el) => {
	$el.getAnimations().forEach((anim) => {
		anim.cancel();
		anim.play();
	});
};


function reload_animations() {
	restart_anim(document.documentElement);
	const sidebar = document.getElementById('sidebar');
	if (sidebar) restart_anim(sidebar);

	document.querySelectorAll('.side-btn').forEach((el) => {
		restart_anim(el);
	});

	document.querySelectorAll('.hint-fx').forEach((el) => {
		restart_anim(el);
	});
};
]]

local pos, ang = vector_origin, Angle()
local mdlang = Angle(0, -90, 0)

function PANEL:BuildFullHTML()
	return [[<html>
		<body oncontextmenu="return false">
			<style>
				@font-face {
					font-family: BlenderProBook; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-Book.ttf");
				}
				@font-face {
					font-family: BlenderProBook; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-BookItalic.ttf");
					font-style: italic;
				}
				@font-face {
					font-family: BlenderProBold; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-Bold.ttf");
				}
				@font-face {
					font-family: BlenderProBold; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-BoldItalic.ttf");
					font-style: italic;
				}
				@font-face {
					font-family: BlenderProMedium; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-Medium.ttf");
				}
				@font-face {
					font-family: BlenderProMedium; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-MediumItalic.ttf");
					font-style: italic;
				}
				@font-face {
					font-family: BlenderProThin; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-Thin.ttf");
				}
				@font-face {
					font-family: BlenderProThin; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-ThinItalic.ttf");
					font-style: italic;
				}
				@font-face {
					font-family: BlenderProHeavy; 
					src: url("asset://garrysmod/resource/fonts/BlenderPro-Heavy.ttf");
				}

			]] .. self.css .. [[</style>]] .. self:BuildBodyHTML() .. [[<script>]] .. self.java .. [[</script>
		</body>
	</html>]]
end

function PANEL:RefreshHTML()
	self:SetHTML(self:BuildFullHTML())
end

function PANEL:Init()
	self.mdl = ClientsideModel('models/cellar/logo.mdl', RENDERGROUP_OPAQUE)
	self.mdl:SetNoDraw(true)
	self.mdl:SetupBones()

	self:SetSize(ScrW(), ScrH())
	self:Center()
	self:SetAlpha(255)
	self:SetAllowLua(true)
	self:RefreshHTML()

	self:AddFunction("menu", "Button", function(id)
		self:MenuClick(tonumber(id))

		LocalPlayer():EmitSound("Helix.Press")
	end)

	self:AddFunction("menu", "Hover", function()
		LocalPlayer():EmitSound("Helix.Rollover")
	end)

	cvars.AddChangeCallback("gmod_language", function()
		if IsValid(self) then
			self:RefreshHTML()
		end
	end, "ui.mainmenu.lang")
end

function PANEL:OnRemove()
	cvars.RemoveChangeCallback("gmod_language", "ui.mainmenu.lang")
end

function PANEL:MenuClick(id)
	local parent = self:GetParent()

	parent:MenuClick(id, self)
end

function PANEL:Show()
	local function render_glow()
		render.PushRenderTarget(tex)
			render.Clear(0, 0, 0, 150)
		
			cam.Start2D()
				if IsValid(self) then
					self.paint_manual = true
					--self:SetPaintedManually(true)
					self:PaintManual()
					--self:SetPaintedManually(false)
					self.paint_manual = false
				end
			cam.End2D()
			render.BlurRenderTarget(tex, 8, 2, 10)
		render.PopRenderTarget()
	end

	hook.Add("HUDPaint", "ui.mainmenu.glow", render_glow)

	ix.UI:Scanline(true)

	self:QueueJavascript("reload_animations();")
end

function PANEL:Paint(w, h)
	if !self.paint_manual then
		surface.SetMaterial(rt_mat)
		surface.SetDrawColor(color_white)
		surface.DrawTexturedRect(0, 0, w, h)
	end

	render.SetBlend(1 * self:GetAlpha())
	render.SetColorModulation(1, 1, 1)
	
	--[[ 3D logo model replaced by sidebar HTML logo
	cam.Start3D(pos, ang, 5, 0, 0, nil, nil, 0.01, 5280)
		render.SuppressEngineLighting(true)
		self.mdl:SetPos(pos + Vector(580, 20, 7))
		self.mdl:SetAngles(mdlang)
		self.mdl:DrawModel()
		render.SuppressEngineLighting(false)
	cam.End3D()
	--]]

	local h = h - 100 - 155
	surface.SetMaterial(console)
	surface.SetDrawColor(clrConsole)
	surface.DrawTexturedRectUV(w - 512, 50 + 7, 512, h, 0, 0, 1, h / 1024)
end

vgui.Register("ui.mainmenu", PANEL, "DHTML")



local PANEL = {}

AccessorFunc(PANEL, "bUsingCharacter", "UsingCharacter", FORCE_BOOL)

local cyb = Material("ui/vignette.png")

function PANEL:Init()
	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()

	self.bg = self:Add("EditablePanel")
	self.bg:Dock(FILL)
	self.bg.Paint = function(this, w, h)
		surface.SetDrawColor(color_black)
		surface.SetMaterial(cyb)
		surface.DrawTexturedRect(0, 0, w, h)

		if BRANCH != "x86-64" then
			surface.SetTextColor(255, 0, 0)
			surface.SetFont("Session")
			surface.SetTextPos(50, 50)
			surface.DrawText(L("mainmenu.x86Warning"))
		end
	end
	
	self.html = self:Add("ui.mainmenu")
end

function PANEL:UpdateReturnButton(bValue)
	if bValue != nil then
		self.bUsingCharacter = bValue
	end
end

function PANEL:OnDim()
	self:SetMouseInputEnabled(false)
	self:SetKeyboardInputEnabled(false)

	ix.UI:Scanline(false)

	hook.Remove("HUDPaint", "ui.mainmenu.glow")
end

function PANEL:OnUndim()
	self:SetMouseInputEnabled(true)
	self:SetKeyboardInputEnabled(true)

	self.html:Show()

	self.bUsingCharacter = LocalPlayer().GetCharacter and LocalPlayer():GetCharacter()
	self:UpdateReturnButton()
end

function PANEL:MenuClick(id)
	local parent = self:GetParent()
	local maximum = hook.Run("GetMaxPlayerCharacter", LocalPlayer()) or ix.config.Get("maxCharacters", 5)
	local bHasCharacter = #ix.characters > 0

	if id == 1 then
		if (#ix.characters >= maximum) then
			parent:ShowNotice(3, L("maxCharacters"))
			return
		end

		self:Dim(parent.newCharacterPanel, function()
			parent.newCharacterPanel:SetActiveSubpanel("faction", 0)
		end)
	elseif id == 2 then
		if !bHasCharacter then
			parent:ShowNotice(3, L("mainmenu.needCharacter"))
		else
			self:Dim(parent.loadCharacterPanel)
		end
	elseif id == 3 then
		gui.OpenURL("https://steamcommunity.com/sharedfiles/filedetails/?id=3680347522")
	elseif id == 4 then
		gui.OpenURL("https://discord.gg/M8FRCsKHSU")
	elseif id == 5 then
		if self.bUsingCharacter then
			parent:Close()
		else
			RunConsoleCommand("disconnect")
		end
	end
end

vgui.Register("ui.mainmenu.wrapper", PANEL, "ixCharMenuPanel")