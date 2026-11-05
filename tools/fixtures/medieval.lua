SERVER=true CLIENT=false clock=10
function CurTime() return clock end
function RealTime() return clock end
function IsValid(v) return type(v)=='table' and v.valid==true end
function istable(v) return type(v)=='table' end
function isnumber(v) return type(v)=='number' end
function isstring(v) return type(v)=='string' end
function isfunction(v) return type(v)=='function' end
function eq(a,b) assert(a==b,tostring(a)..' ~= '..tostring(b)) end
function near(a,b) assert(math.abs(a-b)<.00001,tostring(a)..' ~= '..tostring(b)) end
function math.Clamp(n,a,b) return math.max(a,math.min(n,b)) end
function math.Round(n) return math.floor(n+.5) end
function table.Copy(t) local out={} for k,v in pairs(t) do out[k]=type(v)=='table' and table.Copy(v) or v end return out end
function table.Count(t) local n=0 for _ in pairs(t) do n=n+1 end return n end
function SortedPairs(t) local keys={} for k in pairs(t) do keys[#keys+1]=k end table.sort(keys) local i=0 return function() i=i+1 local k=keys[i] if k then return k,t[k] end end end
hook={handlers={}}
function hook.Add(event,id,fn) hook.handlers[event]=hook.handlers[event] or {};hook.handlers[event][id]=fn end
function hook.Remove(event,id) if hook.handlers[event] then hook.handlers[event][id]=nil end end
function hook.Run(event,...) for _,fn in pairs(hook.handlers[event] or {}) do local a,b=fn(...) if a~=nil then return a,b end end end
timer={Simple=function(_,fn) fn() end,Create=function() end,Remove=function() end}
net={handlers={}};function net.Receive(name,fn) net.handlers[name]=fn end
for _,name in ipairs({'Start','Send','WriteUInt','WriteInt','WriteBool','WriteString','WriteFloat'}) do net[name]=function() end end
util={AddNetworkString=function() end}
resource={AddFile=function() end}
player={GetAll=function() return {} end}
PLUGIN={}
ix={meta={},config={Get=function(_,d) return d end},util={Include=function() end},plugin={list={}}}
function ix.plugin.Get(id) return ix.plugin.list[id] end
local playerMeta={}
function FindMetaTable() return playerMeta end
function class(name) local c={};c.__index=c;function c:New(...) local o=setmetatable({},c);if o.Init then o:Init(...) end return o end ix.meta[name]=c;return c end
