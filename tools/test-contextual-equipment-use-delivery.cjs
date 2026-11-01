// Final run only after author freeze and independent review. No GMod launch/live writes.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),os=require('os'),{spawnSync}=require('child_process');
const parser=require('luaparse'),{normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..'),tag='contextual-equipment-use';
const base='.runtime/'+tag+'-20261009/',file=rel=>path.join(root,rel);
const load=rel=>JSON.parse(fs.readFileSync(file(rel),'utf8').replace(/^\uFEFF/,''));
const sha=rel=>crypto.createHash('sha256').update(fs.readFileSync(file(rel))).digest('hex');
const save=(rel,value)=>fs.writeFileSync(file(rel),JSON.stringify(value,null,2)+'\n');
const python=process.env.PYTHON||path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe');
if(process.argv.includes('--help')){console.log('Final contextual equipment validation: fresh syntax audit, focused suites, delivery safety and one full regression. Requires frozen scope and approved review.');process.exit(0);}
function delivery(flag){
 const p=spawnSync(python,['-X','utf8','tools/deploy-'+tag+'.py',flag],{cwd:root,encoding:'utf8',maxBuffer:24*1024*1024});
 if(p.status!==0)throw Error(p.stderr||p.error||'Delivery scope not ready');return JSON.parse(p.stdout);
}
const config=load(base+'delivery-config.json'),sourceHashes=delivery('--scope-json'),supportHashes=delivery('--support-json');
const review=fs.readFileSync(file(config.review),'utf8');
if(!/^Status:\s*\*\*PASS\b[^\r\n]*\*\*/m.test(review)||/PENDING|CHANGES REQUESTED/.test(review))throw Error('Independent review not approved');
const prior=load(base+'prior-evidence-before.json');
const unchangedPrior=()=>Object.entries(prior).every(([rel,digest])=>sha(rel)===digest);
if(!unchangedPrior())throw Error('Historical evidence changed before validation');
const entries=[];
function walk(rel){for(const dirent of fs.readdirSync(file(rel),{withFileTypes:true})){
 const child=rel+'/'+dirent.name;
 if(dirent.isDirectory())walk(child);else if(child.endsWith('.lua')){
  const source=fs.readFileSync(file(child),'utf8');let syntax='pass';
  try{parser.parse(normalize(source),{luaVersion:'5.2'});}catch(error){syntax=error.message;}
  entries.push({path:child,sha256:sha(child),syntax});
 }
}}
for(const rel of ['helix','ixhl2rp','addons'])if(fs.existsSync(file(rel)))walk(rel);
const audit={note:'Normalized Lua syntax scan, not engine validation.',files:entries.length,entries,syntaxFailures:entries.filter(row=>row.syntax!=='pass')};
const auditPath='docs/'+tag+'-source-audit.json';save(auditPath,audit);
if(audit.syntaxFailures.length)throw Error('Syntax audit failed: '+JSON.stringify(audit.syntaxFailures));
const evidence={startedUTC:new Date().toISOString(),sourceHashes,supportHashes,auditSHA256:sha(auditPath),results:[],engineTested:false,success:false};
const destination='docs/'+tag+'-validation.json';save(destination,evidence);
const scripts=['tools/test-'+tag+'-deploy.py',...config.tests,'tools/test.cjs'];
for(const script of scripts){
 const log='docs/'+tag+'-'+path.basename(script).replace(/\.(cjs|py)$/,'')+'-final.log',scriptSHA256=sha(script);
 const executable=script.endsWith('.py')?python:process.execPath;
 const args=script.endsWith('.py')?['-X','utf8',script]:[script];
 const p=spawnSync(executable,args,{cwd:root,encoding:'utf8',maxBuffer:32*1024*1024});
 const output=(p.stdout||'')+(p.stderr||'')+(p.error?'\n'+p.error:'');
 fs.writeFileSync(file(log),output);
 const result={script,scriptSHA256,scriptUnchanged:scriptSHA256===sha(script),log,logSHA256:sha(log),exitCode:p.status??-1};
 // An exported suite accidentally run as a no-op is not a passing test.
 if(result.exitCode===0&&!/\bPASS\b|\bOK\b/.test(output))result.exitCode=-2;
 evidence.results.push(result);save(destination,evidence);
 console.log(script+': '+(result.exitCode===0?'PASS':'FAIL')+'; '+log);
 if(result.exitCode!==0||!result.scriptUnchanged){process.stdout.write(output);process.exitCode=1;break;}
}
evidence.sourceUnchanged=JSON.stringify(sourceHashes)===JSON.stringify(delivery('--scope-json'));
evidence.supportUnchanged=JSON.stringify(supportHashes)===JSON.stringify(delivery('--support-json'));
evidence.priorEvidenceUnchanged=unchangedPrior();evidence.auditUnchanged=sha(auditPath)===evidence.auditSHA256;
evidence.success=evidence.results.length===scripts.length&&evidence.results.every(r=>r.exitCode===0&&r.scriptUnchanged)
 &&evidence.sourceUnchanged&&evidence.supportUnchanged&&evidence.priorEvidenceUnchanged&&evidence.auditUnchanged;
evidence.finishedUTC=new Date().toISOString();save(destination,evidence);
console.log(JSON.stringify({success:evidence.success,syntaxFiles:audit.files,scripts:evidence.results.length}));
if(!evidence.success)process.exitCode=1;
