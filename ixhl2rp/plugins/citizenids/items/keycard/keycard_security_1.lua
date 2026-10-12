ITEM.name="Ключ-карта / Служба безопасности / Уровень 1"
ITEM.isKeycard=true
ITEM.department="security"
ITEM.departmentLabel="Служба безопасности"
ITEM.clearanceLevel=1
ITEM.model="models/cultist/items/keycards/w_keycard.mdl"
ITEM.skin=15
ITEM.width=1
ITEM.height=1
ITEM.access={DATAFILE_MINOR=true,["SCP_SECURITY_1"]=true}
ITEM.iconCam={pos=Vector(0,0,12),ang=Angle(90,0,-45),fov=45}

for level=1,ITEM.clearanceLevel do ITEM.access["SCP_"..ITEM.department:upper().."_"..level]=true end
