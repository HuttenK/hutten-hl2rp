local F=ix.Fieldlink
F.photoLimit=12
F.photoBytes=131072
F.photoChunk=48000
-- Inspect JPEG dimensions before accepting or decoding client-supplied bytes.
function F.PhotoJPEG(bytes)
 if not isstring(bytes) or #bytes<12 or #bytes>F.photoBytes or bytes:sub(1,2)~="\255\216" or bytes:sub(-2)~="\255\217" then return false end
 local i=3
 local function word(at) local a,b=bytes:byte(at,at+1); return a and b and a*256+b end
 while i<#bytes do
  if bytes:byte(i)~=255 then return false end
  while bytes:byte(i)==255 do i=i+1 end
  local marker=bytes:byte(i); i=i+1
  if marker==218 or marker==217 then return false end
  local length=word(i)
  if not length or length<2 or i+length-1>#bytes then return false end
  if marker==192 or marker==194 then
   return length>=8 and word(i+3)==360 and word(i+5)==640
  end
  i=i+length
 end
 return false
end
