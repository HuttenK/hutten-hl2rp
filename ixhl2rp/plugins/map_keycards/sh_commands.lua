local function dispatch(client, action, ...)
    local plugin = ix.plugin.list.map_keycards
    if not plugin then return "Модуль доступа недоступен." end
    return plugin:AdminCommand(client, action, ...)
end

local function command(name, description, arguments, callback)
    ix.command.Add(name, {
        adminOnly = true,
        description = description,
        arguments = arguments,
        OnRun = callback
    })
end

-- Helix introspects OnRun's named parameters when registering typed arguments.
command("MapDoorAccess", "Назначить допуск двери/кнопке под прицелом: 0–4, отдел необязателен.",
    {ix.type.number, bit.bor(ix.type.string, ix.type.optional)}, function(_, client, level, department)
        return dispatch(client, "set", level, department)
    end)
command("MapDoorAccessRemove", "Удалить правило допуска у двери/кнопки под прицелом.", {}, function(_, client)
    return dispatch(client, "remove")
end)
command("MapDoorAccessInfo", "Проверить группу двери/кнопки под прицелом и её допуск.", {}, function(_, client)
    return dispatch(client, "info")
end)
command("MapDoorAccessTest", "Включить/выключить проверку собственной карты без обхода администратора.",
    {ix.type.bool}, function(_, client, enabled)
        return dispatch(client, "test", enabled)
    end)
