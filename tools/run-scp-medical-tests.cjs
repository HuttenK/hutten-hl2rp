const {run,source,finish}=require('./restored-test-runner.cjs');
require('./test-scp-medical.cjs')((name,files,assertions,setup='')=>run(name,setup+'\n'+source(files)+'\n'+assertions));
finish();
