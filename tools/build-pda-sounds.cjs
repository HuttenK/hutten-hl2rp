// Original FIELDLINK UI synthesis. No samples or third-party recordings.
const fs=require('fs'),path=require('path'),assert=require('assert');
const rate=44100, out=path.resolve('addons/fieldlink_pda/sound/fieldlink/ui');
fs.mkdirSync(out,{recursive:true});
const specs={
 hover:[.065,[[0,.05,1150,.13]]],
 click:[.12,[[0,.025,220,.23],[.018,.072,760,.16]]],
 boot:[1.12,[[0,.36,110,.13],[.16,.14,440,.12],[.34,.14,660,.12],[.56,.18,880,.13],[.76,.3,1320,.09]]],
 sleep:[.42,[[0,.13,880,.12],[.1,.14,440,.13],[.22,.19,220,.12]]],
 success:[.32,[[0,.12,660,.16],[.12,.18,990,.13]]],
 error:[.32,[[0,.11,190,.16],[.16,.13,165,.16]]],
 register:[.65,[[0,.12,440,.14],[.13,.13,660,.14],[.28,.3,880,.12],[.29,.3,1320,.06]]]
};
for(const [name,[duration,tones]] of Object.entries(specs)){
 const n=Math.ceil(duration*rate),pcm=Buffer.alloc(n*2);let peak=0,power=0;
 for(let i=0;i<n;i++){
  const t=i/rate;let v=0;
  for(const [at,len,freq,amp] of tones){
   const u=t-at;if(u<0||u>=len)continue;
   const env=Math.min(1,u/.006)*Math.pow(1-u/len,1.8);
   v+=amp*env*(Math.sin(2*Math.PI*freq*u)+.14*Math.sin(2*Math.PI*freq*2*u));
  }
  assert(Number.isFinite(v)&&Math.abs(v)<.65);peak=Math.max(peak,Math.abs(v));power+=v*v;
  pcm.writeInt16LE(Math.round(v*32767),i*2);
 }
 assert(peak>.04);const header=Buffer.alloc(44);
 header.write('RIFF');header.writeUInt32LE(36+pcm.length,4);header.write('WAVEfmt ',8);
 header.writeUInt32LE(16,16);header.writeUInt16LE(1,20);header.writeUInt16LE(1,22);
 header.writeUInt32LE(rate,24);header.writeUInt32LE(rate*2,28);header.writeUInt16LE(2,32);header.writeUInt16LE(16,34);
 header.write('data',36);header.writeUInt32LE(pcm.length,40);
 fs.writeFileSync(path.join(out,name+'.wav'),Buffer.concat([header,pcm]));
 console.log(`${name}: ${duration}s, peak ${peak.toFixed(3)}, RMS ${Math.sqrt(power/n).toFixed(3)}`);
}
