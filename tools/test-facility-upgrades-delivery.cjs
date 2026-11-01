// Final facility-upgrades delivery verification; does not start GMod or touch live files.
// The previous restoration evidence/manifests are deliberately not rewritten.
const fs=require('fs'),path=require('path'),os=require('os'),crypto=require('crypto'),{spawnSync}=require('child_process');
const root=path.resolve(__dirname,'..'),docs=path.join(root,'docs');
const sha=rel=>crypto.createHash('sha256').update(fs.readFileSync(path.join(root,rel))).digest('hex');
const bundled=path.join(os.homedir(),'.cache/codex-runtimes/codex-primary-runtime/dependencies/python/python.exe');
const python=process.env.PYTHON||(fs.existsSync(bundled)?bundled:'python3');
const tests=[
 ['tools/test-water-sources.cjs','docs/facility-upgrades-water-sources-final.log'],
 ['tools/test-decon.cjs','docs/facility-upgrades-decon-final.log'],
 ['tools/test-bodycams.cjs','docs/facility-upgrades-bodycams-final.log'],
 ['tools/test-animation-upgrades.cjs','docs/facility-upgrades-animation-upgrades-final.log'],
 ['tools/test-cctv.cjs','docs/facility-upgrades-cctv-final.log'],
 ['tools/test-bed-sleep.cjs','docs/facility-upgrades-bed-sleep-final.log'],
 ['tools/test-restored-engineering.cjs','docs/facility-upgrades-restored-engineering-final.log'],
 ['tools/test-restored-furniture.cjs','docs/facility-upgrades-restored-furniture-final.log'],
 ['tools/test-restored-carts.cjs','docs/facility-upgrades-restored-carts-final.log'],
 ['tools/test-restored-quests.cjs','docs/facility-upgrades-restored-quests-final.log'],
 ['tools/test-restored-pose-tools.cjs','docs/facility-upgrades-restored-pose-tools-final.log']
];
if(process.argv.includes('--help')){console.log('node tools/test-facility-upgrades-delivery.cjs\nRuns four upgrade tests, CCTV, sleep, all five restoration tests and full repository regression. Requires a fresh audit and frozen 32-file scope. Writes only facility-upgrades evidence/logs.');process.exit(0);}
function scope(){
 const proc=spawnSync(python,['tools/deploy-facility-upgrades.py','--scope-json'],{cwd:root,encoding:'utf8'});
 if(proc.status!==0)throw Error(proc.stderr||proc.error||'Facility-upgrades scope is not ready');
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
const evidence={startedUTC:new Date().toISOString(),success:false,sourceHashes,auditSHA256:sha(audit),deliveryToolSHA256:sha('tools/deploy-facility-upgrades.py'),aggregateRunnerSHA256:sha('tools/test-facility-upgrades-delivery.cjs'),tests:[],engineTested:false};
fs.mkdirSync(docs,{recursive:true});
const destination=path.join(docs,'facility-upgrades-validation.json');
const save=()=>fs.writeFileSync(destination,JSON.stringify(evidence,null,2)+'\n');save();
evidence.deliverySafety=run('tools/test-facility-upgrades-deploy.py','docs/facility-upgrades-delivery-safety-final.log',python);
if(evidence.deliverySafety.exitCode!==0||!evidence.deliverySafety.scriptUnchanged){save();process.exit(1);}
for(const [script,log] of tests){const result=run(script,log);evidence.tests.push(result);if(result.exitCode!==0||!result.scriptUnchanged)break;}
if(evidence.tests.length===tests.length&&evidence.tests.every(t=>t.exitCode===0&&t.scriptUnchanged)) evidence.regression=run('tools/test.cjs','docs/facility-upgrades-regression-final.log');
evidence.sourceUnchanged=JSON.stringify(scope())===JSON.stringify(evidence.sourceHashes);
evidence.auditUnchanged=evidence.auditSHA256===sha(audit);
evidence.deliveryToolsUnchanged=evidence.deliveryToolSHA256===sha('tools/deploy-facility-upgrades.py')&&evidence.aggregateRunnerSHA256===sha('tools/test-facility-upgrades-delivery.cjs');
evidence.success=evidence.sourceUnchanged&&evidence.auditUnchanged&&evidence.deliveryToolsUnchanged&&evidence.deliverySafety.exitCode===0&&evidence.deliverySafety.scriptUnchanged&&evidence.tests.length===tests.length&&evidence.tests.every(t=>t.exitCode===0&&t.scriptUnchanged)&&evidence.regression?.exitCode===0&&evidence.regression.scriptUnchanged;
evidence.finishedUTC=new Date().toISOString();save();
console.log('\n'+(evidence.success?'PASS':'FAIL')+' facility-upgrades delivery: '+evidence.tests.length+'/11 focused scripts; full regression '+(evidence.regression?.exitCode??'not run')+'. Evidence: docs/facility-upgrades-validation.json');
if(!evidence.success)process.exitCode=1;
