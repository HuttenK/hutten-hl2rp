// Final cctv-recognition-salute delivery verification; does not start GMod or touch live files.
// The previous restoration evidence/manifests are deliberately not rewritten.
const fs=require('fs'),path=require('path'),os=require('os'),crypto=require('crypto'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..'),docs=path.join(root,'docs');
const sha=rel=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,rel))).digest('hex');
const bundled=path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe');
const python=process.env.PYTHON||(fs.existsSync(bundled)?bundled:'python3');
const tests=[
 ['tools/test-pose-reference-loader.cjs','docs/cctv-recognition-salute-pose-reference-loader-final.log'],
 ['tools/test-cctv-recognition.cjs','docs/cctv-recognition-salute-cctv-recognition-final.log'],
 ['tools/test-pose-studio.cjs','docs/cctv-recognition-salute-pose-studio-final.log'],
 ['tools/test-pose-starters.cjs','docs/cctv-recognition-salute-pose-starters-final.log'],
 ['tools/test-restored-pose-tools.cjs','docs/cctv-recognition-salute-restored-pose-tools-final.log'],
 ['tools/test-cctv.cjs','docs/cctv-recognition-salute-cctv-final.log'],
 ['tools/test-bodycams.cjs','docs/cctv-recognition-salute-bodycams-final.log'],
 ['tools/test-animation-upgrades.cjs','docs/cctv-recognition-salute-animation-upgrades-final.log']
];
if(process.argv.includes('--help')){console.log('node tools/test-cctv-recognition-salute-delivery.cjs\nRuns focused recognition/pose checks, related animation/CCTV checks and full repository regression. Requires a fresh audit and frozen source scope. Writes only cctv-recognition-salute evidence/logs.');process.exit(0);}
function scope(){
 const proc=spawnSync(python,['tools/deploy-cctv-recognition-salute.py','--scope-json'],{cwd:root,encoding:'utf8'});
 if(proc.status!==0)throw Error(proc.stderr||proc.error||'CCTV recognition and salute scope is not ready');
 return JSON.parse(proc.stdout);
}
function testSupport(){
 const proc=spawnSync(python,['tools/deploy-cctv-recognition-salute.py','--test-support-json'],{cwd:root,encoding:'utf8'});
 if(proc.status!==0)throw Error(proc.stderr||proc.error||'Test support is not ready');
 return JSON.parse(proc.stdout);
}
function run(script,log,executable=process.execPath){
 console.log('\nRUN '+script);
 const scriptSHA256=sha(script),p=spawnSync(executable,[script],{cwd:root,encoding:'utf8',maxBuffer:32*1024*1024});
 const output=(p.stdout||'')+(p.stderr||'')+(p.error?'\n'+p.error:'');
 fs.writeFileSync(path.join(root,log),output);process.stdout.write(output);
 return {script,scriptSHA256,log,logSHA256:sha(log),scriptUnchanged:scriptSHA256===sha(script),exitCode:p.status??-1};
}
for(const [script] of tests)if(!fs.existsSync(path.join(root,script)))throw Error('Missing required test: '+script);
const audit='docs/source-audit.json';
if(!fs.existsSync(path.join(root,audit)))throw Error('Run node tools/audit.cjs first');
const sourceHashes=scope(),auditData=JSON.parse(fs.readFileSync(path.join(root,audit),'utf8').replace(/^\uFEFF/,'')),audited=new Map(auditData.entries.map(e=>[e.path,e.sha256]));
if(auditData.syntaxFailures.length||Object.entries(sourceHashes).some(([rel,digest])=>audited.get(rel)!==digest))throw Error('Syntax audit is stale or failing; run node tools/audit.cjs after all runtime edits stop');
const evidence={startedUTC:new Date().toISOString(),success:false,sourceHashes,testSupportHashes:testSupport(),auditSHA256:sha(audit),deliveryToolSHA256:sha('tools/deploy-cctv-recognition-salute.py'),aggregateRunnerSHA256:sha('tools/test-cctv-recognition-salute-delivery.cjs'),tests:[],engineTested:false};
fs.mkdirSync(docs,{recursive:true});
const destination=path.join(docs,'cctv-recognition-salute-validation.json');
const save=()=>fs.writeFileSync(destination,JSON.stringify(evidence,null,2)+'\n');save();
evidence.deliverySafety=run('tools/test-cctv-recognition-salute-deploy.py','docs/cctv-recognition-salute-delivery-safety-final.log',python);
if(evidence.deliverySafety.exitCode!==0||!evidence.deliverySafety.scriptUnchanged){save();process.exit(1);}
for(const [script,log] of tests){const result=run(script,log);evidence.tests.push(result);if(result.exitCode!==0||!result.scriptUnchanged)break;}
if(evidence.tests.length===tests.length&&evidence.tests.every(t=>t.exitCode===0&&t.scriptUnchanged)) evidence.regression=run('tools/test.cjs','docs/cctv-recognition-salute-regression-final.log');
evidence.sourceUnchanged=JSON.stringify(scope())===JSON.stringify(evidence.sourceHashes);
evidence.testSupportUnchanged=JSON.stringify(testSupport())===JSON.stringify(evidence.testSupportHashes);
evidence.auditUnchanged=evidence.auditSHA256===sha(audit);
evidence.deliveryToolsUnchanged=evidence.deliveryToolSHA256===sha('tools/deploy-cctv-recognition-salute.py')&&evidence.aggregateRunnerSHA256===sha('tools/test-cctv-recognition-salute-delivery.cjs');
evidence.success=evidence.sourceUnchanged&&evidence.testSupportUnchanged&&evidence.auditUnchanged&&evidence.deliveryToolsUnchanged&&evidence.deliverySafety.exitCode===0&&evidence.deliverySafety.scriptUnchanged&&evidence.tests.length===tests.length&&evidence.tests.every(t=>t.exitCode===0&&t.scriptUnchanged)&&evidence.regression?.exitCode===0&&evidence.regression.scriptUnchanged;
evidence.finishedUTC=new Date().toISOString();save();
console.log('\n'+(evidence.success?'PASS':'FAIL')+' cctv-recognition-salute delivery: '+evidence.tests.length+'/8 focused scripts; full regression '+(evidence.regression?.exitCode??'not run')+'. Evidence: docs/cctv-recognition-salute-validation.json');
if(!evidence.success)process.exitCode=1;
