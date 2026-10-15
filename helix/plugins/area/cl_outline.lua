-- Cache the true boundary of a union of boxes. Four occupied quadrants around
-- an axis-aligned line identify corners; two adjacent quadrants are a flat
-- face, so touching/overlapping volumes never leave a seam on that face.
local cached = setmetatable({}, {__mode="k"})
local axes = {"x", "y", "z"}

function ix.area.GetOutline(info)
 local old = cached[info]
 if old and old.source == info.volumes and old.revision == info.volumeRevision
  and old.low == info.startPosition and old.high == info.endPosition then return old.lines end
 local boxes = ix.area.GetVolumes(info)
 local coordinates, indices, lengths = {}, {}, {}
 for axis, name in ipairs(axes) do
  local values, lookup = {}, {}
  for _, box in ipairs(boxes) do lookup[box.min[name]], lookup[box.max[name]] = true, true end
  for value in pairs(lookup) do values[#values+1] = value end
  table.sort(values)
  for index, value in ipairs(values) do lookup[value] = index end
  coordinates[axis], indices[axis], lengths[axis] = values, lookup, #values-1
 end
 local nx, ny, nz = lengths[1], lengths[2], lengths[3]
 local cells = {}
 local function key(x,y,z) return x + nx*((y-1)+ny*(z-1)) end
 for _, box in ipairs(boxes) do
  for z=indices[3][box.min.z],indices[3][box.max.z]-1 do
   for y=indices[2][box.min.y],indices[2][box.max.y]-1 do
    for x=indices[1][box.min.x],indices[1][box.max.x]-1 do cells[key(x,y,z)] = true end
   end
  end
 end
 local function occupied(x,y,z)
  return x>=1 and y>=1 and z>=1 and x<=nx and y<=ny and z<=nz and cells[key(x,y,z)] or false
 end
 local lines = {}
 for a=1,3 do
  local b, c = a%3+1, (a+1)%3+1
  local function sample(i,j,k)
   if a==1 then return occupied(i,j,k) end
   if a==2 then return occupied(k,i,j) end
   return occupied(j,k,i)
  end
  local function point(i,j,k)
   local p = Vector()
   p[axes[a]], p[axes[b]], p[axes[c]] = coordinates[a][i], coordinates[b][j], coordinates[c][k]
   return p
  end
  for j=1,lengths[b]+1 do
   for k=1,lengths[c]+1 do
    local start
    for i=1,lengths[a]+1 do
     local edge = false
     if i<=lengths[a] then
      local q1,q2,q3,q4 = sample(i,j-1,k-1),sample(i,j,k-1),sample(i,j-1,k),sample(i,j,k)
      local count = (q1 and 1 or 0)+(q2 and 1 or 0)+(q3 and 1 or 0)+(q4 and 1 or 0)
      edge = count==1 or count==3 or (count==2 and q1==q4)
     end
     if edge and not start then start = i end
     if not edge and start then lines[#lines+1] = {point(start,j,k), point(i,j,k)}; start = nil end
    end
   end
  end
 end
 cached[info] = {source=info.volumes, revision=info.volumeRevision,
  low=info.startPosition, high=info.endPosition, lines=lines}
 return lines
end
