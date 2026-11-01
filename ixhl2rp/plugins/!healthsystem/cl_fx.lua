local BLEEDING_DISTANCE = 2048 ^ 2
local bleedingPlayers = {}
local EMISSION_INTERVAL = 1 / 20
local MAX_EFFECTS_PER_STEP = 6
local nextEmission, emissionCursor = 0, 0
if PLUGIN.ClearBleedingEmitters then PLUGIN:ClearBleedingEmitters() end
local bleedingEmitters = {}
function PLUGIN:ClearBleedingEmitters()
	for client, entry in pairs(bleedingEmitters) do
		if IsValid(entry.emitter) then entry.emitter:Finish() end
		bleedingEmitters[client] = nil
	end
end
local healthPlugin = PLUGIN
hook.Add("ShutDown", "ixBleedingEmitters", function() healthPlugin:ClearBleedingEmitters() end)

local function BleedingObject(client)
	-- Cart transport hides the original ragdoll. Its client bone cache may
	-- remain at the pickup point; emit from the visible lying model instead.
	local cart = ix.PushCart
	local display = cart and cart.PatientDisplay and cart:PatientDisplay(client)
	if IsValid(display) then return display end

	local doll = client:GetNetVar("doll")
	doll = doll and Entity(doll)
	return IsValid(doll) and doll or client
end

