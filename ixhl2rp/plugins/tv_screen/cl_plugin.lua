local PLUGIN = PLUGIN

PLUGIN.currentMaterial = PLUGIN.defaultMaterial
PLUGIN.mat             = nil
PLUGIN.blackMat        = nil
PLUGIN.htmlPanel       = nil   -- HTML panel for URL images

PLUGIN.currentSound   = ""
PLUGIN.soundStartTime = 0
PLUGIN.tvSoundObjs    = {}
PLUGIN.tvSoundOnce    = false  -- true = video-file audio, don't restart when channel stops

PLUGIN.cachedTVs   = {}
PLUGIN.lastCacheAt = -999

local CACHE_INTERVAL = 5

local function IsURL(path)
	return isstring(path) and (path:find("^https?://") ~= nil)
end

local function RefreshTVCache()
	local now = CurTime()
	if now - PLUGIN.lastCacheAt < CACHE_INTERVAL then return end
	PLUGIN.lastCacheAt = now

	local tvs = {}
	for model in pairs(PLUGIN.tvModels) do
		for _, ent in ipairs(ents.FindByModel(model)) do
			if IsValid(ent) then table.insert(tvs, ent) end
		end
	end
	PLUGIN.cachedTVs = tvs
end

local function StopAllSounds()
	for _, ch in pairs(PLUGIN.tvSoundObjs) do
		if IsValid(ch) then ch:Stop() end
	end
	PLUGIN.tvSoundObjs = {}
end

-- Returns or creates the off-screen HTML panel used for URL content.
-- SetVisible(false) mutes Chromium audio, so we position it off-screen instead.
local function GetHTMLPanel()
	if not IsValid(PLUGIN.htmlPanel) then
		local p = vgui.Create("HTML")
		p:SetSize(1920, 1080)
		p:SetPos(-2000, -2000)   -- off-screen, not hidden
		p:SetMouseInputEnabled(false)
		p:SetKeyboardInputEnabled(false)
		PLUGIN.htmlPanel = p
	end
	return PLUGIN.htmlPanel
end

-- JS snippet injected into every page to force unmuted autoplay.
local AUTOPLAY_JS = [[
<script>
(function() {
    function forcePlay() {
        document.querySelectorAll("video,audio").forEach(function(el) {
            el.muted  = false;
            el.volume = 1;
            if (el.paused) el.play().catch(function() {});
        });
    }
    document.addEventListener("DOMContentLoaded", forcePlay);
    setTimeout(forcePlay, 500);
    setTimeout(forcePlay, 2000);
})();
</script>
]]

