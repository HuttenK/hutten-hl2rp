CLIENT=true;SERVER=false
function RealTime() return clock end
function ScrH() return 1080 end
function ScrW() return 1920 end
function FrameNumber() return math.floor(clock*100) end
surface={CreateFont=function() end}
function Color(...) return {...} end
tvOptions={}
ix.type={bool=1,number=2};ix.option={Add=function() end,Get=function(key,d)
 if key=='tvMute' then return muted or false end
 if tvOptions[key]~=nil then return tvOptions[key] end;return d
end}
client=admin();LocalPlayer=function() return client end
function client:GetFOV() return 90 end
viewAngle=Angle(45,0,0);viewFOV=90;viewAspect=1920/1080
function EyeAngles() return viewAngle end
function TVTestView() return {origin=client.pos,angles=viewAngle,fov=viewFOV,aspect=viewAspect} end
render={GetViewSetup=TVTestView}
MASK_VISIBLE=99
local originalEntity=entity
function entity(...)
 local e=originalEntity(...);function e:IsDormant() return self.dormant==true end;return e
end
panelsCreated=0;vgui={}
function vgui.Create(name)
 panelsCreated=panelsCreated+1
 local p={valid=true,scripts={}}
 function p:Remove() self.valid=false end
 for _,key in ipairs({'SetSize','SetPos','SetMouseInputEnabled','SetKeyboardInputEnabled','SetAllowLua'}) do p[key]=function() end end
 function p:AddFunction(_,_,fn) assert(self.loaded,'Bridge registered before DOM ready');self.callback=fn end
 function p:SetHTML(html) self.html=html;self.loaded=true;if self.OnDocumentReady then self:OnDocumentReady() end end
 function p:RunJavascript(js) self.scripts[#self.scripts+1]=js end
 return p
end
function Material(path) return {IsError=function() return path=='bad' end} end
function EyePos() return client.pos end
concommands={};concommand={Add=function(name,fn) concommands[name]=fn end}

