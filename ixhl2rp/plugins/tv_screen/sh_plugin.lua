local PLUGIN = PLUGIN

PLUGIN.name        = "TV Screen"
PLUGIN.author      = "Hutten"
PLUGIN.description = "Displays a synchronized material on all TV props in the map."

-- List of TV models and their screen positioning config.
-- forwardOffset : distance from entity origin toward the screen face (world units)
-- upOffset      : vertical shift from entity origin (world units)
-- width/height  : screen size in world units
PLUGIN.tvModels = {
	["models/props_c17/tv_monitor01.mdl"] = {
		forwardOffset = 6,  -- вперёд от origin (к экрану)
		rightOffset   = -2,   -- вправо/влево
		upOffset      = 0.75,  -- вверх от origin
		width         = 14.5,  -- ширина экрана в world units
		height        = 10.5,  -- высота экрана в world units
		pitch         = 270,   -- наклон вверх/вниз
		yaw           = 90,   -- поворот влево/вправо
		roll          = 0,   -- крен
	},
}

PLUGIN.defaultMaterial = "vgui/white"

if SERVER then
	util.AddNetworkString("ix_tv_setmaterial")
	util.AddNetworkString("ix_tv_config")
	util.AddNetworkString("ix_tv_sound")
end

-- Admin command: /tvset <material path>
-- Example: /tvset blaze/posters/poster01
ix.command.Add("TVSet", {
	description = "Установить материал на всех телевизорах.",
	adminOnly   = true,
	arguments   = {
		ix.type.string
	},
	OnRun = function(self, client, materialPath)
		if materialPath == "" then
			return "@commandInvalidArg"
		end

		PLUGIN.currentMaterial = materialPath
		ix.data.Set("tv_material", materialPath)

		net.Start("ix_tv_setmaterial")
			net.WriteString(materialPath)
		net.Broadcast()

		client:ChatPrint("Материал телевизоров установлен: " .. materialPath)
	end
})

-- Admin command: /tvreset
ix.command.Add("TVReset", {
	description = "Сбросить материал телевизоров на стандартный.",
	adminOnly   = true,
	OnRun = function(self, client)
		local mat = PLUGIN.defaultMaterial

		PLUGIN.currentMaterial = mat
		ix.data.Set("tv_material", mat)

		net.Start("ix_tv_setmaterial")
			net.WriteString(mat)
		net.Broadcast()

		client:ChatPrint("Материал телевизоров сброшен.")
	end
})

-- Helper: broadcast current config of all models to everyone.
local function BroadcastConfig()
	for model, cfg in pairs(PLUGIN.tvModels) do
		net.Start("ix_tv_config")
			net.WriteString(model)
			net.WriteFloat(cfg.forwardOffset or 0)
			net.WriteFloat(cfg.rightOffset   or 0)
			net.WriteFloat(cfg.upOffset      or 0)
			net.WriteFloat(cfg.width         or 20)
			net.WriteFloat(cfg.height        or 15)
			net.WriteFloat(cfg.pitch         or 0)
			net.WriteFloat(cfg.yaw           or 0)
			net.WriteFloat(cfg.roll          or 0)
		net.Broadcast()
	end
end

-- /TVForward <number>
ix.command.Add("TVForward", {
	description = "[TV] Изменить forwardOffset (насколько экран выдвинут вперёд).",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.forwardOffset = val end
		BroadcastConfig()
		client:ChatPrint("[TV] forwardOffset = " .. val)
	end
})

-- /TVUp <number>
ix.command.Add("TVUp", {
	description = "[TV] Изменить upOffset (высота экрана над origin).",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.upOffset = val end
		BroadcastConfig()
		client:ChatPrint("[TV] upOffset = " .. val)
	end
})

-- /TVRight <number>
ix.command.Add("TVRight", {
	description = "[TV] Изменить rightOffset (смещение вправо/влево).",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.rightOffset = val end
		BroadcastConfig()
		client:ChatPrint("[TV] rightOffset = " .. val)
	end
})

