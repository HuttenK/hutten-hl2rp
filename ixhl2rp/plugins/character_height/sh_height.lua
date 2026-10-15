ix.CharacterHeight = ix.CharacterHeight or {}
local H = ix.CharacterHeight
H.MIN, H.MAX, H.BASE = 155, 190, 180
H.states = H.states or setmetatable({}, {__mode = "k"})

function H.Height(value)
 value = tonumber(value)
 if not value or value ~= value or math.abs(value) == math.huge then return H.BASE end
 return math.Clamp(math.Round(value), H.MIN, H.MAX)
end

function H.Scale(value) return H.Height(value) / H.BASE end

function H.Supported(entity)
 return entity:LookupBone("ValveBiped.Bip01_Head1") ~= nil
  and entity:LookupBone("ValveBiped.Bip01_Pelvis") ~= nil
  and entity:LookupBone("ValveBiped.Bip01_L_Hand") ~= nil
  and not string.lower(entity:GetModel() or ""):find("vort", 1, true)
end

function H.SavedHeight(client)
 local character = client:GetCharacter()
 local genetics = character and character.Genetic and character:Genetic()
 if client.ixHeightPreview and client.ixHeightPreview.character == character then return client.ixHeightPreview.height end
 return H.Height(genetics and genetics.height)
end

function H.Dimensions(client, scale)
 -- Always derive from the normal dimensions, never from an already scaled hull.
 client:SetHull(Vector(-16, -16, 0) * scale, Vector(16, 16, 72) * scale)
 client:SetHullDuck(Vector(-16, -16, 0) * scale, Vector(16, 16, 36) * scale)
 local view, duck = Vector(0, 0, 64) * scale, Vector(0, 0, 28) * scale
 if prone and client.IsProne and client:IsProne() then
  client:SetHull(Vector(-16, -16, 0) * scale, Vector(16, 16, prone.Config.HullHeight) * scale)
  client:SetHullDuck(Vector(-16, -16, 0) * scale, Vector(16, 16, prone.Config.HullHeight) * scale)
  local state = prone.PlayerStateDatas[client:SteamID()]
  if state then state.OriginalViewOffset, state.OriginalViewOffsetDucked = view, duck end
  if client:GetProneAnimationState() == PRONE_INPRONE then view, duck = prone.Config.View * scale, prone.Config.View * scale end
 end
 local sleep = ix.plugin.Get("sleep")
 local bed = sleep and sleep.bedSessions and sleep.bedSessions[client]
 if bed then bed.view, bed.duckView = view, duck end
 if client.ixCrawlView then
  client.ixCrawlView, client.ixCrawlStandingView = duck, view
 end
 if not client:GetNetVar("bedRestAngle") then
  client:SetViewOffset(client.ixCrawlView and Vector(0, 0, 18) * scale or view)
  client:SetViewOffsetDucked(client.ixCrawlView and Vector(0, 0, 18) * scale or duck)
 end
end

function H.Apply(client, force)
 if not IsValid(client) or not client:IsPlayer() then return end
 local height, scale
 if SERVER then
  height = H.SavedHeight(client)
  scale = client:GetCharacter() and H.Supported(client) and H.Scale(height) or 1
  if math.abs(client:GetNW2Float("ixCharacterScale", 1) - scale) > .00001 then client:SetNW2Float("ixCharacterScale", scale) end
 else
  scale = math.Clamp(client:GetNW2Float("ixCharacterScale", 1), H.MIN / H.BASE, H.MAX / H.BASE)
 end
 local model, state = client:GetModel(), H.states[client]
 local changed = not state or state.model ~= model or math.abs(state.scale - scale) > .00001
 if not force and not changed then return end
 H.states[client] = {model = model, scale = scale}
 if math.abs(client:GetModelScale() - scale) > .00001 then client:SetModelScale(scale, 0) end
 -- SetModelScale disables foot IK; ordinary standing/walking still needs it.
 client:SetIK(true)
 if SERVER or client == LocalPlayer() then H.Dimensions(client, scale) end
 hook.Run("ixCharacterHeightChanged", client, scale)
end

local function deferred(client)
 timer.Simple(0, function() if IsValid(client) then H.Apply(client, true) end end)
end
hook.Add("PostPlayerLoadout", "ixCharacterHeight", deferred)
hook.Add("PlayerModelChanged", "ixCharacterHeight", deferred)
hook.Add("PlayerSpawn", "ixCharacterHeight", deferred)
hook.Add("prone.OnPlayerEntered", "ixCharacterHeight", function(client) H.Apply(client, true) end)
hook.Add("prone.OnPlayerExitted", "ixCharacterHeight", function(client) H.Apply(client, true) end)
timer.Create("ixCharacterHeight", .5, 0, function()
 for _, client in ipairs(player.GetAll()) do H.Apply(client) end
end)

if SERVER then
 -- A temporary, self-only comparison; zero returns to the saved character.
 concommand.Add("ix_height_preview", function(client, _, args)
  if not IsValid(client) or not client:IsAdmin() or not client:GetCharacter() then return end
  local value = tonumber(args[1])
  if not value then client:PrintMessage(HUD_PRINTCONSOLE, "ix_height_preview 155..190; ix_height_preview 0 restores saved height.") return end
  client.ixHeightPreview = value ~= 0 and {character = client:GetCharacter(), height = H.Height(value)} or nil
  H.Apply(client, true)
  client:PrintMessage(HUD_PRINTCONSOLE, "[Height] " .. H.SavedHeight(client) .. " cm" .. (client.ixHeightPreview and " (temporary preview)" or " (saved character height)"))
 end)
end
