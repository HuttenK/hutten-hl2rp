-- Broadcast chat class — registered at file load time (не в хуке InitializedChatClasses)
-- Аналогично admin_chat.lua: ix.chat.Register вызывается напрямую, чтобы класс
-- гарантированно был доступен к моменту, когда команда /broadcast его вызывает.

ix.chat.Register("broadcast", {
	color = Color(150, 125, 175),
	format = "%s транслирует \"%s\"",
	OnChatAdd = function(self, speaker, text)
		local name = IsValid(speaker) and speaker:Name() or "Console"
		local mat = ix.util.GetMaterial("cellar/chat/broadcast.png")
		if mat and !mat:IsError() then
			chat.AddText(self.color, mat, " ", self.color, string.format(self.format, name, text))
		else
			chat.AddText(self.color, string.format(self.format, name, text))
		end
	end
})
