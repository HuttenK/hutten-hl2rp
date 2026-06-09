do
	local meta = FindMetaTable("Player")

	function meta:Emote(chatType, emoteType, args)
		chatType = string.lower(chatType)
		args = args or {}

		local class = ix.chat.classes[chatType]

		if class and class:CanSay(self, text) != false then
			for k, v in pairs(args) do
				if v:sub(1, 1) != "@" then continue end
				args[k] = L(v:sub(2))
			end

			-- Always use the "l" (local) variant without %s — the chat class
			-- adds the character name itself, so passing self:Name() here
			-- would cause the name to appear twice.
			ix.chat.Send(self, chatType, L("l"..emoteType, unpack(args)))
		end
	end
end

net.Receive("ixEmote", function(len)
	local client = net.ReadEntity()

	if !IsValid(client) then
		return
	end

	local chatType = net.ReadString()
	local emoteType = net.ReadString()
	local args = net.ReadTable()

	client:Emote(chatType, emoteType, args)
end)