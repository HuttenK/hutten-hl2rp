// Contact schematic computed by production A.Goals; not an engine/model render.
const fs=require('fs'),path=require('path'),f=require('fengari'),{source,base,read}=require('./restored-test-runner.cjs');
process.chdir(path.resolve(__dirname,'..'));
const code=read('tools/fixture.lua')+'\nunpack=table.unpack\n'+source([...base,'tools/fixtures/water-animations.lua','ixhl2rp/plugins/action_animations/sh_plugin.lua','ixhl2rp/plugins/action_animations/sh_ik.lua','ixhl2rp/plugins/action_animations/cl_actions.lua'])+`
 local A=ix.ActionAnimations;local p=waterUser();local e=waterSource(p);local start=clock
 p.nw.ixContextActionStarted=start;p.nw.ixContextActionFinish=start+2
 local function mat(v) local m=Matrix();m:SetTranslation(v);return m end
 local m={[1]=mat(Vector(0,0,68)),[2]=mat(Vector(0,0,36)),[3]=mat(Vector(0,6,56)),[4]=mat(Vector(0,-6,56))}
 local s={rig={head=1,pelvis=2,arms={L={3},R={4}}},source='sink',anchor=Vector(),target=e}
 local out={}
 for _,spec in ipairs({{'waterdrink',0},{'waterdrink',1.35},{'waterfill',.7},{'wash',.7}}) do
  s.kind=spec[1];clock=start+spec[2];local goals=A.Goals(p,s,m)
  local values={};for _,side in ipairs({'L','R'}) do local v=goals[side];values[#values+1]=string.format('%f,%f,%f',v.x,v.y,v.z) end
  out[#out+1]=table.concat(values,';')
 end
 return table.concat(out,'|')
`;
const L=f.lauxlib.luaL_newstate();f.lualib.luaL_openlibs(L);
if(f.lauxlib.luaL_dostring(L,f.to_luastring(code))!==f.lua.LUA_OK)throw Error(f.to_jsstring(f.lua.lua_tostring(L,-1)));
const stages=f.to_jsstring(f.lua.lua_tostring(L,-1)).split('|').map(row=>row.split(';').map(v=>v.split(',').map(Number)));f.lua.lua_close(L);
const names=['01 · ЗАЧЕРПНУТЬ','02 · ПОДНЕСТИ КО РТУ','03 · НАПОЛНЕНИЕ','04 · МЫТЬЁ РУК'];
const proj=v=>[70+v[0]*3+v[1]*1.1,284-v[2]*3];
const line=(a,b,c,w=3)=>`<path d="M${proj(a).join(',')}L${proj(b).join(',')}" fill="none" stroke="${c}" stroke-width="${w}" stroke-linecap="round"/>`;
const dot=(v,c,r=4)=>`<circle cx="${proj(v)[0]}" cy="${proj(v)[1]}" r="${r}" fill="${c}"/>`;
let svg='<svg xmlns="http://www.w3.org/2000/svg" width="1120" height="390" viewBox="0 0 1120 390"><rect width="1120" height="390" fill="#edf0e9"/><g font-family="Tahoma,Arial" fill="#203a3a">';
svg+='<text x="24" y="30" font-size="20" font-weight="bold">Действия с водой · контакт рук</text><text x="24" y="54" font-size="13">Схема целей из A.Goals. Это не игровой рендер; пропорции и сгиб локтей зависят от модели.</text>';
stages.forEach((goals,i)=>{
 svg+=`<g transform="translate(${16+i*277},66)"><rect width="266" height="280" rx="8" fill="#fafbf5"/><text x="13" y="23" font-size="14" font-weight="bold">${names[i]}</text>`;
 svg+=line([0,0,36],[0,0,65],'#8c9691',6)+dot([0,0,68],'#8c9691',12)+line([0,0,36],[-2,5,5],'#b5bdb6',5)+line([0,0,36],[2,-5,5],'#b5bdb6',5);
 svg+=`<rect x="145" y="147" width="63" height="48" rx="5" fill="#dce5df" stroke="#99aba1"/>${dot([30,0,48],'#ba833e',5)}`;
 goals.forEach((goal,j)=>{const c=j===0?'#286575':'#b04f3d';svg+=line([0,j===0?6:-6,56],goal,c,3)+dot(goal,c,5)});
 if(i===2){const p=proj(goals[1]);svg+=`<rect x="${p[0]-7}" y="${p[1]-13}" width="14" height="24" rx="3" fill="none" stroke="#52614b" stroke-width="2"/>`}
 svg+='<text x="13" y="261" font-size="11" fill="#62746c">Золотая точка — источник воды</text></g>';
});
svg+='<text x="24" y="374" font-size="13">Движение затрагивает только руки. Бутылка при наполнении — визуальная копия выбранной ёмкости.</text></g></svg>';
const out='docs/water-action-animations-contact';fs.writeFileSync(out+'.svg',svg);
require('C:/Users/q1236/.cache/codex-runtimes/codex-primary-runtime/dependencies/node/node_modules/sharp')(Buffer.from(svg)).png().toFile(out+'.png').then(()=>console.log('Painted production-goal contact schematic')).catch(e=>{console.error(e);process.exitCode=1});
