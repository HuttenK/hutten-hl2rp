ix.CharacterHeight = ix.CharacterHeight or {}
local H = ix.CharacterHeight
H.MIN, H.MAX, H.BASE = 155, 190, 180
H.states = H.states or setmetatable({}, {__mode = "k"})

function H.Height(value)
 value = tonumber(value)
 if not value or value ~= value or math.abs(value) == math.huge then return H.BASE end
 return math.Clamp(math.Round(value), H.MIN, H.MAX)
end

function H.Scale(value)
 value=tonumber(value) or H.BASE
 if value~=value or math.abs(value)==math.huge then value=H.BASE end
 return math.Clamp(value,125,215) / H.BASE
end

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
 if ix.Traits then return ix.Traits.ClampHeight(genetics and genetics.height,ix.Traits.Selection(character)) end
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
 local riding = BLH and BLH.Riding
 local mounted = riding and riding.IsMounted and riding.IsMounted(client) or false
 local height, scale
 if SERVER then
  height = H.SavedHeight(client)
  scale = client:GetCharacter() and H.Supported(client) and H.Scale(height) or 1
  if math.abs(client:GetNW2Float("ixCharacterScale", 1) - scale) > .00001 then client:SetNW2Float("ixCharacterScale", scale) end
 else
  scale = math.Clamp(client:GetNW2Float("ixCharacterScale", 1), 125 / H.BASE, 215 / H.BASE)
 end
 -- Replicate the on-foot scale even in the saddle, so dismount can restore it immediately.
 if mounted then scale = 1 end
 local model, state = client:GetModel(), H.states[client]
 local scaleDiffers = math.abs(client:GetModelScale() - scale) > .00001
 local changed = not state or state.model ~= model or state.mounted ~= mounted or math.abs(state.scale - scale) > .00001 or (mounted and scaleDiffers)
 if not force and not changed then return end
 H.states[client] = {model = model, scale = scale, mounted = mounted}
 if scaleDiffers then client:SetModelScale(scale, 0) end
 -- SetModelScale disables foot IK; ordinary standing/walking still needs it.
 client:SetIK(true)
 if not mounted and (SERVER or client == LocalPlayer()) then
  -- On the client the rider link can clear before the addon's next movement tick.
  if CLIENT and client.blhSavedHull and riding and riding.SyncHull then riding.SyncHull(client) end
  H.Dimensions(client, scale)
 end
 hook.Run("ixCharacterHeightChanged", client, scale)
end

local function deferred(client)
 timer.Simple(0, function() if IsValid(client) then H.Apply(client, true) end end)
end
hook.Add("PostPlayerLoadout", "ixCharacterHeight", deferred)
hook.Add("PlayerModelChanged", "ixCharacterHeight", deferred)
hook.Add("PlayerSpawn", "ixCharacterHeight", deferred)
hook.Add("BLH_Mounted", "ixCharacterHeight", function(client) H.Apply(client, true) end)
hook.Add("BLH_Dismounted", "ixCharacterHeight", function(client) H.Apply(client, true) end)
if CLIENT then
 hook.Add("EntityNetworkedVarChanged", "ixCharacterHeightMount", function(entity, key)
  if key == "BLH_Horse" and entity:IsPlayer() then deferred(entity) end
 end)
end
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
