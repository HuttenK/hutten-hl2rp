local P,C=PLUGIN,ix.CCTV
function P:EndPlacement()
 self.placing=nil;self.placementPos=nil;self.surfacePlacement=nil;self.replaceTerminal=nil;self.surfaceReload=nil
 if IsValid(self.ghost) then self.ghost:Remove() end;self.ghost=nil
end
function P:BeginPlacement(kind,id)
 if not C.kinds[kind] or not LocalPlayer():IsAdmin() then return end
 self:CloseTerminalUI()
 if IsValid(self.window) then self.window:Remove() end
 self:EndPlacement();self.placing=kind;self.placeArmed=false
 if kind=="terminal" then self.replaceTerminal=id;self.useSurfacePreset=true;return end
 self.ghost=ClientsideModel(C.kinds[kind].model,RENDERGROUP_TRANSLUCENT)
 if IsValid(self.ghost) then self.ghost:SetNoDraw(true);self.ghost:SetMaterial("models/wireframe") end
 if kind=="camera" and IsValid(self.ghost) then self.ghost:ResetSequence("idle");self.ghost:SetCycle(0);self.ghost:SetPlaybackRate(0) end
end
hook.Add("CreateMove","ixCCTVPlacement",function(cmd)
 if not P.placing then return end
 local p=LocalPlayer();if not IsValid(p) or not p:IsAdmin() then P:EndPlacement();return end
 if P.placing=="terminal" then P:UpdateSurfacePlacement(cmd);return end
 local left=cmd:KeyDown(IN_ATTACK);local right=cmd:KeyDown(IN_ATTACK2)
 cmd:RemoveKey(IN_ATTACK);cmd:RemoveKey(IN_ATTACK2)
 if not left and not right then P.placeArmed=true end
 if not P.placeArmed then return end
 if right or input.IsKeyDown(KEY_ESCAPE) then P:EndPlacement();return end
 local pos,ang=C.Placement(p,p:GetEyeTrace(),P.placing);P.placementPos=pos;P.placementAngle=ang
 if left and pos then local kind=P.placing;P:EndPlacement();P:Request("place",{kind=kind}) end
end)
hook.Add("PostDrawTranslucentRenderables","ixCCTVGhost",function(depth,sky,sky3d)
 if C.rendering or depth or sky or sky3d or not P.placementPos or not IsValid(P.ghost) then return end
 local blend=render.GetBlend();local r,g,b=render.GetColorModulation()
 P.ghost:SetPos(P.placementPos);P.ghost:SetAngles(P.placementAngle)
 render.SetBlend(.55);render.SetColorModulation(.3,1,.85);P.ghost:DrawModel()
 render.SetBlend(blend);render.SetColorModulation(r,g,b)
 if P.placing=="camera" then
  local lens,angle=C.CameraLens(P.placementPos,P.placementAngle);local forward=angle:Forward()
  render.DrawLine(lens,lens+forward*80,Color(92,229,201),true)
 end
end)
hook.Add("HUDPaint","ixCCTVPlacement",function()
 if not P.placing then return end
 local c=C.Desk.colors;local w=math.min(720,ScrW()-40);local x,y=(ScrW()-w)/2,ScrH()-136
 surface.SetDrawColor(c.bg);surface.DrawRect(x,y,w,108)
 surface.SetDrawColor(c.metal);surface.DrawRect(x,y,w,36)
 surface.SetDrawColor(c.accent);surface.DrawRect(x+12,y+12,5,12)
 draw.SimpleText("МОНТАЖ CCTV / "..C.kinds[P.placing].name,"ixCCTVTitle",x+28,y+8,c.text)
 draw.SimpleText("ЛКМ — установить     ПКМ / Esc — отмена","ixCCTVBody",x+16,y+48,c.accent)
 local text=P.placementPos and "После установки: E — имя, направление и подключение" or "Наведите на поверхность поблизости"
 if P.placing=="terminal" then text="Наведите на prop · R — пресет / поверхность · После установки — точная настройка" end
 draw.SimpleText(C.FitText(text,"ixCCTVPlate",w-32),"ixCCTVPlate",x+16,y+79,c.muted)
end)
