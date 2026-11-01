-- Private native-Derma adapter extension for the production surveillance UI.
-- No engine footage is invented: previews deliberately show no-signal/standby.
local create=vnew
local function nop() end
ix.option.Add=nop
surface.CreateFont('ixPreviewNative',{font='Tahoma',size=14,weight=500,extended=true})
function vnew(class,parent)
 local p=create(class,parent)
 p.enabled=true
 function p:SetTooltip(t) self.tooltip=t end
 function p:IsDown() return false end
 function p:IsEnabled() return self.enabled end
 function p:SetEnabled(v) self.enabled=v end
 function p:SetValue(v) self.value=v;if self.OnValueChanged then self:OnValueChanged(v) end end
 function p:GetValue() return self.value or self.text end
 function p:GetChecked() return self.value==true end
 function p:SetMinMax(a,b) self.minimum=a;self.maximum=b end
 function p:SetMin(v) self.minimum=v end
 function p:SetMax(v) self.maximum=v end
 function p:AddChoice(t,id,selected) if selected then self.text=t;self.value=id end end
 function p:SizeToContents() self.h=24 end
 function p:Remove() self.valid=false;self.visible=false;if self.OnRemove then self:OnRemove() end end
 p.SetDecimals=nop;p.SetDraggable=nop;p.ShowCloseButton=nop
 if class=='DScrollPanel' then
  -- Approximate the native scrollbar, absent from the generic paint adapter.
  -- The actual production controls still use the engine DVScrollBar.
  p.bar.grip=create('DPanel',p.bar)
  p.bar.Paint=function(_,w,h) surface.SetDrawColor(55,61,52);surface.DrawRect(0,0,w,h) end
  p.bar.grip.Paint=function(_,w,h) surface.SetDrawColor(163,165,145);surface.DrawRect(1,0,w-2,h) end
  p.Think=function(self)
   local extent=0;for _,child in ipairs(self.canvas.children) do extent=math.max(extent,child.y+child.h) end
   self.bar:SetVisible(extent>self.h);self.bar:SetPos(self.w-10,0);self.bar:SetSize(10,self.h)
   local size=math.Clamp(self.h*self.h/math.max(1,extent),28,self.h)
   local fraction=math.Clamp((self.bar.scroll or 0)/math.max(1,extent-self.h),0,1)
   self.bar.grip:SetSize(10,size);self.bar.grip:SetPos(0,(self.h-size)*fraction)
  end
 elseif class=='DNumSlider' then
  p.Label=create('DLabel');p.Label.visible=false
  p.Paint=function(self,w,h)
   local font=self.Label.font or 'ixPreviewNative'
   draw.SimpleText(self.text,font,0,h/2,Color(185,177,156),0,1)
   local left=math.max(125,w*.39);local wide=math.max(10,w-left-58)
   surface.SetDrawColor(98,102,91);surface.DrawRect(left,h/2,wide,2)
   local fraction=math.Clamp(((tonumber(self.value) or 0)-(self.minimum or 0))/math.max(.0001,(self.maximum or 100)-(self.minimum or 0)),0,1)
   surface.SetDrawColor(220,222,205);surface.DrawRect(left+wide*fraction-3,h/2-5,6,12)
   draw.SimpleText(string.format('%.2f',tonumber(self.value) or 0),font,w,h/2,Color(219,220,207),2,1)
  end
 elseif class=='DCheckBoxLabel' then
  p.Paint=function(self,w,h)
   surface.SetDrawColor(133,145,115);surface.DrawOutlinedRect(0,5,12,12)
   if self:GetChecked() then surface.DrawRect(3,8,6,6) end
   draw.SimpleText(self.text,self.font or 'ixPreviewNative',22,2,self.ink or color_white)
  end
 elseif class=='DComboBox' then
  p.Paint=function(self,w,h)
   surface.SetDrawColor(12,18,13);surface.DrawRect(0,0,w,h)
   draw.SimpleText(self.text,self.font or 'ixCCTVBody',9,h/2,Color(227,230,212),0,1)
   draw.SimpleText('▾','ixCCTVBody',w-16,h/2,Color(166,180,145),1,1)
  end
 end
 return p
end
vgui.Create=vnew
function ixSurveillancePreview(root)
 root:SetPos(0,0)
 return (PreviewSVG(root):gsub('width="1920" height="1120"','width="'..root.w..'" height="'..root.h..'"'):gsub('viewBox="0 0 1920 1120"','viewBox="0 0 '..root.w..' '..root.h..'"'))
end
