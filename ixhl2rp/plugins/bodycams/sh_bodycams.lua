local B = ix.bodycams
-- Explicit item IDs: a cap, gas mask or whole uniform is not a helmet mount.
-- Additional head-slot helmets may declare ITEM.bodycamMount = true.
B.helmets = {head_helmet_tier4=true, head_helmet_tier5=true, helmet_construction=true}
B.model = "models/cod/bo1/interrogation_room/mtl_p_int_security_camera.mdl"
-- The BO1 prop points down local -Y and its origin is behind the housing.
-- Center the actual mesh on the helmet instead of attaching its empty origin.
B.mount = {scale=.28,center=Vector(0,-11.637,4.369),angle=Angle(0,90,0),lamp=Vector(.02,-17.62,5.2)}
-- The model's eyes attachment is a calibrated frame on its animated head.
-- Player:EyeAngles/GetShootPos describe aim and are intentionally not used.
function B.HeadFrame(p, bonesReady)
 if not IsValid(p) then return end
 if CLIENT and not bonesReady then p:SetupBones() end
 local bone=p:LookupBone("ValveBiped.Bip01_Head1")
 local matrix=bone and p:GetBoneMatrix(bone)
 if not matrix then return end
 local head=matrix:GetTranslation()
 if head:DistToSqr(p:GetPos())>128*128*p:GetModelScale()^2 then return end
 local index=p:LookupAttachment("eyes")
 local eyes=index and index>0 and p:GetAttachment(index)
 return head, eyes and eyes.Ang or matrix:GetAngles()
end
function B.MountTransform(head,eye)
 local target=head+eye:Right()*5+eye:Up()*3
 local _,angle=LocalToWorld(Vector(),B.mount.angle,Vector(),eye)
 local offset=LocalToWorld(B.mount.center*B.mount.scale,Angle(),Vector(),angle)
 local origin=target-offset
 local lamp=LocalToWorld(B.mount.lamp*B.mount.scale,Angle(),origin,angle)
 return origin,angle,lamp
end
function B.Compatible(item)
 return item and item.equip_inv == "head" and (item.bodycamMount == true or B.helmets[item.uniqueID] == true)
end
function B.Attached(item) return item and item:GetData("helmetCamera", false) == true end
function B.Enabled(item) return B.Attached(item) and item:GetData("helmetCameraOn", false) == true end
function B.Owns(p, item)
 return IsValid(p) and p:IsPlayer() and p:GetCharacter() and item and not IsValid(item:GetEntity()) and p:HasItemByID(item.id)
end
function B.WornHelmet(p)
 if not IsValid(p) or not p:GetCharacter() or not p:GetInventory("head") then return end
 local id = p:GetFirstAtSlot(1, 1, "head")
 local item = id and ix.Item.instances[id]
 if B.Compatible(item) and B.Owns(p,item) and item:IsEquipped() then return item end
end
function B.FindCamera(p)
 if not IsValid(p) or not p:GetCharacter() then return end
 for _, item in ipairs(p:GetItems()) do
  if item.uniqueID == "helmet_bodycam" and B.Owns(p,item) then return item end
 end
end
function B.Available(p)
 return IsValid(p) and p:IsPlayer() and p:Alive() and p:GetCharacter() and not p:GetNoDraw() and not p.ixBodycamCharacterLoading
  and (not CLIENT or not p:IsDormant())
  and p:GetMoveType() ~= MOVETYPE_OBSERVER and p:GetMoveType() ~= MOVETYPE_NOCLIP
  and not IsValid(p.ixRagdoll) and not p:GetLocalVar("knocked",false) and p:GetLocalVar("ragdoll",0)==0
  and not (p.InCriticalState and p:InCriticalState())
end
function B.Active(d)
 if not d or not d.bodycam then return false end
 local p = d.entity or Entity(d.entityIndex or -1)
 if not B.Available(p) then return false end
 if CLIENT then return p:GetNW2Int("ixHelmetCamera",0) == d.id and p:GetNW2Bool("ixHelmetCameraOn",false) end
 local helmet = B.WornHelmet(p)
 return helmet and helmet.id == d.helmetID and B.Enabled(helmet)
end
function B.Lens(p)
 local head,ang=B.HeadFrame(p)
 if not head then return end
 local origin,mountAngle=B.MountTransform(head,ang)
 local wanted=LocalToWorld(Vector(.02,-18.2,5.2)*B.mount.scale,Angle(),origin,mountAngle)
 local trace = util.TraceLine({start=head,endpos=wanted,filter=p,mask=MASK_SOLID})
 if trace.StartSolid then return end
 return trace.Hit and (trace.HitPos - ang:Forward()*2) or wanted, Angle(ang.p,ang.y,ang.r)
end
function B.RegisterHelmets()
 for _, item in pairs(ix.Item.stored) do
  if B.Compatible(item) then
   item:AddData("helmetCamera",{Transmit=ix.transmit.owner})
   item:AddData("helmetCameraOn",{Transmit=ix.transmit.owner})
   local actions = {
    {"bodycamAttach","Прикрепить камеру","attach",function(i) return not B.Attached(i) and B.FindCamera(i.player) ~= nil end},
    {"bodycamDetach","Снять камеру","detach",function(i) return B.Attached(i) end},
    {"bodycamOn","Включить камеру","on",function(i) return B.Attached(i) and not B.Enabled(i) end},
    {"bodycamOff","Выключить камеру","off",function(i) return B.Enabled(i) end}
   }
   for _,spec in ipairs(actions) do
    local action, predicate = spec[3], spec[4]
    item.functions[spec[1]] = {name=spec[2],icon="icon16/camera.png",
     OnCanRun=function(i) return B.Owns(i.player,i) and predicate(i) end,
     OnRun=function(i) local _,message=B.Change(i.player,i,action);i.player:Notify(message);return false end}
   end
   -- The native item action protocol sends deterministic registered indexes.
   ix.Item:Register(item.uniqueID,item)
  end
 end
end
