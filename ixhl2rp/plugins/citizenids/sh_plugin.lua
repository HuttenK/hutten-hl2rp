PLUGIN.name = "New Citizen IDs"
PLUGIN.description = ""
PLUGIN.author = "Schwarz Kruppzo"

ix.util.Include("sh_portrait.lua")
ix.util.Include("cl_portrait.lua")
ix.util.Include("cl_hooks.lua")
ix.util.Include("sv_hooks.lua")

-- Админ-команда: впечатать (привязать) экипированную ключ-карту цели к её персонажу.
-- Снимает: имя, модель, скин, генетику (физописание), а также связь datafileID.
ix.command.Add("CardImprint", {
	description = "Впечатать ключ-карту цели в её персонажа (имя, модель, генетика, связь).",
	adminOnly = true,
	arguments = {
		ix.type.player
	},
	OnRun = function(self, client, target)
		local character = target:GetCharacter()
		if !character then
			return "У цели нет активного персонажа."
		end

		local card = ix.Item.instances[target:GetFirstAtSlot(1,1,"cid")]
		if !card or not card.isKeycard then
			return target:Name() .. ": нет экипированной ключ-карты в слоте 'cid'."
		end

		if !Schema.ImprintCard then
			return "Ошибка: Schema:ImprintCard не загружена."
		end

		if not Schema:ImprintCard(card, character) then return "Не удалось сохранить фотографию владельца." end

		return string.format("Карта впечатана в персонажа %s (Табельный №%s).",
			target:Name(), tostring(card:GetData("cid", "000-00")))
	end
})
ix.command.Add("DocumentImprint",{
 description="Зарегистрировать документ и сохранить текущую внешность владельца.",adminOnly=true,
 arguments={ix.type.player,bit.bor(ix.type.number,ix.type.optional)},
 OnRun=function(self,client,target,itemID)
  local character=target:GetCharacter()
  if not character then return "У игрока нет персонажа." end
  local candidates={}
  for _,item in pairs(target:GetItems()) do
   if item.isIdentityDocument and (not itemID or item:GetID()==itemID) then candidates[#candidates+1]=item end
  end
  if #candidates~=1 then
   local ids={}; for _,item in ipairs(candidates) do ids[#ids+1]=tostring(item:GetID()) end
   return #candidates==0 and "Документ не найден в инвентаре игрока." or "Укажите ID документа: "..table.concat(ids,", ")
  end
  if not Schema:ImprintCard(candidates[1],character) then return "Не удалось сохранить фотографию." end
  return "Документ зарегистрирован. Фотография зафиксирована."
 end
})
