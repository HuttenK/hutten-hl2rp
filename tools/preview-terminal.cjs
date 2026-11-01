// Render production Lua panels through a small offline VGUI/SVG adapter.
const fs=require('fs'),path=require('path');const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');const {normalize}=require('./glua.cjs');const root=path.join(__dirname,'..');
const files=['tools/fixture.lua','tools/terminal-preview-fixture.lua','ixhl2rp/plugins/foundation_network/cl_design.lua','ixhl2rp/plugins/foundation_network/cl_sites.lua','ixhl2rp/plugins/foundation_network/cl_network.lua'];
const pages={
 login:'',
 home:`p:ApplyPage({route='scip://home',token='preview',name='Thomas',level=4,department='Служба безопасности',webAdmin=true,rows={}})`,
 browser:`p:ApplyPage({route='scip://web',token='preview',name='Thomas',level=4,department='Служба безопасности',webAdmin=true,title='Внутренняя сеть',body='Ресурсы и сервисы объекта. Выберите сайт или введите адрес.',rows={{title='Портал объекта',detail='Рабочие ресурсы внутренней сети.',url='scip://web/welcome',image='facility'},{title='Инженерная служба',detail='Диагностика цепей и технический справочник.',url='scip://web/engineering',image='facility'},{title='Биобезопасность',detail='Исследования и контроль очагов.',url='scip://web/biosafety',image='biosafety'}}})`,
 site:`p:ApplyPage({route='scip://web/welcome',token='preview',name='Thomas',level=4,department='Служба безопасности',webAdmin=true,webDesign={title='Портал объекта',summary='Рабочие ресурсы внутренней сети.',image='facility',template='portal',theme='cyan',level=1,revision=2,body='# Начните смену\\nПроверьте состояние систем и ознакомьтесь с внутренними инструкциями.\\n\\n# Инфраструктура\\nВсе управляющие команды сохраняются в журнале объекта.',links={{title='Состояние энергосети',url='scip://power'},{title='Создать техническую заявку',url='scip://service'}}}})`,
 editor:`p:ApplyPage({route='scip://editor',token='preview',name='Thomas',level=4,department='Служба безопасности',webAdmin=true,title='Студия сайтов',body='Оформление, содержание и публикация внутренних ресурсов.',webEdit={slug='welcome',title='Портал объекта',summary='Рабочие ресурсы сети.',body='# Информация\\nСодержание страницы.',level=1,revision=2,template='portal',theme='cyan',image='facility',links={}}})`
};
let body='';
for(const [name,action] of Object.entries(pages)){
 const L=lauxlib.luaL_newstate();lualib.luaL_openlibs(L);
 const code=files.map(f=>'do\n'+normalize(fs.readFileSync(path.join(root,f),'utf8'))+'\nend').join('\n')+`\nlocal p=vgui.Create('ixFoundationNetwork');p.bootAt=0;${action}\nreturn PreviewSVG(p)`;
 if(lauxlib.luaL_dostring(L,to_luastring(code))!==lua.LUA_OK)throw Error(name+': '+to_jsstring(lua.lua_tostring(L,-1)));
 const svg=to_jsstring(lua.lua_tostring(L,-1));fs.writeFileSync(path.join(root,'docs/terminal-'+name+'.svg'),svg);
 body+=`<section id="${name}" ${name==='home'?'':'hidden'}>${svg}</section>`;
}
fs.writeFileSync(path.join(root,'docs/terminal-preview.html'),`<!doctype html><meta charset="utf-8"><title>SCiPNET — production Lua paint preview</title><style>body{margin:0;background:#050a10;color:#bddbdc;font:14px Consolas}nav{display:flex;gap:8px;padding:10px;align-items:center}button{background:#1c343e;border:1px solid #456572;color:#d4efeb;padding:8px 20px;cursor:pointer}small{margin-left:auto}svg{width:100%;height:auto;display:block}section[hidden]{display:none}</style><nav>${Object.keys(pages).map(n=>`<button onclick="document.querySelectorAll('section').forEach(s=>s.hidden=s.id!=='${n}')">${n}</button>`).join('')}<small>Production Lua layout / offline paint preview · not Source rendering</small></nav>${body}`);
console.log('docs/terminal-preview.html');
