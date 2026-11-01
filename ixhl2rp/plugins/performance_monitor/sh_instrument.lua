local P=ix.performance
local unpack=unpack or table.unpack
local function pack(...) return {n=select('#',...),...} end
local function row(c,group,name)
 local collection=c[group];local r=collection[name]
 if not r then
  if c.labels>=2048 then name="[other]";r=collection[name] end
  if not r then r={calls=0,totalMs=0,maxMs=0};collection[name]=r;c.labels=c.labels+1 end
 end
 return r
end
local function time(c,group,name,elapsed)
 local r=row(c,group,name);r.calls=r.calls+1;r.totalMs=r.totalMs+elapsed;r.maxMs=math.max(r.maxMs,elapsed);return r
end
function P.InstallInstrumentation(c)
 c.timings={};c.network={};c.database={};c.labels=0;c.restores={};c.stack={}
 local originals=setmetatable({}, {__mode="k"})
 local function replace(target,key,wrapper)
  local original=target[key];target[key]=wrapper
  c.restores[#c.restores+1]=function() if target[key]==wrapper then target[key]=original end end
 end
 local function measured(original,name)
  return function(...)
   if P.capture~=c then return original(...) end
   local frame={started=SysTime(),children=0};local stack=c.stack;stack[#stack+1]=frame
   local values=pack(pcall(original,...))
   local elapsed=(SysTime()-frame.started)*1000
   stack[#stack]=nil
   if stack[#stack] then stack[#stack].children=stack[#stack].children+elapsed end
   local r=time(c,"timings",name,elapsed);r.selfMs=(r.selfMs or 0)+math.max(0,elapsed-frame.children)
   if not values[1] then r.errors=(r.errors or 0)+1;error(values[2],0) end
   return unpack(values,2,values.n)
  end
 end
 -- Wrap both live methods and the Helix hook cache: the latter stores a
 -- separate function reference. Retain later replacements on restoration.
 for id,plugin in pairs(ix.plugin and ix.plugin.list or {}) do
  if id~="performance_monitor" then
   originals[plugin]={}
   for key,fn in pairs(plugin) do
    if isfunction(fn) and key~="SetData" and key~="GetData" then
     local wrapper=measured(fn,"plugin:"..id..":"..tostring(key))
     originals[plugin][fn]=wrapper;replace(plugin,key,wrapper)
    end
   end
  end
 end
 for name,cache in pairs(HOOKS_CACHE or {}) do
  for owner,fn in pairs(cache) do if originals[owner] and originals[owner][fn] then replace(cache,owner,originals[owner][fn]) end end
 end
 if hook.GetTable then
  for event,callbacks in pairs(hook.GetTable()) do
   for id,fn in pairs(callbacks) do
    local label=isstring(id) and id or ("["..type(id).."]")
    if isfunction(fn) and not label:find("ixPerformance",1,true) then replace(callbacks,id,measured(fn,"hook:"..event..":"..label)) end
   end
  end
 end
 for name,fn in pairs(net.Receivers or {}) do
  if isfunction(fn) then replace(net.Receivers,name,measured(fn,"receive:"..name)) end
 end
 -- Existing scheduled jobs are public entries, so no undocumented timer API
 -- or timer monkey-patching is necessary. Closed-over timer work is counted
 -- only when it enters a wrapped plugin method.
 for id,job in pairs(ix.runtime and ix.runtime.jobs or {}) do
  if isfunction(job.callback) then replace(job,"callback",measured(job.callback,"job:"..id)) end
 end
 local message
 if net.Start and net.BytesWritten then
  local original=net.Start
  replace(net,"Start",function(name,...)
   local result=pack(original(name,...));message=tostring(name);return unpack(result,1,result.n)
  end)
  if net.Abort then
   local originalAbort=net.Abort
   replace(net,"Abort",function(...) message=nil;return originalAbort(...) end)
  end
  local function humans() return player.GetHumans and player.GetHumans() or player.GetAll() end
  local function recipients(value)
   if value==nil then return nil end
   if isentity and isentity(value) then return IsValid(value) and 1 or 0 end
   if istable(value) and not value.GetPlayers then
    if value.IsPlayer then return IsValid(value) and 1 or 0 end
    local count,seen=0,{};for _,p in pairs(value) do if IsValid(p) and not seen[p] then seen[p]=true;count=count+1 end end;return count
   end
   if value.GetPlayers then return #value:GetPlayers() end
   return IsValid(value) and 1 or 0
  end
  for _,method in ipairs({"Send","Broadcast","SendOmit","SendPVS","SendPAS","SendToServer"}) do
   if net[method] then
    local originalSend=net[method]
    replace(net,method,function(...)
     local target=select(1,...)
     local name=message or "[unknown]";local bytes=net.BytesWritten() or 0;local count
     if method=="Broadcast" then count=#humans()
     elseif method=="SendToServer" then count=1
     elseif method=="SendOmit" then count=math.max(0,#humans()-(recipients(target) or 0))
     elseif method=="Send" then count=recipients(target) end
     message=nil;local result=pack(originalSend(...))
     if P.capture==c then
      local r=row(c,"network",name);r.calls=r.calls+1;r.bytes=(r.bytes or 0)+bytes;r.maxBytes=math.max(r.maxBytes or 0,bytes)
      if count then r.recipients=(r.recipients or 0)+count;r.recipientBytes=(r.recipientBytes or 0)+bytes*count
      else r.unknownRecipientCalls=(r.unknownRecipientCalls or 0)+1 end
     end
     return unpack(result,1,result.n)
    end)
   end
  end
 end
 local function kind(statement) return isstring(statement) and (statement:match("^%s*(%a+)") or "OTHER"):upper() or "OTHER" end
 if SERVER and sql and sql.Query then
  local original=sql.Query
  replace(sql,"Query",function(statement,...)
   local start=SysTime();local result=pack(original(statement,...))
   if P.capture==c then local r=time(c,"database","sqlite:"..kind(statement),(SysTime()-start)*1000);if result[1]==false then r.errors=(r.errors or 0)+1 end end
   return unpack(result,1,result.n)
  end)
 end
 if SERVER and mysql and mysql.RawQuery then
  local original=mysql.RawQuery
  replace(mysql,"RawQuery",function(self,statement,callback,...)
   if P.capture~=c then return original(self,statement,callback,...) end
   local start=SysTime();local name=tostring(self.module)..":"..kind(statement)
   local r=row(c,"database","issue:"..name);r.calls=r.calls+1
   -- Install a completion observer even without a user callback. Errors in
   -- the existing MySQL adapter do not invoke callbacks: they remain pending.
   r.pending=(r.pending or 0)+1
   local completion=function(...)
    if P.capture==c then
     r.pending=math.max(0,r.pending-1)
     time(c,"database","completion:"..name,(SysTime()-start)*1000)
    end
    if callback then return callback(...) end
   end
   -- SQLite's adapter queries last_insert_rowid only when a callback exists;
   -- do not introduce that extra query for fire-and-forget synchronous work.
   local observed=(callback or self.module=="mysqloo") and completion or nil
   local result=pack(pcall(original,self,statement,observed,...))
   local elapsed=(SysTime()-start)*1000;r.totalMs=r.totalMs+elapsed;r.maxMs=math.max(r.maxMs,elapsed)
   if not result[1] then r.errors=(r.errors or 0)+1;r.pending=math.max(0,r.pending-1);error(result[2],0) end
   if not observed then completion() end
   return unpack(result,2,result.n)
  end)
 end
end
function P.RemoveInstrumentation(c)
 for i=#(c.restores or {}),1,-1 do c.restores[i]() end
 c.restores=nil
end
