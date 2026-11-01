const fs=require('fs'),{run,finish}=require('./restored-test-runner.cjs');
const code=fs.readFileSync('tools/ix_animation_content_check.lua','utf8');
const fixture=`
local script=[====[${code}]====]
local reports, nextReport = {}, 0
local rows, output, sent, writes = {}, {}, {}, {}
local world='server'
function SysTime() return 123.456 end
VERSIONSTR='test';BRANCH='test'
function GetConVar() return {GetString=function() return '1' end} end
function util.CRC(s) local sum=0;for i=1,#s do sum=(sum*31+s:byte(i))%10000007 end;return tostring(sum) end
function util.TableToJSON(t) nextReport=nextReport+1;local key='json'..nextReport;reports[key]=t;return key end
function util.JSONToTable(s) return reports[s] end
function print(...) local words={};for _,v in ipairs({...}) do words[#words+1]=tostring(v) end;output[#output+1]=table.concat(words,' | ') end
file={Read=function(path,realm) if path=='ix_animation_content_check.lua' then return script end;return rows[world..':'..path] end,
 CreateDir=function() end,Write=function(path,data) writes[world..':'..path]=reports[data] end}
local delayed={};timer.Simple=function(delay,fn) delayed[#delayed+1]=fn end
local p={valid=true}
function p:GetModel() return 'models/a.mdl' end
function p:GetSequenceList() return world=='client' and clientNames or {'idle','walk'} end
function p:GetSequenceCount() return #self:GetSequenceList() end
function p:EntIndex() return 1 end
function p:Nick() return 'Test player' end
function p:SendLua(payload) sent[#sent+1]=payload end
player.GetAll=function() return {p} end;player.GetHumans=player.GetAll
net.Start=function() outgoing={} end
net.WriteString=function(s) outgoing[#outgoing+1]=s end
net.SendToServer=function() end
net.ReadString=function() return table.remove(outgoing,1) end
local function mdl(includes,ani)
 local fields={};for i=1,600 do fields[i]='\\0' end
 local function put(offset,s) for i=1,#s do fields[offset+i]=s:sub(i,i) end end
 local function int(offset,n) put(offset,string.char(n%256,math.floor(n/256)%256,math.floor(n/65536)%256,0)) end
 put(0,'IDST');int(336,#includes);int(340,360)
 local cursor=400
 for i,path in ipairs(includes) do int(360+(i-1)*8+4,cursor-(360+(i-1)*8));put(cursor,path..'\\0');cursor=cursor+#path+1 end
 if ani then int(352,2);int(348,550);put(550,ani..'\\0') end
 return table.concat(fields)
end
local original=mdl({'models/b.mdl'},'models/a.ani')
rows['server:models/a.mdl']=original;rows['client:models/a.mdl']=original
rows['server:models/b.mdl']=mdl({'models/a.mdl'});rows['client:models/b.mdl']=rows['server:models/b.mdl']
rows['server:models/a.ani']='animation data';rows['client:models/a.ani']='animation data'
clientNames={'idle','walk'}
local function Start()
 SERVER=true;CLIENT=false;world='server';assert(load(script))()
 eq(#sent,1);assert(#sent[1]<6000)
end
local function Reply()
 SERVER=false;CLIENT=true;world='client';assert(load(sent[1]))()
 SERVER=true;CLIENT=false;world='server'
 net.handlers.ixAnimationContentAudit(8000,p)
 return writes['server:ix_animation_content_audit/latest.json']
end
`;
run('Content audit follows MDL and ANI dependencies, stops include cycles, and compares matching server/client reports',fixture+`
Start();local result=Reply()
assert(result.server.files['models/b.mdl']);assert(result.server.files['models/a.ani'])
assert(result.clients['1']);assert(table.concat(output,' | '):find('Differences: | 0',1,true))
`);
run('Content audit distinguishes missing data, changed library bytes and reordered loaded sequences',fixture+`
rows['client:models/a.ani']=nil;rows['client:models/b.mdl']='different version';clientNames={'walk','idle'}
Start();local result=Reply();local text=table.concat(output,' | ')
assert(text:find('DIFFERENT: | models/a.ani',1,true));assert(text:find('DIFFERENT: | models/b.mdl',1,true))
assert(text:find('LOADED SEQUENCES:',1,true));assert(text:find('Differences: | 3',1,true))
`);
run('Content audit rejects unsolicited, expired and oversized replies; valid replies are accepted once',fixture+`
Start();local outsider={valid=true};outgoing={}
net.handlers.ixAnimationContentAudit(8000,outsider);eq(#outgoing,0)
net.handlers.ixAnimationContentAudit(262145,p);eq(#outgoing,0)
clock=41;net.handlers.ixAnimationContentAudit(8000,p);eq(#outgoing,0);clock=10
local result=Reply();outgoing={};net.handlers.ixAnimationContentAudit(8000,p);eq(#outgoing,0)
assert(result.clients['1'])
`);
finish();
