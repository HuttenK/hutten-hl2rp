ITEM.name="Ключ-карта / Военное подразделение / Уровень 2"
ITEM.isKeycard=true
ITEM.department="military"
ITEM.departmentLabel="Военное подразделение"
ITEM.clearanceLevel=2
ITEM.model="models/cultist/items/keycards/w_keycard.mdl"
ITEM.skin=12
ITEM.width=1
ITEM.height=1
ITEM.access={DATAFILE_MEDIUM=true,["SCP_MILITARY_2"]=true}
ITEM.iconCam={pos=Vector(0,0,12),ang=Angle(90,0,-45),fov=45}

for level=1,ITEM.clearanceLevel do ITEM.access["SCP_"..ITEM.department:upper().."_"..level]=true end
