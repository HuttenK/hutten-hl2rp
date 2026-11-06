local PLUGIN = PLUGIN

ix.weaponDamageMultiplier = 2

do
	local PLAYER = FindMetaTable("Player")

	function PLAYER:ProcessMeleeStamina(staminaUse, callbackFailed)
		local character = self:GetCharacter()
		local canAttack = true

		if staminaUse > 0 and character then
			local value = self:GetLocalVar("stm", 0) - staminaUse

			if value < 0 then
				canAttack = false

				if callbackFailed then
					callbackFailed(self)
				end
			elseif SERVER then
				self:ConsumeStamina(staminaUse)
			end
		end

		return canAttack
	end
end
