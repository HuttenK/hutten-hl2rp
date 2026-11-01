const fs=require('fs'),f=require('fengari'),{program}=require('./character-skills-preview.cjs');
module.exports=run=>{
 for(const [w,h] of [[1920,1080],[1280,720]]) run(`Character page embeds all skills beside health with scrollable bounds at ${w}x${h}`,[],program(w,h)+`
  local panel=SkillsPreview();PreviewLayout(panel)
  eq(#panel.skillRows,11)
  local row=panel.skillRows[1];local scroll=row:GetParent():GetParent()
  eq(scroll.class,'DScrollPanel')
  local section=scroll:GetParent();local content=section:GetParent()
  eq(content:GetParent(),panel.body);eq(#content:GetChildren(),2)
  local medical=content:GetChildren()[2]
  assert(medical:GetWide()>400);assert(section:GetWide()>280)
  assert(medical.x+medical.w<section.x)
  for _,skillRow in ipairs(panel.skillRows) do
   assert(skillRow:GetWide()>250);assert(skillRow:GetTall()>60)
  end
  assert(panel.skillRows[11].y>scroll:GetTall()) -- list scrolls independently, not off the character page
  local sx,sy=section:LocalToScreen(0,0)
  assert(sx+section.w<=ScrW());assert(sy+section.h<=ScrH())
 `);
 run('Character skills show real XP curves, boosts, zero-level defaults and live cap/level changes',[],program(1920,1080)+`
  local panel=SkillsPreview();local rows={}
  for _,r in ipairs(panel.skillRows) do rows[r.skillID]=r end
  local electric=rows.electric;eq(electric.skillState.level,3);eq(electric.skillState.modified,4)
  near(electric.skillState.fraction,85/math.ceil(75*3^1.55+100))
  assert(electric.tooltip:find('Электроника')==nil);assert(electric.tooltip:find('Базовый уровень: 3',1,true))
  eq(rows.medicine.skillState.fraction,1);eq(rows.acrobatics.skillState.level,0)
  panel.character.skills.electric={4,150};panel:UpdateSkills()
  eq(electric.skillState.level,4);eq(electric.skillState.modified,5)
  near(electric.skillState.fraction,150/math.ceil(75*4^1.55+100))
  panel.character.skills.electric={10,900};panel:UpdateSkills()
  eq(electric.skillState.fraction,1);assert(electric.skillState.caption:find('Максимальный уровень',1,true))
  panel.character.skills={};panel:UpdateSkills();eq(electric.skillState.level,0);eq(electric.skillState.fraction,0)
 `);
};
if(require.main===module){let n=0;module.exports((name,files,code)=>{
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 console.log('PASS '+name);n++;
});console.log(n+' character skills suites passed.');}
