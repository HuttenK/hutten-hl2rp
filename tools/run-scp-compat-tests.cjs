const {run,source,read,finish}=require('./restored-test-runner.cjs');
require('./test-scp-compat.cjs')((name,files,assertions,setup='')=>run(name,setup+'\n'+source(files)+'\n'+assertions));
finish();
