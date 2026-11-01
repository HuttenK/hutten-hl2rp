const fs=require('fs'),{run,source,native,finish}=require('./restored-test-runner.cjs');
const env=`
 ix.Reagents={stored={},liquid=2,Register=function(self,id,data) self.stored[id]=data end}
 local Reagents=ix.Reagents
 ${native('helix/plugins/reagents/libs/sh_reagents.lua','function Reagents:Consume(holder, amount, client)','local function BlendRGB')}
`+source(['ixhl2rp/plugins/food/sh_reagents.lua']);
run('Saved legacy water consumes through native reagent path exactly like normal water without harmful callback',env+`
 local p={valid=true,GetCharacter=function() error('water must not apply radiation or health effects') end}
 for _,id in ipairs({'water','dirty_water'}) do
  local saved={volume=330,reagents={{uniqueID=id,volume=330}}}
  function saved:RemoveReagent(index,n) self.reagents[index].volume=self.reagents[index].volume-n end
  function saved:UpdateTotal() self.volume=self.reagents[1].volume end
  local thirst,hunger=Reagents:Consume(saved,66,p);near(thirst,9.9);eq(hunger,0);eq(saved.volume,264);eq(saved.reagents[1].uniqueID,id)
  eq(Reagents.stored[id].OnConsume,nil)
 end
`);
run('Water change preserves alcohol effects and existing branded-water hydration',env+`
 near(Reagents.stored.breens_water.thirst,.152);near(Reagents.stored.smooth_breens_water.thirst,.303)
 local received
 local p={GetCharacter=function() return {Health=function() return {AddHediff=function(_,id,_,data) received={id,data.effect} end} end} end}
 Reagents.stored.vodka:OnConsume(p,10);eq(received[1],'alcohol');near(received[2],2.67)
`);
run('Existing loot item ID creates normal water without deleting the compatible item definition',`
 function Vector(...) return {...} end;function Angle(...) return {...} end
 ITEM={stats={}}
`+source(['ixhl2rp/plugins/food/items/drinks/dirty_water.lua'])+`
 eq(ITEM.name,'item.dirty_water');eq(ITEM.reagent_type,'water');eq(ITEM.volume,330);eq(ITEM.junk,'empty_can')
`);
run('Native crafting loader skips retired purification recipe and drops obsolete cached entry',`
 local Craft={recipes={purified_water={old=true}}};ix.Craft=Craft
 ix.meta.CraftRecipe={New=function(_,id) return {uniqueID=id} end}
 file={Find=function() return {'purified_water.lua'} end};ix.util={Include=function()
`+source(['ixhl2rp/plugins/recipes_cooking/cooking/purified_water.lua'])+`
 end}
 ${native('ixhl2rp/plugins/ixcraft/libs/sh_crafting.lua','function Craft:LoadFromDir(directory, pathType, category)','if SERVER then')}
 Craft:LoadFromDir('ignored','recipe','drinks');eq(Craft.recipes.purified_water,nil);eq(RECIPE,nil)
`);
for(const [locale,name] of Object.entries({russian:'Вода',english:'Water',french:'Eau',spanish:'Agua'})){
 const txt=fs.readFileSync('ixhl2rp/plugins/food/languages/'+locale+'.lua','utf8');
 const value=key=>txt.split(/\r?\n/).find(l=>l.trimStart().startsWith(key+' '))?.match(/=\s*"([^"]*)"/)?.[1];
 if(value('item.dirty_water')!==name)throw Error('Incorrect compatible water name for '+locale);
 if(!value('item.dirty_water.desc')||!value('item.purified_water.desc'))throw Error('Missing truthful water description '+locale);
 run('Water locale names and descriptions: '+locale,'eq('+JSON.stringify(value('item.dirty_water'))+','+JSON.stringify(name)+')');
}
finish();
