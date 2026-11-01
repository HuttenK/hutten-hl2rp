module.exports = function(suite) {
 const file = 'ixhl2rp/plugins/downed_state/cl_legacy.lua';
 const setup = `
 SERVER=false; CLIENT=true
 local events={}; messages={}; shaderDraws=0; medicalDraws=0; unrelatedDraws=0
 hook.GetTable=function() return events end
 hook.Add=function(event,id,callback) events[event]=events[event] or {};events[event][id]=callback end
 hook.Remove=function(event,id) if events[event] then events[event][id]=nil end end
 print=function(message) messages[#messages+1]=message end
 function Dispatch(event) for _,callback in pairs(events[event] or {}) do callback() end end
 function OldOverlay()
  shaderDraws=shaderDraws+1
  error('missing effects/shaders/autonomous_vignette covers the screen')
 end
 function Material() error('cleanup must not load the old shader') end
 hook.Add('HUDPaintBackground','ixHealthDamageOverlay',function() medicalDraws=medicalDraws+1 end)
 hook.Add('HUDPaintBackground','other_addon',function() unrelatedDraws=unrelatedDraws+1 end)
 hook.Add('HUDPaintBackground','autonomous.unconscious',OldOverlay)
 `;
 suite('Downed compatibility removes the legacy missing-shader pass and preserves other HUD callbacks', [file], `
 eq(hook.GetTable().HUDPaintBackground['autonomous.unconscious'],nil)
 Dispatch('HUDPaintBackground');eq(shaderDraws,0);eq(medicalDraws,1);eq(unrelatedDraws,1)
 eq(#messages,1);assert(messages[1]:find('autonomous.unconscious',1,true))
 `,setup);
 suite('Late plugin loading, reconnect initialization and Lua refresh cannot restore the retired overlay', [file], `
 for _,event in ipairs({'InitializedPlugins','InitPostEntity','OnReloaded'}) do
  hook.Add('HUDPaintBackground','autonomous.unconscious',OldOverlay)
  Dispatch(event);Dispatch(event);Dispatch('HUDPaintBackground')
  eq(hook.GetTable().HUDPaintBackground['autonomous.unconscious'],nil)
 end
 eq(shaderDraws,0);eq(medicalDraws,3);eq(unrelatedDraws,3);eq(#messages,4)
 `,setup);
 suite('Clean installs and repeated refreshes require no legacy shader or HUD hook table', [file,file], `
 Dispatch('InitializedPlugins');Dispatch('InitPostEntity');Dispatch('OnReloaded')
 eq(#messages,0);eq(hook.GetTable().HUDPaintBackground,nil)
 `,setup+`hook.GetTable().HUDPaintBackground=nil`);
};
