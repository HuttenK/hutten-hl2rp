-- Use opens the same small action list as inventory items. Native one-action
-- devices keep their own Use handler; no wheel bindings or extra progress bar.
local F=ix.Facility
F.QuickUse=F.QuickUse or {}
local Q=F.QuickUse
surface.CreateFont("EquipmentUseTitle",{font="Tahoma",size=15,weight=600,extended=true})
surface.CreateFont("EquipmentUseAction",{font="Tahoma",size=18,weight=600,extended=true})
surface.CreateFont("EquipmentUseDetail",{font="Tahoma",size=15,weight=500,extended=true})
local white,muted,warning,shadow=Color(240,245,240),Color(204,216,214),Color(255,196,104),Color(0,0,0,235)
function Q.Busy() return ix.bar and (ix.bar.actionEnd or 0)>CurTime() end
function Q.Key(command) return string.upper(input.LookupBinding(command) or "?") end
function Q.Clear() Q.current=nil;Q.selected=nil;Q.entity=nil;Q.character=nil end
function Q.CloseMenu()
 if IsValid(Q.menu) then Q.menu:Remove() end
 Q.menu=nil
end
function Q.Allowed(p,ownMenu)
 if not F.Active(p) or p:GetNetVar("forcedSequence") or p:GetNetVar("isCreature") then return false end
 if ix.CCTV and ix.CCTV.rendering or gui.IsGameUIVisible() or gui.IsConsoleVisible() or not ownMenu and vgui.CursorVisible() or input.IsKeyTrapping() then return false end
 if IsValid(ix.gui.fieldlink) or ix.Fieldlink and ix.Fieldlink.camera then return false end
 if ix.PoseStudio and (ix.PoseStudio.placement or ix.PoseStudio.placementPending) then return false end
 local plugins=ix.plugin.list
 if plugins.cctv and plugins.cctv.placing or plugins.tv_screen and plugins.tv_screen.placement then return false end
 if plugins.sithelper and plugins.sithelper.IsPlacingPose and plugins.sithelper:IsPlacingPose() then return false end
 if ix.menu and ix.menu.IsOpen() and (not ownMenu or ix.menu.panel~=Q.menu) then return false end
 if IsValid(vgui.GetKeyboardFocus()) then return false end
 if F.connectionActive or IsValid(F.repairWindow) or IsValid(F.window) then return false end
 return true
end
function Q.Refresh(force)
 local p=LocalPlayer()
 if not Q.Allowed(p) then Q.Clear();return end
 if not force and RealTime()<(Q.nextRefresh or 0) and Q.character==p:GetCharacter() then return Q.current end
 Q.nextRefresh=RealTime()+.1
 -- Remote CCTV RenderView must never alter this physical use ray.
 local start=p:GetShootPos()
 local tr=util.TraceLine({start=start,endpos=start+p:GetAimVector()*150,filter=p,mask=MASK_SOLID})
 local e=tr.Entity
 if not IsValid(e) then Q.Clear();return end
 local spec=hook.Run("GetEquipmentInteraction",p,e)
 if not spec then Q.Clear();return end
 if e~=Q.entity or p:GetCharacter()~=Q.character then Q.selected=nil end
 Q.entity=e;Q.character=p:GetCharacter();Q.current=spec;spec.entity=e
 local index
 if not Q.selected then index=1 end
 for i,option in ipairs(spec.options or {}) do if option.id==Q.selected then index=i;break end end
 Q.index=index;Q.option=index and (spec.options or {})[index]
 if Q.option then Q.selected=Q.option.id elseif Q.selected then spec.status="Действие изменилось · выберите заново" end
 return spec
end
function Q.MenuSpec(menu)
 if not IsValid(menu) or menu~=Q.menu then return end
 local p=LocalPlayer()
 if not Q.Allowed(p,true) or Q.Busy() or p:GetCharacter()~=menu.character or not IsValid(menu.entity) then return end
 local start=p:GetShootPos()
 local trace=util.TraceLine({start=start,endpos=start+p:GetAimVector()*150,filter=p,mask=MASK_SOLID})
 if trace.Entity~=menu.entity then return end
 local spec=hook.Run("GetEquipmentInteraction",p,menu.entity)
 if spec and not spec.native then spec.entity=menu.entity;return spec end
end
local icons={drink="icon16/cup.png",wash="icon16/water.png",generator="icon16/control_play.png",refuel="icon16/drop.png",
 connect="icon16/connect.png",pack="icon16/box.png",repair="icon16/wrench.png"}
