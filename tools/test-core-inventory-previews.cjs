const fs = require('fs');
const path = require('path');
const {normalize} = require('./glua.cjs');
const root = path.resolve(__dirname, '..');
const itemClass = fs.readFileSync(path.join(root, 'helix/gamemode/game/items/sh_item.class.lua'), 'utf8');
// Use the real base getters; custom overrides must fail the production allowlist.
const getters = ['GetModel', 'GetSkin', 'GetMaterial'].map(name =>
  itemClass.match(new RegExp(`function ITEM:${name}\\(\\)[^\\r\\n]*`))[0]).join('\n') + '\n' +
  itemClass.slice(itemClass.lastIndexOf('function ITEM:GetIconModel()'), itemClass.indexOf('\n\tlocal queue_ents'));
const setup = fs.readFileSync(path.join(__dirname, 'fixtures/core-inventory-previews.lua'), 'utf8') +
  '\ndo\nlocal ITEM=ix.meta.Item\n' + normalize(getters) + '\nend\n';
const files = ['helix/gamemode/game/inventory/ui/cl_inventory_item.lua'];
module.exports = suite => {
 const check = (name, body) => suite(name, files, body, setup);
 check('Static preview repeated/resize rebuilds retain one model and refresh tooltip, drop and camera', `
 local slot=newSlot(newItem()); slot:Rebuild(); local mdl=slot.mdl
 for i=1,100 do slot.w=64+i; slot:Rebuild() end
 eq(slot.mdl,mdl); eq(createdModels,1); eq(createdPanels,1); eq(cameraCalls,101)
 eq(slot.tooltipUpdates,101); eq(slot.dropUpdates,101)
 `);
 check('Model, icon model, skin, rotation and item dimensions invalidate static previews', `
 local item=newItem(); local slot=newSlot(item); slot:Rebuild()
 item.model='changed.mdl'; slot:Rebuild(); eq(createdModels,2)
 item.icon_model='icon.mdl'; slot:Rebuild(); eq(createdModels,3)
 item.skin=3; slot:Rebuild(); eq(createdModels,4); eq(slot.mdl.Entity.skin,3)
 slot:Turn(); eq(createdModels,5); eq(slot.rotated,true); eq(slot.mdl.lookAng.r,-83)
 item.width=3; slot:Rebuild(); eq(createdModels,6)
 item.height=2; slot:Rebuild(); eq(createdModels,7)
 `);
 check('In-place camera vectors, angles and FOV invalidate; camera removal restores automatic setup', `
 local item=newItem({iconCam={pos=Vector(1,2,3),ang=Angle(4,5,6),fov=32}})
 local slot=newSlot(item); slot:Rebuild(); slot:Rebuild(); eq(createdModels,1)
 item.iconCam.pos.x=2; slot:Rebuild(); eq(createdModels,2); eq(slot.mdl.camPos.x,2)
 item.iconCam.ang.r=10; slot:Rebuild(); eq(createdModels,3); eq(slot.mdl.lookAng.r,10)
 item.iconCam.fov=40; slot:Rebuild(); eq(createdModels,4); eq(slot.mdl.fov,40)
 item.iconCam=nil; slot:Rebuild(); eq(createdModels,5); eq(slot.mdl.camPos.x,2)
 `);
 check('Custom appearance getters always rebuild even when their returned value is unchanged', `
 for _,name in ipairs({'GetModel','GetIconModel','GetSkin','GetMaterial','GetIconData'}) do
  local item=newItem(); local original=item[name]
  item[name]=function(self) return original(self) end
  local slot=newSlot(item); local count=createdModels
  slot:Rebuild(); slot:Rebuild(); eq(createdModels,count+2)
 end
 local item=newItem(); function item:GetMaterial() return self.tint end
 item.tint='first'; local slot=newSlot(item); slot:Rebuild(); item.tint='second'; slot:Rebuild()
 eq(slot.mdl.Entity.material,'second')
 `);
 check('LayoutIcon stays live and receives a fresh preview on rebuild', `
 local calls=0; local item=newItem({LayoutIcon=function(_,panel,entity) calls=calls+1; entity.fill=calls end})
 local slot=newSlot(item); slot:Rebuild(); local first=slot.mdl
 slot:Paint(64,32); slot:Paint(64,32); eq(calls,2); eq(first.Entity.fill,2)
 slot:Rebuild(); assert(slot.mdl~=first); eq(createdModels,2)
 slot:Paint(64,32); eq(calls,3)
 `);
 check('Late custom-item model delivery reloads through original LayoutEntity path', `
 local item=newItem({isCustomBase=true,data={checksum='late'}})
 local slot=newSlot(item); slot:Rebuild(); eq(slot.mdl.reload,true)
 slot:Rebuild(); eq(createdModels,2)
 item.model='delivered.mdl'; ix.CustomItem.stored.late={}
 slot.mdl:LayoutEntity(slot.mdl.Entity)
 eq(slot.mdl.Entity.model,'delivered.mdl'); eq(slot.mdl.reload,nil); eq(createdModels,3)
 slot:Rebuild(); eq(createdModels,4)
 `);
 check('ARC9 keeps original rebuild path and safely transitions to an ordinary preview', `
 ix.WeaponAssembly={Supports=function(item) return item.weapon end}
 local item=newItem({weapon=true}); local slot=newSlot(item); slot:Rebuild(); local first=slot.mdl
 slot:Rebuild(); assert(slot.mdl~=first); eq(slot.mdl.class,'ixARC9ItemIcon'); eq(createdModels,0)
 item.weapon=nil; slot:Rebuild(); eq(slot.mdl.class,'DModelPanel'); eq(createdModels,1)
 item.weapon=true; slot:Rebuild(); eq(slot.mdl.class,'ixARC9ItemIcon'); eq(removedModels,1)
 ix.WeaponAssembly=nil; slot:Rebuild(); eq(slot.mdl.class,'DModelPanel'); eq(createdModels,2)
 `);
 check('Missing models retry, and externally removed model entities cannot be reused', `
 local slot=newSlot(newItem()); failModel=true; slot:Rebuild(); eq(createdModels,1)
 eq(slot.mdl.ixStaticPreviewState,nil)
 failModel=false; slot:Rebuild(); eq(createdModels,2); assert(IsValid(slot.mdl.Entity))
 slot.mdl.Entity:Remove(); slot:Rebuild(); eq(createdModels,3); assert(IsValid(slot.mdl.Entity))
 `);
 check('Valid error-placeholder models retry and externally changed appearance is rebuilt', `
 local slot=newSlot(newItem()); errorModel=true; slot:Rebuild(); eq(createdModels,1)
 errorModel=false; slot:Rebuild(); eq(createdModels,2); eq(slot.mdl.Entity.model,'models/test.mdl')
 slot.mdl.Entity:SetSkin(2); slot:Rebuild(); eq(createdModels,3); eq(slot.mdl.Entity.skin,0)
 slot.mdl.Entity:SetMaterial('foreign'); slot:Rebuild(); eq(createdModels,4); eq(slot.mdl.Entity.material,'')
 slot.mdl.Entity.model='foreign.mdl'; slot:Rebuild(); eq(createdModels,5)
 `);
 check('Changed item identity, getter hot reload and newly introduced dynamic hook invalidate', `
 local slot=newSlot(newItem()); slot:Rebuild(); slot.item_data=newItem(); slot:Rebuild(); eq(createdModels,2)
 local getter=ix.meta.Item.GetSkin; ix.meta.Item.GetSkin=function(self) return getter(self) end
 slot:Rebuild(); eq(createdModels,3)
 slot.item_data.LayoutIcon=function() end; slot:Rebuild(); slot:Rebuild(); eq(createdModels,5)
 `);
 check('Reset releases preview resources while preserving transfer flags; empty-to-item creates anew', `
 local slot=newSlot(newItem()); slot:Rebuild(); slot.pendingTransfer='pending'; slot.reservedTransferTarget=true
 slot:Reset(); eq(slot.mdl,nil); eq(removedModels,1); eq(slot.pendingTransfer,'pending'); eq(slot.reservedTransferTarget,true)
 slot.item_data=newItem(); slot:Rebuild(); eq(createdModels,2)
 `);
 check('Live draw and item overlays continue on reused previews without cached transient appearance', `
 local over,paint=0,0; local item=newItem({PaintOver=function() over=over+1 end,PaintSlot=function() paint=paint+1 end})
 local slot=newSlot(item); slot:Rebuild(); slot:Rebuild()
 slot:Paint(64,32); slot:PaintOver(64,32); slot:Paint(64,32); slot:PaintOver(64,32)
 eq(createdModels,1); eq(renderedModels,2); eq(over,2); eq(paint,2)
 `);
};

if (require.main === module) {
 const {lua,lauxlib,lualib,to_luastring,to_jsstring}=require('fengari');
 let passed=0;
 module.exports((name, paths, assertions, prelude) => {
  const state=lauxlib.luaL_newstate(); lualib.luaL_openlibs(state);
  const source=[prelude,...paths.map(file=>'do\n'+normalize(fs.readFileSync(path.join(root,file),'utf8'))+'\nend'),assertions].join('\n');
  const result=lauxlib.luaL_dostring(state,to_luastring(source));
  if(result!==lua.LUA_OK) throw new Error(name+': '+to_jsstring(lua.lua_tostring(state,-1)));
  passed++; console.log('PASS '+name);
 });
 console.log(`${passed} inventory preview checks passed; rendering is mocked.`);
}
