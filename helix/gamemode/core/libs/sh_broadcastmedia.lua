-- Shared, bounded media validation and client audio ownership for world devices.
ix.BroadcastMedia = ix.BroadcastMedia or {}
local M = ix.BroadcastMedia

function M.ValidSource(path, allowEmpty)
	if not isstring(path) or #path > 2048 then return false end
	if path == "" then return allowEmpty == true end
	if path:find('[%c<>"\']') then return false end
	if path:match("^https?://[^/%s]+") then return not path:find("%s") end
	return not path:find(":", 1, true) and not path:find("..", 1, true)
		and not path:find("\\", 1, true) and path:sub(1, 1) ~= "/"
end

function M.Volume(distance, full, silent)
	return math.Clamp((silent - distance) / (silent - full), 0, 1)
end

function M.StartTime(previous)
	-- Distinguish repeated commands even when they arrive in the same server tick.
	return math.max(CurTime(), (previous or 0) + 0.001)
end

function M.Powered(ent)
	local blackout = ix.plugin.list.blackout
	return IsValid(ent) and (not blackout or not blackout:IsPosBlackedOut(ent:GetPos()))
end

function M.ParseSubtitles(raw)
	if not isstring(raw) or #raw > 48000 then return nil, "Subtitle file exceeds 48 KB." end
	raw = raw:gsub("\239\187\191", ""):gsub("\r", "")
	local cues = {}
	local function timestamp(value)
		local h, m, s, ms = value:match("^(%d+):(%d%d):(%d%d)[,.](%d%d%d)$")
		if not h then m, s, ms = value:match("^(%d+):(%d%d)[,.](%d%d%d)$"); h = "0" end
		if not m or tonumber(m) >= 60 or tonumber(s) >= 60 then return end
		return tonumber(h) * 3600 + tonumber(m) * 60 + tonumber(s) + tonumber(ms) / 1000
	end
	for block in (raw .. "\n\n"):gmatch("(.-)\n%s*\n") do
		local first, last, text = block:match("([%d:.,]+)%s+%-%->%s+([%d:.,]+)[^\n]*\n(.*)")
		if first then
			local a, b = timestamp(first), timestamp(last)
			if not a or not b or b <= a then return nil, "Invalid subtitle timestamp." end
			text = text:gsub("<[^>]*>", ""):gsub("&amp;", "&"):gsub("&lt;", "<"):gsub("&gt;", ">")
			if #text > 1000 then return nil, "Subtitle cue exceeds 1000 bytes." end
			cues[#cues + 1] = {start = a, finish = b, text = text}
			if #cues > 1000 then return nil, "Too many subtitle cues." end
		end
	end
	if #cues == 0 and raw ~= "" then return nil, "No SRT/VTT cues found." end
	table.sort(cues, function(a, b) return a.start < b.start end)
	return cues
end

if SERVER then return end

function M.NewAudio(label, full, silent)
	local manager = {entries = {}, label = label, full = full, silent = silent}
	function manager:Drop(ent)
		local entry = self.entries[ent]
		self.entries[ent] = nil -- invalidate pending callbacks before stopping
		if entry and IsValid(entry.channel) then entry.channel:Stop() end
	end
	function manager:Destroy()
		self.dead = true
		for ent in pairs(self.entries) do self:Drop(ent) end
	end
	function manager:Seek(entry, channel)
		local length = channel:GetLength()
		if length <= 0 or channel:IsBlockStreamed() then return true end -- live stream
		local offset = math.max(0, CurTime() - entry.start)
		if entry.loop then offset = offset % length
		elseif offset >= length then entry.finished = true; return false end
		-- Online files must buffer up to the requested position before seeking.
		if offset > channel:GetBufferedTime() then return false end
		channel:SetTime(offset)
		return true
	end
	function manager:Open(ent, entry)
		entry.pending, entry.requested = true, CurTime()
		local request = {} -- every retry owns a distinct token
		entry.request = request
		local function loaded(channel, code, message)
			if self.dead or self.entries[ent] ~= entry or entry.request ~= request or not IsValid(ent) then
				if IsValid(channel) then channel:Stop() end
				return
			end
			entry.pending = false
			if not IsValid(channel) then
				entry.failures = (entry.failures or 0) + 1
				entry.retry = CurTime() + math.min(60, 2 ^ math.min(entry.failures, 6))
				entry.error = tostring(code) .. ": " .. tostring(message)
				print("[" .. self.label .. "] audio load failed: " .. entry.error)
				return
			end
			entry.channel = channel
			entry.error, entry.failures = nil, 0
			channel:SetVolume(0)
			channel:SetPos(ent:GetPos())
			channel:Set3DFadeDistance(self.silent, self.silent * 4)
			if channel:GetLength() > 0 and not channel:IsBlockStreamed() then channel:EnableLooping(entry.loop) end
			entry.started = self:Seek(entry, channel)
			if entry.finished then self:Drop(ent); self.entries[ent] = entry; entry.channel = nil
			elseif entry.started then channel:Play() end
		end
		if entry.path:match("^https?://") then sound.PlayURL(entry.path, "3d noblock noplay", loaded)
		else sound.PlayFile("sound/" .. entry.path, "3d noblock noplay", loaded) end
	end
	-- Sources are keyed by entity object, never by a recycled EntIndex.
	function manager:Update(sources)
		if self.dead then return end
		local seen, total = {}, 0
		for ent, source in pairs(sources) do
			if IsValid(ent) and source.volume > 0 and M.ValidSource(source.path) then
				seen[ent] = true
				total = total + source.volume
			end
		end
		for ent in pairs(self.entries) do if not seen[ent] then self:Drop(ent) end end
		for ent in pairs(seen) do
			local source, entry = sources[ent], self.entries[ent]
			if entry and (entry.path ~= source.path or entry.start ~= source.start or entry.loop ~= source.loop) then
				self:Drop(ent); entry = nil
			end
			if not entry then
				entry = {path = source.path, start = source.start, loop = source.loop, retry = 0}
				self.entries[ent] = entry
			end
			if entry.pending and CurTime() - entry.requested > 30 then
				entry.pending, entry.request = false, nil
				entry.retry = CurTime() + 10
				entry.error = "Audio request timed out"
			end
			local channel = entry.channel
			if IsValid(channel) then
				channel:SetPos(ent:GetPos())
				if not entry.started then
					entry.started = self:Seek(entry, channel)
					if entry.started then channel:Play() end
				end
				if entry.finished then
					channel:Stop(); entry.channel = nil
				elseif entry.started and channel:GetState() == GMOD_CHANNEL_STOPPED then
					channel:Stop(); entry.channel = nil
					if entry.loop then entry.retry = CurTime() + 2 else entry.finished = true end
				else
					channel:SetVolume(entry.started and source.volume / math.max(1, total) or 0)
				end
			elseif not entry.pending and not entry.finished and CurTime() >= entry.retry then self:Open(ent, entry) end
		end
	end
	function manager:Status()
		local active, pending = 0, 0
		for _, entry in pairs(self.entries) do
			if IsValid(entry.channel) then active = active + 1 end
			if entry.pending then pending = pending + 1 end
			if entry.error then print("[" .. self.label .. "] " .. entry.error) end
		end
		print("[" .. self.label .. "] active=" .. active .. " pending=" .. pending)
	end
	return manager
end