-- /TVWidth <number>
ix.command.Add("TVWidth", {
	description = "[TV] Изменить ширину экрана (world units).",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.width = val end
		BroadcastConfig()
		client:ChatPrint("[TV] width = " .. val)
	end
})

-- /TVHeight <number>
ix.command.Add("TVHeight", {
	description = "[TV] Изменить высоту экрана (world units).",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.height = val end
		BroadcastConfig()
		client:ChatPrint("[TV] height = " .. val)
	end
})

-- /TVPitch <number>
ix.command.Add("TVPitch", {
	description = "[TV] Наклон экрана вверх/вниз.",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.pitch = val end
		BroadcastConfig()
		client:ChatPrint("[TV] pitch = " .. val)
	end
})

-- /TVYaw <number>
ix.command.Add("TVYaw", {
	description = "[TV] Поворот экрана влево/вправо.",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.yaw = val end
		BroadcastConfig()
		client:ChatPrint("[TV] yaw = " .. val)
	end
})

-- /TVRoll <number>
ix.command.Add("TVRoll", {
	description = "[TV] Крен экрана.",
	adminOnly = true,
	arguments = { ix.type.number },
	OnRun = function(self, client, val)
		for _, cfg in pairs(PLUGIN.tvModels) do cfg.roll = val end
		BroadcastConfig()
		client:ChatPrint("[TV] roll = " .. val)
	end
})

-- /TVPrint — показать текущие значения
ix.command.Add("TVPrint", {
	description = "[TV] Показать текущие значения конфига экрана.",
	adminOnly = true,
	OnRun = function(self, client)
		for model, cfg in pairs(PLUGIN.tvModels) do
			client:ChatPrint("[TV] Модель: " .. model)
			client:ChatPrint("  forwardOffset = " .. (cfg.forwardOffset or 0))
			client:ChatPrint("  rightOffset   = " .. (cfg.rightOffset   or 0))
			client:ChatPrint("  upOffset      = " .. (cfg.upOffset      or 0))
			client:ChatPrint("  width         = " .. (cfg.width         or 0))
			client:ChatPrint("  height        = " .. (cfg.height        or 0))
			client:ChatPrint("  pitch         = " .. (cfg.pitch         or 0))
			client:ChatPrint("  yaw           = " .. (cfg.yaw           or 0))
			client:ChatPrint("  roll          = " .. (cfg.roll          or 0))
		end
	end
})

-- /TVSound <sound_path> — установить звук на все телевизоры
-- Пример: /tvsound ambient/tv_static.wav
ix.command.Add("TVSound", {
	description = "[TV] Установить звук на телевизорах.",
	adminOnly = true,
	arguments = { ix.type.string },
	OnRun = function(self, client, soundPath)
		PLUGIN.currentSound     = soundPath
		PLUGIN.soundStartTime   = CurTime()
		ix.data.Set("tv_sound", soundPath)
		ix.data.Set("tv_sound_start", PLUGIN.soundStartTime)

		net.Start("ix_tv_sound")
			net.WriteString(soundPath)
			net.WriteDouble(PLUGIN.soundStartTime)
		net.Broadcast()

		client:ChatPrint("[TV] Звук установлен: " .. soundPath)
	end
})

-- /TVSoundStop — остановить звук
ix.command.Add("TVSoundStop", {
	description = "[TV] Остановить звук на телевизорах.",
	adminOnly = true,
	OnRun = function(self, client)
		PLUGIN.currentSound   = ""
		PLUGIN.soundStartTime = 0
		ix.data.Set("tv_sound", "")

		net.Start("ix_tv_sound")
			net.WriteString("")
			net.WriteDouble(0)
		net.Broadcast()

		client:ChatPrint("[TV] Звук остановлен.")
	end
})

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
