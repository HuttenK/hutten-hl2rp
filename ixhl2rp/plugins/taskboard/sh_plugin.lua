local PLUGIN = PLUGIN

PLUGIN.name = "Доска объявлений"
PLUGIN.author = "Claude"
PLUGIN.description = "Терминал, где жители оставляют и берут задания. Детали и оплата обсуждаются лично."

-- Сколько открытых заданий может одновременно висеть у одного персонажа.
PLUGIN.maxOpenPerChar = 3
-- Дальность «клика» по терминалу для публикации/приёма (юниты).
PLUGIN.useRadius = 140

-- Ограничители длины полей (символы).
PLUGIN.limits = {
	title   = 120,
	summary = 300,
	details = 2000,
	reward  = 120,
}

ix.util.Include("sv_plugin.lua")
ix.util.Include("cl_plugin.lua")
