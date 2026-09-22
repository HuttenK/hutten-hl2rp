-- The landing screen uses the existing character-menu actions. All typography,
-- geometry and artwork are local; the DHTML bridge exposes only menu buttons.
local PANEL = {}
PANEL.css = [[
:root{--ink:#e8e9de;--dim:#99a9a9;--gold:#ddb873;--line:#334145;--bg:#0c1114}
*{box-sizing:border-box}html,body{margin:0;width:100%;height:100%;overflow:hidden;color:var(--ink);font-family:'Segoe UI',sans-serif}
body{background:linear-gradient(90deg,rgba(8,13,17,.97),rgba(8,13,17,.73) 60%,rgba(8,13,17,.85));font-size:clamp(13px,1.12vw,20px)}
button{font:inherit;cursor:pointer}button:focus-visible{outline:2px solid var(--gold);outline-offset:5px}
.screen{height:100%;display:grid;grid-template-rows:76px 1fr 52px;padding:0 4.5vw;animation:enter .35s ease-out}
header,footer{display:flex;align-items:center;justify-content:space-between;border-bottom:1px solid var(--line);font:12px Consolas,monospace;letter-spacing:.14em;color:var(--dim)}
.mark{color:var(--gold);display:flex;align-items:center;gap:16px}.mark:before{content:'';width:5px;height:26px;background:var(--gold)}
main{display:grid;grid-template-columns:1.35fr 1fr;gap:7vw;align-items:center;position:relative;min-height:0}
.hero{padding:3vh 0;position:relative;z-index:1}.eyebrow{font:12px Consolas,monospace;letter-spacing:.24em;color:var(--gold);margin-bottom:3vh}
h1{font-family:Bahnschrift,'Segoe UI',sans-serif;font-size:clamp(54px,7.6vw,150px);font-weight:600;letter-spacing:-.065em;line-height:.9;margin:0 0 1.7vh}
.subtitle{font:13px Consolas,monospace;letter-spacing:.4em;color:var(--dim)}
.intro{margin:4vh 0;max-width:36em;line-height:1.75;color:var(--dim);font-size:.95em}
.citadel{position:absolute;width:46%;height:70%;bottom:5%;left:12%;opacity:.12;pointer-events:none}
.coordinates{display:flex;gap:28px;font:11px Consolas,monospace;color:var(--dim);letter-spacing:.12em;border-top:1px solid var(--line);padding-top:20px}
nav{border-top:1px solid var(--gold);position:relative;z-index:2}.nav-label{font:12px Consolas,monospace;color:var(--gold);letter-spacing:.15em;padding:22px 0}
.action{width:100%;border:0;border-top:1px solid var(--line);background:transparent;color:var(--ink);text-align:left;padding:20px 4px;display:flex;align-items:center;gap:22px;transition:background .15s,padding .15s}
.action:hover{background:#1b2428;padding-left:14px}.action .num{font:12px Consolas,monospace;color:var(--dim)}.action .arrow{margin-left:auto;color:var(--gold)}
.action.primary{background:var(--gold);color:var(--bg);padding:22px 18px;border:0;font-weight:600}.action.primary .num,.action.primary .arrow{color:var(--bg)}.action.primary:hover{background:#ecd09a}
.support{display:flex;gap:20px;margin-top:24px}.support button{padding:5px 0;background:transparent;border:0;color:var(--dim);font-size:.8em}.support button:hover{color:var(--gold)}
.notice{margin-top:3vh;padding:16px 0 0;border-top:1px solid var(--line);font-size:.76em;line-height:1.6;color:var(--dim)}
footer{border-top:1px solid var(--line);border-bottom:0;font-size:10px;letter-spacing:.07em}footer span:last-child{color:var(--gold)}
@keyframes enter{from{opacity:0;transform:translateY(8px)}to{opacity:1;transform:none}}
@media(max-width:1000px){.screen{grid-template-rows:60px 1fr 40px}main{gap:4vw}.action{padding:16px 4px;gap:12px}.intro{margin:3vh 0}.subtitle{letter-spacing:.2em}.coordinates{gap:12px;font-size:9px}header{font-size:10px}}
@media(max-height:600px){.notice,.coordinates{display:none}.intro{margin:15px 0}.action{padding:12px 4px}.screen{grid-template-rows:48px 1fr 30px}.nav-label{padding:12px 0}}
@media(prefers-reduced-motion:reduce){*{animation:none!important;transition:none!important}}
]]

local function Escape(text)
	return tostring(text):gsub("&", "&amp;"):gsub("<", "&lt;"):gsub(">", "&gt;"):gsub('"', "&quot;")
end

function PANEL:BuildBodyHTML()
	local function phrase(key) return Escape(L(key)) end
	local function button(id, key, primary)
		return '<button class="action' .. (primary and ' primary' or '') .. '" onclick="menu.Button(' .. id .. ')"><span class="num">0' .. id .. '</span><span>' .. phrase(key) .. '</span><span class="arrow">↗</span></button>'
	end
	return [[<div class="screen"><header><span class="mark">C24 / CIVIC LINK</span><span>HALF-LIFE 2 ROLEPLAY</span></header>
<main><svg class="citadel" viewBox="0 0 420 700" preserveAspectRatio="xMidYMax meet" aria-hidden="true"><path fill="#99a9a9" d="M0 700V520h44V460h38v170h28V370h26v280h30L189 90l24-80 22 80 35 540h28V420h38v100h45v-90h39v270z"/><path fill="none" stroke="#ddb873" stroke-width="2" d="M205 100v570m-14-500-7 400m52-370 18 420M0 680h420"/></svg>
<section class="hero"><div class="eyebrow">]] .. phrase("civic.arrival") .. [[</div><h1>LEGENDS</h1><div class="subtitle">HUTTEN · CITY 24</div>
<p class="intro">]] .. phrase("civic.manifesto") .. [[</p><div class="coordinates"><span>01 / IDENTITY</span><span>02 / SURVIVAL</span><span>03 / CONSEQUENCE</span></div></section>
<nav><div class="nav-label">]] .. phrase("civic.access") .. [[</div>]] ..
		button(2, "mainmenu.btnCharacters", true) .. button(1, "mainmenu.btnNewArrival") .. button(5, "mainmenu.btnClose") ..
		[[<div class="support"><button onclick="menu.Button(3)">]] .. phrase("mainmenu.btnContent") .. [[ ↗</button><button onclick="menu.Button(4)">]] .. phrase("mainmenu.btnInfo") .. [[ ↗</button></div><div class="notice">]] .. phrase("mainmenu.hintText") .. [[</div></nav></main>
<footer><span>HELIX / AUTONOMOUS — SCHWARZ KRUPPZO · MODIFIED BY HUTTEN</span><span>]] .. phrase("civic.subtitle") .. [[</span></footer></div>]]
end

function PANEL:BuildFullHTML()
	return '<!doctype html><html><head><meta charset="UTF-8"><meta name="viewport" content="width=device-width, initial-scale=1"><style>' .. self.css .. '</style></head><body oncontextmenu="return false">' .. self:BuildBodyHTML() .. '</body></html>'
end

function PANEL:RefreshHTML()
	self:SetHTML(self:BuildFullHTML())
end

function PANEL:Init()
	self:SetSize(ScrW(), ScrH())
	self:SetAllowLua(false)
	self:AddFunction("menu", "Button", function(id)
		id = tonumber(id)
		if not id or id < 1 or id > 5 or id ~= math.floor(id) then return end
		local parent = self:GetParent()
		if IsValid(parent) and parent.MenuClick then parent:MenuClick(id, self) end
		surface.PlaySound("buttons/lightswitch2.wav")
	end)
	self:RefreshHTML()
	cvars.AddChangeCallback("gmod_language", function()
		if IsValid(self) then self:RefreshHTML() end
	end, "civic.title.language")
end

function PANEL:Show()
	self:SetVisible(true)
	ix.UI:Scanline(false)
end

function PANEL:OnRemove()
	cvars.RemoveChangeCallback("gmod_language", "civic.title.language")
end

vgui.Register("ui.mainmenu", PANEL, "DHTML")
