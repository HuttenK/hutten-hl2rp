// Run from the complete source checkout. Never starts GMod or deploys files.
const fs=require('fs'),path=require('path'),crypto=require('crypto'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..'),out=path.join(root,'docs');
const sha=p=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,p))).digest('hex');
const scripts=['test-restored-engineering.cjs','test-restored-furniture.cjs','test-restored-carts.cjs','test-restored-quests.cjs','test-restored-pose-tools.cjs'];
if(process.argv.includes('--help')){console.log('node tools/test-restored-systems.cjs [--with-regression]\nRuns all five focused suites and optionally the full repository regression; saves fresh logs and hash-bound evidence.');process.exit(0);}
const bundledPython=path.join(require('os').homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe');
const python=process.env.PYTHON||(fs.existsSync(bundledPython)?bundledPython:'python3');
function scope(){const p=spawnSync(python,['tools/deploy-restored-systems.py','--scope-json'],{cwd:root,encoding:'utf8'});if(p.status!==0)throw Error(p.stderr||p.error||'Cannot collect deployment scope');return JSON.parse(p.stdout);}
function run(script,log){
 console.log('\nRUN '+script);
 const p=spawnSync(process.execPath,[script],{cwd:root,encoding:'utf8',maxBuffer:32*1024*1024});
 const output=(p.stdout||'')+(p.stderr||'')+(p.error?'\n'+p.error:'');
 fs.writeFileSync(path.join(root,log),output);process.stdout.write(output);
 const docLog=log.replace(/-final\.log$/,'-tests.log');
 if(docLog!==log)fs.writeFileSync(path.join(root,docLog),output);
 return {script,scriptSHA256:sha(script),log,logSHA256:sha(log),docLog,docLogSHA256:sha(docLog),exitCode:p.status??-1};
}
const evidence={startedUTC:new Date().toISOString(),success:false,sourceHashes:scope(),tests:[],engineTested:false};
for(const filename of scripts){if(!fs.existsSync(path.join(root,'tools',filename)))throw Error('Missing required suite: '+filename);}
fs.mkdirSync(out,{recursive:true});
const evidencePath=path.join(out,'restored-systems-validation.json');
fs.writeFileSync(evidencePath,JSON.stringify(evidence,null,2)+'\n');
for(const filename of scripts){const result=run('tools/'+filename,'docs/'+filename.replace(/^test-/,'').replace(/\.cjs$/,'-final.log'));evidence.tests.push(result);if(result.exitCode!==0)break;}
if(evidence.tests.length===scripts.length&&evidence.tests.every(r=>r.exitCode===0)&&process.argv.includes('--with-regression')) evidence.regression=run('tools/test.cjs','docs/restored-systems-regression-final.log');
const after=scope();
evidence.sourceUnchanged=JSON.stringify(after)===JSON.stringify(evidence.sourceHashes);
const audit='docs/source-audit.json';evidence.auditSHA256=fs.existsSync(path.join(root,audit))?sha(audit):null;
evidence.success=evidence.sourceUnchanged&&evidence.tests.length===scripts.length&&evidence.tests.every(r=>r.exitCode===0)&&(!evidence.regression||evidence.regression.exitCode===0);
evidence.finishedUTC=new Date().toISOString();
fs.writeFileSync(evidencePath,JSON.stringify(evidence,null,2)+'\n');
console.log('\n'+(evidence.success?'PASS':'FAIL')+' restoration aggregate: '+evidence.tests.length+'/5 focused scripts; regression '+(evidence.regression?'exit '+evidence.regression.exitCode:'not requested')+'. Evidence: docs/restored-systems-validation.json');
if(!evidence.success)process.exitCode=1;