-- Detect URL type and load appropriate content into the HTML panel.
-- IMPORTANT: all HTML panel audio is muted.
-- HTML panel audio is inherently 2D (global), so we suppress it here and let
-- the ix_tv_sound / CreateTVChannel system handle positional 3D audio instead.
local function LoadURLContent(url)
	local p = GetHTMLPanel()

	-- YouTube: navigate directly to embed URL.
	-- mute=1 suppresses 2D global audio; no loop.
	local ytID = url:match("[?&]v=([%w%-_]+)") or url:match("youtu%.be/([%w%-_]+)")
	if ytID then
		p:OpenURL("https://www.youtube.com/embed/" .. ytID
			.. "?autoplay=1&mute=1&controls=0&rel=0")
		return
	end

	-- Twitch: muted=true suppresses 2D audio.
	local twitchChannel = url:match("twitch%.tv/([%w_]+)$")
	if twitchChannel then
		p:OpenURL("https://player.twitch.tv/?channel=" .. twitchChannel
			.. "&parent=twitch.tv&autoplay=true&muted=true")
		return
	end

	-- Classify by extension. Strip query/fragment and lowercase first, otherwise
	-- "clip.MP4" or "host/file.webm?token=..." get misdetected and fall through to
	-- the <img> branch (which shows nothing for a video). Anything that isn't a
	-- known IMAGE type is treated as video — for a TV, extensionless/stream links
	-- (CDN redirects, etc.) are far more likely to be video than image.
	-- NOTE: GMod's Chromium has NO H.264 codec, so .mp4 will load but render black.
	-- Use .webm (VP8/VP9) or .ogg/.ogv for direct video.
	local clean = (url:lower():match("^[^?#]+")) or url:lower()
	local isImage = clean:match("%.png$") or clean:match("%.jpe?g$") or clean:match("%.gif$")
		or clean:match("%.webp$") or clean:match("%.bmp$") or clean:match("%.svg$")

	-- Direct video: muted (3D audio via CreateTVChannel), plays ONCE (no loop).
	-- onended: clears screen and tells Lua to stop 3D audio channels.
	local body
	if not isImage then
		-- Video starts muted for autoplay policy compliance.
		-- The ix_tv_html_volume Think hook immediately adjusts volume via RunJavascript.
		body = '<video id="v" src="' .. url .. '" autoplay playsinline muted '
			.. 'style="width:100%;height:100%;object-fit:contain;background:#000;display:block;">'
			.. '</video>'
			.. '<script>'
			.. 'var v=document.getElementById("v");'
			.. 'v.onended=function(){'
			..   'document.body.style.background="#000";'
			..   'v.style.display="none";'
			.. '};'
			.. '</script>'

	-- Image / GIF: no audio concerns.
	else
		body = '<img src="' .. url .. '" '
			.. 'style="width:100%;height:100%;object-fit:contain;display:block;">'
	end

	p:SetHTML('<html><head><style>'
		.. 'html,body{margin:0;padding:0;background:#000;width:100%;height:100%;overflow:hidden;}'
		.. '</style></head><body>' .. body .. '</body></html>')
end

-- Create one sound channel for a TV entity.
local function CreateTVChannel(ent)
	if not IsValid(ent) then return end
	if PLUGIN.currentSound == "" then return end

	local idx       = ent:EntIndex()
	local soundPath = PLUGIN.currentSound
	local startTime = PLUGIN.soundStartTime
	local flags     = "3d noblock"

	local function onChannel(channel, errNum)
		if not IsValid(channel) then return end
		if PLUGIN.currentSound != soundPath then channel:Stop(); return end
		if not IsValid(ent) then channel:Stop(); return end

		local len    = channel:GetLength()
		local offset = CurTime() - startTime
		if len > 0 then offset = offset % len end
		if offset > 0 then channel:SetTime(offset) end

		channel:SetPos(ent:GetPos())
		channel:Set3DFadeDistance(80, 500)

		local isOn = ent:GetNWBool("tv_on", true)
		channel:SetVolume(isOn and 1 or 0)
		channel:Play()

		PLUGIN.tvSoundObjs[idx] = channel
	end

	if IsURL(soundPath) then
		sound.PlayURL(soundPath, flags, onChannel)
	else
		sound.PlayFile("sound/" .. soundPath, flags, onChannel)
	end
end

