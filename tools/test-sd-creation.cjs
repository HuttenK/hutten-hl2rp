module.exports = function(suite) {
suite('SD creation groups actual hairstyle variants and rejects invalid skin choices',
 ['helix/gamemode/game/character/appearance/sh_modelchoices.lua','ixhl2rp/plugins/sd_creation.lua'], `
 local models={'models/sd/citizens/citizen_male_08_hair1.mdl','models/sd/citizens/citizen_male_08_hair2.mdl','models/sd/citizens/citizen_male_08_hair3.mdl','models/sd/citizens/citizen_male_09_hair1.mdl'}
 local choices=ix.BuildCharacterModelChoices(models,nil)
 eq(#choices,2); eq(#choices[1].variants,3); eq(choices[2].index,4)
 ix.faction.indices[1]={sdSkinCounts={[models[1]]=27},GetModels=function() return models end}
 local payload={faction=1,gender=1,model=1}; local v=ix.char.vars.sdSkin
 eq(v:OnValidate(0,payload,{}),0); eq(v:OnValidate(26,payload,{}),26)
 eq(v:OnValidate(27,payload,{}),false); eq(v:OnValidate(-1,payload,{}),false)
 eq(v:OnValidate(1.5,payload,{}),false); eq(v:OnValidate(0/0,payload,{}),false)
 eq(v:OnValidate('1',payload,{}),false)
 eq(v.field,'sd_skin'); eq(v.Net.Transmit,ix.transmit.all)
 payload.faction=2; eq(v:OnValidate(6,payload,{}),0)
 `, `ix.char={vars={},RegisterVar=function(k,v) ix.char.vars[k]=v end}; ix.faction={indices={}}; ix.type={number=1}; ix.transmit={all=1}`);
};
