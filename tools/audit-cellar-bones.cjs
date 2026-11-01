// Compare the editor's actual whitelist to mounted Cellar animation skeletons.
// Usage: node tools/audit-cellar-bones.cjs <models/ix_cellar/cellar directory>
const fs = require('fs');
const path = require('path');
const assert = require('assert');
const {lua, lauxlib, lualib, to_luastring, to_jsstring} = require('fengari');
const directory = process.argv[2];
if (!directory) throw new Error('Supply the installed Cellar animation model directory.');
const models = ['male_anims.mdl', 'female_anims.mdl', 'male_stance_anims.mdl', 'female_stance_anims.mdl'];
const sets = [], report = [];
for (const file of models) {
  const buffer = fs.readFileSync(path.join(directory, file));
  assert.equal(buffer.toString('ascii', 0, 4), 'IDST');
  const count = buffer.readInt32LE(156), offset = buffer.readInt32LE(160), names = [];
  assert(count > 0 && count <= 256 && offset + count * 216 <= buffer.length);
  for (let i = 0; i < count; i++) {
    const entry = offset + i * 216, start = entry + buffer.readInt32LE(entry);
    const end = buffer.indexOf(0, start);
    assert(start >= 0 && end >= start);
    names.push(buffer.toString('utf8', start, end));
  }
  sets.push(new Set(names)); report.push({file, count});
}
const shared = [...sets[0]].filter(name => name.startsWith('ValveBiped.Bip01_') && sets.every(set => set.has(name))).sort();
const L = lauxlib.luaL_newstate(); lualib.luaL_openlibs(L);
const source = fs.readFileSync(path.join(__dirname, '../ixhl2rp/plugins/pose_studio/sh_clip.lua'), 'utf8');
const code = 'ix={PoseStudio={}}; include=function() end; ' + source + `
result={} for name in pairs(ix.PoseStudio.humanoidBones) do result[#result+1]=name end
table.sort(result); result=table.concat(result,"\\n")`;
const status = lauxlib.luaL_dostring(L, to_luastring(code));
assert.equal(status, lua.LUA_OK, status ? to_jsstring(lua.lua_tostring(L, -1)) : '');
lua.lua_getglobal(L, to_luastring('result'));
assert.deepEqual(to_jsstring(lua.lua_tostring(L, -1)).split('\n'), shared);
assert.equal(shared.length, 53);
console.log(JSON.stringify({models: report, sharedAnatomicalBones: shared.length, exactWhitelistMatch: true,
  excludedHelpers: [...sets[0]].filter(name => !shared.includes(name)), liveVisualTest: false}, null, 2));
