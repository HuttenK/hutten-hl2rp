-- Put in garrysmod/lua; run lua_openscript ix_animation_content_check.lua in
-- the SERVER console with the affected players connected. Read-only comparison;
-- no animation, model, addon or convar changes. No client installation needed.
local channel = "ixAnimationContentAudit"
local function Collect()
 local report = {files = {}, models = {}, settings = {}, build = tostring(VERSIONSTR), branch = tostring(BRANCH)}
 local visited, remaining = {}, 96
 local function Scan(path)
  if not isstring(path) then return end
  path = path:lower():gsub("\\", "/")
  if visited[path] or remaining <= 0 or path:find("..", 1, true) or path:sub(1, 7) ~= "models/" then return end
  visited[path], remaining = true, remaining - 1
  local data = file.Read(path, "GAME")
  if not data then report.files[path] = "MISSING" return end
  report.files[path] = #data .. ":" .. util.CRC(data)
  if path:sub(-4) ~= ".mdl" or #data < 360 or data:sub(1, 4) ~= "IDST" then return end
  local function U32(offset)
   if offset < 0 or offset + 4 > #data then return end
   local a, b, c, d = data:byte(offset + 1, offset + 4)
   return a + b * 256 + c * 65536 + d * 16777216
  end
  local function CString(offset)
   if not offset or offset < 0 or offset >= #data then return end
   local finish = data:find("\0", offset + 1, true)
   if finish and finish - offset <= 260 then return data:sub(offset + 1, finish - 1) end
  end
  local count, offset = U32(336), U32(340)
  if count and count <= 64 and offset and offset + count * 8 <= #data then
   for index = 0, count - 1 do
    local entry = offset + index * 8
    local relative = U32(entry + 4)
    if relative >= 2147483648 then relative = relative - 4294967296 end
    Scan(CString(entry + relative))
   end
  end
  local blocks, ani = U32(352), U32(348)
  if blocks and blocks > 1 then Scan(CString(ani)) end
 end
 for _, p in ipairs(player.GetAll()) do
  if IsValid(p) then
   local model = p:GetModel() or ""
   local names = p:GetSequenceList() or {}
   report.models[tostring(p:EntIndex())] = {path = model, count = p:GetSequenceCount(), crc = util.CRC(table.concat(names, "\n"))}
   Scan(model)
  end
 end
 -- Includes the stock reference rig used by the SD weapon adapter.
 for _, path in ipairs({"models/player/kleiner.mdl", "models/m_anm.mdl", "models/f_anm.mdl",
  "models/humans/male_gestures.mdl", "models/humans/female_gestures.mdl",
  "models/cellar/male_anims.mdl", "models/cellar/female_anims.mdl"}) do Scan(path) end
 for _, path in ipairs({"weapons/arc9_base/cl_tpik.lua", "weapons/arc9_base/cl_model.lua", "weapons/arc9_eft_base.lua"}) do
  local data = file.Read(path, "LUA")
  report.files["lua/" .. path] = data and (#data .. ":" .. util.CRC(data)) or "MISSING"
 end
 for _, name in ipairs({"arc9_tpik", "arc9_tpik_others", "arc9_tpik_framerate_local", "arc9_tpik_framerate_others", "arc9_eft_nontpik_mode"}) do
  local setting = GetConVar(name)
  report.settings[name] = setting and setting:GetString() or "MISSING"
 end
 return report
end
-- SERVER
if SERVER then
 local source = file.Read("ix_animation_content_check.lua", "LUA")
 if not source then print("[Animation audit] Put this file in garrysmod/lua first.") return end
 local shared = source:match("^(.-)%-%- SERVER")
 local client = source:match("%-%- CLIENT\r?\n(.*)$")
 if not shared or not client then print("[Animation audit] Incomplete script.") return end
 util.AddNetworkString(channel)
 local token = tostring(SysTime())
 local payload = shared .. "\nlocal auditToken = " .. string.format("%q", token) .. "\n" .. client
 if #payload >= 6000 then error("Animation audit client payload exceeds SendLua limit") end
 local pending, results = {}, {server = Collect(), clients = {}}
 local deadline = CurTime() + 30
 local function Save()
  file.CreateDir("ix_animation_content_audit")
  file.Write("ix_animation_content_audit/latest.json", util.TableToJSON(results, true))
 end
 Save()
 net.Receive(channel, function(bits, p)
  if not pending[p] or CurTime() > deadline or bits > 262144 then return end
  if net.ReadString() ~= token then return end
  local report = util.JSONToTable(net.ReadString())
  if not istable(report) or not istable(report.files) or not istable(report.models) then return end
  pending[p] = nil
  results.clients[tostring(p:EntIndex())] = {name = p:Nick(), report = report}
  local mismatches = 0
  print("[Animation audit] Client:", p:Nick(), "build:", tostring(report.build), "branch:", tostring(report.branch))
  for path, fingerprint in pairs(results.server.files) do
   if report.files[path] ~= fingerprint then
    mismatches = mismatches + 1
    print("[Animation audit] DIFFERENT:", path, "server:", fingerprint, "client:", tostring(report.files[path]))
   end
  end
  for id, model in pairs(results.server.models) do
   local other = report.models[id]
   if istable(other) and other.path == model.path and (model.count ~= other.count or model.crc ~= other.crc) then
    mismatches = mismatches + 1
    print("[Animation audit] LOADED SEQUENCES:", model.path, "server:", model.count, model.crc, "client:", tostring(other.count), tostring(other.crc))
   end
  end
  print("[Animation audit] Differences:", mismatches, "Saved data/ix_animation_content_audit/latest.json")
  Save()
 end)
 for _, p in ipairs(player.GetHumans()) do pending[p] = true; p:SendLua(payload) end
 timer.Simple(30, function()
  for p in pairs(pending) do
   if IsValid(p) then print("[Animation audit] No reply from:", p:Nick()) end
  end
 end)
 print("[Animation audit] Comparing server and connected clients. Keep the affected players connected for 30 seconds.")
 return
end
-- CLIENT
if CLIENT then
 local report = Collect()
 file.CreateDir("ix_animation_content_audit")
 file.Write("ix_animation_content_audit/latest.json", util.TableToJSON(report, true))
 if auditToken then
  net.Start(channel)
  net.WriteString(auditToken)
  net.WriteString(util.TableToJSON(report))
  net.SendToServer()
 end
 print("[Animation audit] Saved data/ix_animation_content_audit/latest.json")
end
