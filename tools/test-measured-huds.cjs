const r = require('./restored-test-runner.cjs');
const fixture = r.read('tools/fixtures/measured-huds.lua');
const anatomy = r.source(['ixhl2rp/plugins/zz_legends_interface/cl_anatomy.lua']);
const status = r.source(['ixhl2rp/plugins/status_display/sh_plugin.lua', 'ixhl2rp/plugins/status_display/cl_status.lua']);
const run = (name, files, assertions) => r.run(name, fixture + files + assertions);

run('Compact anatomy reuses one image for fresh equivalent states and preserves every original stroke', anatomy, `
 local state=NewBody()
 ix.Anatomy.Draw(40,38,66,158,state);local expected=table.Copy(drawn);assert(polys>1000)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);SameDrawing(expected,drawn);CheckState()
 eq(captureCount,1);eq(blits,1);eq(ResourceCount(),1)
 for i=1,100 do
  ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,NewBody())
  eq(polys,0);eq(blits,1);SameDrawing(expected,drawn);CheckState()
 end
 eq(captureCount,1);eq(ResourceCount(),1)
`);

run('Anatomy changes health colours, fractures, missing limbs and hover immediately with original priority', anatomy, `
 local state=NewBody();ix.Anatomy.DrawHUD(40,38,66,158,state)
 state.parts[1].ratio=.999;ix.Anatomy.DrawHUD(40,38,66,158,state);eq(captureCount,1)
 local cases={function() state.parts[1].ratio=.98 end,function() state.parts[1].ratio=.5 end,
  function() state.parts[2].fractured=true end,function() state.parts[2].amputated=true end,
  function() table.remove(state.parts,3) end,function() state.parts[1],state.parts[4]=state.parts[4],state.parts[1] end}
 for i,edit in ipairs(cases) do
  edit();ResetDrawing();ix.Anatomy.Draw(40,38,66,158,state);local expected=table.Copy(drawn)
  ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);SameDrawing(expected,drawn);eq(captureCount,i+1);CheckState()
 end
 local hovered=state.parts[2].id
 ResetDrawing();ix.Anatomy.Draw(40,38,66,158,state,hovered);local expected=table.Copy(drawn)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state,hovered);SameDrawing(expected,drawn);eq(captureCount,8)
 for _,size in ipairs({{70,50,99,237},{41,39,66,158},{200,100,66,158}}) do
  ResetDrawing();ix.Anatomy.Draw(size[1],size[2],size[3],size[4],state);local direct=table.Copy(drawn)
  ResetDrawing();ix.Anatomy.DrawHUD(size[1],size[2],size[3],size[4],state);SameDrawing(direct,drawn);CheckState()
 end
 eq(ResourceCount(),1)
`);

run('Interactive anatomy and unsupported or faded HUD contexts preserve direct rendering', anatomy, `
 local state=NewBody()
 ix.Anatomy.Draw(0,30,240,420,state,12);assert(polys>1000);eq(captureCount,0)
 local cases={function() windows=false end,function() windows=true;alphaMultiplier=.5 end,
  function() alphaMultiplier=1;nestedTarget={} end,function() nestedTarget=nil;GetRenderTargetEx=nil end}
 for _,change in ipairs(cases) do change();ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);assert(polys>1000);eq(blits,0);eq(captureCount,0);CheckState() end
 windows=true;ResetDrawing();ix.Anatomy.DrawHUD(40,38,400,900,state);assert(polys>1000);eq(captureCount,0)
 ResetDrawing();ix.Anatomy.DrawHUD(40.5,38,66,158,state);assert(polys>1000)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,0,158,state);ix.Anatomy.DrawHUD(40,38,66,158,nil);eq(polys,0)
`);

run('Anatomy target capture failure restores render state and keeps its visible direct fallback', anatomy, `
 local state=NewBody();failPoly=true;ix.Anatomy.DrawHUD(40,38,66,158,state)
 CheckState();eq(#errors,1);eq(blits,0);assert(#drawn>1000)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);assert(polys>1000);eq(captureCount,1);CheckState()
`);

run('Anatomy image draw failure restores blending before direct fallback', anatomy, `
 failBlit=true;ix.Anatomy.DrawHUD(40,38,66,158,NewBody());eq(#errors,1);CheckState();assert(#drawn>1000)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,NewBody());assert(polys>1000);eq(captureCount,1);CheckState()
`);

run('Anatomy rejects a hardware-clamped target before capturing or sampling', anatomy, `
 clampedWidth=128;local state=NewBody()
 ix.Anatomy.Draw(40,38,66,158,state);local direct=table.Copy(drawn)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);SameDrawing(direct,drawn);CheckState()
 eq(captureCount,0);eq(blits,0);eq(#errors,1);eq(ResourceCount(),1)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);eq(captureCount,0);eq(#errors,1);SameDrawing(direct,drawn)
`);

