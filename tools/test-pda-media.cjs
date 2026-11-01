module.exports=function(suite){
suite('PDA photo validation rejects malformed headers, oversized payloads and wrong dimensions',
 ['ixhl2rp/plugins/site_pda/sh_media.lua'],`
 local function jpeg(w,h)
  return string.char(255,216,255,192,0,17,8,math.floor(h/256),h%256,math.floor(w/256),w%256,3,1,17,0,2,17,0,3,17,0,255,217)
 end
 eq(ix.Fieldlink.PhotoJPEG(jpeg(640,360)),true)
 eq(ix.Fieldlink.PhotoJPEG(jpeg(1920,1080)),false)
 eq(ix.Fieldlink.PhotoJPEG('not a jpeg'),false)
 eq(ix.Fieldlink.PhotoJPEG(string.rep('x',131073)),false)
 eq(ix.Fieldlink.PhotoJPEG(jpeg(640,360):sub(1,-3)),false)
 eq(ix.Fieldlink.PhotoJPEG(string.char(255,216,255,224,0,0)..string.rep('x',10)..string.char(255,217)),false)
 `,`ix.Fieldlink={}`);
suite('PDA media validates uploads, transfers devices, delivers offline messages and retains shared photos',
 ['ixhl2rp/plugins/site_pda/sh_media.lua','ixhl2rp/plugins/site_pda/sv_media.lua'],`
 local F=ix.Fieldlink
 local a,b,c=device(101,'Alice'),device(202,'Bob'),device(303,'Other')
 local p=user(a,1); local q=user(b,2); local stranger=user(c,3)
 PLUGIN:MediaDevice(a); PLUGIN:MediaDevice(b); PLUGIN:MediaDevice(c)
 local bytes=string.char(255,216,255,192,0,17,8,1,104,2,128,3,1,17,0,2,17,0,3,17,0,255,217)
 eq(PLUGIN:PhotoChunk(p,999,#bytes,0,bytes),false)
 eq(PLUGIN:PhotoChunk(p,101,#bytes,5,bytes:sub(6)),false)
 eq(PLUGIN:PhotoChunk(p,101,#bytes,0,bytes:sub(1,10)),true)
 eq(PLUGIN:PhotoChunk(p,101,#bytes,11,bytes:sub(12)),false)
 eq(PLUGIN:PhotoChunk(p,101,#bytes,10,bytes:sub(11)),true)
 local id=string.rep('a',64); local ad=PLUGIN:MediaDevice(a); local bd=PLUGIN:MediaDevice(b)
 eq(#ad.photos,1); eq(PLUGIN:PhotoAccess(ad,id),true); eq(PLUGIN:PhotoAccess(bd,id),false)
 eq(PLUGIN:MediaAction(stranger,'photo',{device=303,id=id}),false)
 eq(PLUGIN:MediaAction(p,'message',{device=999,target=202,text='stale'}),false)
 eq(PLUGIN:MediaAction(p,'message',{device=101,target=404,text='unknown'}),false)
 eq(PLUGIN:MediaAction(p,'message',{device=101,target=202,text='Look',photo=id}),true)
 eq(#bd.messages,1); eq(bd.messages[1].name,'Alice'); eq(PLUGIN:PhotoAccess(bd,id),true)
 eq(PLUGIN:MediaAction(p,'message',{device=101,target=202,text='spam'}),false)
 eq(PLUGIN:MediaAction(p,'deletePhoto',{device=101,id=id}),true)
 assert(files['fieldlink_media/'..id..'.jpg']); eq(#ad.photos,0)
 -- The sender copy and recipient copy independently retain attachment access.
 local messageID=bd.messages[1].id
 eq(PLUGIN:MediaAction(p,'deleteMessage',{device=101,id=messageID}),true)
 eq(PLUGIN:PhotoAccess(ad,id),false); eq(PLUGIN:PhotoAccess(bd,id),true)
 local thief=user(b,99); q.item=nil
 local snapshot={device=202}; PLUGIN:MediaSnapshot(thief,snapshot)
 eq(snapshot.messages[1].text,'Look'); eq(snapshot.messages[1].name,'Alice')
 eq(PLUGIN:MediaAction(q,'photo',{device=202,id=id}),false)
 eq(PLUGIN:MediaAction(thief,'photo',{device=202,id=id}),true); assert(sent>0)
 eq(PLUGIN:MediaAction(thief,'savePhoto',{device=202,id=id}),true)
 eq(PLUGIN:MediaAction(thief,'savePhoto',{device=202,id=id}),false)
 eq(PLUGIN:MediaAction(thief,'deleteMessage',{device=202,id=messageID}),true)
 assert(files['fieldlink_media/'..id..'.jpg'])
 eq(PLUGIN:MediaAction(thief,'deletePhoto',{device=202,id=id}),true)
 eq(files['fieldlink_media/'..id..'.jpg'],nil); eq(PLUGIN.media.photos[id],nil)
 clock=clock+5; eq(PLUGIN:PhotoChunk(p,101,#bytes,0,bytes:sub(1,10)),true)
 p.charid=8; eq(PLUGIN:PhotoChunk(p,101,#bytes,10,bytes:sub(11)),false)
 clock=clock+5; eq(PLUGIN:PhotoChunk(p,101,#bytes,0,bytes:sub(1,10)),true)
 clock=clock+16; eq(PLUGIN:PhotoChunk(p,101,#bytes,10,bytes:sub(11)),false)
 for i=1,F.photoLimit do ad.photos[i]=id end
 clock=clock+5; eq(PLUGIN:PhotoChunk(p,101,#bytes,0,bytes),false)
 assert(files['fieldlink_media/index.json'])
 -- Recognition uses the traced person's equipped card only; never their character name.
 p.EyePos=function() return 0 end; p.EyeAngles=function() return {Forward=function() return 1 end} end
 local visible={valid=true,IsPlayer=function() return true end,Alive=function() return true end,
  GetCharacter=function() return {} end,GetInventory=function() return {GetItems=function() return {{name='Borrowed CID',cid='54321',serial='card-9',secret='never'}} end} end}
 F.CardIdentity=function(card) return card end
 util.TraceLine=function(args) eq(args.endpos,256); eq(args.filter,p); return {Entity=visible} end
 local info=PLUGIN:ScanIdentity(p); eq(info.name,'Borrowed CID'); eq(info.secret,nil)
 visible=nil; eq(PLUGIN:ScanIdentity(p),nil)
 `,`
 files={}; sent=0
 file={CreateDir=function() end,Read=function(path) return files[path] end,
 Write=function(path,data) files[path]=data end,Delete=function(path) files[path]=nil end}
 util.JSONToTable=function() return nil end; util.TableToJSON=function() return 'saved metadata' end
 util.SHA256=function() return string.rep('a',64) end
 table.Count=function(t) local n=0; for _ in pairs(t) do n=n+1 end return n end
 net.Start=function() end; net.WriteUInt=function() end; net.WriteString=function() end
 net.WriteData=function() end; net.Send=function() sent=sent+1 end
 ix.Fieldlink={}
 function device(id,name)
  return {id=id,identity={id='cid:'..id,name=name,cid=tostring(id)},GetID=function(self) return self.id end,
  GetData=function(self,key) if key=='fieldlinkIdentity' then return self.identity end end}
 end
 function user(item,id)
  local p={valid=true,item=item,charid=id,ready=true}
  p.GetCharacter=function(self) return {GetID=function() return self.charid end} end
  return p
 end
 ix.Fieldlink.Ready=function(p) return p.ready and p.item~=nil end
 ix.Fieldlink.Identity=function(p) return p.item and p.item.identity end
 ix.Fieldlink.DeviceItem=function(p) return p.item end
 ix.Fieldlink.Text=function(v,n) if type(v)=='string' and #v>0 and #v<=n then return v end end
 PLUGIN.Send=function(self,p,message) self.lastMessage=message end
 `);
suite('PDA camera input arms after release, debounces shutter, exits on RMB and restores popup input',
 ['ixhl2rp/plugins/site_pda/cl_camera.lua'],`
 local F=ix.Fieldlink
 F.SetCamera(true); eq(F.camera,true); eq(host.mouse,false); eq(host.keyboard,false); eq(clicker,false)
 left=true; F.CameraThink(); eq(F.capturePending,nil)
 left=false; F.CameraThink(); left=true; F.CameraThink(); eq(F.capturePending,true)
 F.capturePending=nil; F.CameraThink(); eq(F.capturePending,nil)
 left=false; F.CameraThink(); left=true; F.CameraThink(); eq(F.capturePending,nil)
 left=false; right=true; F.CameraThink(); eq(F.camera,false); eq(host.popup,true); eq(shield.mouse,true); eq(shield.keyboard,false); eq(page,'camera')
 F.SetCamera(true); left=false; right=false; F.CameraThink()
 panel.data.photos={}; for i=1,12 do panel.data.photos[i]={} end
 clock=clock+5; left=true; F.CameraThink(); eq(F.capturePending,nil); eq(sound,'error')
 `,`
 CLIENT=true; SERVER=false; ix.Fieldlink={photoLimit=12,photoBytes=131072,photoChunk=48000}
 local F=ix.Fieldlink; F.Ready=function() return true end; F.Sound=function(n) sound=n end
 ix.gui={}; left=false; right=false; MOUSE_LEFT=1; MOUSE_RIGHT=2
 function RealTime() return clock end
 input={IsMouseDown=function(k) return k==1 and left or k==2 and right end}
 gui={EnableScreenClicker=function(v) clicker=v end}; hook.Add=function() end
 net.Start=function() end; net.SendToServer=function() end
 function LocalPlayer() return {} end
 shield={SetMouseInputEnabled=function(self,v) self.mouse=v end,SetKeyboardInputEnabled=function(self,v) self.keyboard=v end}
 host={valid=true,screenShield=shield,SetMouseInputEnabled=function(self,v) self.mouse=v end,
 SetKeyboardInputEnabled=function(self,v) self.keyboard=v end,MakePopup=function(self) self.popup=true end}
 panel={valid=true,data={registered=true,device=101,photos={}},inputHost=host,
 SetMouseInputEnabled=function() end,SetKeyboardInputEnabled=function() end,Navigate=function(_,v) page=v end}
 ix.gui.fieldlink=panel
 `);
suite('PDA camera render failure restores target and camera stacks and exits capture mode',
 ['ixhl2rp/plugins/site_pda/cl_camera.lua'],`
 ix.Fieldlink.camera=true; ix.Fieldlink.RenderCamera()
 eq(targetDepth,0); eq(cameraDepth,0); eq(ix.Fieldlink.renderingCamera,false); eq(ix.Fieldlink.camera,false); eq(errors,1)
 `,`
 CLIENT=true; SERVER=false; ix.Fieldlink={}; ix.gui={}; function RealTime() return clock end
 targetDepth=0; cameraDepth=0; errors=0
 hook.Add=function() end
 function GetRenderTarget() return {GetName=function() return 'rt' end} end
 function CreateMaterial() return {SetTexture=function() end} end
 function LocalPlayer() return {EyePos=function() return {} end,EyeAngles=function() return {} end} end
 render={PushRenderTarget=function() targetDepth=targetDepth+1 end,PopRenderTarget=function() targetDepth=targetDepth-1 end,
 Clear=function() end,RenderView=function() end,CopyRenderTargetToTexture=function() end}
 cam={Start2D=function() cameraDepth=cameraDepth+1 end,End2D=function() cameraDepth=cameraDepth-1 end}
 surface={SetDrawColor=function() end,SetMaterial=function() error('intentional shader failure') end}
 function ErrorNoHalt() errors=errors+1 end
 `);
};
