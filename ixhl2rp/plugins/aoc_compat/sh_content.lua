-- The old SD/Prone bridge and DynaBase both supply m_anm/f_anm. When the
-- former wins, DynaBase's registry exists but its AoC sequences are unreachable.
-- Mount an additive cache only for our known Cellar bridge; never write into
-- an addon or replace meshes, animation data, ANI blocks or existing includes.
local A = ix.AOC
local donor = "models/player/aoc_male_anims.mdl"

local function U32(n)
 return string.char(n % 256, math.floor(n / 256) % 256, math.floor(n / 65536) % 256, math.floor(n / 16777216) % 256)
end
local function Read32(bytes, offset)
 if offset < 0 or offset + 4 > #bytes then return end
 local a, b, c, d = bytes:byte(offset + 1, offset + 4)
 return a + b * 256 + c * 65536 + d * 16777216
end
local function CString(bytes, offset)
 if offset < 0 or offset >= #bytes then return end
 local finish = bytes:find("\0", offset + 1, true)
 if not finish or finish - offset > 260 then return end
 return bytes:sub(offset + 1, finish - 1)
end
local function Replace32(bytes, offset, value)
 return bytes:sub(1, offset) .. U32(value) .. bytes:sub(offset + 5)
end

function A.BridgeModel(bytes)
 if not isstring(bytes) or #bytes < 408 or #bytes > 8388608 or bytes:sub(1, 4) ~= "IDST" then return end
 local version = Read32(bytes, 4)
 if (version ~= 48 and version ~= 49) or Read32(bytes, 76) ~= #bytes then return end
 local count, offset = Read32(bytes, 336), Read32(bytes, 340)
 if count > 64 or offset + count * 8 > #bytes then return end
 local includes, ours = {}, false
 for index = 0, count - 1 do
  local base = offset + index * 8
  local name = CString(bytes, base + Read32(bytes, base + 4))
  local label = CString(bytes, base + Read32(bytes, base))
  if not name or not label then return end
  if name:lower() == donor then return end
  if name:lower():find("^models/ix_cellar/") then ours = true end
  includes[#includes + 1] = {label, name}
 end
 if not ours then return end -- Stock, arbitrary third-party and DynaBase roots are left alone.
 includes[#includes + 1] = {"ix_aoc", donor}
 local start = math.ceil(#bytes / 4) * 4
 local cursor, entries, strings = start + #includes * 8, {}, {}
 for index, entry in ipairs(includes) do
  local base = start + (index - 1) * 8
  for _, value in ipairs(entry) do
   entries[#entries + 1] = U32(cursor - base)
   strings[#strings + 1] = value .. "\0"
   cursor = cursor + #value + 1
  end
 end
 local result = bytes .. string.rep("\0", start - #bytes) .. table.concat(entries) .. table.concat(strings)
 result = Replace32(result, 76, #result)
 result = Replace32(result, 336, #includes)
 return Replace32(result, 340, start)
end

function A.BridgeArchive(entries)
 -- GMAD v3: an index followed by unchanged file payloads and a whole-file CRC.
 local chunks = {"GMAD", string.char(3), string.rep("\0", 16), "\0",
  "Medieval AoC compatibility cache\0", '{"type":"model","tags":[]}\0', "Hutten\0", U32(1)}
 for index, entry in ipairs(entries) do
  chunks[#chunks + 1] = U32(index) .. entry.name .. "\0" .. U32(#entry.bytes) .. U32(0) .. U32(tonumber(util.CRC(entry.bytes)))
 end
 chunks[#chunks + 1] = U32(0)
 for _, entry in ipairs(entries) do chunks[#chunks + 1] = entry.bytes end
 local archive = table.concat(chunks)
 return archive .. U32(tonumber(util.CRC(archive)))
end

function A.MountBridge()
 if A.contentMounted then return end
 if not file.Exists(donor, "GAME") then A.contentStatus = "AoC animation extension is missing" return end
 if not game.MountGMA then A.contentStatus = "runtime content mounting unavailable" return end
 local entries = {}
 for _, name in ipairs({"m_anm", "f_anm", "z_anm", "humans/male_postures", "humans/female_postures",
  "police_ss", "combine_soldier_anims"}) do
  name = "models/" .. name .. ".mdl"
  local bytes = A.BridgeModel(file.Read(name, "GAME"))
  if bytes then entries[#entries + 1] = {name = name, bytes = bytes} end
 end
 if #entries == 0 then A.contentStatus = "no legacy Cellar roots require bridging" return end
 local archive = A.BridgeArchive(entries)
 local destination = "ix_aoc/bridge_v1_" .. util.CRC(archive) .. ".dat"
 file.CreateDir("ix_aoc")
 if file.Read(destination, "DATA") ~= archive then file.Write(destination, archive) end
 local success = game.MountGMA("data/" .. destination)
 if not success then A.contentStatus = "compatibility cache failed to mount" return end
 -- Validate search-path precedence instead of claiming success from MountGMA.
 for _, entry in ipairs(entries) do
  if file.Read(entry.name, "GAME") ~= entry.bytes then
   A.contentStatus = "another mounted model overrides the compatibility cache"
   ErrorNoHalt("[AoC/Helix] " .. A.contentStatus .. ": " .. entry.name .. "\n")
   return
  end
 end
 A.contentMounted = true
 A.contentStatus = "legacy Cellar bridge: " .. #entries .. " additive roots mounted"
 print("[AoC/Helix] " .. A.contentStatus)
end

-- Run during schema load, before DynaBase's CreateTeams cache refresh and
-- player spawning. Do not flush live player models from a per-frame hook.
A.MountBridge()