function Q.MenuRows(menu,spec)
 for _,child in ipairs(menu:GetCanvas():GetChildren()) do child:Remove() end
 for _,row in ipairs(spec.options or {}) do
  local id=row.id
  local option=menu:AddOption(Q.Fit(row.label,"simple.option.button",math.min(480,ScrW()-72)),function()
   -- Re-resolve the exact ID after the click: a removed bottle/link must never
   -- fall through to another action. All resulting requests are server checked.
   local current=Q.MenuSpec(menu)
   if current then for _,choice in ipairs(current.options or {}) do
    if choice.id==id and choice.label==row.label and choice.expectedRunning==row.expectedRunning and choice.expectedLink==row.expectedLink and not choice.disabled then
     Q.CloseMenu();current.use(choice);return
    end
   end end
   Q.CloseMenu()
  end)
  option:SetEnabled(not row.disabled)
  option:SetTooltip(row.label..(row.detail and "\n"..row.detail or ""))
  option:SetImage(row.icon or icons[id] or (id:find("fill:",1,true)==1 and "icon16/cup.png") or
   (id:find("disconnect:",1,true)==1 and "icon16/disconnect.png") or "icon16/cog.png")
 end
 if #(spec.options or {})==0 then
  local status=menu:AddOption(Q.Fit(spec.status or "Нет доступных действий","simple.option.button",math.min(480,ScrW()-72)))
  status:SetEnabled(false)
 end
 menu:AddOption("Отмена",Q.CloseMenu):SetImage("icon16/cancel.png")
 menu:InvalidateLayout(true)
end
local function signature(spec)
 local rows={spec.status or ""}
 for _,row in ipairs(spec.options or {}) do rows[#rows+1]=row.id..":"..row.label..":"..tostring(row.disabled)..":"..tostring(row.expectedLink) end
 return table.concat(rows,"\n")
end
function Q.OpenMenu(spec)
 if IsValid(Q.menu) or not spec or spec.native then return end
 local menu=ix.SimpleMenu();Q.menu=menu
 menu.entity=spec.entity;menu.character=LocalPlayer():GetCharacter()
 menu.signature=signature(spec);Q.MenuRows(menu,spec)
 -- Gameplay has no useful mouse position (often 0,0). Explicit coordinates
 -- avoid the top-left bug and do not project with a remote CCTV camera.
 menu:Open(ScrW()/2,ScrH()/2)
 menu.Think=function(this)
  if RealTime()<(this.nextCheck or 0) then return end;this.nextCheck=RealTime()+.1
  local current=Q.MenuSpec(this)
  if not current then this:Remove();return end
  local value=signature(current)
  if value~=this.signature then
   this.signature=value;Q.MenuRows(this,current)
   local x,y=this:GetPos();this:SetPos(math.Clamp(x,1,math.max(1,ScrW()-this:GetWide())),math.Clamp(y,1,math.max(1,ScrH()-this:GetTall())))
  end
 end
end
function Q.Input(cmd)
 local down=cmd:KeyDown(IN_USE)
 -- Match the engine's existing IMGUI binding path. Other CreateMove hooks can
 -- ClearButtons while a menu is open; that must not re-arm a physically held E.
 local bind=input.LookupBinding("+use",true);local key=bind and input.GetKeyCode(bind)
 local physical=key and input.IsButtonDown(key)
 local pressed=down and not Q.useDown;Q.useDown=down or physical==true
 if not Q.useDown then Q.consumeUse=false end
 if not Q.Allowed(LocalPlayer()) and physical then Q.consumeUse=true end
 local spec=Q.Refresh(pressed)
 if spec and not spec.native and not (spec.config and cmd:KeyDown(IN_WALK) and LocalPlayer():IsAdmin()) then
  if down then Q.consumeUse=true end
  if pressed and not Q.Busy() then Q.OpenMenu(spec) end
 end
 -- A captured press cannot become engine +use on another prop mid-hold.
 if Q.consumeUse then cmd:RemoveKey(IN_USE) end
end
hook.Add("CreateMove","ixEquipmentContextUse",Q.Input)
-- Retire the previous hotloaded wheel hook as well as omitting it on new joins.
hook.Remove("PlayerBindPress","ixEquipmentContextWheel")
function Q.Fit(value,font,width)
 local text=tostring(value or "");surface.SetFont(font)
 local count=utf8.len(text) or #text
 if surface.GetTextSize(text)<=width then return text end
 repeat count=count-1;text=string.utf8sub(text,1,count) until count<=0 or surface.GetTextSize(text.."…")<=width
 return text.."…"
end
function Q.Paint(spec,option,index)
 local busy=Q.Busy()
 if busy and not spec.duringAction then return end
 local x=ScrW()/2;local y=math.min(ScrH()/2+32,ScrH()*.72-100);local width=math.min(440,ScrW()-40)
 local function line(text,font,offset,color)
  draw.SimpleTextOutlined(Q.Fit(text,font,width),font,x,y+offset,color or white,TEXT_ALIGN_CENTER,TEXT_ALIGN_TOP,1,shadow)
 end
 line(spec.title,"EquipmentUseTitle",0,muted)
 if not spec.native then line("["..Q.Key("+use").."]  Действия","EquipmentUseAction",23);return end
 local action=option and option.label or spec.status or ""
 line((option and not option.disabled and "["..Q.Key("+use").."]  " or "")..action,"EquipmentUseAction",23,option and option.warning and warning or white)
 if busy then return end
 local detail=option and option.detail or spec.detail
 if detail and detail~="" then line(detail,"EquipmentUseDetail",48,option and option.warning and warning or muted) end
end
hook.Add("HUDPaint","ixEquipmentContextHint",function()
 local spec=Q.Refresh();if spec then Q.Paint(spec,Q.option,Q.index) end
end)
