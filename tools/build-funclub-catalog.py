"""Build authorized full HRP roleplay documents; no remote scripts or website UI."""
from pathlib import Path
from urllib.parse import unquote, urlsplit
from urllib.request import Request, urlopen
import json, hashlib, re, io
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
BASE=ROOT/'ixhl2rp/plugins/foundation_network'
sources=json.loads((ROOT/'docs/funclub-source/crawl.json').read_text(encoding='utf8'))
articles=json.loads((ROOT/'tools/funclub-full-articles.json').read_text(encoding='utf8'))
assert len(articles)==60 and len(sources)==62
by_url={unquote(sources[a['index']]['url']).rstrip('/'):a for a in articles}
asset_dir=ROOT/'addons/foundation_terminal_assets/materials/foundation/hrp'
asset_dir.mkdir(parents=True,exist_ok=True)
def lua(value):
    if value is None: return 'nil'
    if value is True: return 'true'
    if value is False: return 'false'
    if isinstance(value,(int,float)): return str(value)
    if isinstance(value,str): return json.dumps(value,ensure_ascii=False)
    if isinstance(value,list): return '{'+','.join(lua(v) for v in value)+'}'
    return '{'+','.join('['+lua(k)+']='+lua(v) for k,v in value.items())+'}'

catalog={};minimum={};images=[['none','Без изображения']];artwork={};manifest=[]
def roleplay_body(body):
    """Omit player knowledge rules, including children, but retain the next section."""
    kept=[];skip_depth=None;changed=False
    for line in body.splitlines():
        heading=re.match(r'^(#+)\s+(.+)$',line)
        if heading:
            depth=len(heading[1])
            if skip_depth is not None and depth<=skip_depth: skip_depth=None
            title=heading[2].rstrip('#').strip().rstrip(':').strip().lower()
            if skip_depth is None and title in ('знает','не знает'):
                skip_depth=depth;changed=True
        if skip_depth is None: kept.append(line)
    return '\n'.join(kept).rstrip() if changed else body

role_templates={1:'medical',2:'security',7:'engineering',10:'records',11:'research',28:'security',31:'security',32:'logistics',36:'records'}
for a in articles:
    i=a['index'];s=sources[i];id=a['slug'];scp=i>=37
    classification=s['text'].splitlines()[2] if scp else None
    if id=='scp-420-j': classification='Безопасный' # source's humorous spelling; safe icon confirms class
    level=3 if scp and (classification=='Кетер' or id=='scp-079') else (2 if scp or i in role_templates else 1)
    if i in (4,19,20,21,24): level=3
    if i in (15,23,25,26): level=2
    if id=='management': level=3
    if id=='security': level=1
    if id in ('mtf','security-forces','headquarters'): level=1
    # Preserve the established SCP card policy independently of physical object access in the article.
    minimum[id]=level
    template=role_templates.get(i, 'portal' if i in (0,12,13,30,35) else ('bulletin' if i%2 else 'reference'))
    if scp: template={'scp-939-f':'scp939','scp-3114-f':'scp3114'}.get(id,id.replace('-',''))
    if scp and template not in ('scp939','scp173','scp096','scp3114','scp079','scp106','scp049'): template='reference' if i%2 else 'bulletin'
    theme='green' if id=='scp-079' else ('crimson' if classification=='Кетер' else ('amber' if scp else ('cyan' if i%2 else 'slate')))
    image='none';image_source=None
    if a['images']:
        assert len(a['images'])==1,(id,'Multiple article images require explicit gallery layout')
        image_source=a['images'][0]
        assert urlsplit(image_source).hostname=='hrp.funclub.pro'
        target=asset_dir/(id+'.png')
        # The only conversion is unsupported web formats to PNG; no invented/generated artwork.
        if not target.exists():
            with urlopen(Request(image_source,headers={'User-Agent':'Mozilla/5.0'}),timeout=30) as response: raw=response.read()
            img=Image.open(io.BytesIO(raw));img.save(target,'PNG')
        image='hrp-'+id;images.append([image,s['title']]);artwork[image]='foundation/hrp/'+target.name
    links=[];seen=set()
    for link in s['links']:
        dest=by_url.get(unquote(link['url']).rstrip('/'))
        if not dest or dest['slug']==id or dest['slug'] in seen: continue
        seen.add(dest['slug']);links.append({'title':sources[dest['index']]['title'],'url':'scip://web/'+dest['slug']})
    parent='contained-objects' if scp else 'welcome'
    if parent!=id and parent not in seen: links.append({'title':sources[12]['title'] if scp else 'УВС-19F','url':'scip://web/'+parent})
    assert len(links)<=32
    # User confirmed authorization to reproduce complete articles and images.
    assert len(s['title'].encode())<=220 and len(a['body'].encode())<=64000
    summary=('ДОСЬЕ ОБЪЕКТА / '+classification if scp else 'СЛУЖЕБНАЯ ДОКУМЕНТАЦИЯ / УВС-19F')
    category='scp' if scp else ('department' if i in role_templates else 'general')
    row=dict(title=s['title'],summary=summary,body=roleplay_body(a['body']),level=level,published=True,hidden=False,
             links=links,template=template,theme=theme,image=image,category=category,
             source=s['url'],sourceHash=s['sha256'])
    if scp:
        row.update(code=s['title'],classification=classification,status='В ожидании' if i in (44,55,57,58,61) else 'Транзитный список')
        if len(a['classification'])>=3: row.update(disruption=a['classification'][1],risk=a['classification'][2])
    catalog[id]=row
    dimensions=Image.open(target).size if image_source else None
    manifest.append({'slug':id,'title':s['title'],'source':s['url'],'sourceSHA256':s['sha256'],'level':level,'imageDimensions':dimensions,
                     'imageSource':image_source,'image':artwork.get(image),'imageSHA256':hashlib.sha256(target.read_bytes()).hexdigest() if image_source else None})

