-- Synchronous, local SQLite records. Unlike independent JSON files, changes
-- and removals commit together. The old plugin save is retained as a backup.
ix.recordStore = ix.recordStore or {}
local R = ix.recordStore
R.cache = R.cache or {}
local ready = false
local function finite(value) return isnumber(value) and value==value and math.abs(value)<math.huge end
local function keyToken(key) return type(key)..":"..(isnumber(key) and string.format("%.17g",key) or key) end
local function encode(value,seen,depth)
 depth=depth or 0;assert(depth<64,"Record nesting limit")
 if isvector and isvector(value) then assert(finite(value.x) and finite(value.y) and finite(value.z),"Invalid vector");return {t="vector",x=value.x,y=value.y,z=value.z} end
 if isangle and isangle(value) then assert(finite(value.p) and finite(value.y) and finite(value.r),"Invalid angle");return {t="angle",p=value.p,y=value.y,r=value.r} end
 if not istable(value) then
  assert(isstring(value) or type(value)=="boolean" or finite(value),"Unsupported record value")
  return value
 end
 seen=seen or {};assert(not seen[value],"Cyclic record");seen[value]=true
 local keys={};for key in pairs(value) do
  assert(isstring(key) or finite(key),"Unsupported record key");keys[#keys+1]=key
 end
 table.sort(keys,function(a,b) return keyToken(a)<keyToken(b) end)
 local entries={};for _,key in ipairs(keys) do entries[#entries+1]={k=key,v=encode(value[key],seen,depth+1)} end
 seen[value]=nil;return {t="table",v=entries}
end
local function decode(node,depth)
 depth=depth or 0;assert(depth<64,"Record nesting limit")
 if not istable(node) then assert(isstring(node) or type(node)=="boolean" or finite(node),"Invalid record scalar");return node end
 if node.t=="vector" then assert(finite(node.x) and finite(node.y) and finite(node.z),"Invalid vector");return Vector(node.x,node.y,node.z) end
 if node.t=="angle" then assert(finite(node.p) and finite(node.y) and finite(node.r),"Invalid angle");return Angle(node.p,node.y,node.r) end
 assert(node.t=="table" and istable(node.v),"Invalid record encoding")
 local count=0;for key in pairs(node.v) do assert(isnumber(key) and key>=1 and key%1==0,"Invalid record entry index");count=count+1 end
 assert(count==#node.v,"Sparse record encoding")
 local value={};for _,entry in ipairs(node.v) do
  assert(istable(entry) and (isstring(entry.k) or finite(entry.k)) and value[entry.k]==nil,"Duplicate or invalid record key")
  value[entry.k]=decode(entry.v,depth+1)
 end
 return value
end
local function query(statement)
 local result = sql.Query(statement)
 if result == false then return nil, sql.LastError() or "SQLite failure" end
 return result
end
local function scope(namespace)
 assert(isstring(namespace) and #namespace > 0 and #namespace <= 180, "invalid record namespace")
 return engine.ActiveGamemode() .. ":" .. namespace
end
local function ensure()
 if ready then return true end
 local _,err=query("CREATE TABLE IF NOT EXISTS ix_runtime_records (scope TEXT NOT NULL, key TEXT NOT NULL, value TEXT NOT NULL, PRIMARY KEY(scope,key))")
 if err then return false,err end
 ready=true;return true
end
function R.Load(namespace)
 local ok,err=ensure();if not ok then return nil,err end
 local id=scope(namespace)
 R.cache[id]=nil
 local rows,failure=query("SELECT key,value FROM ix_runtime_records WHERE scope="..sql.SQLStr(id))
 if failure then return nil,failure end
 local values,encoded,initialized={},{},false
 for _,row in ipairs(rows or {}) do
  if row.key=="@initialized" then
   if row.value~="1" then return nil,"Invalid record-store commit marker: "..namespace end
   initialized=true
  else
   local ok,value=pcall(function() return decode(util.JSONToTable(row.value,true,true)) end)
   if not ok or not istable(value) then return nil,"Invalid persisted record: "..namespace.."/"..row.key end
   values[row.key]=value;encoded[row.key]=row.value
  end
 end
 -- Rows without their marker cannot come from a committed Save; fail closed.
 if not initialized and next(encoded) then return nil,"Missing record-store commit marker: "..namespace end
 R.cache[id]={encoded=encoded,initialized=initialized}
 if initialized then return values end
end
function R.Save(namespace,records)
 assert(istable(records),"records must be a table")
 local id=scope(namespace)
 if not R.cache[id] then local _,err=R.Load(namespace);if err then return false,err end end
 local previous=R.cache[id];local encoded,changes={},{}
 for key,value in pairs(records) do
  if not isstring(key) or key=="@initialized" or key:find("%z") or not istable(value) then return false,"Invalid record key or value" end
  local ok,payload=pcall(function() return util.TableToJSON(encode(value)) end)
  if not ok or not isstring(payload) then return false,"Record encoding failed: "..key end
  encoded[key]=payload
  if previous.encoded[key]~=payload then changes[#changes+1]={key=key,value=payload} end
 end
 for key in pairs(previous.encoded) do if encoded[key]==nil then changes[#changes+1]={key=key} end end
 if previous.initialized and #changes==0 then return true,0 end
 -- Own the transaction so success really means COMMIT. A nested call inside
 -- someone else's transaction fails rather than caching uncommitted values.
 local _,err=query("BEGIN IMMEDIATE")
 if err then return false,err end
 local function abort(failure)
  query("ROLLBACK")
  return false,failure
 end
 for _,change in ipairs(changes) do
  local statement=change.value and ("INSERT OR REPLACE INTO ix_runtime_records (scope,key,value) VALUES ("..sql.SQLStr(id)..","..sql.SQLStr(change.key)..","..sql.SQLStr(change.value)..")")
   or ("DELETE FROM ix_runtime_records WHERE scope="..sql.SQLStr(id).." AND key="..sql.SQLStr(change.key))
  local _,failure=query(statement);if failure then return abort(failure) end
 end
 if not previous.initialized then
  local _,failure=query("INSERT OR REPLACE INTO ix_runtime_records (scope,key,value) VALUES ("..sql.SQLStr(id)..",'@initialized','1')")
  if failure then return abort(failure) end
 end
 local _,failure=query("COMMIT");if failure then return abort(failure) end
 R.cache[id]={encoded=encoded,initialized=true}
 return true,#changes
end
-- Split large plugin stores by top-level collection entry, preserving arrays,
-- numeric IDs, empty collections and metadata without lossy key conversion.
function R.Split(store)
 local records={root={values={},collections={}}}
 for field,value in pairs(store) do
  assert(isstring(field),"Record collection names must be strings")
  if istable(value) then
   records.root.collections[field]=true
   for key,entry in pairs(value) do
    records[field.."/"..keyToken(key)]={collection=field,key=key,value=entry}
   end
  else records.root.values[field]=value end
 end
 return records
end
function R.Join(records)
 if not istable(records.root) or not istable(records.root.values) or not istable(records.root.collections) then return nil,"Invalid record root" end
 local store={}
 for key,value in pairs(records.root.values) do
  if not isstring(key) or istable(value) then return nil,"Invalid root metadata" end
  store[key]=value
 end
 for key,enabled in pairs(records.root.collections) do
  if not isstring(key) or enabled~=true or store[key]~=nil then return nil,"Invalid collection metadata" end
  store[key]={}
 end
 for key,row in pairs(records) do
  if key~="root" then
   if not istable(row) or not isstring(row.collection) or not istable(store[row.collection]) or (not isstring(row.key) and not finite(row.key)) or row.value==nil
    or key~=row.collection.."/"..keyToken(row.key) or store[row.collection][row.key]~=nil then return nil,"Invalid collection record: "..key end
   store[row.collection][row.key]=row.value
  end
 end
 return store
end
