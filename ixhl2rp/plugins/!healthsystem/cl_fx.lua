local BLEEDING_DISTANCE = 2048 ^ 2
local bleedingPlayers = {}

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
			
			if math.random() <= 0.005 then
				util.Decal("Blood", position + normal, position - normal, particle.Entity)
			end

			particle.Painted = true
		end
	end

	function EFFECT:Init(data)
		local pos = data:GetOrigin()
		local ang = data:GetAngles()
		self.Entity = data:GetEntity()
		self.Emitter = ParticleEmitter(pos)

		local lcol = render.GetLightColor(pos) * 255
		lcol.r = math.Clamp(lcol.r, 50, 150)

		for i = 1, 5 do
			local smoke = self.Emitter:Add("particle/smokesprites_000"..math.random(1,6), pos + VectorRand()*2)
			smoke:SetVelocity(ang:Up())
			smoke:SetDieTime(FrameTime() * 4)
			smoke:SetStartAlpha(math.random(200,255))
			smoke:SetStartSize(math.random(5,10))
			smoke:SetEndSize(0)
			smoke:SetColor(255, 0, 0)
			smoke:SetGravity(vector_origin)
		end

		for i = 1, 5 do
			local smoke = self.Emitter:Add("effects/blooddrop", pos + VectorRand()*2)
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

		self.Emitter:Finish()
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
		return
	end
	
	for _, v in ipairs(bleedingPlayers) do
		if !IsValid(v) then continue end
		if !v:Alive() or !v:GetNetVar("isBleeding") then continue end

		local object = BleedingObject(v)
		local boneID = object:LookupBone("ValveBiped.Bip01_Spine1")
		if !boneID then continue end

		local pos, ang = object:GetBonePosition(boneID)
		local effectData = EffectData()
			effectData:SetEntity(v)
			effectData:SetOrigin(pos or (object:GetPos() + offset))
			effectData:SetAngles(ang or angle_zero)
		util.Effect("bleeding", effectData, true, true)
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
