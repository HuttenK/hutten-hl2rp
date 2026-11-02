Schema.name = "Medieval RP"
Schema.author = "AUTONOMOUS Team"
Schema.description = ""

ix.config.language = "russian"

ix.currency.symbol = ""
ix.currency.singular = "монета"
ix.currency.plural = "монет"

-- Include netstream
ix.util.Include("libs/thirdparty/sh_netstream2.lua")
ix.util.Include("libs/sh_factiongroups.lua")

ix.util.Include("sh_configs.lua")
ix.util.Include("sh_commands.lua")

ix.util.Include("cl_hooks.lua")
ix.util.Include("sh_hooks.lua")
ix.util.Include("sv_schema.lua")
ix.util.Include("sv_hooks.lua")


ix.Net:AddEntityVar("stock", nil, ix.Net.Type.Table)
ix.Net:AddPlayerVar("tying", false, nil, ix.Net.Type.Bool)
ix.Net:AddPlayerVar("untying", false, nil, ix.Net.Type.Bool)

Schema.banned_doors = {}

function Schema:ZeroNumber(number, length)
	local amount = math.max(0, length - string.len(number))
	return string.rep("0", amount)..tostring(number)
end