run('Anatomy stops using cached pixels after target dimensions change', anatomy, `
 local state=NewBody();ix.Anatomy.DrawHUD(40,38,66,158,state);eq(blits,1)
 targets.ix_anatomy_hud_v1.height=256
 ResetDrawing();ix.Anatomy.Draw(40,38,66,158,state);local direct=table.Copy(drawn)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);SameDrawing(direct,drawn);CheckState()
 eq(blits,0);eq(captureCount,1);eq(#errors,1)
 ResetDrawing();ix.Anatomy.DrawHUD(40,38,66,158,state);eq(#errors,1);eq(blits,0);CheckState()
`);

run('Status typewriter and row fades remain live until every visible character finishes', status, `
 statusText=string.rep('Я',64)..'\\n'..string.rep('W',64);net.handlers.ixStatusHUD()
 for _,elapsed in ipairs({0,.05,.15,.34,.4,.5,.6}) do
  clock=20+elapsed;windows=false;ResetDrawing();PLUGIN:HUDPaint();local direct=table.Copy(drawn)
  windows=true;ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);eq(captureCount,0);CheckState()
 end
 clock=23;windows=false;ResetDrawing();PLUGIN:HUDPaint();local direct=table.Copy(drawn)
 windows=true;ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);eq(captureCount,1);eq(blits,1);CheckState()
 local created=matrixCreates
 for i=1,100 do ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);eq(texts,0);eq(lines,0);eq(blits,1);CheckState() end
 eq(captureCount,1);eq(matrixCreates,created);eq(ResourceCount(),1)
`);

run('Final status cache preserves Cyrillic glyph positions, shadows and curved strokes across resolutions', status, `
 statusText='Внимание всем сотрудникам МОГ\\nНарушение содержания SCP-610\\nОжидайте дальнейших указаний.'
 net.handlers.ixStatusHUD();clock=25
 for _,size in ipairs({{1920,1080},{1280,720},{1024,768},{2560,1440},{3840,2160},{3440,1440}}) do
  screenW,screenH=size[1],size[2];windows=false;ResetDrawing();PLUGIN:HUDPaint();local direct=table.Copy(drawn)
  windows=true;ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);eq(blits,1);CheckState()
  ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);eq(texts,0);eq(lines,0);CheckState()
 end
 eq(ResourceCount(),1);eq(captureCount,6)
`);

run('Status invalidates message, sync revision and fonts without allocating unbounded textures', status, `
 statusText='Ожидайте';net.handlers.ixStatusHUD();reduced=true;PLUGIN:HUDPaint();eq(captureCount,1)
 net.handlers.ixStatusHUD();ResetDrawing();PLUGIN:HUDPaint();eq(captureCount,1);eq(texts,0)
 for i=1,30 do
  statusText='Обновление '..i;statusRevision=statusRevision+1;net.handlers.ixStatusHUD()
  windows=false;ResetDrawing();PLUGIN:HUDPaint();local direct=table.Copy(drawn)
  windows=true;ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);CheckState()
 end
 eq(captureCount,31);eq(ResourceCount(),1)
 statusRevision=statusRevision+1;net.handlers.ixStatusHUD();PLUGIN:HUDPaint();eq(captureCount,32)
 PLUGIN:OnReloaded();PLUGIN:HUDPaint();eq(captureCount,33);eq(ResourceCount(),1);CheckState()
 statusEnabled=false;net.handlers.ixStatusHUD();ResetDrawing();PLUGIN:HUDPaint();eq(#drawn,0)
 statusEnabled=true;net.handlers.ixStatusHUD();PLUGIN:HUDPaint();eq(captureCount,34)
`);

run('Status cached output remains gated by faction, alive state and every blocking menu', status, `
 statusText='Готовность 2';net.handlers.ixStatusHUD();clock=25;PLUGIN:HUDPaint();eq(captureCount,1)
 for _,key in ipairs({'foundationNetwork','characterMenu','menu','fieldlink'}) do
  ix.gui[key]={valid=true};ResetDrawing();PLUGIN:HUDPaint();eq(#drawn,0);ix.gui[key]=nil
 end
 for _,f in ipairs({1,2,0}) do statusFaction=f;ResetDrawing();PLUGIN:HUDPaint();eq(#drawn,0) end
 statusFaction=3;statusNoCharacter=true;ResetDrawing();PLUGIN:HUDPaint();eq(#drawn,0);statusNoCharacter=false
 alive=false;PLUGIN:HUDPaint();eq(#drawn,0);alive=true
 gameMenu=true;PLUGIN:HUDPaint();eq(#drawn,0);gameMenu=false
 ResetDrawing();PLUGIN:HUDPaint();eq(blits,1);eq(captureCount,1);CheckState()
 statusText='';net.handlers.ixStatusHUD();ResetDrawing();PLUGIN:HUDPaint();eq(#drawn,0)
`);

