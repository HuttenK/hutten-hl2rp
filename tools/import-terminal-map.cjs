// Reproducible, isolated terminal renderer import from the user's E:/map copy.
const fs=require('fs'),path=require('path'),crypto=require('crypto');
const root=path.resolve(__dirname,'..'),source='E:/map/lua',dest=path.join(root,'addons/foundation_map_renderer/lua');
const files=['shared/sh_enums.lua','shared/sh_util.lua','shared/sh_themes.lua','shared/sh_mapdata.lua',
 ...['cl_materials','cl_surface_colours','cl_water','cl_extract','cl_relief','cl_spatial','cl_surface_query','cl_props','cl_bake_cache','cl_bake'].map(x=>'client/geometry/'+x+'.lua'),
 ...['cl_camera','cl_native_props','cl_renderer'].map(x=>'client/render/'+x+'.lua')];
const manifest=[];function hash(s){return crypto.createHash('sha256').update(s).digest('hex');}
function write(file,s,original){const p=path.join(dest,file);fs.mkdirSync(path.dirname(p),{recursive:true});fs.writeFileSync(p,s);manifest.push({file,sourceSha256:hash(original??s),sha256:hash(s)});}
function change(s,a,b){if(!s.includes(a))throw Error('Import anchor missing: '+a);return s.replace(a,b);}
let all='';
for(const file of files){
 const original=fs.readFileSync(path.join(source,'dynamic_minimap',file),'utf8');let s=original.replaceAll('\r\n','\n');
 s=change(s,'local DM = DynamicMinimap','local DM = ix.FoundationMap3D');
 if(file==='shared/sh_themes.lua'){
  const a=s.indexOf('local syncedServerTheme ='),b=s.indexOf('local function luminance(');
  if(a<0||b<a)throw Error('Theme anchors missing');
  s=s.slice(0,a)+`register{ id="foundation", name="Foundation", background=Color(5,13,20),
 monochrome=Color(216,237,243), render={world=Color(186,230,239),terrain=Color(116,161,181),road=Color(216,247,251),prop=Color(139,192,206),water=Color(53,125,161),glass=Color(125,217,226)} }
function Themes.GetActive() return Themes.Get("foundation") end
`+s.slice(b);
 }
 if(file==='client/geometry/cl_bake.lua'){
  s=s.slice(0,s.indexOf('local bootStarted = false'));
  s=change(s,'local BUDGET_CAP     = 0.006','local BUDGET_CAP     = 0.002');
  s=change(s,'hook.Add( "Think", "dm_bake_step", function()','hook.Add( "Think", "dm_bake_step", function()\n\tif not DM.IsActive() then return end');
  s=change(s,'if finished and finished.onDone then','DM.lastError = errorMessage\n\tif finished and finished.onDone then');
 }
 if(file==='client/render/cl_camera.lua')s=change(s,'hook.Add( "Think", "dm_camera_update", Camera.Update )','-- The terminal supplies its own camera; no follow-player hook.');
 if(file==='client/render/cl_native_props.lua'){
  s=change(s,'\tif building then','\tif not DM.IsActive() then return end\n\tif building then');
 }
 if(file==='client/render/cl_renderer.lua'){
  s=change(s,'local clippingWasEnabled = false','');
  s=change(s,'\tstartView( view )\n\n\trender.PushFlashlightMode( false )', '\tstartView( view )\n\tlocal clippingWasEnabled, clipCount, flashlight = false, 0, false\n\tlocal ok, failure = xpcall(function()\n\trender.PushFlashlightMode( false ); flashlight=true');
  s=change(s,'\tif layerOn( DM.LAYER.WORLD ) then\n\t\tapplyThemeModulation( "world" )', '\tif opts.clipZ then clipCount=clipCount+1 end\n\tif opts.clipLow then\n\t\tif clipCount==0 then clippingWasEnabled=render.EnableClipping(true) end\n\t\trender.PushCustomClipPlane(Util.VEC_UP,opts.clipLow);clipCount=clipCount+1\n\tend\n\tif layerOn( DM.LAYER.WORLD ) then\n\t\tapplyThemeModulation( "world" )');
  s=change(s,'\tif opts.extra then opts.extra( view ) end\n\n\tif opts.clipZ then\n\t\trender.PopCustomClipPlane()\n\t\trender.EnableClipping( clippingWasEnabled )\n\tend', '\tif opts.extra then opts.extra( view ) end\n\tend,debug.traceback)\n\tfor _=1,clipCount do render.PopCustomClipPlane() end\n\tif clipCount>0 then render.EnableClipping(clippingWasEnabled) end\n\trender.CullMode(MATERIAL_CULLMODE_CCW)\n\trender.OverrideDepthEnable(false,false)\n\trender.MaterialOverride()\n\trender.SuppressEngineLighting(false)');
  s=change(s,'\trender.PopFlashlightMode()\n\tendView()', '\tif flashlight then render.PopFlashlightMode() end\n\tendView()\n\tif not ok then error(failure,0) end');
 }
 s=s.replaceAll('"dynamic_minimap/','"ix_foundation_map3d/vendor/').replaceAll('"dynamic_minimap"','"ix_foundation_map3d"')
  .replaceAll('"dm_','"ix_ftmap_').replaceAll('"DM_','"IX_FTMAP_').replaceAll('"DynamicMinimap','"IXFoundationMap');
 all+=s;
 write('ix_foundation_map3d/vendor/'+file,'-- Adapted from Dynamic 3D MAP v3.0.0 supplied in E:/map; see source-manifest.json.\n'+s,original);
}
// Keep only configuration consumed by the imported renderer, with no global
// convars, network protocol, standalone HUD, keybinds or editor.
const upstream=fs.readFileSync(path.join(source,'dynamic_minimap/shared/sh_config.lua'),'utf8');
const defs={};for(const m of upstream.matchAll(/register\{ name = "([^"]+)", default = ([^,]+), type = "([^"]+)"/g))defs[m[1].replace('dm_','ix_ftmap_')]={value:m[2],type:m[3]};
const keys=[...new Set([...all.matchAll(/Config\.Get\(\s*"([^"]+)"/g)].map(m=>m[1]))].sort();
const overrides={ix_ftmap_cl_material_colours:'false',ix_ftmap_cl_npcs:'false',ix_ftmap_cl_map_textures:'false',ix_ftmap_cl_skip_ceilings:'true',ix_ftmap_cl_clip_invert:'false',ix_ftmap_sv_prop_lod:'1',ix_ftmap_sv_face_shading:'0.55',ix_ftmap_sv_height_shading:'0.25'};
const rows=keys.map(k=>{const d=defs[k];if(!d)throw Error('Unknown config '+k);let v=overrides[k]??d.value;if(d.type==='bool'&&!(k in overrides))v=['1','true','"1"'].includes(v)?'true':'false';return ` ["${k}"]=${v},`;});
write('ix_foundation_map3d/config.lua',`local DM=ix.FoundationMap3D\nDM.settings={\n${rows.join('\n')}\n}\nDM.Config={Get=function(key) return DM.settings[key] end}\n`);
function copyTree(dir,relative=''){for(const ent of fs.readdirSync(dir,{withFileTypes:true})){const rel=path.posix.join(relative,ent.name);if(ent.isDirectory())copyTree(path.join(dir,ent.name),rel);else if(ent.name.endsWith('.lua'))write('niknaks/'+rel,fs.readFileSync(path.join(dir,ent.name)));}}
copyTree(path.join(source,'niknaks'));
write('includes/modules/niknaks.lua',fs.readFileSync(path.join(source,'includes/modules/niknaks.lua')));
fs.writeFileSync(path.join(dest,'../source-manifest.json'),JSON.stringify({source:'E:/map',version:'3.0.0',note:'Private terminal integration; original NikNaks copyright headers preserved. No original autorun/HUD/editor/network files imported.',files:manifest},null,2)+'\n');
console.log(`Imported ${files.length} renderer modules and NikNaks (${manifest.length} Lua files total).`);
