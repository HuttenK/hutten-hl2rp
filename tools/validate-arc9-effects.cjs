const fs=require('node:fs'),path=require('node:path'),crypto=require('node:crypto');
const {spawnSync}=require('node:child_process');
const {normalize}=require('./glua.cjs');
const parser=require('luaparse');
const root=path.resolve(__dirname,'..'),out=path.join(root,'docs/performance-audit');
const baseline='C:/Users/q1236/AppData/Local/Temp/ix-arc9-effects-before-20261018T152206Z';
const sha=filename=>crypto.createHash('sha256').update(fs.readFileSync(filename)).digest('hex');
const allowed=['ixhl2rp/plugins/render_efficiency/cl_budget.lua',
 'ixhl2rp/plugins/arc9_shot_effects/sh_plugin.lua','ixhl2rp/plugins/arc9_shot_effects/sv_effects.lua','ixhl2rp/plugins/arc9_shot_effects/cl_effects.lua'];
function list(roots) {
 const result=[];
 function walk(dir) {for(const e of fs.readdirSync(dir,{withFileTypes:true})) {
  const p=path.join(dir,e.name);if(e.isDirectory()) walk(p);else if(p.endsWith('.lua')) result.push(path.relative(root,p).replaceAll('\\','/'));
 }}
 for(const dir of roots) walk(path.join(root,dir));return result.sort();
}
function hashes() {return Object.fromEntries(list(['helix','ixhl2rp','addons']).map(p=>[p,sha(path.join(root,p))]));}
const before=hashes();
const previous=Object.fromEntries(JSON.parse(fs.readFileSync(path.join(baseline,'manifest.json'),'utf8')).map(r=>[r.path,r.sha256]));
const changed=Object.keys(before).filter(p=>before[p]!==previous[p]);
if(JSON.stringify([...changed].sort())!==JSON.stringify([...allowed].sort()) || Object.keys(previous).some(p=>!before[p])) throw Error('Unexpected runtime scope');
const modules=['arc9-shot-effects','render-budget','performance-client-review','arc9-helperbones','arc9-sd-pose','body-drag-render','weapon-display','performance-overall'];
const run=spawnSync(process.execPath,['tools/run-performance-tests.cjs',...modules],{cwd:root,encoding:'utf8',maxBuffer:8*1024*1024});
const log=(run.stdout||'')+(run.stderr||'');
fs.writeFileSync(path.join(out,'arc9-effects-tests.log'),log);
const syntax=list(['helix','ixhl2rp','addons','base','sandbox','terrortown']);
const errors=[];
for(const p of syntax) {try {parser.parse(normalize(fs.readFileSync(path.join(root,p),'utf8')),{luaVersion:allowed.includes(p)?'5.1':'5.2'});}catch(e) {errors.push({path:p,error:e.message});}}
const after=hashes();
const stable=JSON.stringify(before)===JSON.stringify(after);
const passed=[...log.matchAll(/^PASS /gm)].length;
const result={generatedUTC:new Date().toISOString(),exitCode:run.status===0&&passed>0&&!errors.length&&stable?0:1,
 modules,passed,regressionExitCode:run.status,syntaxFiles:syntax.length,syntaxErrors:errors,stable,baseline,
 runtimeHashes:after,runtimeChanges:Object.fromEntries(allowed.map(p=>[p,after[p]])),
 upstreamFixtures:Object.fromEntries(['arc9_tracer.lua','sh_effects.lua'].map(p=>[p,sha(path.join(root,'tools/fixtures/arc9-upstream',p))])),
 limits:['Mocked Lua/render/network contracts, not live GPU/PVS evidence.','Near-tracer invalid width reproduced using the installed upstream effect and GMod Clamp implementation.',
 'User could not perform the muzzle A/B check; server cause is not conclusively attributed.','Physical bullets, damage and Workshop content are unchanged.']};
fs.writeFileSync(path.join(out,'arc9-effects-verification.json'),JSON.stringify(result,null,2)+'\n');
console.log(JSON.stringify({exitCode:result.exitCode,passed,syntaxFiles:syntax.length,errors,stable,runtimeChanges:result.runtimeChanges},null,2));
process.exitCode=result.exitCode;
