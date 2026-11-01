local P=PLUGIN
ix.runtime=ix.runtime or {}
local R=ix.runtime
R.jobs=R.jobs or {};R.order=R.order or {};R.cursor=R.cursor or 0
R.active=true
local function phase(id)
 local hash=0
 for i=1,#id do hash=(hash*31+id:byte(i))%1009 end
 return (hash+1)/1010
end
-- Noncritical maintenance only. Return false to continue a bounded slice on
-- the next frame. Critical saves and gameplay validation must call directly.
function R.Schedule(id,interval,callback,options)
 assert(isstring(id) and isfunction(callback) and interval>0,"invalid maintenance task")
 options=options or {}
 if not R.jobs[id] then R.order[#R.order+1]=id end
 R.jobs[id]={id=id,interval=interval,callback=callback,due=CurTime()+(options.delay or interval*phase(id))}
end
function R.Cancel(id)
 R.jobs[id]=nil
 for i=#R.order,1,-1 do if R.order[i]==id then table.remove(R.order,i);if i<=R.cursor then R.cursor=math.max(0,R.cursor-1) end end end
end
function R.Step()
 local count=#R.order;if count==0 then return end
 local started,now,visited,ran=SysTime(),CurTime(),0,0
 while visited<count and #R.order>0 do
  R.cursor=R.cursor%#R.order+1;local id=R.order[R.cursor];local job=R.jobs[id]
  visited=visited+1
  if job and now>=job.due then
   ran=ran+1
   local ok,complete=xpcall(job.callback,debug.traceback)
   if R.jobs[id]==job then job.due=now+((ok and complete==false) and 0 or job.interval) end
   if not ok then
    job.due=now+math.max(job.interval,5)
    if now>=(job.nextError or 0) then job.nextError=now+30;ErrorNoHalt("[Runtime maintenance] "..id..": "..tostring(complete).."\n") end
   end
   -- At least one job progresses under pressure; round-robin cursor prevents
   -- a yielding task from starving other jobs. No missed-interval catch-up.
   if ran>=8 or SysTime()-started>=.0015 then break end
  end
 end
end
hook.Add("Think","ixRuntimeMaintenance",R.Step)
function P:OnUnload()
 R.active=false;R.jobs={};R.order={};R.cursor=0
 hook.Remove("Think","ixRuntimeMaintenance")
 if self.RestoreAdapters then self:RestoreAdapters() end
end
