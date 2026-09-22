local F=ix.Fieldlink
local nextSound={}
function F.Sound(name)
 local delays={hover=.12,click=.07,boot=1,sleep=.3,success=.2,error=.4,register=.5}
 if not delays[name] or RealTime()<(nextSound[name] or 0) then return end
 nextSound[name]=RealTime()+delays[name]
 surface.PlaySound("fieldlink/ui/"..name..".wav")
end
