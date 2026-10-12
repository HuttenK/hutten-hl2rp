local P=PLUGIN
-- Numeric status codes only: remote media cannot supply screen text or Lua.
local PLAYER_JS = [=[
const video=document.getElementById('video');
const picture=document.getElementById('picture');
let state={time:0,at:performance.now(),volume:0,loop:false}, code=0, suspended=false;
let lastTime=-1,lastProgress=performance.now(),playRequest=0;
function reportPlayback() {
 if(video && !suspended && code!==3 && code!==4 && code!==5){
  if(video.currentTime!==lastTime){lastTime=video.currentTime;lastProgress=performance.now();}
  if(video.readyState<1) code=0;
  else if(video.readyState<2 || video.seeking || performance.now()-lastProgress>8000) code=2;
  else code=1;
 }
 if(window.ixTV && typeof window.ixTV.playback==='function')
  window.ixTV.playback(video && Number.isFinite(video.currentTime)?video.currentTime:0,
   !!video && code===1 && !video.paused && !video.seeking && !video.ended,code);
}
window.ixMediaSuspend=function(){
 suspended=true;playRequest++;if(video){video.muted=true;video.pause();}
};
window.ixMediaUpdate=function(time,volume,loop){
 if(suspended) lastProgress=performance.now();suspended=false;
 state={time:time,at:performance.now(),volume:volume,loop:loop};sync();
};
function sync(){
 if(!video || suspended || code===4 || code===5) return;
 video.volume=Math.max(0,Math.min(1,state.volume));video.muted=state.volume<=0;video.loop=state.loop;
 if(video.readyState<1) return;
 let target=Math.max(0,state.time+(performance.now()-state.at)/1000);
 const duration=video.duration;
 if(Number.isFinite(duration) && duration>0){
  if(state.loop) target%=duration;
  else if(target>=duration){code=3;video.pause();video.style.visibility='hidden';reportPlayback();return;}
  if(Math.abs(video.currentTime-target)>1.25){try{video.currentTime=target;}catch(_){}}
 }
 video.style.visibility='visible';
 if(code===3) code=1;
 if(video.paused) {
  const request=++playRequest,result=video.play();
  if(result && result.catch) result.catch(function(){
   // An intentional pause can reject an outstanding play promise. It is not
   // a codec/autoplay failure and must not poison the next resume.
   if(!suspended && request===playRequest){code=5;reportPlayback();}
  });
 }
}
if(video){
 video.addEventListener('loadedmetadata',sync);
 video.addEventListener('canplay',function(){code=1;lastProgress=performance.now();sync();});
 video.addEventListener('waiting',function(){code=2;reportPlayback();});
 video.addEventListener('playing',function(){code=1;lastProgress=performance.now();});
 video.addEventListener('ended',function(){code=3;reportPlayback();});
 video.addEventListener('error',function(){code=4;reportPlayback();});
 setInterval(sync,1000);
}
if(picture){
 picture.addEventListener('load',function(){code=1;reportPlayback();});
 picture.addEventListener('error',function(){code=4;reportPlayback();});
 if(picture.complete) code=picture.naturalWidth>0?1:4;
}
setInterval(reportPlayback,100);
]=]
local function escape(v) return v:gsub("&","&amp;"):gsub('"',"&quot;"):gsub("<","&lt;"):gsub(">","&gt;") end
function P:BuildTVHTML(path)
 local clean=path:lower():match("^[^?#]+") or path:lower()
 local image=clean:match("%.png$") or clean:match("%.jpe?g$") or clean:match("%.gif$") or clean:match("%.webp$") or clean:match("%.bmp$") or clean:match("%.svg$")
 local body=image and ('<img id="picture" src="'..escape(path)..'">') or ('<video id="video" src="'..escape(path)..'" autoplay muted playsinline></video>')
 return '<!doctype html><meta charset="utf-8"><style>html,body{margin:0;width:100%;height:100%;overflow:hidden;background:#000}video,img{width:100%;height:100%;object-fit:contain}</style>'..body..'<script>'..PLAYER_JS..'</script>'
end