-- Receive new material / image URL from server.
net.Receive("ix_tv_setmaterial", function()
	local path = net.ReadString()
	PLUGIN.currentMaterial = path

	if IsURL(path) then
		PLUGIN.mat = nil
		LoadURLContent(path)

		-- Video audio is handled by the HTML panel itself with distance-based JS volume.
		-- (sound.PlayURL cannot decode video containers, so we don't use it here.)
	else
		PLUGIN.mat = Material(path)
	end
end)

-- Receive sound update from server.
net.Receive("ix_tv_sound", function()
	local path      = net.ReadString()
	local startTime = net.ReadDouble()

	PLUGIN.currentSound   = path
	PLUGIN.soundStartTime = startTime
	PLUGIN.tvSoundOnce    = false  -- manual sound command = looping/persistent

	StopAllSounds()
	if path == "" then return end

	for _, ent in ipairs(PLUGIN.cachedTVs) do
		CreateTVChannel(ent)
	end
end)

-- Receive config update from server.
net.Receive("ix_tv_config", function()
	local model         = net.ReadString()
	local forwardOffset = net.ReadFloat()
	local rightOffset   = net.ReadFloat()
	local upOffset      = net.ReadFloat()
	local width         = net.ReadFloat()
	local height        = net.ReadFloat()
	local pitch         = net.ReadFloat()
	local yaw           = net.ReadFloat()
	local roll          = net.ReadFloat()

	if PLUGIN.tvModels[model] then
		local cfg = PLUGIN.tvModels[model]
		cfg.forwardOffset = forwardOffset
		cfg.rightOffset   = rightOffset
		cfg.upOffset      = upOffset
		cfg.width         = width
		cfg.height        = height
		cfg.pitch         = pitch
		cfg.yaw           = yaw
		cfg.roll          = roll
	end
end)

PLUGIN.tvLastState = {}

local lastSoundTick = 0
hook.Add("Think", "ix_tv_sound_update", function()
	-- Update 3D position every frame.
	for _, ent in ipairs(PLUGIN.cachedTVs) do
		if not IsValid(ent) then continue end
		local ch = PLUGIN.tvSoundObjs[ent:EntIndex()]
		if IsValid(ch) then ch:SetPos(ent:GetPos()) end
	end

	-- (UpdateHTMLTexture is called in the render hook for better frame timing)

	-- Every 2 seconds: open missing channels (only for persistent/looping sounds).
	-- tvSoundOnce=true means a video file played once — don't restart stopped channels.
	local now = CurTime()
	if now - lastSoundTick < 2 then return end
	lastSoundTick = now

	if PLUGIN.currentSound == "" then return end
	if PLUGIN.tvSoundOnce then return end  -- one-shot video audio, never restart
	for _, ent in ipairs(PLUGIN.cachedTVs) do
		if IsValid(ent) and not IsValid(PLUGIN.tvSoundObjs[ent:EntIndex()]) then
			CreateTVChannel(ent)
		end
	end
end)

-- Distance-based volume control for HTML panel video/audio.
-- sound.PlayURL cannot decode video containers, so we control the HTML panel's
-- own audio via RunJavascript. Volume is 1.0 up to 80 units, fades to 0 at 500 units.
do
	local lastTick     = 0
	local lastVol      = -1
	local lastMaterial = ""
	local DIST_FULL   = 60
	local DIST_SILENT = 200

	hook.Add("Think", "ix_tv_html_volume", function()
		-- Reset when material changes so the new video element gets unmuted immediately.
		if PLUGIN.currentMaterial != lastMaterial then
			lastMaterial = PLUGIN.currentMaterial
			lastVol = -1
		end

		if not IsURL(PLUGIN.currentMaterial) then
			-- Ensure panel is silent when not showing URL content.
			if lastVol != 0 and IsValid(PLUGIN.htmlPanel) then
				lastVol = 0
				PLUGIN.htmlPanel:RunJavascript(
					'document.querySelectorAll("video,audio").forEach(function(e){try{e.volume=0;e.muted=true;}catch(x){}});'
				)
			end
			return
		end
		if not IsValid(PLUGIN.htmlPanel) then return end

		local now = CurTime()
		if now - lastTick < 0.05 then return end   -- 20 updates/sec
		lastTick = now

		local ply = LocalPlayer()
		if not IsValid(ply) then return end

		-- Find nearest ON TV entity (off TVs don't emit sound).
		local minDist = math.huge
		for _, ent in ipairs(PLUGIN.cachedTVs) do
			if IsValid(ent) and ent:GetNWBool("tv_on", true) then
				local d = ply:GetPos():Distance(ent:GetPos())
				if d < minDist then minDist = d end
			end
		end

		-- Linear falloff between DIST_FULL and DIST_SILENT.
		local vol = 0
		if minDist <= DIST_FULL then
			vol = 1
		elseif minDist < DIST_SILENT then
			vol = 1 - (minDist - DIST_FULL) / (DIST_SILENT - DIST_FULL)
		end
		vol = math.Round(vol, 2)

		if vol == lastVol then return end
		lastVol = vol

		local muted = vol <= 0 and "true" or "false"
		PLUGIN.htmlPanel:RunJavascript(
			'document.querySelectorAll("video,audio").forEach(function(e){'
			..   'try{e.muted=' .. muted .. ';if(!e.muted)e.volume=' .. vol .. ';}catch(x){}'
			.. '});'
		)
	end)
end

hook.Add("PostDrawOpaqueRenderables", "ix_tv_screen_render", function()
	if not PLUGIN.mat and not IsURL(PLUGIN.currentMaterial) then
		PLUGIN.mat = Material(PLUGIN.currentMaterial)
	end
	if not PLUGIN.blackMat then
		PLUGIN.blackMat = Material("blackscreen")
		if PLUGIN.blackMat:IsError() then PLUGIN.blackMat = nil end
	end

	RefreshTVCache()
	if table.IsEmpty(PLUGIN.cachedTVs) then return end

	-- For URL images, grab the HTML panel material each frame.
	-- UpdateHTMLTexture must be called right before sampling to get the latest frame.
	-- DrawTexturedRectUV is required: GMod pads HTML textures to the next power-of-2
	-- (e.g. 1920x1080 → 2048x2048), so plain DrawTexturedRect only fills ~53% vertically.
	local urlMat = nil
	local urlU, urlV = 1, 1
	if IsURL(PLUGIN.currentMaterial) and IsValid(PLUGIN.htmlPanel) then
		PLUGIN.htmlPanel:UpdateHTMLTexture()
		urlMat = PLUGIN.htmlPanel:GetHTMLMaterial()
		if urlMat then
			local tex = urlMat:GetTexture("$basetexture")
			if tex then
				local tw, th = tex:Width(), tex:Height()
				if tw > 0 and th > 0 then
					urlU = 1920 / tw
					urlV = 1080 / th
				end
			end
		end
	end

	for _, ent in ipairs(PLUGIN.cachedTVs) do
		if not IsValid(ent) then continue end

		local config = PLUGIN.tvModels[ent:GetModel()]
		if not config then continue end

		local pos = ent:LocalToWorld(Vector(
			config.forwardOffset,
			config.rightOffset or 0,
			config.upOffset
		))

		local ang = ent:GetAngles()
		ang:RotateAroundAxis(ang:Forward(), config.roll  or 0)
		ang:RotateAroundAxis(ang:Right(),   config.pitch or 0)
		ang:RotateAroundAxis(ang:Up(),      config.yaw   or 0)

		local scale = 0.1
		local pw = config.width  / scale * 0.5
		local ph = config.height / scale * 0.5

		local isOn = ent:GetNWBool("tv_on", true)
		local idx  = ent:EntIndex()

		if PLUGIN.tvLastState[idx] != isOn then
			PLUGIN.tvLastState[idx] = isOn
			local ch = PLUGIN.tvSoundObjs[idx]
			if IsValid(ch) then ch:SetVolume(isOn and 1 or 0) end
		end

		cam.Start3D2D(pos, ang, scale)
			if isOn then
				local mat = urlMat or PLUGIN.mat
				if mat then
					surface.SetMaterial(mat)
					surface.SetDrawColor(255, 255, 255, 255)
					if mat == urlMat then
						-- Use correct UV bounds to avoid power-of-2 padding crop.
						surface.DrawTexturedRectUV(-pw, -ph, pw * 2, ph * 2, 0, 0, urlU, urlV)
					else
						surface.DrawTexturedRect(-pw, -ph, pw * 2, ph * 2)
					end
				else
					surface.SetDrawColor(0, 0, 0, 255)
					surface.DrawRect(-pw, -ph, pw * 2, ph * 2)
				end
			else
				if PLUGIN.blackMat then
					surface.SetMaterial(PLUGIN.blackMat)
					surface.SetDrawColor(255, 255, 255, 255)
					surface.DrawTexturedRect(-pw, -ph, pw * 2, ph * 2)
				else
					surface.SetDrawColor(0, 0, 0, 255)
					surface.DrawRect(-pw, -ph, pw * 2, ph * 2)
				end
			end
		cam.End3D2D()
	end
end)
