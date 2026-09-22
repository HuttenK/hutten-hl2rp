local treatment
surface.CreateFont("ixMedicalTreatment", {font="Consolas", size=18, weight=500, extended=true})
net.Receive("ixMedicalProgress", function()
 local name, duration = net.ReadString(), net.ReadFloat()
 if name == "" then treatment=nil return end
 treatment = {name=name, duration=duration, started=CurTime()}
 if IsValid(ix.gui.menu) and ix.gui.menu.Close then ix.gui.menu:Close() end
 if IsValid(ix.gui.charRadial) then ix.gui.charRadial:Remove() end
end)
hook.Add("HUDPaint", "ixMedicalTreatment", function()
 if not treatment then return end
 local x,y = ScrW()*.5, ScrH()*.81
 local a=math.Clamp((CurTime()-treatment.started)/.15, 0, 1)*255
 draw.SimpleTextOutlined(treatment.name, "ixMedicalTreatment", x,y,Color(229,209,207,a),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(0,0,0,a))
 draw.SimpleTextOutlined("ЛЕЧЕНИЕ  /  R — ПРЕРВАТЬ", "ixMedicalTreatment", x,y+25,Color(246,83,99,a),TEXT_ALIGN_CENTER,TEXT_ALIGN_CENTER,1,Color(0,0,0,a))
 if treatment.duration > 0 then
  surface.SetDrawColor(45,25,29,a) surface.DrawRect(x-110,y+44,220,2)
  surface.SetDrawColor(246,83,99,a) surface.DrawRect(x-110,y+44,220*math.Clamp((CurTime()-treatment.started)/treatment.duration,0,1),2)
 end
end)
