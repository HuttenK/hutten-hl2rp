local P, S = PLUGIN, ix.sleep
local fade, menu = 0
local function binding(name, fallback)
 return string.upper(input.LookupBinding(name) or fallback)
end
local function request(action, bed)
 net.Start("ixBedRestRequest"); net.WriteUInt(action,2); net.WriteEntity(bed); net.SendToServer()
end
net.Receive("ixBedRestMenu",function()
 local bed = net.ReadEntity()
 local p=LocalPlayer()
 if not S.IsBed(bed) or S.IsResting(p) or not S.CanReach(p,bed) then return end
 if gui.IsGameUIVisible() or gui.IsConsoleVisible() or vgui.CursorVisible() then return end
 if IsValid(menu) then menu:Remove() end
 menu = ix.SimpleMenu()
 local opened,chosen=menu,false
 local character=p:GetCharacter()
 local function choose(action)
  if chosen or not IsValid(opened) then return end
  chosen=true;opened:Remove()
  if p==LocalPlayer() and p:GetCharacter()==character and not S.IsResting(p) and S.CanReach(p,bed) then request(action,bed) end
 end
 menu:AddOption("Лечь отдохнуть",function() choose(1) end):SetImage("icon16/user.png")
 menu:AddOption("Лечь спать",function() choose(2) end):SetImage("icon16/weather_clouds.png")
 menu:AddOption("Отмена",function() end):SetImage("icon16/cancel.png")
 menu:Open(ScrW()/2,ScrH()/2)
 menu.Think=function(this)
  if not IsValid(p) or not p:Alive() or p:GetCharacter()~=character or S.IsResting(p) or not S.CanReach(p,bed) then this:Remove() end
 end
end)

function P:HUDPaint()
 local p = LocalPlayer()
 if not IsValid(p) then return end
 local resting = S.IsResting(p)
 local asleep = S.IsSleeping(p)
 fade = math.Approach(fade, asleep and 1 or 0, FrameTime()/(asleep and S.FADE_TIME or .45))
 if fade>0 then
  surface.SetDrawColor(5,8,12,255*fade)
  surface.DrawRect(0,0,ScrW(),ScrH())
 end
 if resting or fade>.05 then
  local title = p:GetLocalVar("bedRestBlocked",false) and "Вы проснулись — выход занят" or asleep and "Вы спите" or "Вы отдыхаете на койке"
  local detail = p:GetLocalVar("bedRestBlocked",false) and "Нужно освободить место рядом с койкой." or
   (binding("+use","использование").." / "..binding("+jump","прыжок").." — встать     /Wake — встать")
  if resting and not asleep and not p:GetLocalVar("bedRestBlocked",false) then detail=detail.."     /Sleep — уснуть" end
  draw.SimpleTextOutlined(title,"DermaLarge",ScrW()/2,ScrH()*.65,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
  draw.SimpleTextOutlined(detail,"DermaDefault",ScrW()/2,ScrH()*.65+38,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
 elseif not IsValid(menu) and p:GetCharacter() then
  local origin=p:GetShootPos()
  local trace=util.TraceLine({start=origin,endpos=origin+p:GetAimVector()*S.USE_RANGE,filter=p,mask=MASK_SOLID})
  if S.IsBed(trace.Entity) and p:GetShootPos():DistToSqr(trace.HitPos)<=S.USE_RANGE^2 then
   draw.SimpleTextOutlined(binding("+use","использование").." — отдохнуть / спать", "DermaDefaultBold",ScrW()/2,ScrH()*.7,color_white,TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,color_black)
  end
 end
end
function P:OnUnload()
 if IsValid(menu) then menu:Remove() end
end