header='-- Authorized HRP roleplay documents. Provenance is server-side only.\n-- Generated by tools/build-funclub-catalog.py from tools/funclub-full-articles.json.\nlocal P=PLUGIN\n'
migration=r'''
function P:WebLevel(id,page)
 return math.max(tonumber(page.level) or 4,self.webMinimum[id] or 1)
end
function P:StripPlayerKnowledge(body)
 if not isstring(body) then return body end
 local kept,skipDepth,changed={},nil,false
 for line in (body:gsub('\r\n','\n')..'\n'):gmatch('(.-)\n') do
  local hashes,title=line:match('^(#+)%s+(.+)$')
  if hashes then
   local depth=#hashes
   if skipDepth and depth<=skipDepth then skipDepth=nil end
   title=string.Trim(string.Trim(title:gsub('#+$','')):gsub(':$',''))
   -- Lua's ASCII string.lower does not fold Cyrillic headings.
   title=title:gsub('З','з'):gsub('Н','н'):gsub('А','а'):gsub('Е','е'):gsub('Т','т')
   if not skipDepth and (title=='знает' or title=='не знает') then skipDepth=depth;changed=true end
  end
  if not skipDepth then kept[#kept+1]=line end
 end
 if not changed then return body end
 return (table.concat(kept,'\n'):gsub('%s+$',''))
end
function P:RemovePlayerKnowledgeSections()
 if self.store.webKnowledgeRevision=='roleplay-20261002' then return false end
 -- Patch only the requested sections in saved articles; do not reseed the catalog.
 local backups=self.store.webKnowledgeBackups or {}
 for id,page in pairs(self.store.webPages or {}) do
  local body=self:StripPlayerKnowledge(page.body)
  if body~=page.body then
   backups[id]=backups[id] or {body=page.body,revision=page.revision,updated=page.updated}
   page.body=body;page.revision=(tonumber(page.revision) or 0)+1;page.updated=os.time()
  end
 end
 self.store.webKnowledgeBackups=backups
 self.store.webKnowledgeRevision='roleplay-20261002'
 return true
end
function P:SeedWebCatalog()
 if self.store.webSourceRevision==self.webSourceRevision then return self:RemovePlayerKnowledgeSections() end
 -- One-time replacement also applies to servers with saved custom/legacy pages.
 -- Keep an archival copy server-side; it is never included in a page response.
 self.store.webSourceBackups=self.store.webSourceBackups or {}
 local backupKey=self.webSourceRevision
 if not self.store.webSourceBackups[backupKey] then
  self.store.webSourceBackups[backupKey]={time=os.time(),pages=table.Copy(self.store.webPages or {}),
   documents=table.Copy(self.store.documents or {}),seeds=table.Copy(self.store.webSeeds or {}),previousSource=self.store.webSourceRevision}
 end
 local previous=self.store.webPages or {}
 local replacement={}
 for id,definition in pairs(self.webCatalog) do
  local page=table.Copy(definition)
  page.revision=(previous[id] and tonumber(previous[id].revision) or 0)+1
  page.updated=os.time();replacement[id]=page
 end
 self.store.webPages=replacement;self.store.webSeeds={};self.store.documents={}
 self.store.webSourceRevision=self.webSourceRevision
 self:RemovePlayerKnowledgeSections()
 return true
end
'''
(BASE/'sv_catalog.lua').write_text(header+'P.webSourceRevision="hrp-rp-20261002-2"\nP.webMinimum='+lua(minimum)+'\nP.webCatalog={\n'+',\n'.join(' ['+lua(k)+']='+lua(v) for k,v in catalog.items())+'\n}\n'+migration,encoding='utf8')
styles='''-- Presentation choices; article bodies and source inventory remain server-only.
local N=ix.FoundationNet
N.siteTemplates={{'portal','Портал'},{'reference','Технический справочник'},{'bulletin','Бюллетень'},
 {'research','Научный журнал'},{'security','Командный пост'},{'medical','Клинический центр'},
 {'engineering','Сервисная документация'},{'logistics','Реестр'},{'records','Архив'},
 {'scp939','Биоакустика'},{'scp173','Наблюдение'},{'scp096','Изоляция'},
 {'scp3114','Идентификация'},{'scp079','Машинный архив'},{'scp106','Содержание'},{'scp049','Досье'}}
'''
(BASE/'sh_webstyles.lua').write_text(styles+'N.siteImages='+lua(images)+'\nN.artwork='+lua(artwork)+'\nif SERVER then for _,path in pairs(N.artwork) do resource.AddFile("materials/"..path) end end\n',encoding='utf8')
(ROOT/'docs/funclub-catalog-manifest.json').write_text(json.dumps({'origin':'https://hrp.funclub.pro/','snapshot':'2026-10-02','authorized':True,'pages':manifest},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'pages':len(catalog),'scp':sum(x['category']=='scp' for x in catalog.values()),'images':len(artwork),'bytes':sum(f.stat().st_size for f in asset_dir.glob('*.png'))}))
