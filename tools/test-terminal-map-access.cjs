const fs=require('node:fs'),path=require('node:path');
const {normalize}=require('./glua.cjs');
const addon=process.env.FOUNDATION_MAP_ADDON || 'E:/map/lua';
const source=normalize(fs.readFileSync(path.join(addon,'dynamic_minimap/client/render/cl_fullscreen.lua'),'utf8'));
const gate='ixhl2rp/plugins/foundation_network/cl_map_access.lua';
const setup=`
 SERVER=false;CLIENT=true;ix.FoundationNet={};hooks={};commands={};pending={};keys={}
 function hook.Add(e,n,f) hooks[e]=hooks[e] or {};hooks[e][n]=f end
 function hook.Remove(e,n) if hooks[e] then hooks[e][n]=nil end end
 function hook.Run(e,...) for _,f in pairs(hooks[e] or {}) do f(...) end end
 timer.Simple=function(_,f) pending[#pending+1]=f end
 function flush() local list=pending;pending={};for _,f in ipairs(list) do f() end end
 concommand={Add=function(n,f) commands[n]=f end}
 function Vector() return {} end
 input={IsKeyDown=function(k) return keys[k] end,IsMouseDown=function(k) return keys[k] end}
 KEY_M=20;KEY_ESCAPE=27;KEY_F=6;KEY_R=18;KEY_T=22;KEY_O=15
 local mapKey=KEY_M
 function setMapKey(k) mapKey=k end
 gui={IsGameUIVisible=function() return false end,EnableScreenClicker=function() error('Unexpected cursor change') end}
 vgui={GetKeyboardFocus=function() end,Create=function() error('Fullscreen frame must not be created') end}
 DynamicMinimap={Util={},UIStyle={Colors={}},Config={Get=function(k) return k=='dm_cl_map_key' and mapKey or true end}}
 function reloadFullscreen()
  assert(load([==[${source}]==], '@lua/dynamic_minimap/client/render/cl_fullscreen.lua'))()
 end
 reloadFullscreen()
 nativeOpen=DynamicMinimap.Fullscreen.Open
 `;
module.exports=suite=>{
 suite('Fullscreen native hotkey, rebound keyboard/mouse key, command, Toggle and Open cannot create the map window',[gate],`
  local f=DynamicMinimap.Fullscreen
  for _,key in ipairs({20,67,107}) do
   setMapKey(key);keys[key]=true;hook.Run('Think');keys[key]=false;hook.Run('Think')
   eq(f.IsOpen(),false)
  end
  commands.dm_map();f.Toggle();eq(f.Open(),false);eq(f.IsOpen(),false)
 `,setup);
 suite('Blocking an already open map closes only its fullscreen frame, and reapplying does not disturb another UI',[gate],`
  local closes=0;local wasOpen=true
  local f={Open=function() error('must not open') end,IsOpen=function() return wasOpen end,
   Close=function() closes=closes+1;wasOpen=false end}
  DynamicMinimap.Fullscreen=f;ix.FoundationNet.FullscreenMapGate.Apply()
  eq(closes,1);eq(f.Open(),false)
  ix.FoundationNet.FullscreenMapGate.Apply();eq(closes,1)
 `,setup);
 suite('Late addon availability and addon refresh reapply the fullscreen block without changing renderer or configuration',[gate],`
  local g=ix.FoundationNet.FullscreenMapGate;g.Stop()
  DynamicMinimap.Fullscreen=nil
 `+normalize(fs.readFileSync(path.join(__dirname,'..',gate),'utf8'))+`
  local config=DynamicMinimap.Config.Get
  reloadFullscreen();local refreshed=DynamicMinimap.Fullscreen.Open
  hook.Run('InitPostEntity');eq(DynamicMinimap.Fullscreen.Open(),false)
  reloadFullscreen();eq(DynamicMinimap.Fullscreen.Open==refreshed,false)
  hook.Run('OnReloaded');flush();eq(DynamicMinimap.Fullscreen.Open(),false)
  eq(DynamicMinimap.Config.Get,config)
 `,setup);
 suite('Unloading restores only the owned entry point and queued reload callbacks cannot reinstall the block',[gate],`
  local f=DynamicMinimap.Fullscreen
  hook.Run('OnReloaded');PLUGIN:OnUnload();eq(f.Open,nativeOpen)
  flush();eq(f.Open,nativeOpen);eq(hooks.OnReloaded.FoundationTerminalMapAccess,nil)
 `,setup);
 suite('Unloading does not overwrite a newer fullscreen function from another addon',[gate],`
  local newer=function() return 'newer' end
  DynamicMinimap.Fullscreen.Open=newer;PLUGIN:OnUnload();eq(DynamicMinimap.Fullscreen.Open,newer)
 `,setup);
};
