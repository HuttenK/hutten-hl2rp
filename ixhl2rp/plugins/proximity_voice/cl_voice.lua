local PLUGIN=PLUGIN
local V=ix.voice
local routes,speakers={},{}
local held,recording,normalHeld=false,false,false
local nextPing=0
local normalKey
local function RefreshNormalKey()
 if normalKey then
  local down
  if normalKey>=MOUSE_FIRST and normalKey<=MOUSE_LAST then down=input.IsMouseDown(normalKey)
  else down=input.IsKeyDown(normalKey) end
  normalHeld=down and system.HasFocus()
  if not normalHeld then normalKey=nil end
 end
end
local keyWasDown=false
local keyOwned=false
local lastKey=0
local function InputBlocked()
 return gui.IsGameUIVisible() or not system.HasFocus() or IsValid(vgui.GetKeyboardFocus()) or IsValid(ix.gui.menu) or IsValid(V.keyDialog)
end
local function Send(on)
 net.Start("ixRadioVoicePTT"); net.WriteBool(on); net.SendToServer()
end
local function Stop()
 RefreshNormalKey()
 held=false; keyOwned=false; Send(false)
 if recording and not normalHeld then permissions.EnableVoiceChat(false) end
 recording=false
end
local function Start()
 local p=LocalPlayer()
 RefreshNormalKey()
 if held or not V.CanSpeak(p) or p:IsRestricted() or InputBlocked() then return end
 held=true; nextPing=RealTime()+1; Send(true)
end
concommand.Add("+ix_radio_voice",Start)
concommand.Add("-ix_radio_voice",Stop)
net.Receive("ixRadioVoiceAck",function()
 local accepted=net.ReadBool()
 if not held then return end
 if not accepted then
  Stop(); LocalPlayer():Notify("Нет доступного канала. Включите рацию и выберите частоту."); return
 end
 if not recording then
  recording=true
  -- Local confirmation once per accepted press, never on keepalive acknowledgements.
  LocalPlayer():EmitSound("npc/overwatch/radiovoice/on3.wav",0,100,.15,CHAN_AUTO)
  -- Engine-controlled consent is required; never run blocked +voicerecord.
  permissions.EnableVoiceChat(true)
 end
end)
function PLUGIN:PlayerBindPress(p,bind,pressed,code)
 if bind=="+voicerecord" and pressed then
  -- PlayerBindPress does not deliver release events. Observe the physical button.
  normalKey=code
  normalHeld=code~=nil
 end
end
net.Receive("ixVoiceRoute",function()
 local p=net.ReadEntity(); local mode=net.ReadUInt(2); local label=net.ReadString()
 local gain=mode==3 and net.ReadFloat() or 1
 if IsValid(p) then routes[p]={mode=mode,label=label,gain=math.Clamp(gain,0,1),at=RealTime()} end
end)
function PLUGIN:PlayerStartVoice(p)
 speakers[p]=true
 return true -- Suppress the default avatar/name card.
end
function PLUGIN:PlayerEndVoice(p)
 speakers[p]=nil; routes[p]=nil
 if V.UpdateRadioEffects then V.UpdateRadioEffects(LocalPlayer(),speakers,routes) end
 if IsValid(p) then p:SetVoiceVolumeScale(1) end
end
function PLUGIN:HUDShouldDraw(name)
 if name=="CHudVoiceSelfStatus" then return false end
end
function PLUGIN:Think()
 local p=LocalPlayer()
 local wasNormal=normalHeld
 RefreshNormalKey()
 if wasNormal and not normalHeld and held and recording then
  -- The engine may process -voicerecord later in this frame.
  timer.Simple(0,function() if held and recording then permissions.EnableVoiceChat(true) end end)
 end
 local key=tonumber(ix.option.Get("radioVoiceKey",0)) or 0
 local down=key>0 and key<KEY_LAST and input.IsKeyDown(key)
 if key~=lastKey then
  if keyOwned then Stop() end
  lastKey=key; keyWasDown=down -- Do not transmit the key used to configure the binding.
 else
  if down and not keyWasDown and not InputBlocked() and not held then
   Start(); keyOwned=held
  elseif not down and keyOwned then Stop() end
  keyWasDown=down
 end
 if held then
  if not V.CanSpeak(p) or p:IsRestricted() or InputBlocked() then Stop()
  elseif RealTime()>=nextPing then nextPing=RealTime()+1; Send(true) end
 end
