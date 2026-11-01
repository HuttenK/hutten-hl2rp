// Final validation only after explicit root GO and independent PASS. No live writes.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),os=require('os'),{spawnSync}=require('child_process');
const parser=require('luaparse'),{normalize}=require('./glua.cjs');
const root=path.resolve(__dirname,'..'),tag='pose-portable-symmetry';
const file=rel=>path.join(root,rel),sha=rel=>crypto.createHash('sha256').update(fs.readFileSync(file(rel))).digest('hex');
const save=(rel,value)=>fs.writeFileSync(file(rel),JSON.stringify(value,null,2)+'\n');
const python=process.env.PYTHON||path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe');
function delivery(flag){const p=spawnSync(python,['-X','utf8','tools/deploy-'+tag+'.py',flag],{cwd:root,encoding:'utf8',maxBuffer:24*1024*1024});if(p.status!==0)throw Error(p.stderr||p.error);return JSON.parse(p.stdout);}
const review=fs.readFileSync(file('docs/'+tag+'-review.md'),'utf8');
if(!/^Status:\s*\*\*PASS\b[^\r\n]*\*\*/m.test(review)||/PENDING|CHANGES REQUESTED/.test(review))throw Error('Independent review not PASS');
delivery('--plan');
const sourceHashes=delivery('--scope-json'),supportHashes=delivery('--support-json');
const entries=[];
function walk(rel){for(const de of fs.readdirSync(file(rel),{withFileTypes:true})){const child=rel+'/'+de.name;if(de.isDirectory())walk(child);else if(child.endsWith('.lua')){let syntax='pass';try{parser.parse(normalize(fs.readFileSync(file(child),'utf8')),{luaVersion:'5.2'});}catch(e){syntax=e.message;}entries.push({path:child,sha256:sha(child),syntax});}}}
walk('ixhl2rp/plugins/pose_studio');
const audit={files:entries.length,entries,syntaxFailures:entries.filter(r=>r.syntax!=='pass'),engineTested:false};
const auditPath='docs/'+tag+'-source-audit.json';save(auditPath,audit);
if(audit.syntaxFailures.length)throw Error(JSON.stringify(audit.syntaxFailures));
const evidence={startedUTC:new Date().toISOString(),sourceHashes,supportHashes,auditSHA256:sha(auditPath),results:[],engineTested:false,success:false};
const report='docs/'+tag+'-validation.json';save(report,evidence);
const scripts=['tools/test-pose-reference-loader.cjs','tools/test-pose-embedded-reference.cjs','tools/test-pose-live-symmetry.cjs','tools/test-restored-pose-tools.cjs','tools/test-animation-upgrades.cjs','tools/test.cjs'];
for(const script of scripts){
 const scriptSHA256=sha(script),log='docs/'+tag+'-'+path.basename(script,'.cjs')+'-final.log';
 const p=spawnSync(process.execPath,[script],{cwd:root,encoding:'utf8',maxBuffer:32*1024*1024});
 const output=(p.stdout||'')+(p.stderr||'')+(p.error?'\n'+p.error:'');fs.writeFileSync(file(log),output);
 const result={script,scriptSHA256,scriptUnchanged:sha(script)===scriptSHA256,log,logSHA256:sha(log),exitCode:p.status??-1,suites:(output.match(/^PASS /gm)||[]).length};
 if(result.exitCode===0&&result.suites===0)result.exitCode=-2;
 evidence.results.push(result);save(report,evidence);console.log(script+': '+(result.exitCode===0?'PASS':'FAIL')+' ('+result.suites+' suites)');
 if(result.exitCode!==0||!result.scriptUnchanged){process.stdout.write(output);process.exitCode=1;break;}
}
evidence.sourceUnchanged=JSON.stringify(sourceHashes)===JSON.stringify(delivery('--scope-json'));
evidence.supportUnchanged=JSON.stringify(supportHashes)===JSON.stringify(delivery('--support-json'));
evidence.preserved=delivery('--plan').preserved;
evidence.success=evidence.results.length===scripts.length&&evidence.results.every(r=>r.exitCode===0&&r.scriptUnchanged)&&evidence.sourceUnchanged&&evidence.supportUnchanged;
evidence.finishedUTC=new Date().toISOString();save(report,evidence);
console.log(JSON.stringify({success:evidence.success,syntaxFiles:audit.files,scripts:evidence.results.length,suites:evidence.results.reduce((n,r)=>n+r.suites,0)}));
if(!evidence.success)process.exitCode=1;
