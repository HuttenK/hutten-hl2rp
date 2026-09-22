local PLUGIN = PLUGIN

PLUGIN.name = "Sit Helper"
PLUGIN.author = "Zombine"
PLUGIN.description = "Adds a console command to show a graphical helper for sitting in chairs."

PLUGIN.sitMins = Vector(-5, -5, 0);
PLUGIN.sitMaxs = Vector(5, 5, 2);

PLUGIN.OBB = {
	[0] = {Vector(-5, -5, 0), Vector(5, 5, 2)},
	[7] = {Vector(-18, -18, 0), Vector(18, 18, 36)},
	[9] = {Vector(-5, -5, 0), Vector(5, 5, 32)},
}
PLUGIN.OBBF = {
	[7] = {Vector(-5, -5, 0), Vector(5, 5, 2)},
}

PLUGIN.sitStances = {
	"stances_sit01",
	"stances_sit02",
	"stances_sit03",
	"stances_sit04",
	"stances_sit05",
	"stances_sit06",
	"stances_sit07",
	"stances_sitground",
	"stances_sitwall",
	"stances_sit08",
	"stances_sit09",
	"stances_check",
	"stances_lean01",
	"stances_lean02",
	"stances_down01",
	"stances_down02",
	"stances_down03",
	"stances_arrest",
	"stances_stand01",
	"stances_stand02",
	"stances_stand03",
};

PLUGIN.sitOffsets = {
	Vector(20, 0, -19),
	Vector(20, 0, -19),
	Vector(20, 0, -19),
	Vector(20, 0, -19),
	Vector(20, 0, -19),
	Vector(20, 0, -19),
	Vector(0, 0, 0),
	Vector(12, 0, 0),
	Vector(12, 0, 0),
	Vector(20, 0, 0),
	Vector(20, 0, 0),
	Vector(0, 0, 0),
	Vector(18, 0, 0),
	Vector(12, 0, 0),
	Vector(0, 0, 0),
	Vector(0, 0, 0),
	Vector(0, 0, 0),
	Vector(0, 0, 0),
	Vector(0, 0, 0),
	Vector(0, 0, 0),
	Vector(0, 0, 0),
};

PLUGIN.sitOffsetsF = {
	[7] = Vector(20, 0, -19)
};

ix.Net:AddPlayerVar("sitHelperPos", false, nil, ix.Net.Type.Vector)

-- Stable wire IDs: original Cellar options stay 1..21; native ground/chair variants are 22..24.
function PLUGIN:ResolvePose(entity, option)
 if not ix.act or not ix.act.Sequence then return end
 if option == 22 then return ix.act.Sequence(entity, {"sit_zen"}) end
 if option == 23 then
  local candidates = {"sit_passive"}
  if ACT_HL2MP_SIT_PASSIVE then candidates[#candidates + 1] = ACT_HL2MP_SIT_PASSIVE end
  return ix.act.Sequence(entity, candidates)
 end
 if option == 24 then
  local candidates = {"sit_fist"}
  if ACT_HL2MP_SIT_FIST then candidates[#candidates + 1] = ACT_HL2MP_SIT_FIST end
  return ix.act.Sequence(entity, candidates)
 end
 local name = self.sitStances[option]
 if name then return ix.act.Sequence(entity, {name}) end
end

function PLUGIN:GetPoseOffset(entity, option, character)
 local _,_,shared=self:ResolvePose(entity,option)
 local ratio=1
 if shared and ix.sharedPoses then
  local target,source=ix.sharedPoses.Rig(entity:GetModel()),ix.sharedPoses.Rig(shared.model)
  if target and source then ratio=target.height/source.height end
 end
 if option >= 22 and option <= 24 then
  local name = self:ResolvePose(entity, option)
  -- Native chair poses have an elevated pelvis; zen sits at ground level.
  return name == "sit_zen" and vector_origin or Vector(0, 0, -36*ratio)
 end
 local offset = self.sitOffsets[option] or vector_origin
 if (shared and shared.model:find("female",1,true)) or (not shared and character and character:GetGender() == GENDER_FEMALE) then
  offset = self.sitOffsetsF[option] or offset
 end
 if shared then return offset*ratio end
 return offset
end

function PLUGIN:CanSit(player, pos, option, character)
 if not character or not player:Alive() or player:InVehicle() or
  player:GetLocalVar("ragdoll") or player:WaterLevel() > 0 or not self:ResolvePose(player, option) then return false, "Персонаж сейчас не может сесть" end
 for _, value in ipairs({pos.x, pos.y, pos.z}) do
  if value ~= value or math.abs(value) == math.huge then return false, "Некорректная позиция" end
 end
	local obb = self.OBB[option] or self.OBB[0]

	if character and character:GetGender() == GENDER_FEMALE then
		obb = self.OBBF[option] or obb
	end

	local sitTrace = util.TraceHull({
		start = pos + Vector(0, 0, 3),
		-- The previous trace stops just above contact. Cross the surface to
		-- avoid rejecting its floating-point contact epsilon as unsupported.
		endpos = pos - Vector(0, 0, 4),
		filter = function(ent)
			if (ent == player or ent:IsWeapon()) then
				return false;
			else
				return true;
			end;
		end,
		mins = obb[1],
		maxs = obb[2]
	});

	if (sitTrace.AllSolid or sitTrace.StartSolid or not sitTrace.Hit or sitTrace.HitNormal.z <= 0.75) then
		return false, "Нет ровной свободной опоры";
	end;

	local norm = (pos - player:EyePos()):GetNormalized();

	local visTrace = util.TraceLine({
		start = player:EyePos(),
		endpos = pos - norm * 2,
		filter = player,
	});

	if (visTrace.Hit) then
		return false, "Место закрыто препятствием";
	end;

	if (pos:Distance(player:EyePos()) >= 100) then
		return false, "Подойдите ближе";
	end;

	return true;
end;

function PLUGIN:StartCommand(client, command)
	if (!client:GetNetVar("sitHelperPos")) then
		return
	end

	if command:KeyDown(IN_DUCK) then
		command:RemoveKey(IN_DUCK)
	end
end

ix.util.Include("cl_plugin.lua")
ix.util.Include("sv_plugin.lua")
