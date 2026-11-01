// Read-only source inventory. Counts identify review candidates, not measured cost.
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const parser = require('luaparse');
const {normalize} = require('./glua.cjs');
const root = path.resolve(__dirname, '..');
const out = process.argv[2] ? path.resolve(process.argv[2]) : path.join(root, 'docs', 'performance-audit');
const roots = ['helix', 'ixhl2rp', 'addons', 'base', 'sandbox', 'terrortown'];
const rules = {
  population: /\b(?:player\.GetAll|player\.GetHumans|ents\.GetAll|ents\.FindByClass|ents\.FindInSphere|ents\.FindInBox|ents\.FindByModel)\s*\(/,
  trace: /\b(?:util\.Trace\w*|util\.IntersectRay\w*|GetEyeTrace(?:NoCursor)?)\s*\(/,
  bones: /\b(?:SetupBones|InvalidateBoneCache|GetBoneMatrix|ManipulateBone\w*|SetBoneMatrix|BuildBonePositions)\b/,
  render: /\b(?:RenderView|ClientsideModel|ClientsideRagdoll|DrawModel|DrawCustomModel|GetRenderTarget\w*|CreateMaterial|DynamicLight|ProjectedTexture|CreateParticleSystem)\s*\(/,
  serialization: /\b(?:util\.(?:TableToJSON|JSONToTable|Compress|Decompress)|net\.WriteTable|table\.Copy)\s*\(/,
  persistence: /\b(?:mysql:(?:Update|Insert|Select|Delete)|sql\.Query|ix\.data\.Set|file\.Write|SaveData|SetData)\s*\(/,
  network: /\b(?:net\.(?:Receive|Start|Send|Broadcast|SendPVS|SendPAS)|netstream\.(?:Start|Hook)|SetNW\w*|SetNetVar|SetLocalVar)\s*\(/,
  timer: /\b(?:timer\.(?:Create|Simple|Adjust)|NextThink|SetNextClientThink)\s*\(/,
  browser: /\b(?:DHTML|HTML|RunJavascript|QueueJavascript|UpdateHTMLTexture|SetHTML|OpenURL)\b/,
  physics: /\b(?:PhysicsInit|ComputeShadowControl|SetVelocity|ApplyForceCenter|ApplyForceOffset|EnableMotion|Simulate)\s*\(/,
};
const hot = /(?:Think|Tick|HUDPaint|HUDPaintBackground|RenderScreenspaceEffects|PreDraw|PostDraw|CalcView|CalcViewModelView|SetupMove|Move|FinishMove|StartCommand|CalcMainActivity|UpdateAnimation|TranslateActivity|BuildBonePositions|EntityTakeDamage|ScalePlayerDamage|PlayerCanHearPlayersVoice|SetupPlayerVisibility|DrawTranslucentRenderables|DrawOpaqueRenderables|DoTPIK|RenderOverride|Paint|Draw|PerformLayout)/;
function group(rel) {
  const p = rel.split('/');
  if (p[1] === 'plugins') return p.slice(0,3).join('/');
  if (p[0] === 'addons') return p.slice(0,2).join('/');
  return p.slice(0,Math.min(p.length-1,3)).join('/');
}
function label(n) {
  if (!n) return '';
  if (n.type === 'Identifier') return n.name;
  if (n.type === 'MemberExpression') return label(n.base)+n.indexer+label(n.identifier);
  if (n.type === 'StringLiteral') return n.value || n.raw.slice(1,-1);
  return n.type;
}
const entries=[];
function walk(dir) {
  if (!fs.existsSync(dir)) return;
  for (const e of fs.readdirSync(dir,{withFileTypes:true}).sort((a,b)=>a.name.localeCompare(b.name))) {
    const file=path.join(dir,e.name);
    if(e.isDirectory()) { walk(file); continue; }
    if(!e.name.endsWith('.lua')) continue;
    const raw=fs.readFileSync(file), source=raw.toString('utf8'), lines=source.split('\n');
    const rel=path.relative(root,file).replaceAll('\\','/');
    const scope=rel.includes('/_old/')?'legacy-not-loaded-by-normal-plugin-loader':(['base','sandbox','terrortown'].includes(rel.split('/')[0])?'other-gamemode-or-base-dependency':'deployment-source');
    const entry={path:rel,group:group(rel),scope,bytes:raw.length,lines:lines.length,sha256:crypto.createHash('sha256').update(raw).digest('hex'),syntax:'pass',signals:[],functions:[],hooks:[],netReceivers:[]};
    lines.forEach((line,i)=>{for(const [kind,re] of Object.entries(rules)) if(re.test(line)) entry.signals.push({kind,line:i+1,text:line.trim().slice(0,350)});});
    try {
      const ast=parser.parse(normalize(source),{luaVersion:'5.2',locations:true,comments:false});
      function visit(n,context='') {
        if(!n||typeof n!=='object') return;
        if(n.type==='CallExpression') {
          const name=label(n.base);
          if(['hook.Add','timer.Create','timer.Simple','net.Receive','netstream.Hook','concommand.Add'].includes(name)) {
            const tag=name+'('+label(n.arguments[0])+')';
            if(name==='hook.Add') entry.hooks.push({name:label(n.arguments[0]),line:n.loc.start.line});
            if(name==='net.Receive'||name==='netstream.Hook') entry.netReceivers.push({name:label(n.arguments[0]),line:n.loc.start.line});
            n.arguments.forEach(a=>visit(a,tag)); return;
          }
        }
        if(n.type==='FunctionDeclaration') {
          const name=n.identifier?label(n.identifier):(context||'anonymous');
          const start=n.loc.start.line, end=n.loc.end.line;
          const signals=entry.signals.filter(s=>s.line>=start&&s.line<=end);
          entry.functions.push({name,start,end,hot:hot.test(name)||/timer\./.test(name),signals:signals.reduce((a,s)=>(a[s.kind]=(a[s.kind]||0)+1,a),{})});
          context=name;
        }
        for(const [k,v] of Object.entries(n)) if(k!=='loc'&&k!=='range') {
          if(Array.isArray(v)) v.forEach(c=>visit(c,context));
          else if(v&&typeof v==='object') visit(v,context);
        }
      }
      visit(ast);
    } catch(e) {entry.syntax=e.message;}
    entries.push(entry);
  }
}
roots.forEach(r=>walk(path.join(root,r)));
const groups={};
for(const e of entries){const g=groups[e.group]??={files:0,lines:0,signals:{},hotFunctions:[],syntaxFailures:0};g.files++;g.lines+=e.lines;g.syntaxFailures+=e.syntax!=='pass'?1:0;for(const s of e.signals)g.signals[s.kind]=(g.signals[s.kind]||0)+1;for(const f of e.functions)if(f.hot&&Object.keys(f.signals).length)g.hotFunctions.push({path:e.path,...f});}
const report={generatedAt:new Date().toISOString(),note:'Every Lua file in listed roots was read and normalized-parsed; lexical signals and function names guide semantic review. This is not profiling or proof that a plugin is enabled on the remote server. Nested function signals may overlap. Non-Lua modules/assets and external Workshop implementations need separate runtime/dependency checks.',roots,files:entries.length,lines:entries.reduce((n,e)=>n+e.lines,0),groups,entries};
fs.mkdirSync(out,{recursive:true});
fs.writeFileSync(path.join(out,'inventory.json'),JSON.stringify(report,null,2)+'\n');
console.log(JSON.stringify({files:report.files,lines:report.lines,groups:Object.keys(groups).length,syntaxFailures:entries.filter(e=>e.syntax!=='pass').map(e=>({path:e.path,error:e.syntax})),topGroups:Object.entries(groups).sort((a,b)=>b[1].hotFunctions.length-a[1].hotFunctions.length).slice(0,35).map(([name,g])=>({name,files:g.files,lines:g.lines,hotFunctions:g.hotFunctions.length,signals:g.signals}))},null,2));
