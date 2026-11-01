"""Package reviewed changes and the supplied addons; install locally with backups."""
from pathlib import Path
from urllib.parse import urlsplit
import datetime, hashlib, json, re, shutil, zipfile
from PIL import Image

ROOT=Path(__file__).resolve().parent.parent
LIVE=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
assert (LIVE/'gamemodes/ixhl2rp').is_dir()
audit=json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited={e['path']:e['sha256'] for e in audit['entries']}
sha=lambda p:hashlib.sha256(p.read_bytes()).hexdigest()
raw=(ROOT/'docs/rp-update-test-run.txt').read_bytes()
log=raw.decode('utf-16' if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else 'utf-8-sig')
passed=re.search(r'(\d+) regression suites passed\.',log)
assert passed and int(passed.group(1))>=224
catalog=json.loads((ROOT/'docs/funclub-catalog-manifest.json').read_text(encoding='utf8'))
pages=catalog['pages'];assert len(pages)==60
files=[]
for name in ['foundation_network','status_display','scp610_control']:
    for p in sorted((ROOT/'ixhl2rp/plugins'/name).rglob('*.lua')):
        files.append((p,Path('gamemodes')/p.relative_to(ROOT)))
for name in ['ammo_cringe/items/base/weapon.lua','ammo_cringe/sh_arc9.lua','ammo_cringe/items/weapon/sh_flamethrower_m2.lua','ammo_cringe/items/weapon/sh_flamethrower_fm35.lua','infectionzone/sv_plugin.lua']:
    p=ROOT/'ixhl2rp/plugins'/name
    files.append((p,Path('gamemodes')/p.relative_to(ROOT)))
for src,_ in files:
    assert audited[src.relative_to(ROOT).as_posix()]==sha(src),'Stale syntax audit: '+str(src)
for page in pages:
    assert urlsplit(page['source']).hostname=='hrp.funclub.pro'
    if not page['image']:continue
    src=ROOT/'addons/foundation_terminal_assets/materials'/page['image']
    assert sha(src)==page['imageSHA256']
    with Image.open(src) as im:
        assert list(im.size)==page['imageDimensions'];im.verify()
    files.append((src,Path('materials')/page['image']))
assert len([p for p in pages if p['image']])==23
dependencies=[]
for source,dest in [('flamethrower','foundation_flamethrower'),('610','foundation_scp610_npcs'),('610-2','foundation_scp610_models')]:
    source_root=Path('E:/')/source
    for p in sorted(source_root.rglob('*')):
        if p.is_file():dependencies.append((p,Path('addons')/dest/p.relative_to(source_root)))
assert len({rel.as_posix() for _,rel in files+dependencies})==len(files+dependencies)
OUT=Path('E:/Codex-Archives')/('HL2RP-foundation-v9-20261002-'+datetime.datetime.now().strftime('%H%M%S'))
OUT.mkdir(parents=True,exist_ok=False)
backup=OUT/'before-local';records=[]
def install_zip(name,entries):
    archive=OUT/name;subset=[]
    with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
        z.write(ROOT/'docs/foundation-v9.md','README.md')
        for src,rel in entries:
            target=(LIVE/rel).resolve();assert target.is_relative_to(LIVE)
            original=target.exists()
            if original:
                b=backup/rel;b.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(target,b)
                assert sha(b)==sha(target)
            z.write(src,'garrysmod/'+rel.as_posix())
            target.parent.mkdir(parents=True,exist_ok=True);shutil.copy2(src,target)
            digest=sha(src);assert sha(target)==digest
            row={'path':rel.as_posix(),'bytes':src.stat().st_size,'sha256':digest,'previouslyExisted':original}
            subset.append(row);records.append(row)
        z.writestr('files.json',json.dumps(subset,indent=2))
    with zipfile.ZipFile(archive) as z:
        assert z.testzip() is None
        for row in subset:assert hashlib.sha256(z.read('garrysmod/'+row['path'])).hexdigest()==row['sha256']
    result={'path':str(archive),'sha256':sha(archive),'files':len(subset),'bytes':archive.stat().st_size}
    print(json.dumps(result),flush=True);return result
archives=[install_zip('HL2RP-foundation-v9.zip',files),install_zip('HL2RP-thermal-scp610-addons.zip',dependencies)]
manifest={'localInstall':str(LIVE),'backup':str(backup),'archives':archives,'files':records,
          'pages':60,'scpPages':25,'images':23,'tests':int(passed.group(1)),'syntaxFiles':audit['files'],'engineTested':False}
(ROOT/'docs/foundation-v9-deployment.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
(OUT/'deployment.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
shutil.copy2(ROOT/'docs/foundation-v9.md',OUT/'README.md')
print('Local files and both ZIP archives verified.',flush=True)
