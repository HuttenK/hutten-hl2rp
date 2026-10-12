local LocalRagdollID = 0
local hiddenHead
CreateConVar("bd_firstperson", 0, {FCVAR_ARCHIVE, FCVAR_USERINFO}, "", 0, 1)
CreateConVar("bd_customcamdisable", 0, {FCVAR_ARCHIVE, FCVAR_USERINFO}, "", 0, 1)

local function restoreHead()
    if IsValid(hiddenHead) then
        local bone = hiddenHead:LookupBone("ValveBiped.Bip01_Head1")
        if bone then hiddenHead:ManipulateBoneScale(bone, Vector(1, 1, 1)) end
    end
    hiddenHead = nil
end
net.Receive("BD.DeathCam", function()
    restoreHead()
    LocalRagdollID = net.ReadInt(32)
end)
hook.Add("CalcView", "RagDeath_Cam", function(ply, pos, angles, fov)
    restoreHead()
    -- Let Helix's character/death/observer camera own its view.
    if (ix and ix.char) or ply:Alive() or GetConVar("bd_customcamdisable"):GetBool() then return end
    local rag = Entity(LocalRagdollID)
    if not IsValid(rag) or GetViewEntity() ~= ply then return end
    if GetConVar("bd_firstperson"):GetBool() then
        local eyes = rag:GetAttachment(rag:LookupAttachment("eyes"))
        if eyes then
            local bone = rag:LookupBone("ValveBiped.Bip01_Head1")
            if bone then rag:ManipulateBoneScale(bone, Vector(0, 0, 0)); hiddenHead = rag end
            return {origin = eyes.Pos, angles = eyes.Ang, fov = fov, znear = 0.5}
        end
    end
    local trace = util.TraceLine({start = rag:GetPos(),
        endpos = rag:GetPos() - angles:Forward() * 106, filter = {rag, ply}})
    return {origin = rag:GetPos() - angles:Forward() * (100 * trace.Fraction),
        angles = angles, fov = fov, znear = 0.5}
end)

local function divider(panel, title)
    local divider = vgui.Create("DHorizontalDivider", panel)
    function divider:Paint(w, h)
        if (title != nil) then
            surface.SetFont("GModToolHelp")
            local widthOfText = surface.GetTextSize(title)
            
            surface.SetDrawColor(200, 200, 200, 255)
            surface.DrawLine(0, h * 0.5, w * 0.5 - widthOfText, h * 0.5)
            surface.DrawLine(w * 0.5 + widthOfText, h * 0.5, w, h * 0.5)

            draw.SimpleTextOutlined(title, "GModToolHelp", w * 0.5, h * 0.5, Color(245, 245, 245, 255), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER, 1, Color(0, 0, 0, 45))
        else
            surface.SetDrawColor(200, 200, 200, 255)
            surface.DrawLine(0, h * 0.5, w, h * 0.5)
        end
    end
    panel:AddItem(divider)
end

hook.Add("PopulateToolMenu", "BrutalDeathsBD", function()
    spawnmenu.AddToolMenuOption("Options", "Complex Death Animations", "CDA_BD", "Settings", "", "", function(panel)
        panel:ClearControls()
        if LocalPlayer():IsSuperAdmin() then
            divider(panel, "Server Settings")
            panel:CheckBox("Enable on Players?", "bd_enable_players")
            panel:ControlHelp("Enabling work of the system on players.")
            panel:CheckBox("Enable on NPCs?", "bd_enable_npcs")
            panel:ControlHelp("Enabling work of the system on players.")
            panel:CheckBox("Enable Semi-Generation?", "bd_generative_anims")
            panel:ControlHelp("Make anims with random velocities, bones rotating, trying to generate something new, based on default animations.")
            panel:CheckBox("Change Club damage to Bullet?", "bd_club_as_default")
            panel:ControlHelp("Changing club damage animations to bullet animations.")
            panel:CheckBox("Change Other damage to Bullet?", "bd_other_as_default")
            panel:ControlHelp("Changing other damage to bullet animations.")
            panel:CheckBox("Enable Face Expression?", "bd_face_expression")
            panel:ControlHelp("Changing face on death.")
            panel:CheckBox("Enable Quicker Death?", "bd_quicker_ragdoll")
            panel:ControlHelp("Ragdoll transition will be faster.")
            panel:Help("Bodies never collide with players; physgun access follows server permissions.")
            panel:NumSlider("Life Scale", "bd_life_scale", 0, 10, 2)
            panel:ControlHelp("Scaling health of ragdoll, because ragdoll can be killed.")
            panel:NumSlider("Crawl Chance", "bd_crawl_chance", 0, 100, 0)
            panel:ControlHelp("Changing chance of crawling state after bullet or slash damage.")
            panel:NumSlider("Anim Chance", "bd_anim_chance", 1, 100, 0)
            panel:ControlHelp("Changing chance of anim after death.")
            panel:NumSlider("Remove Time", "bd_remove_time", 0, 300, 0)
            panel:ControlHelp("Removing ragdoll after that time.\n0 - disable removing.")
            panel:Help("-----")
            panel:CheckBox("Enable Club Anims?", "bd_enableanim_club")
            panel:CheckBox("Enable Fire Anims?", "bd_enableanim_fire")
            panel:CheckBox("Enable Explosion Anims?", "bd_enableanim_explode")
            panel:CheckBox("Enable Bullet Anims?", "bd_enableanim_bullet")
            panel:CheckBox("Enable Moving Anims?", "bd_enableanim_moving")
            panel:CheckBox("Enable Headshot Anims?", "bd_enableanim_headshot")
        end
        divider(panel, "Client Settings")
        panel:CheckBox("Enable Firstperson?", "bd_firstperson")
        panel:ControlHelp("Enabling firstperson when you dead.")
        panel:CheckBox("Disable Custom Camera?", "bd_customcamdisable")
        panel:ControlHelp("Fixing camera for spectate mode and other things.")
    end)
end)