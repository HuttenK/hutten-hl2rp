ITEM.name="Ключ-карта / Научный отдел / Уровень 4"
ITEM.isKeycard=true
ITEM.department="science"
ITEM.departmentLabel="Научный отдел"
ITEM.clearanceLevel=4
ITEM.model="models/cultist/items/keycards/w_keycard.mdl"
ITEM.skin=10
ITEM.width=1
ITEM.height=1
ITEM.access={DATAFILE_ELEVATED=true,["SCP_SCIENCE_4"]=true}
ITEM.iconCam={pos=Vector(0,0,12),ang=Angle(90,0,-45),fov=45}

for level=1,ITEM.clearanceLevel do ITEM.access["SCP_"..ITEM.department:upper().."_"..level]=true end
