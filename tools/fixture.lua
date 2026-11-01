SERVER=true
CLIENT=false
clock=10
function CurTime() return clock end
function RealTime() return clock end
function isnumber(v) return type(v)=='number' end
function istable(v) return type(v)=='table' end
function isstring(v) return type(v)=='string' end
function isfunction(v) return type(v)=='function' end
function IsValid(v) return type(v)=='table' and v.valid==true end
function math.Clamp(v,a,b) return math.max(a,math.min(b,v)) end
function math.Round(v) return math.floor(v+0.5) end
function table.Copy(t) local r={} for k,v in pairs(t) do r[k]=type(v)=='table' and table.Copy(v) or v end return r end
function table.GetKeys(t) local r={} for k in pairs(t) do r[#r+1]=k end return r end
function string.Trim(s) return s:match('^%s*(.-)%s*$') end
-- Fixtures below use ASCII task strings. Real UTF-8 slicing is separately
-- exercised by loading the project's string library in engine smoke tests.
string.utf8sub=string.sub
function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
function near(a,b) assert(math.abs(a-b)<0.00001,tostring(a)..' ~= '..tostring(b)) end
hook={Run=function() end}
util={AddNetworkString=function() end}
timer={Simple=function(_,fn) fn() end,Create=function() end,Remove=function() end}
net={handlers={}}
function net.Receive(name,fn) net.handlers[name]=fn end
function net.ReadInt() return net.amount end
function net.ReadTable() return net.payload end
netstream={handlers={},Start=function() end}
function netstream.Hook(name,fn) netstream.handlers[name]=fn end
player={GetAll=function() return allPlayers or {} end}
ents={FindInSphere=function() return nearby or {} end,FindByClass=function() return {} end}
PLUGIN={maxLevel=100,limits={title=120,summary=300,details=2000,reward=120},useRadius=140,maxOpenPerChar=3}
function PLUGIN:GetRequiredLevelXP(level) return level<100 and 100 or 0 end
function PLUGIN:GetPointsAtLevel(level) return 2 end
ix={meta={character={}},chat={Send=function() end},specials={list={st={},en={}},Setup=function() end},
 skills={list={}}, log={AddType=function() end}, City={stored={}}, plugin={list={}},config={Get=function() return 1 end}}
function ix.plugin.Get(id)
 if id=='blackout' then return {IsEntityBlackedOut=function() return blackoutOn end} end
 return ix.plugin.list[id]
end
function class(name)
 local c={}; c.__index=c
 function c:New(...) local obj=setmetatable({},c); if obj.Init then obj:Init(...) end return obj end
 ix.meta[name]=c; return c
end
local PLAYER={}
function FindMetaTable() return PLAYER end
function character(level,xp,points)
 local c=setmetatable({level=level,xp=xp,points=points,id=1,specials={},data={}}, {__index=ix.meta.character})
 local p={valid=true,GetCharacter=function() return c end,IsDonator=function(self) return self.donor end,
 Alive=function() return true end, GetPos=function() return {} end,IsAdmin=function() return false end,
 IsSuperAdmin=function() return false end, Notify=function() end}
 c.player=p
 function c:GetLevel() return self.level end
 function c:SetLevel(v) self.level=v end
 function c:GetLevelXP() return self.xp end
 function c:SetLevelXP(v) self.xp=v end
 function c:GetSkillPoints() return self.points end
 function c:SetSkillPoints(v) self.points=v end
 function c:GetPlayer() return self.player end
 function c:SetData(k,v) self.data[k]=v end
 function c:GetData(k,d) return self.data[k] or d end
 function c:GetSpecials() return self.specials end
 function c:SetSpecials(v) self.specials=v end
 function c:GetPrimaryStat(k) return k=='st' end
 function c:GetID() return self.id end
 function c:GetName() return 'Citizen' end
 return c
end
