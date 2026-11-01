const fs=require('fs'),f=require('fengari'),{normalize}=require('./glua.cjs');
const source=p=>'do\n'+normalize(fs.readFileSync(p,'utf8'))+'\nend\n';
const files=['tools/fixture.lua','tools/terminal-preview-fixture.lua','tools/fixtures/character-skills.lua',
 'helix/gamemode/game/cl_legends_theme.lua','helix/gamemode/game/cl_interface_os.lua','helix/gamemode/game/ui/legends.workspace.lua'];
const definitions=fs.readdirSync('ixhl2rp/plugins/!!skills/skills').map(name=>
 'SKILL={}\n'+source('ixhl2rp/plugins/!!skills/skills/'+name)+`\nSKILL.GetMaximum=SKILL.GetMaximum or function() return 10 end
 SKILL.GetRequiredXP=SKILL.GetRequiredXP or function(_,skills,level) return math.ceil(75*level^1.95+100) end
 ix.skills.list[${JSON.stringify(name.slice(3,-4))}]=SKILL\n`).join('');
function program(w,h){return files.slice(0,3).map(source).join('')+`\npreviewWidth=${w};previewHeight=${h}\n`+files.slice(3).map(source).join('')+'\nix.skills.list={}\n'+definitions;}
module.exports={program};
if(require.main===module) for(const [w,h] of [[1920,1080],[1280,720]]){
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 const code=program(w,h)+'\nreturn PreviewSVG(SkillsPreview())';
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const svg=f.to_jsstring(f.lua.lua_tostring(L,-1)).replace(/width="1920" height="1120" viewBox="0 0 1920 1120"/,`width="${w}" height="${h}" viewBox="0 0 ${w} ${h}"`);
 fs.writeFileSync(`docs/character-skills-${w}.svg`,svg);
 console.log('Rendered native character-page layout',w,h);
}
