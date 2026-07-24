local PLUGIN = PLUGIN

-- Согласие жертвы. Отказ — это полноценный ответ: без него операция не начнётся.
-- Окно закрывается само по таймауту и считается отказом, чтобы игрок, отошедший
-- от клавиатуры, не оказался «согласившимся» молча.
net.Receive("ixAmputationRequest", function()
	local surgeonName = net.ReadString()
	local key = net.ReadString()

	local limb = ix.Amputation.limbs[key]
	if !limb then return end

	local answered = false

	local function Answer(consent)
		if answered then return end
		answered = true

		net.Start("ixAmputationConsent")
			net.WriteBool(consent)
		net.SendToServer()
	end

	-- Клиентский L(key, ...) сам вызывает string.format — оборачивать не нужно.
	local query = Derma_Query(
		L("amputation.request", surgeonName, L(limb.phrase)),
		L("amputation.cut"),
		L("yes"), function() Answer(true) end,
		L("no"), function() Answer(false) end
	)

	surface.PlaySound("buttons/button17.wav")

	if IsValid(query) then
		-- Молчание = отказ.
		timer.Simple(ix.Amputation.consentTimeout, function()
			if IsValid(query) then
				query:Remove()
			end

			Answer(false)
		end)
	end
end)
