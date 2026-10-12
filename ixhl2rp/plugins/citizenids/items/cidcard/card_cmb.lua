-- Compatibility alias: saved identity details survive; only one document is registered.
ix.Item.legacyIDs=ix.Item.legacyIDs or {}
ix.Item.legacyIDs["card_cmb"]="card"
function ITEM:Register() end