run('Status unsupported renderer, nested targets and inherited opacity retain direct drawing', status, `
 statusText='Оперативная информация';net.handlers.ixStatusHUD();clock=25
 for _,change in ipairs({function() windows=false end,function() windows=true;alphaMultiplier=.5 end,
  function() alphaMultiplier=1;nestedTarget={} end,function() nestedTarget=nil;GetRenderTargetEx=nil end}) do
  change();ResetDrawing();PLUGIN:HUDPaint();assert(texts>0);eq(blits,0);eq(captureCount,0);CheckState()
 end
`);

run('Oversized status on a narrow tall display falls back instead of cropping or growing target memory', status, `
 screenW,screenH=300,2160
 statusText=string.rep(string.rep('W',64)..'\\n',7)..string.rep('W',64)
 net.handlers.ixStatusHUD();reduced=true;PLUGIN:HUDPaint()
 assert(texts>900);eq(captureCount,0);eq(ResourceCount(),0);CheckState()
`);

run('Status text failure during capture balances the active glyph matrix and target before fallback', status, `
 statusText='Обнаружен SCP';net.handlers.ixStatusHUD();clock=25;failText=true
 PLUGIN:HUDPaint();eq(#errors,1);eq(blits,0);assert(#drawn>50);CheckState()
 ResetDrawing();PLUGIN:HUDPaint();assert(texts>0);eq(captureCount,1);CheckState()
`);

run('Status image failure cannot leave blending enabled or lose the message', status, `
 statusText='Нужна помощь';net.handlers.ixStatusHUD();clock=25;failBlit=true
 PLUGIN:HUDPaint();eq(#errors,1);assert(#drawn>50);CheckState()
 ResetDrawing();PLUGIN:HUDPaint();assert(texts>0);eq(captureCount,1);CheckState()
`);

run('Status rejects a hardware-clamped target without losing or cropping text', status, `
 statusText='Проверка оборудования';net.handlers.ixStatusHUD();clock=25;windows=false;PLUGIN:HUDPaint();local direct=table.Copy(drawn)
 windows=true;clampedHeight=512;ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);CheckState()
 eq(captureCount,0);eq(blits,0);eq(#errors,1);eq(ResourceCount(),1)
 ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);eq(#errors,1);eq(captureCount,0)
`);

run('Status abandons a cached target when its dimension API becomes unavailable', status, `
 statusText='Ожидайте указаний';net.handlers.ixStatusHUD();clock=25;PLUGIN:HUDPaint();eq(blits,1)
 targets.ix_status_visor_v1.Width=nil
 windows=false;ResetDrawing();PLUGIN:HUDPaint();local direct=table.Copy(drawn)
 windows=true;ResetDrawing();PLUGIN:HUDPaint();SameDrawing(direct,drawn);CheckState()
 eq(blits,0);eq(captureCount,1);eq(#errors,1)
 ResetDrawing();PLUGIN:HUDPaint();eq(#errors,1);eq(blits,0);CheckState()
`);

run('Premultiplied cached anatomy composes original overlapping glow over bright and dark scenes', anatomy, `
 local state=NewBody();ix.Anatomy.Draw(40,38,66,158,state)
 local layers={drawn[1].color,drawn[2].color,drawn[40].color,Color(255,224,217,190)}
 local pr,pg,pb,pa=0,0,0,0
 for _,c in ipairs(layers) do local a=c.a/255;pr=c.r/255*a+pr*(1-a);pg=c.g/255*a+pg*(1-a);pb=c.b/255*a+pb*(1-a);pa=a+pa*(1-a) end
 for _,scene in ipairs({{0,0,0},{1,1,1},{.6,.2,.8},{.08,.1,.12}}) do
  local cr,cg,cb=scene[1],scene[2],scene[3]
  for _,c in ipairs(layers) do local a=c.a/255;cr=c.r/255*a+cr*(1-a);cg=c.g/255*a+cg*(1-a);cb=c.b/255*a+cb*(1-a) end
  near(cr,pr+scene[1]*(1-pa));near(cg,pg+scene[2]*(1-pa));near(cb,pb+scene[3]*(1-pa))
 end
 ix.Anatomy.DrawHUD(40,38,66,158,state);CheckState()
`);
r.finish();
