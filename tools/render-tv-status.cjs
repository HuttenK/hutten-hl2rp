// Records actual TV/Fieldlink Lua draw calls for an offline typography preview.
const fs=require('fs'),f=require('fengari'),{normalize}=require('./glua.cjs');
const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
const frames=[],fonts={};let frame;
function value(index){
 const i=f.lua.lua_absindex(L,index),t=f.lua.lua_type(L,i);
 if(t===f.lua.LUA_TNUMBER)return f.lua.lua_tonumber(L,i);
 if(t===f.lua.LUA_TSTRING)return f.to_jsstring(f.lua.lua_tostring(L,i));
 if(t===f.lua.LUA_TTABLE){const o={};f.lua.lua_pushnil(L);while(f.lua.lua_next(L,i)){o[value(-2)]=value(-1);f.lua.lua_pop(L,1);}return o;}
 return null;
}
f.lua.lua_pushcfunction(L,()=>{const args=[];for(let i=1;i<=f.lua.lua_gettop(L);i++)args.push(value(i));
 if(args[0]==='font')fonts[args[1]]=args[2];else if(args[0]==='frame'){frame={status:args[1],w:args[2],h:args[3],ops:[]};frames.push(frame);}else frame.ops.push(args);return 0;});
f.lua.lua_setglobal(L,f.to_luastring('emit'));
const emblem=fs.readFileSync('ixhl2rp/plugins/site_pda/cl_fieldlink.lua','utf8');
const source=`
 ix={TV={},Fieldlink={}};local F=ix.Fieldlink
 function string.utf8len(s) return utf8.len(s) end
 function string.utf8sub(s,a,b) return s:sub(utf8.offset(s,a),b and ((utf8.offset(s,b+1) or (#s+1))-1) or #s) end
 TEXT_ALIGN_CENTER=1;TEXT_ALIGN_RIGHT=2
 function Color(r,g,b,a) return {r=r,g=g,b=b,a=a or 255} end
 local color
 local fontSizes={};local activeFont
 surface={CreateFont=function(name,def) fontSizes[name]=def.size;emit('font',name,def) end,
 SetFont=function(font) activeFont=font end,GetTextSize=function(text) return utf8.len(text)*fontSizes[activeFont]*.6 end,
 SetDrawColor=function(a,b,c,d) color=type(a)=='table' and a or Color(a,b,c,d) end,
 DrawRect=function(x,y,w,h) emit('rect',x,y,w,h,color) end,
 DrawLine=function(x,y,x2,y2) emit('line',x,y,x2,y2,color) end,
 DrawPoly=function(p) emit('poly',p,color) end}
 draw={NoTexture=function() end,SimpleText=function(text,font,x,y,c,align) emit('text',text,font,x,y,c,align) end}
 ${emblem.slice(emblem.indexOf('local emblemCache='),emblem.indexOf('-- Fixed device pixels'))}
 ${normalize(fs.readFileSync('ixhl2rp/plugins/tv_screen/cl_display.lua','utf8'))}
 for _,status in ipairs({'idle','loading','buffering','ended','error','blocked','missing'}) do
  for _,size in ipairs({{1024,576},{700,240}}) do
   emit('frame',status,size[1],size[2]);ix.TV.DrawFailure(size[1],size[2],status,'ОБЩИЙ ЭФИР / 01')
  end
 end`;
if(f.lauxlib.luaL_dostring(L,f.to_luastring(source))!==f.lua.LUA_OK)throw Error(f.to_jsstring(f.lua.lua_tostring(L,-1)));
fs.writeFileSync('docs/tv-status-draw.json',JSON.stringify({fonts,frames}));
console.log(`Recorded ${frames.length} actual status layouts; render with tools/render-tv-status.py.`);