end
-- Only audible speakers are traced. Preserve engine mute and reset our scales.
timer.Create("ixVoiceOcclusion",.2,0,function()
 local listener=LocalPlayer()
 if V.UpdateRadioEffects then V.UpdateRadioEffects(listener,speakers,routes) end
 if not V.Active(listener) then return end
 for talker in pairs(speakers) do
  if not IsValid(talker) then speakers[talker]=nil; routes[talker]=nil
  elseif talker~=listener and not talker:IsMuted() then
   local route=routes[talker]
   if route and route.mode==3 and RealTime()-route.at<2 then talker:SetVoiceVolumeScale(route.gain or 1)
   elseif route and route.mode==2 and RealTime()-route.at<2 then
    if not V.UpdateRadioEffects or ix.option.Get("radioInterference",.35)==0 then talker:SetVoiceVolumeScale(1) end
   else
    local trace=util.TraceLine({start=listener:EyePos(),endpos=talker:EyePos(),filter={listener,talker},mask=MASK_SOLID_BRUSHONLY})
    local volume=trace.Hit and ix.config.Get("voiceWallVolume",.3) or 1
    if talker:WaterLevel()==3 then volume=volume*.5 end
    talker:SetVoiceVolumeScale(volume)
   end
  end
 end
end)
local function Fonts()
 surface.CreateFont("ixVoiceMinimal",{font="Consolas",size=math.max(12,math.floor(ScrH()/1080*14)),weight=500,extended=true})
end
Fonts(); hook.Add("OnScreenSizeChanged","ixVoiceMinimalFonts",Fonts)
function V.RadioSpeakerName(listener,talker)
 local character=IsValid(talker) and talker:GetCharacter()
 if not IsValid(listener) or not listener:GetCharacter() or not character then return "Неизвестный" end
 local id=character:GetID()
 -- Match F3's per-listener saved alias, never faction/admin automatic recognition.
 if talker:GetNetVar("hide",0)==id then return "Неизвестный" end
 local name=listener.recognize and listener.recognize[id]
 if not isstring(name) then return "Неизвестный" end
 name=string.Trim(name:gsub("[%c]"," "))
 return name~="" and name or "Неизвестный"
end
function PLUGIN:HUDPaint()
 local listener=LocalPlayer(); if not V.Active(listener) then return end
 local x,y=ScrW()-24,ScrH()*.68
 local ordered={}
 for p in pairs(speakers) do if IsValid(p) and not p:IsMuted() then ordered[#ordered+1]=p end end
 table.sort(ordered,function(a,b) return a:EntIndex()<b:EntIndex() end)
 for i,p in ipairs(ordered) do
  if i>6 then break end
  local r=routes[p]; local radio=r and (r.mode==2 or r.mode==3) and RealTime()-r.at<2
  local text=p==listener and (held and "ПЕРЕДАЧА / РАЦИЯ" or "ГОЛОС / РЯДОМ") or (radio and "RX / "..r.label.." / "..V.RadioSpeakerName(listener,p) or "ГОЛОС РЯДОМ")
  local color=Color(255,255,255,180)
  if p~=listener and not radio then
   -- Fixed screen size and a visibility trace prevent giant sprites or wall tracking.
   if p:GetPos():DistToSqr(listener:GetPos())<=ix.config.Get("voiceRange",600)^2 then
    local head=p:LookupBone("ValveBiped.Bip01_Head1")
    local pos=head and p:GetBonePosition(head) or p:EyePos()
    pos=pos+Vector(0,0,10)
    local trace=util.TraceLine({start=listener:EyePos(),endpos=pos,filter={listener,p},mask=MASK_VISIBLE})
    local screen=pos:ToScreen()
    if screen.visible and not trace.Hit then
     surface.SetDrawColor(255,255,255,185)
     for bar=1,3 do
      local height=bar==2 and 10 or 6
      surface.DrawRect(math.floor(screen.x)-6+bar*3,math.floor(screen.y)-height/2,2,height)
     end
    end
   end
  else
  draw.SimpleText(text,"ixVoiceMinimal",x-23,y,color,TEXT_ALIGN_RIGHT,TEXT_ALIGN_CENTER)
  local volume=math.Clamp(p:VoiceVolume()*8,0,1)
  for bar=1,3 do
   local height=3+volume*(bar==2 and 10 or 6)
   surface.SetDrawColor(color); surface.DrawRect(x-14+bar*4,y-height/2,2,height)
  end
  y=y+22
  end
 end
end
hook.Add("ShutDown","ixVoiceStop",function() if held or recording then Stop() end end)
