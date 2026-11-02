module.exports=suite=>{
 suite('Engraved icons resolve actions and draw within their allocated slot',
 ['helix/gamemode/game/cl_medieval_icons.lua'],`
 eq(ix.Legends.IconName('drop'),'drop');eq(ix.Legends.IconName('icon16/book_open.png'),'book')
 eq(ix.Legends.IconName('перевязать'),'heart');eq(ix.Legends.IconName('незнакомое действие'),'seal')
 for name in pairs(ix.Legends.Glyphs) do
  lines={};ix.Legends.Icon(name,10,20,48)
  assert(#lines>0,name)
  for _,v in ipairs(lines) do
   assert(v[1]>=10 and v[1]<=58 and v[3]>=10 and v[3]<=58,name)
   assert(v[2]>=20 and v[2]<=68 and v[4]>=20 and v[4]<=68,name)
  end
 end
 `,`
 ix.Legends={};function string.utf8lower(s) return string.lower(s) end
 lines={};surface={SetDrawColor=function() end,DrawLine=function(...) lines[#lines+1]={...} end}
 `);
 suite('Textured frames keep nonnegative patches and bounded UVs, including tiny controls',
 ['helix/gamemode/game/cl_legends_theme.lua'],`
 for _,size in ipairs({{1,1},{24,18},{310,46},{600,750},{2200,400}}) do
  for name in pairs(ix.Legends.Art) do
   local area,count=0,0
   surface.DrawTexturedRectUV=function(x,y,w,h,u0,v0,u1,v1)
    count=count+1;area=area+w*h
    assert(x>=10 and y>=20 and x+w<=10+size[1] and y+h<=20+size[2])
    assert(w>0 and h>0 and u0>=0 and v0>=0 and u1<=1 and v1<=1 and u1>=u0 and v1>=v0)
   end
   assert(ix.Legends.NineSlice(name,10,20,size[1],size[2],26))
   near(area,size[1]*size[2]);assert(count<=9)
  end
 end
 ix.Legends.Art.panel.material.IsError=function() return true end
 eq(ix.Legends.NineSlice('panel',0,0,100,100,26),false)
 `,`
 ix.Civic={Scale=function(n) return n end}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end;color_white=Color(255,255,255)
 function Material() return {IsError=function() return false end} end
 surface={CreateFont=function() end,SetDrawColor=function() end,SetMaterial=function() end}
 vgui={Register=function() end}
 `);
 suite('Downed screen preserves hold-to-give-up, cancellation, rescue and death controls',
 ['ixhl2rp/plugins/downed_state/cl_downed.lua'],`
 local P=registered.ixDownedScreen
 local p=setmetatable({valid=true},{__index=function(_,key) return P[key] or paneMethods[key] end})
 p:Init();eq(p.button.visible,true)
 p.button.OnMousePressed(p.button,2);eq(#sent,0)
 p.button.OnMousePressed(p.button,MOUSE_LEFT);eq(sent[1],0)
 clock=clock+.4;held=false;p:Think();eq(sent[2],1);eq(p.button.started,nil)
 held=true;p.button.OnMousePressed(p.button,MOUSE_LEFT);clock=clock+1.6;p:Think();eq(sent[#sent],2)
 local count=#sent;p:Think();eq(#sent,count)
 alive=false;active=false;p:Think();eq(p.button.visible,false);eq(p.mouse,false)
 p:Paint(1280,720);eq(rendered['ВЫ ПАЛИ'],true)
 alive=true;active=true;p:Paint(1280,720);eq(rendered['На грани смерти'],true)
 rescue=true;p:Think();eq(p.removed,true)
 `,`
 SERVER=false;CLIENT=true;MOUSE_LEFT=1;TEXT_ALIGN_CENTER=1;TEXT_ALIGN_TOP=0
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 function Lerp(f,a,b) return a+(b-a)*f end;function FrameTime() return .016 end
 function ScrW() return 1280 end;function ScrH() return 720 end
 alive=true;active=true;rescue=false;held=true;sent={};rendered={}
 local character={};local player={valid=true,Alive=function() return alive end,GetCharacter=function() return character end,GetNetVar=function(_,k,v) return v end}
 function LocalPlayer() return player end
 ix.gui={};ix.Downed={HoldTime=1.5,Active=function() return active end,RescueWindow=function() return rescue end,Blood=function() return .3 end}
 ix.Legends={Icon=function() end,Rule=function() end,ButtonFace=function() end}
 surface={CreateFont=function() end,SetDrawColor=function() end,DrawRect=function() end}
 draw={NoTexture=function() end,SimpleText=function(s) rendered[s]=true end,SimpleTextOutlined=function(s) rendered[s]=true end}
 net.SendToServer=function() end;net.WriteUInt=function(v) sent[#sent+1]=v end
 input={IsMouseDown=function() return held end}
 registered={};vgui={Register=function(name,p) registered[name]=p end}
 paneMethods={SetSize=function() end,MakePopup=function() end,SetKeyboardInputEnabled=function() end,
  SetMouseInputEnabled=function(s,v) s.mouse=v end,GetWide=ScrW,GetTall=ScrH,Remove=function(s) s.removed=true end}
 function paneMethods:Add()
  return {valid=true,SetText=function() end,SetVisible=function(s,v) s.visible=v end,
    MouseCapture=function() end,IsHovered=function() return true end}
 end
 PLUGIN={}
 `);
 const setup=`
 SERVER=false;CLIENT=true
 viewport={1280,720};function ScrW() return viewport[1] end;function ScrH() return viewport[2] end
 function LocalPlayer() return {valid=true,GetCharacter=function() return nil end,HasWhitelist=function() return true end} end
 ix.Legends={Scale=function(n) return math.floor(n*math.Clamp(math.min(ScrW()/1600,ScrH()/900),.7,1.6)+.5) end,T=function(en,ru) return ru end}
 ix.InterfaceOS=ix.Legends
 ix.Civic={Scale=ix.Legends.Scale};ix.Locale={lang='ru'}
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end;color_white=Color(255,255,255)
 function Material() return {IsError=function() return false end} end
 surface={CreateFont=function() end,SetDrawColor=function() end,SetMaterial=function() end}
 ix.gui={};ix.char={vars={},loaded={}};ix.characters={}
 ix.languages={stored={rus={uniqueID='rus'},hidden={notSelectable=true}}}
 ix.option={Get=function(_,d) return d end}
 registered={};vgui={Register=function(name,panel) registered[name]=panel end,GetControlTable=function() return {} end}
 function pane() return {SetPos=function(self,x,y) self.x=x;self.y=y end,SetSize=function(self,w,h) self.w=w;self.h=h end,SetDisabled=function(self,v) self.disabled=v end} end
 `;
 suite('Character creation has four steps, rejects invalid input, and submits without stats',
  ['helix/gamemode/game/cl_legends_theme.lua','ixhl2rp/plugins/zz_legends_interface/cl_menu.lua'],`
  local P=registered.ixCharMenu;local p=setmetatable({view='create',step=1,next=pane()},{__index=P})
  p:ResetDraft();eq(p.draft.primaryStat,nil);eq(p.draft.skills,nil);eq(#p.draft.languages,1)
  p.valid=false;function p:Validate(keys) self.checked=keys;return self.valid end
  function p:ShowStep() self.shown=self.step end
  p:Advance();eq(p.step,1);p.valid=true;p:Advance();eq(p.step,2)
  p:Advance();eq(p.step,3);p:Advance();eq(p.step,4);eq(p.shown,4)
  local called=false;function p:Submit() called=true end;p:Advance();assert(called)
  p:Back();eq(p.step,3);p.awaitingResponse=100;p:Back();eq(p.step,3)
  `,setup);
 suite('Creation panels stay within 720p, 1080p and ultrawide viewports',
  ['helix/gamemode/game/cl_legends_theme.lua','ixhl2rp/plugins/zz_legends_interface/cl_menu.lua'],`
  local P=registered.ixCharMenu
  for _,size in ipairs({{1280,720},{1920,1080},{3440,1440}}) do
   viewport=size
   for _,view in ipairs({'home','roster','create'}) do
    local p=setmetatable({controlsReady=true,view=view,scene=pane(),previewToggle=pane(),content=pane(),back=pane(),next=pane()},{__index=P})
    p:PerformLayout(size[1],size[2])
    for _,field in ipairs({'scene','previewToggle','content','back','next'}) do
     local v=p[field];assert(v.x>=0 and v.y>=0 and v.w>0 and v.h>0,field)
     assert(v.x+v.w<=size[1]+1 and v.y+v.h<=size[2]+1,field..' outside screen')
    end
    assert(p.back.x+p.back.w<p.next.x)
   end
  end
  `,setup);
 suite('TAB defaults to inventory and discards remembered removed pages',
  ['helix/gamemode/game/cl_legends_theme.lua','helix/gamemode/game/ui/legends.workspace.lua'],`
  local p=setmetatable({character={GetID=function() return 7 end}},{__index=registered['ui.tabmenu']})
  eq(p:RememberedPage(),'equipment')
  ix.Legends.lastTabByCharacter[7]='skills';eq(p:RememberedPage(),'equipment')
  ix.Legends.lastTabByCharacter[7]='journal';eq(p:RememberedPage(),'journal')
  for _,size in ipairs({{1280,720},{1920,1080},{3440,1440}}) do
   viewport=size
   local S=ix.Legends.Scale
   local w,h=size[1]-S(48),size[2]-S(155)
   local lw,dw,gap,rw=p:EquipmentGeometry(w,h)
   eq(lw+dw+gap*2+rw,w);assert(lw>0 and dw>0 and rw>0 and gap>0)
   local seam=ix.Legends.BackdropGeometry(size[1],size[2])
   assert(S(24)+lw+gap+dw<seam,'panels must not cover the niche')
   local x,y,pw,ph=ix.Legends.PortraitBounds(size[1],size[2])
   assert(x>seam and x+pw<size[1] and y>S(80))
   assert(y+ph*.98<size[2]-S(75)-S(104),'vitals must not cover the feet')
  end
  `,setup);
 suite('The continuous backdrop and live portrait share pedestal coordinates at every aspect',
  ['helix/gamemode/game/cl_legends_theme.lua'],`
  local U=ix.Legends
  for _,size in ipairs({{1280,720},{1920,1080},{1920,1200},{3440,1440}}) do
   local w,h=size[1],size[2];local draws={}
   surface.DrawRect=function() end;surface.DrawTexturedRect=function() end
   surface.DrawTexturedRectUV=function(...) draws[#draws+1]={...} end
   U.Backdrop(w,h);eq(#draws,2)
   near(draws[1][3]+draws[2][3],w);near(draws[1][3],draws[2][1])
   near(draws[1][7],draws[2][5]);eq(draws[1][8],1);eq(draws[2][8],1)
   local x,y,pw,ph=U.PortraitBounds(w,h)
   near(y+ph*.98,h*.787);assert(x>=draws[2][1] and x+pw<=w)
   near(pw/ph,(1672/941)*.274/.65)
  end
  local P=registered['legends.portrait']
  function Vector(x,y,z) return {x=x,y=y,z=z} end
  local p=setmetatable({modelFloor=-2,modelHeight=74,SetLookAt=function(s,v) s.target=v end,
   SetCamPos=function(s,v) s.camera=v end},{__index=P})
  p:SetPortraitFocus(false)
  near(.5+(p.target.z-p.modelFloor)/p.portraitSpan,.98)
  near(.5+(p.target.z-p.modelFloor-p.modelHeight)/p.portraitSpan,.10)
  local span=p.portraitSpan;p:SetPortraitFocus(true);assert(p.portraitSpan<span)
  p:SetPortraitFocus(false);near(p.portraitSpan,span)
  `,setup);
};