timer.Create("ixBleedingUpdate", 1, 0, function()
	for client, entry in pairs(bleedingEmitters) do
		if not IsValid(client) or not client:Alive() or not client:GetNetVar("isBleeding") or CurTime()-entry.last>2 then
			if IsValid(entry.emitter) then entry.emitter:Finish() end
			bleedingEmitters[client] = nil
		end
	end
	if !IsValid(LocalPlayer()) then return end

	bleedingPlayers = {}

	local origin = LocalPlayer():EyePos()

	for _, client in ipairs(player.GetAll()) do
		if !client:Alive() then continue end
		if !client:GetNetVar("isBleeding") then continue end

		local pos = BleedingObject(client):GetPos()
		if pos:DistToSqr(origin) <= BLEEDING_DISTANCE then
			bleedingPlayers[#bleedingPlayers + 1] = client
		end
	end
end)

do
	local EFFECT = {}
	local gravity = Vector(0, 0, -500)

	local function ParticleCollides(particle, position, normal)
		if !particle.Painted then
			if particle.Entity and IsValid(particle.Entity) and particle.Entity == LocalPlayer() then
				if position:IsEqualTol(LocalPlayer():GetPos(), 16) then
					return
				end
			end
			
			-- Keep the approximate 60-FPS blood-trail rate with 20-Hz emission.
			if math.random() <= 0.015 then
				util.Decal("Blood", position + normal, position - normal, particle.Entity)
			end

			particle.Painted = true
		end
	end

	function EFFECT:Init(data)
		local pos = data:GetOrigin()
		local ang = data:GetAngles()
		self.Entity = data:GetEntity()
		if not IsValid(self.Entity) then return end
		local entry = bleedingEmitters[self.Entity]
		if not entry or not IsValid(entry.emitter) then
			entry = {emitter=ParticleEmitter(pos)}
			bleedingEmitters[self.Entity] = entry
		end
		entry.last = CurTime()
		self.Emitter = entry.emitter
		if not IsValid(self.Emitter) then return end
		self.Emitter:SetPos(pos)

		for i = 1, 5 do
			local smoke = self.Emitter:Add("particle/smokesprites_000"..math.random(1,6), pos + VectorRand()*2)
			if not smoke then continue end
			smoke:SetVelocity(ang:Up())
			-- Fixed lifetime keeps the visible cloud independent of client FPS.
			smoke:SetDieTime(EMISSION_INTERVAL * 4)
			smoke:SetStartAlpha(math.random(200,255))
			smoke:SetStartSize(math.random(5,10))
			smoke:SetEndSize(0)
			smoke:SetColor(255, 0, 0)
			smoke:SetGravity(vector_origin)
		end

		for i = 1, 5 do
			local smoke = self.Emitter:Add("effects/blooddrop", pos + VectorRand()*2)
			if not smoke then continue end
			smoke:SetVelocity((ang:Up()*-math.Rand(.5, 1) + ang:Forward()*math.Rand(-1, 1) + ang:Right()*math.Rand(-1, 1)) * 15)
			smoke:SetDieTime(math.Rand(.12, .8))
			smoke:SetStartSize(1)
			smoke:SetEndSize(3)
			smoke:SetColor(255, 0, 0)
			smoke:SetGravity(gravity)
			smoke.Entity = self.Entity
			smoke:SetCollideCallback(ParticleCollides)
			smoke:SetCollide(true)
		end

		-- Reuse this patient's emitter; cleanup finishes it after emission stops.
	end

	function EFFECT:Think()
		return false
	end

	function EFFECT:Render()
	end

	effects.Register(EFFECT, "bleeding")
end

local offset = Vector(0,0,32)
function PLUGIN:DrawBleeding()
	if !bleedingPlayers or #bleedingPlayers <= 0 then
		nextEmission, emissionCursor = 0, 0
		return
	end
	local now = CurTime()
	if now + 0.000001 < nextEmission then return end
	nextEmission = nextEmission + EMISSION_INTERVAL
	-- Never replay a backlog of particles after a hitch.
	if nextEmission <= now then nextEmission = now + EMISSION_INTERVAL end
	local observer = LocalPlayer()
	if not IsValid(observer) then return end
	local origin = observer:EyePos()
	local emitted = 0
	-- Round-robin budgeting avoids starving patients at the end of the list.
	for i = 1, #bleedingPlayers do
		emissionCursor = emissionCursor % #bleedingPlayers + 1
		local v = bleedingPlayers[emissionCursor]
		if !IsValid(v) then continue end
		if !v:Alive() or !v:GetNetVar("isBleeding") then continue end

		local object = BleedingObject(v)
		if not IsValid(object) or (object.IsDormant and object:IsDormant()) then continue end
		if object:GetPos():DistToSqr(origin) > BLEEDING_DISTANCE then continue end
		local boneID = object:LookupBone("ValveBiped.Bip01_Spine1")
		if !boneID then continue end

		local pos, ang = object:GetBonePosition(boneID)
		local effectData = EffectData()
			effectData:SetEntity(v)
			effectData:SetOrigin(pos or (object:GetPos() + offset))
			effectData:SetAngles(ang or angle_zero)
		util.Effect("bleeding", effectData, true, true)
		if ix.performance then ix.performance.Count("bleeding_effect_bursts") end
		emitted = emitted + 1
		if emitted >= MAX_EFFECTS_PER_STEP then break end
	end
end

do
	local oldST
	local targetAng = Angle()
	function PLUGIN:CalcView(client, origin, angles, fov)
		if !IsValid(client) then return end

		local character = client:GetCharacter()

		if !character or client:GetLocalVar("ragdoll", 0) != 0 then
			return
		end

		local health = character:Health()
		local pain = health:GetPain()

		if pain <= 0 then return end

		pain = pain * 0.2

		local delta
		local st = SysTime()

		oldST = oldST or st
		delta = math.min(st - oldST, FrameTime(), 1 / 30)
		oldST = st

		local mulRand = math.Clamp((1 - pain) - 0.3, 0, 1)
		local rand = 15 * mulRand 

		targetAng = LerpAngle(delta * (10 + (20 * pain)), targetAng, Angle(math.Rand(-rand, rand), math.Rand(-rand, rand), 0))
		targetAng.r = 0

		local eyeAngle = client:EyeAngles()
		eyeAngle = LerpAngle(delta * (10 * pain), eyeAngle, eyeAngle + targetAng)
		eyeAngle.r = 0
		
		client:SetEyeAngles(eyeAngle)
	end
end

do
 local damagePulse=0
 -- Clear the old plugin callback when Lua is refreshed in an existing session.
 PLUGIN.RenderScreenspaceEffects=nil
 hook.Add("HUDPaintBackground","ixHealthDamageOverlay",function()
  local client=LocalPlayer()
  if not IsValid(client) then return end
  local character=client:GetCharacter()
  if not character then damagePulse=0; return end
  local hp=math.Clamp(character:Health():GetPercent(),0,1)
  damagePulse=Lerp(math.Clamp(FrameTime()*10,0,1),damagePulse,0)
  local strength=math.Clamp((1-hp)*.45+damagePulse*.15,0,.8)
  if strength<.001 then return end
  -- Solid geometry cannot render a missing material or a broken framebuffer.
  draw.NoTexture()
  local w,h=ScrW(),ScrH()
  for i=0,31 do
   local edge=(1-i/32)^2
   surface.SetDrawColor(45,0,5,edge*strength*170)
   local y=i*h*.3/32
   surface.DrawRect(0,y,w,math.ceil(h*.3/32))
   surface.DrawRect(0,h-y-h*.3/32,w,math.ceil(h*.3/32))
  end
 end)
 net.Receive("shock.pain",function() damagePulse=math.min(damagePulse+net.ReadUInt(3),3) end)
end
