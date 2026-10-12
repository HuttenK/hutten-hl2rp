PLUGIN.name = "Flashlight item"
PLUGIN.author = "SleepyMode / Legends"
PLUGIN.description = "Inventory flashlight with a bounded, shadowed client beam."
local PLUGIN = PLUGIN
ix.util.Include("cl_flashlight.lua")

if SERVER then
    function PLUGIN:CanUseFlashlight(client)
        return client:Alive() and client:GetCharacter() and not client:IsRestricted()
            and not (client.IsPilotScanner and client:IsPilotScanner())
            and (client:HasItem("flashlight") or client:IsCombine())
    end

    function PLUGIN:PlayerSwitchFlashlight(client, enabled)
        -- Keep the native F binding. The engine beam stays off so it cannot double
        -- up with the projected beam. Explicit off requests always clear our state.
        if not enabled then client:SetNWBool("ixFieldFlashlight", false); return false end
        if CurTime() < (client.ixFlashlightNext or 0) then return false end
        client.ixFlashlightNext = CurTime() + .2
        if not self:CanUseFlashlight(client) then return false end
        client:SetNWBool("ixFieldFlashlight", not client:GetNWBool("ixFieldFlashlight", false))
        client:EmitSound("items/flashlight1.wav", 50, 100, .45)
        return false
    end

    function PLUGIN:PlayerLoadedCharacter(client) client:SetNWBool("ixFieldFlashlight", false) end
    function PLUGIN:PlayerDeath(client) client:SetNWBool("ixFieldFlashlight", false) end
    timer.Create("ixFieldFlashlightCheck", .5, 0, function()
        for _, client in ipairs(player.GetAll()) do
            if client:GetNWBool("ixFieldFlashlight", false) and not PLUGIN:CanUseFlashlight(client) then
                client:SetNWBool("ixFieldFlashlight", false)
            end
        end
    end)
    function PLUGIN:OnUnload()
        timer.Remove("ixFieldFlashlightCheck")
        for _, client in ipairs(player.GetAll()) do client:SetNWBool("ixFieldFlashlight", false) end
    end
end
