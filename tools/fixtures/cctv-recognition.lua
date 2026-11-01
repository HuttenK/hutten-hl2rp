-- Native inventory methods and schema GetIDCard are loaded by the suites;
-- only engine entities, traces and drawing boundaries are mocked here.
local V=getmetatable(Vector());function V:LengthSqr() return self:Dot(self) end
MOVETYPE_WALK=2;MOVETYPE_NOCLIP=8;MOVETYPE_OBSERVER=10
playerMeta={};function FindMetaTable(name) if name=='Player' then return playerMeta end end
ix.Item={instances={}}
local nextPerson=300
function person(name,pos)
 nextPerson=nextPerson+1
 local p=admin();p.id=nextPerson;p.userid=nextPerson+100;p.pos=pos or Vector(200,0,0);p.eyeAngle=Angle(0,180,0)
 p.inventories={};p.vars={};p.secretName=name or 'Hidden real character';setmetatable(p,{__index=playerMeta})
 function p:EntIndex() return self.id end
 function p:UserID() return self.userid end
 function p:EyePos() return self.pos+Vector(0,0,64) end
 function p:GetShootPos() return self:EyePos() end
 function p:LookupBone() return self.noHead and nil or 1 end
 function p:GetBonePosition() return self.badBone and self.pos or self:EyePos()-Vector(0,0,2) end
 function p:GetNoDraw() return self.hidden or false end
 function p:IsDormant() return self.dormant or false end
 function p:GetMoveType() return self.move or MOVETYPE_WALK end
 function p:GetLocalVar(key,default) local value=self.vars[key];if value~=nil then return value end;return default end
 function p:Name() error('must never query real player identity') end
 local getCharacter=p.GetCharacter
 function p:GetCharacter() return getCharacter(self) and {GetName=function() error('must never query character identity') end} or nil end
 entities[p.id]=p;return p
end
function giveCard(p,name,department,level)
 local card={id=9000+p.id,isKeycard=true,department=department or 'security',clearanceLevel=level or 2,
  data={name=name or 'Borrowed identity',cid='135-79',number='123-456'}}
 function card:GetData(k,d) if self.data[k]~=nil then return self.data[k] end;return d end
 ix.Item.instances[card.id]=card
 p.inventories.cid={GetFirstAtSlot=function(_,x,y) eq(x,1);eq(y,1);return p.cardSlot end};p.cardSlot=card.id
 return card
end
function makeRecognitionView()
 PLUGIN:LoadData();local viewer=person('Observer',Vector(-100,0,0));viewer.admin=false
 local camera=makeDevice('camera',Vector(0,0,64));camera.entity:SetAngles(Angle(-25,0,0));local monitor=makeDevice('monitor',Vector(-50,0,64));monitor.camera=camera.id
 return viewer,camera,monitor
end
function string.utf8sub(value,start,finish)
 local length=utf8.len(value);start=start or 1;finish=finish or length
 if start<0 then start=length+start+1 end;if finish<0 then finish=length+finish+1 end
 if start>finish then return '' end
 return value:sub(utf8.offset(value,start),finish>=length and #value or utf8.offset(value,finish+1)-1)
end
function recognitionPaintRecorder()
 rectangles={};labels={};outlines={}
 surface.DrawRect=function(x,y,w,h) rectangles[#rectangles+1]={x=x,y=y,w=w,h=h} end
 surface.DrawOutlinedRect=function(x,y,w,h) outlines[#outlines+1]={x=x,y=y,w=w,h=h} end
 surface.GetTextSize=function(s) return (utf8.len(s) or 0)*6,12 end
 draw.SimpleText=function(text,_,x,y) labels[#labels+1]={text=text,x=x,y=y} end
end
