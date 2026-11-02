module.exports=suite=>{
 const files=['ixhl2rp/plugins/medical/cl_examination.lua'];
 const setup=`
 SERVER=false;CLIENT=true;KEY_ESCAPE=70;MOUSE_LEFT=1;MOUSE_RIGHT=2
 function Color(...) return {...} end
 ix.Legends={accent={},ink={},PlayUISound=function() end};ix.Medicine={}
 local character={GetID=function() return 11 end}
 viewer={valid=true,alive=true,character=character,items={}}
 function viewer:GetCharacter() return self.character end
 function viewer:Alive() return self.alive end
 function viewer:GetItems() return self.items end
 function LocalPlayer() return viewer end
 function ScrW() return 1280 end;function ScrH() return 720 end
 input={IsKeyDown=function() return escape or false end}
 gui={IsGameUIVisible=function() return gameMenu or false end,
  EnableScreenClicker=function() error('Must not disable another popup globally') end}
 function RunConsoleCommand() error('Closing examination must not reopen a menu') end
 function L(v) return v end
 messages={};net.Start=function(name) messages[#messages+1]=name end
 net.SendToServer=function() end;net.WriteEntity=function() end
 net.WriteTable=function(data) treatment=data end;net.WriteBool=function() end
 local controls={}
 for _,name in ipairs({'SetTitle','ShowCloseButton','SetDraggable','SetAlpha','AlphaTo','SetFont',
  'SetTextColor','SetWrap','SetContentAlignment','Center','SetPos','SetEnabled'}) do controls[name]=function() end end
 function controls:SetText(v) self.text=v end
 function controls:SetSize(w,h) self.w=w;self.h=h end
 function controls:GetWide() return self.w or 300 end;function controls:GetTall() return self.h or 200 end
 function controls:CursorPos() return 0,0 end
 function controls:GetChildren() return self.children end
 function controls:SetMouseInputEnabled(v) self.mouse=v end
 function controls:SetKeyboardInputEnabled(v) self.keyboard=v end
 function controls:MouseCapture(v) self.capture=v end
 function controls:KillFocus() self.focus=false end
 function controls:SetVisible(v) self.visible=v end
 function controls:MakePopup() self.mouse=true;self.keyboard=true;self.focus=true end
 function controls:Remove() FindMetaTable('Panel').Remove(self) end
 local native={Remove=function(p) p.marked=true;p.removeCalls=(p.removeCalls or 0)+1 end}
 function FindMetaTable() return native end
 registered={}
 function panel(definition)
  return setmetatable({valid=true,visible=true,mouse=true,keyboard=true,capture=true,focus=true,children={}},
   {__index=function(_,key) return definition and definition[key] or controls[key] end})
 end
 function controls:Add() local child=panel();self.children[#self.children+1]=child;return child end
 vgui={Register=function(name,p) registered[name]=p end,
  Create=function(name) local p=panel(registered[name]);p:Init();return p end}
 function DermaMenu()
  local m=panel();m.options={}
  function m:AddOption(label,callback) local opt=self:Add();opt.callback=callback;self.options[#self.options+1]=opt;return opt end
  function m:Open() self:MakePopup() end
  return m
 end
 function assertReleased(p)
  eq(p.visible,false);eq(p.mouse,false);eq(p.keyboard,false);eq(p.capture,false);eq(p.focus,false)
  for _,child in ipairs(p.children) do assertReleased(child) end
 end
 function openExam() ix.Medicine.OpenExamination(viewer);return ix.Medicine.examination end
 `;
 suite('Medical close releases window, child controls and medicine popup before deferred engine deletion',files,`
  local other=panel()
  local p=openExam();local menu=DermaMenu();local child=menu:Add();p.medicineMenu=menu
  p.close.DoClick();assertReleased(p);assertReleased(menu);eq(p.marked,true);eq(menu.marked,true)
  eq(ix.Medicine.examination,nil);eq(p.removeCalls,1)
  eq(other.visible,true);eq(other.mouse,true);eq(other.keyboard,true)
  p:Close();p:Remove();p:Think();eq(p.removeCalls,1);eq(#messages,0)
  net.ReadEntity=function() return viewer end;net.ReadUInt=function() return 11 end
  net.ReadTable=function() return {parts={}} end
  net.handlers.ixMedicalExamine();eq(p.state,nil)
 `,setup);
 suite('Escape, engine pause, death and character changes all release medical UI',files,`
  local p=openExam();p:OnKeyCodePressed(KEY_ESCAPE);assertReleased(p)
  p=openExam();escape=true;p:Think();escape=false;assertReleased(p)
  p=openExam();gameMenu=true;p:Think();gameMenu=false;assertReleased(p)
  p=openExam();viewer.alive=false;p:Think();viewer.alive=true;assertReleased(p)
  p=openExam();local character=viewer.character;viewer.character=nil;p:Think();viewer.character=character;assertReleased(p)
  p=openExam();viewer.valid=false;p:Think();viewer.valid=true;assertReleased(p)
  eq(#messages,0);eq(ix.Medicine.examination,nil)
 `,setup);
 suite('Replacing an examination cannot leave its popup active or clear its successor',files,`
  local old=openExam();local menu=DermaMenu();old.medicineMenu=menu
  local current=openExam();assert(old~=current);assertReleased(old);assertReleased(menu)
  old:OnRemove();eq(ix.Medicine.examination,current);eq(current.visible,true)
  current:Remove();assertReleased(current);eq(ix.Medicine.examination,nil)
 `,setup);
 suite('Medical action preserves item and limb data, closes both popups, and ignores stale clicks',files,`
  local p=openExam();p.hover={medicines={7},hitgroup=4};p.state={parts={}};p.received=CurTime()
  viewer.items={{id=7,inventory_id=5,functions_bits=4,functions={use={index=2}},
   GetName=function() return 'Bandage' end,GetResourceText=function() return '1/1' end}}
  p:OnMousePressed(MOUSE_RIGHT);local first=p.medicineMenu
  p:OnMousePressed(MOUSE_RIGHT);assertReleased(first)
  local menu=p.medicineMenu;eq(#menu.options,1)
  menu.options[1].callback();eq(messages[1],'item.action');eq(treatment.target,viewer);eq(treatment.limb,4)
  assertReleased(p);assertReleased(menu);eq(ix.Medicine.examination,nil)
  menu.options[1].callback();eq(#messages,1)
 `,setup);
};
