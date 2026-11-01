const r=require('./restored-test-runner.cjs');
module.exports=suite=>{
 const setup=`
 CLIENT=true;SERVER=false
 ix.lang={AddTable=function() end};ix.Net={Type={},AddPlayerVar=function() end}
 ix.char={loaded={}};ix.faction={indices={},teams={citizen={models={}}}};ix.voice={}
 function Color() return {} end
 FACTION={index=2};${r.source(['ixhl2rp/schema/factions/sh_foundation.lua'])}
 ix.faction.indices[2]=FACTION
 FACTION={index=3};${r.source(['ixhl2rp/schema/factions/sh_mtf.lua'])}
 ix.faction.indices[3]=FACTION;FACTION=nil;ix.faction.indices[1]={}
 function L(value) return value end
 function LocalPlayer() return viewer end
 function person(id,faction,name)
  local c=setmetatable({id=id,faction=faction,name=name},{__index=ix.meta.character})
  local p={valid=true,char=c,recognize={}}
  function c:GetID() return self.id end;function c:GetFaction() return self.faction end
  function c:GetPlayer() return p end;function c:GetName() return self.name end
  function c:GetDescription() return 'Description' end
  function p:GetCharacter() return self.char end;function p:Team() return self.char.faction end
  function p:GetNetVar(_,default) return self.hidden and id or default end
  function p:Name() return self.char.name end
  ix.char.loaded[id]=c;return p,c
 end
 hook.Run=function(name,...) if PLUGIN[name] then return PLUGIN[name](PLUGIN,...) end end
 `;
 const source=['helix/plugins/recognition.lua'];
 suite('Foundation and MTF recognize their own faction live without exposing hidden identities or changing aliases',source,`
 local a,ac=person(10,2,'Scientist');local b,bc=person(11,2,'Doctor');local c,cc=person(12,3,'Operative')
 viewer=a
 assert(ac:DoesRecognize(bc));eq(PLUGIN:GetCharacterName(b),'Doctor');eq(ac:DoesRecognize(cc),nil)
 eq(PLUGIN:GetCharacterName(c),'unknown');eq(next(a.recognize),nil)
 a.recognize[11]='Known alias';eq(PLUGIN:GetCharacterName(b),'Known alias')
 b.hidden=true;eq(ac:DoesRecognize(bc),false);eq(PLUGIN:GetCharacterName(b),'unknown');b.hidden=false
 a.recognize[11]=nil;bc.faction=3;eq(ac:DoesRecognize(bc),nil);eq(PLUGIN:GetCharacterName(b),'unknown')
 ac.faction=3;assert(ac:DoesRecognize(bc));assert(ac:DoesRecognize(cc));eq(PLUGIN:GetCharacterName(b),'Doctor')
 ac.faction=1;bc.faction=1;eq(ac:DoesRecognize(bc),nil);eq(PLUGIN:GetCharacterName(b),'unknown')
 a.recognize[11]='Remembered citizen';assert(ac:DoesRecognize(bc));eq(PLUGIN:GetCharacterName(b),'Remembered citizen')
 ac.faction=2;bc.faction=2;bc.name='Renamed colleague';a.recognize={};eq(PLUGIN:GetCharacterName(b),'Renamed colleague')
 a.recognize=nil;bc.faction=1;eq(ac:DoesRecognize(bc),nil)
 CLIENT=false;SERVER=true;eq(ac:DoesRecognize(bc),nil);bc.faction=2;assert(ac:DoesRecognize(bc))
 `,setup);
 suite('Voice labels use same-faction names and saved aliases while respecting hidden identities and transfers',source,`
 local V=ix.voice
 ${r.native('ixhl2rp/plugins/proximity_voice/cl_voice.lua','function V.RadioSpeakerName','function PLUGIN:HUDPaint()')}
 local a,ac=person(10,2,'Scientist');local b,bc=person(11,2,'Doctor');viewer=a
 eq(V.RadioSpeakerName(a,b),'Doctor');a.recognize[11]='Saved alias';eq(V.RadioSpeakerName(a,b),'Saved alias')
 b.hidden=true;eq(V.RadioSpeakerName(a,b),'Неизвестный');b.hidden=false;a.recognize={}
 bc.faction=3;eq(V.RadioSpeakerName(a,b),'Неизвестный');ac.faction=3;eq(V.RadioSpeakerName(a,b),'Doctor')
 ac.faction=1;bc.faction=1;eq(V.RadioSpeakerName(a,b),'Неизвестный')
 `,setup);
};
