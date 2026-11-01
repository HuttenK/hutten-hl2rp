const fs=require('fs'),vm=require('vm'),assert=require('assert');
const source=fs.readFileSync('ixhl2rp/plugins/tv_screen/cl_html.lua','utf8');
const js=source.match(/local PLAYER_JS = \[=\[([\s\S]*?)\]=\]/)[1];
function player(image=false){
 let now=0;
 const events={},timers=[],reports=[];
 const media={readyState:0,currentTime:0,duration:100,paused:true,seeking:false,volume:0,muted:true,style:{},complete:false,naturalWidth:0,
  play(){this.paused=false;return {catch:fn=>{this.reject=fn;}}},pause(){this.paused=true;},
  addEventListener(name,fn){events[name]=fn;}};
 const context={window:{ixTV:{playback:(time,active,state)=>reports.push({time,active,state})}},
  document:{getElementById:id=>(id===(image?'picture':'video')?media:null)},
  performance:{now:()=>now},setInterval:fn=>timers.push(fn),console,Math,Number};
 vm.createContext(context);vm.runInContext(js,context);
 return {media,events,timers,reports,context,at:t=>{now=t},update:context.window.ixMediaUpdate,report:()=>timers.at(-1)()};
}
const a=player(),b=player();
a.update(30,.5,false);assert.equal(a.media.currentTime,0);
a.report();assert.equal(a.reports.at(-1).state,0);
a.at(2000);a.media.readyState=4;a.events.loadedmetadata();assert.equal(a.media.currentTime,32);
a.report();assert.deepEqual(a.reports.at(-1),{time:32,active:true,state:1});
assert.equal(b.media.volume,0);assert.equal(b.media.currentTime,0);
a.media.seeking=true;a.report();assert.equal(a.reports.at(-1).state,2);a.media.seeking=false;
a.at(12000);a.report();assert.equal(a.reports.at(-1).state,2);
a.media.currentTime=36;a.report();assert.equal(a.reports.at(-1).state,1);
a.update(120,1,false);assert.equal(a.media.paused,true);assert.equal(a.reports.at(-1).state,3);
a.update(120,0,true);assert.equal(a.media.currentTime,20);assert.equal(a.media.muted,true);
a.events.error();assert.equal(a.reports.at(-1).state,4);
a.update(30,1,false);a.report();assert.equal(a.reports.at(-1).state,4);
b.media.readyState=4;b.update(0,.5,false);b.media.reject();assert.equal(b.reports.at(-1).state,5);
const image=player(true);image.media.naturalWidth=1024;image.events.load();assert.equal(image.reports.at(-1).state,1);
image.events.error();assert.equal(image.reports.at(-1).state,4);
delete image.context.window.ixTV;image.report();
const parked=player();parked.media.readyState=4;parked.update(12,.6,true);
const previousRejection=parked.media.reject;
parked.context.window.ixMediaSuspend();assert.equal(parked.media.paused,true);assert.equal(parked.media.muted,true);
previousRejection();parked.report();assert.notEqual(parked.reports.at(-1).state,5);
parked.at(20000);parked.timers[0]();parked.report();assert.equal(parked.media.paused,true);
assert.equal(parked.reports.at(-1).active,false);assert.notEqual(parked.reports.at(-1).state,2);
// Loading finishes while parked: metadata/canplay must not restart the decoder.
parked.events.loadedmetadata();parked.events.canplay();assert.equal(parked.media.paused,true);
parked.update(42,.4,true);assert.equal(parked.media.currentTime,42);assert.equal(parked.media.paused,false);
assert.equal(parked.media.volume,.4);parked.report();assert.equal(parked.reports.at(-1).state,1);
previousRejection();parked.report();assert.equal(parked.reports.at(-1).state,1);
assert(!source.includes('id="caption"'));
console.log('PASS TV JavaScript: isolated channels, delayed readiness, late-join seek, stalls, recovery, end, loop, URL image failure, playback rejection, safe bridge, parked decoder and synchronized resume.');

