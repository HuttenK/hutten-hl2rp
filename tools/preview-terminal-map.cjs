// Offline production-map paint with faces read from a locally installed BSP.
// Layouts: ValveSoftware/source-sdk-2013 src/public/bspfile.h.
const fs=require('fs'),path=require('path');
const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');const {normalize}=require('./glua.cjs');
const root=path.join(__dirname,'..'),map=process.argv[2]||'C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod/maps/gm_construct.bsp';
const bytes=fs.readFileSync(map);if(bytes.toString('ascii',0,4)!=='VBSP')throw Error('Not a Source BSP');
const lump=id=>{const off=bytes.readInt32LE(8+id*16),size=bytes.readInt32LE(12+id*16);if(off<0||off+size>bytes.length)throw Error('Invalid lump');const b=bytes.subarray(off,off+size);if(b.toString('ascii',0,4)==='LZMA')throw Error('Compressed fixture requires decompression');return b;};
const verts=lump(3),edges=lump(12),surfedges=lump(13),faces=lump(7).length?lump(7):lump(58),models=lump(14),texinfo=lump(6),texdata=lump(2),strings=lump(43),stringtable=lump(44);
const first=models.readInt32LE(40),count=models.readInt32LE(44),entries=[];
for(let i=first;i<first+count;i++){
 const off=i*56,start=faces.readInt32LE(off+4),n=faces.readInt16LE(off+8),tex=faces.readInt16LE(off+10);if(tex<0||n<3)continue;
 const td=texinfo.readInt32LE(tex*72+68),str=texdata.readInt32LE(td*32+12),st=stringtable.readInt32LE(str*4),name=strings.toString('utf8',st,strings.indexOf(0,st));
 if(name.toLowerCase().includes('tools/')||name.toLowerCase().includes('sky'))continue;
 const poly=[];for(let j=0;j<n;j++){const signed=surfedges.readInt32LE((start+j)*4),vertex=edges.readUInt16LE(Math.abs(signed)*4+(signed<0?2:0));poly.push([0,4,8].map(k=>verts.readFloatLE(vertex*12+k)));}
 entries.push(`{${poly.map(v=>`Vector(${v.join(',')})`).join(',')}}`);
}
for(const mode of ['whole','facility','floor']){
 const setup=`polygons={${entries.join(',')}};surfaces={};for _,p in ipairs(polygons) do local v=p;surfaces[#surfaces+1]={GetMaterial=function() return {GetName=function() return 'brick' end} end,GetVertices=function() return v end} end
 CLIENT=true;SERVER=false;ix.FoundationNet={};clock=10;function SysTime() return clock end;function RealTime() return clock end
 vgui={Register=function(_,v) mapPanel=v end};game={GetMap=function() return 'gm_construct' end,GetWorld=function() return {GetBrushSurfaces=function() return surfaces end} end}
 function GetRenderTarget() return {Width=function() return 2048 end,Height=function() return 1024 end,GetName=function() return 'rt' end} end;function CreateMaterial() return {} end
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 render={PushRenderTarget=function() end,PopRenderTarget=function() end,Clear=function() end};cam={Start2D=function() end,End2D=function() end};parts={};color='white'
 surface={SetDrawColor=function(r,g,b) if istable(r) then g,b,r=r.g,r.b,r.r end;color=string.format('rgb(%s,%s,%s)',r,g,b) end,
 DrawLine=function(x,y,u,v) parts[#parts+1]=string.format('<path d="M%.2f %.2fL%.2f %.2f" stroke="%s" stroke-width="1.3"/>',x,y,u,v,color) end,
 DrawPoly=function(points) local out={} for _,p in ipairs(points) do out[#out+1]=string.format('%.2f,%.2f',p.x,p.y) end;parts[#parts+1]='<polygon points="'..table.concat(out,' ')..'" fill="'..color..'"/>' end,
 DrawRect=function(x,y,w,h) parts[#parts+1]=string.format('<rect x="%.2f" y="%.2f" width="%.2f" height="%.2f" fill="%s"/>',x,y,w,h,color) end}
 draw={NoTexture=function() end,SimpleText=function(t,font,x,y,c) parts[#parts+1]=string.format('<text x="%.2f" y="%.2f" fill="rgb(%d,%d,%d)" font-family="Consolas" font-size="20">%s</text>',x,y+20,c.r,c.g,c.b,t) end};MOUSE_LEFT=1;MOUSE_RIGHT=2`;
 const code=[fs.readFileSync(path.join(__dirname,'fixture.lua'),'utf8'),fs.readFileSync(path.join(__dirname,'geometry-fixture.lua'),'utf8'),setup,normalize(fs.readFileSync(path.join(root,'ixhl2rp/plugins/foundation_network/cl_map.lua'),'utf8')),
 `local p=setmetatable({valid=true,SetTall=function() end,GetWide=function() return 1724 end,GetTall=function() return 620 end},{__index=mapPanel});p:Init();while not p.geometry.ready and not p.geometry.error do ix.FoundationNet.StepMapGeometry(p.geometry) end;p:SetData({origin={0,0,0},name='gm_construct',zones={},terminals={}});p:ResetOrbit(${mode==='whole'?'true':'false'});${mode==='floor'?"p.threeD=false;p.cutaway=true;p.center.z=0;":''}ix.FoundationNet.RenderMap(p);assert(p.mapReady,p.renderError);p:Paint(1724,620);return table.concat(parts)`].join('\n');
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK)throw Error(to_jsstring(lua.lua_tostring(L,-1)));
 const body=to_jsstring(lua.lua_tostring(L,-1));fs.writeFileSync(path.join(root,`docs/terminal-map-${mode}.svg`),`<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 1724 620"><rect width="1724" height="620" fill="#050d14"/>${body}</svg>`);
 console.log(mode+': '+entries.length+' actual BSP faces through production Lua renderer');
}
