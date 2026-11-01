// Offline output of production HUD callbacks; no game or browser is started.
const fs=require('fs'),path=require('path'),f=require('fengari');
const {client}=require('./test-contextual-equipment-use.cjs');
const {read,native}=require('./restored-test-runner.cjs');
const sharp=require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp');
const out=path.resolve(__dirname,'../.runtime/contextual-equipment-use-20261009/previews');fs.mkdirSync(out,{recursive:true});
const progress=`
 ix.Legends={accent=Color(229,64,90),T=function(_,ru) return ru end,Rect=function(x,y,w,h,c) surface.SetDrawColor(c);surface.DrawRect(x,y,w,h) end}
 ix.lang={AddTable=function() end};ix.option.Add=function() end;ix.type={bool=1};ix.option.Get=function(_,default) return default end
 function GetConVar() return {GetBool=function() return true end} end
 string.utf8len=utf8.len
`+native('ixhl2rp/plugins/zz_legends_interface/cl_gameplay.lua','local H = {}','function H.Pickup()');
const cases={
 'sink-1280':`screenW=1280;screenH=720;aimed=fixture('sink');bottle(1,'Фляга');Q.Refresh(true)`,
 'fill-640':`screenW=640;screenH=480;aimed=fixture('sink');bottle(1,'Фляга сотрудника');Q.Cycle(1)`,
 'toilet-640':`screenW=640;screenH=480;aimed=fixture('toilet');Q.Refresh(true)`,
 'decon-active-640':`screenW=640;screenH=480;aimed=fixture('decon_shower');aimed.PrintName='Душ деконтаминации';aimed.ixFacilityPowered=true;aimed.ixDeconUser=p;ix.bar.actionStart=clock-1;ix.bar.actionEnd=clock+7;ix.bar.actionText='Деконтаминация — оставайтесь рядом...';Q.Refresh(true)`,
 'generator-640':`screenW=640;screenH=480;aimed=fixture('generator');aimed.ixFacilityName='Резервный генератор';F.OpenDevice({device={entity=aimed:EntIndex(),id=700,kind='generator',fault=false,fuel=300,canStart=true,hasFuel=true,links={}}});Q.Refresh(true)`,
 'sensor-640':`screenW=640;screenH=480;aimed=fixture('decon_sensor');aimed.PrintName='Биологический контроль';aimed.ixFacilityPowered=true;aimed.ixDeconAlarm=true;aimed.ixDeconStatus='ЗОНЫ 1 / SCP 2 / ФЛОРА 0 / ОСТАНКИ 1 / ТОКСИНЫ 0';Q.Refresh(true)`
};
(async()=>{for(const [name,code] of Object.entries(cases)){
 const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
 const script=read('tools/fixture.lua')+'\nunpack=table.unpack\n'+client+'\n'+progress+'\n'+code+`
 local panel=vgui.Create('DPanel');panel:SetSize(ScrW(),ScrH())
 panel.Paint=function(_,w,h)
  surface.SetDrawColor(58,64,61);surface.DrawRect(0,0,w,h)
  surface.SetDrawColor(160,172,168);surface.DrawRect(w/2-1,h/2-1,2,2)
  Q.Paint(Q.current,Q.option,Q.index)
  if Q.Busy() then ix.GameplayHUD.Action() end
 end
 return PreviewSVG(panel),ScrW(),ScrH()
`;
 if(f.lauxlib.luaL_dostring(L,f.to_luastring(script))!==f.lua.LUA_OK)throw Error(name+': '+f.to_jsstring(f.lua.lua_tostring(L,-1)));
 const w=f.lua.lua_tonumber(L,-2),h=f.lua.lua_tonumber(L,-1);
 const svg=f.to_jsstring(f.lua.lua_tostring(L,-3)).replace('width="1920" height="1120"',`width="${w}" height="${h}"`).replace('viewBox="0 0 1920 1120"',`viewBox="0 0 ${w} ${h}"`);
 fs.writeFileSync(path.join(out,name+'.svg'),svg);await sharp(Buffer.from(svg)).png().toFile(path.join(out,name+'.png'));
 f.lua.lua_close(L);console.log('Painted '+name+' '+w+'x'+h);
}})().catch(error=>{console.error(error);process.exitCode=1});