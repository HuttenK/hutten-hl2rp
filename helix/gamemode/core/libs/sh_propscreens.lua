-- Per-screen membership prevents a recycled entity index from inheriting an
-- overlay. Keep the old primary ID for integrations which only need a host flag.
ix.PropScreens=ix.PropScreens or {}
local S=ix.PropScreens
local function chunkKey(key,index) return key.."s"..(index==1 and "" or index) end
function S.IDs(ent,key)
 local ids={};if not IsValid(ent) then return ids end
 local raw=ent:GetNW2String(key.."s","")
 if raw~="" then
  for index=1,math.max(1,ent:GetNW2Int(key.."Chunks",1)) do
   for id in ent:GetNW2String(chunkKey(key,index),""):gmatch("%d+") do ids[tonumber(id)]=true end
  end
 else local id=ent:GetNW2Int(key,0);if id>0 then ids[id]=true end end
 return ids
end
local function write(ent,key,ids)
 local list={};for id in pairs(ids) do list[#list+1]=id end;table.sort(list)
 -- NW2 strings hold at most 511 bytes. Split on whole IDs so even the global
 -- screen quota can fit on one host without losing membership on the client.
 local chunks={};local value=","
 for _,id in ipairs(list) do
  local token=id..","
  if #value+#token>480 then chunks[#chunks+1]=value;value="," end
  value=value..token
 end
 chunks[#chunks+1]=value
 local previous=ent:GetNW2Int(key.."Chunks",1)
 for index,chunk in ipairs(chunks) do ent:SetNW2String(chunkKey(key,index),chunk) end
 for index=#chunks+1,previous do ent:SetNW2String(chunkKey(key,index),"") end
 ent:SetNW2Int(key.."Chunks",#chunks);ent:SetNW2Int(key,list[1] or 0)
end
function S.Bind(ent,key,id)
 if not IsValid(ent) then return end
 local ids=S.IDs(ent,key);ids[id]=true;write(ent,key,ids)
end
function S.Unbind(ent,key,id)
 if not IsValid(ent) then return end
 local ids=S.IDs(ent,key);ids[id]=nil;write(ent,key,ids)
end
function S.Has(ent,key,id)
 if not IsValid(ent) then return false end
 local raw=ent:GetNW2String(key.."s","")
 if raw~="" then
  for index=1,math.max(1,ent:GetNW2Int(key.."Chunks",1)) do
   if ent:GetNW2String(chunkKey(key,index),""):find(","..id..",",1,true) then return true end
  end
  return false
 end
 return ent:GetNW2Int(key,0)==id
end
function S.Occupied(ent)
 for _,key in ipairs({"ixCCTVSurfaceID","ixTVScreenID","ixFacilityPanelID"}) do
  if IsValid(ent) and ent:GetNW2Int(key,0)>0 then return true end
 end
 return false
end
-- Resolve one physical screen across all overlay types. A single E press must
-- not open a terminal and toggle the TV behind it, regardless of hook order.
function S.Aim(p,limit)
 local best,depth=nil,(limit or 220)^2
 local function consider(kind,row,hit)
  if not row or not hit then return end
  local distance=hit:DistToSqr(p:GetShootPos())
  if distance<depth then best={kind=kind,row=row,hit=hit};depth=distance end
 end
 local c=ix.plugin.list.cctv
 if c and c.devices and ix.CCTV and ix.CCTV.AimTerminal then
  local row,hit=ix.CCTV.AimTerminal(p,c.devices);consider("cctv",row,hit)
 end
 local t=ix.plugin.list.tv_screen
 if t and t.screens and ix.TV and ix.TV.AimScreen then
  local row,hit=ix.TV.AimScreen(p,t.screens,limit);consider("tv",row,hit)
 end
 local f=ix.plugin.list.facility_utilities
 if f and f.AimPanel then local row,hit=f:AimPanel(p,limit);consider("panel",row,hit) end
 return best
end
