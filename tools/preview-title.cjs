// Exports the actual Lua HTML builder for browser-only visual review.
// Does not start Garry's Mod or change its installation.
const fs = require('fs');
const path = require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring} = require('fengari');
const {normalize} = require('./glua.cjs');
const root = path.resolve(__dirname,'..');
for (const [locale,file] of [['en','english'],['ru','russian']]) {
  const phrases = {};
  const language = fs.readFileSync(path.join(root,`helix/gamemode/languages/${file}.lua`),'utf8');
  for (const match of language.matchAll(/^(mainmenu\.\w+)\s*=\s*"([^"\r\n]*)"/gm)) phrases[match[1]] = match[2];
  const initialPhrases = Object.entries(phrases).map(([key,value]) => `[${JSON.stringify(key)}]=${JSON.stringify(value)}`).join(',');
  const source = `
    ix={Locale={}}
    phrases={${initialPhrases}}
    function ix.Locale:AddTable(locale, values) if locale == '${locale}' then for k,v in pairs(values) do phrases[k]=v end end end
    function L(key) return phrases[key] or key end
    function Color(...) return {...} end
    function ScrW() return 1600 end
    function ScrH() return 900 end
    function math.Clamp(v,a,b) return math.max(a,math.min(b,v)) end
    surface={CreateFont=function() end}; hook={Add=function() end}
    vgui={Register=function(_, panel) titlePanel=panel end}
    ${normalize(fs.readFileSync(path.join(root,'helix/gamemode/game/cl_civic_theme.lua'),'utf8'))}
    do ${normalize(fs.readFileSync(path.join(root,'helix/gamemode/game/ui/civic.title.lua'),'utf8'))} end
    return titlePanel:BuildFullHTML()
  `;
  const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
  if (lauxlib.luaL_dostring(L,to_luastring(source)) !== lua.LUA_OK) throw Error(to_jsstring(lua.lua_tostring(L,-1)));
  let html = to_jsstring(lua.lua_tostring(L,-1));
  html = html.replace('</body>', '<script>window.menu={Button:id=>{document.querySelector(".notice").textContent="Browser preview only — game action "+id;}};</script></body>');
  const output = path.join(root,`docs/startup-preview-${locale}.html`);
  fs.writeFileSync(output,html);
  console.log(output);
}
