from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
paths=['ixhl2rp/plugins/facility_utilities/'+s+'.lua' for s in ['cl_ui','cl_devices','sv_jobs']]
paths+=['ixhl2rp/plugins/blackout/sh_plugin.lua','ixhl2rp/plugins/blackout/sv_plugin.lua']
for rel in paths:
 p=ROOT/rel;s=p.read_text(encoding='utf-8')
 s=s.replace('три контакта','пять контактов').replace('тремя контактами','пятью контактами').replace('3 контакта','5 контактов').replace('three-contact','five-stage')
 p.write_text(s,encoding='utf-8')
p=ROOT/'tools/test-facility.cjs';s=p.read_text(encoding='utf-8')
s=s.replace('for i=1,3 do local r=PLUGIN.work[p].repair','for i=PLUGIN.work[p].repair.stage,ix.Facility.repair.contacts do local r=PLUGIN.work[p].repair')
s=s.replace('three scored contacts','five scored contacts').replace('three contacts','five contacts').replace('all three contacts','all five contacts')
s=s.replace('Разомкните 3 контакта','Разомкните 5 контактов').replace('data.stage=4;F.OpenRepair','data.stage=6;F.OpenRepair').replace('final.stage=4','final.stage=6')
s=s.replace("period=7.2,title=", "period=7.2,width=.20,title=")
p.write_text(s,encoding='utf-8')
p=ROOT/'tools/preview-facility-repair.cjs';s=p.read_text(encoding='utf-8')
s=s.replace('period=7.2,','period=6.3,width=.18,')
p.write_text(s,encoding='utf-8')
for rel in ['tools/build-facility-guide.cjs','docs/facility-utilities.md']:
 p=ROOT/rel;s=p.read_text(encoding='utf-8')
 s=s.replace('three-contact','five-stage').replace('Three-contact','Five-stage').replace('Three correctly','Five correctly')
 s=s.replace('three contacts','five contacts').replace('Three contacts','Five contacts').replace('3 contacts','5 contacts')
 s=s.replace('three successes','five successes').replace('three times','five times').replace('all three','all five')
 s=s.replace('The zone changes for the next contact.', 'Each stage moves faster and has a narrower target. A miss retries the same stage without reducing its difficulty.')
 p.write_text(s,encoding='utf-8')
