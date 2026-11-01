"""Package and install the reviewed terminal catalogue with backups and hash checks."""
from pathlib import Path
from urllib.parse import urlsplit
import datetime, hashlib, json, re, shutil, zipfile
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
LIVE = Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod/garrysmod').resolve()
assert (LIVE/'gamemodes/ixhl2rp').is_dir()
audit = json.loads((ROOT/'docs/source-audit.json').read_text(encoding='utf8'))
assert not audit['syntaxFailures']
audited = {entry['path']: entry['sha256'] for entry in audit['entries']}
raw = (ROOT/'docs/funclub-test-run.txt').read_bytes()
log = raw.decode('utf-16' if raw.startswith((b'\xff\xfe', b'\xfe\xff')) else 'utf-8-sig')
passed = re.search(r'(\d+) regression suites passed\.', log)
assert passed and int(passed.group(1)) >= 213
source_manifest = json.loads((ROOT/'docs/funclub-catalog-manifest.json').read_text(encoding='utf8'))
crawl = json.loads((ROOT/'docs/funclub-source/crawl.json').read_text(encoding='utf8'))
pages = source_manifest['pages']
assert len(pages) == len(crawl) == 62 and not any('error' in p for p in crawl)
assert {p['source'] for p in pages} == {p['url'] for p in crawl}
assert len({p['slug'] for p in pages}) == 62
hashes = {p['url']: p['sha256'] for p in crawl}
sha = lambda p: hashlib.sha256(p.read_bytes()).hexdigest()

files = []
for src in sorted((ROOT/'ixhl2rp/plugins/foundation_network').rglob('*.lua')):
    rel = src.relative_to(ROOT)
    assert audited[rel.as_posix()] == sha(src), 'Syntax audit is stale: '+str(rel)
    files.append((src, Path('gamemodes')/rel))
for page in pages:
    assert urlsplit(page['source']).hostname == 'hrp.funclub.pro'
    assert hashes[page['source']] == page['sourceSHA256']
    if not page['image']:
        continue
    assert urlsplit(page['imageSource']).hostname == 'hrp.funclub.pro'
    src = ROOT/'addons/foundation_terminal_assets/materials'/page['image']
    assert sha(src) == page['imageSHA256']
    with Image.open(src) as im:
        assert list(im.size) == page['imageDimensions']
        im.verify()
    files.append((src, Path('materials')/page['image']))
assert len({rel.as_posix() for _, rel in files}) == len(files)
assert len([p for p in pages if p['image']]) == 22

OUT = Path('E:/Codex-Archives')/('HL2RP-HRP-terminal-v8-'+datetime.datetime.now().strftime('%Y%m%d-%H%M%S'))
OUT.mkdir(parents=True, exist_ok=False)
PACKAGE, BACKUP = OUT/'package', OUT/'before-local'
records = []
for src, destrel in files:
    src, target = src.resolve(), (LIVE/destrel).resolve()
    assert src.is_relative_to(ROOT) and target.is_relative_to(LIVE)
    existed = target.exists()
    if existed:
        backup = BACKUP/destrel
        backup.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(target, backup)
        assert sha(target) == sha(backup)
    staged = PACKAGE/'garrysmod'/destrel
    staged.parent.mkdir(parents=True, exist_ok=True)
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(src, staged)
    shutil.copy2(src, target)
    assert sha(src) == sha(staged) == sha(target)
    records.append({'path':destrel.as_posix(), 'sha256':sha(src), 'bytes':src.stat().st_size, 'previouslyExisted':existed})

shutil.copy2(ROOT/'docs/funclub-terminal-v8.md', PACKAGE/'README.md')
shutil.copy2(ROOT/'docs/funclub-catalog-manifest.json', PACKAGE/'source-manifest.json')
manifest = {'localInstall':str(LIVE), 'backup':str(BACKUP), 'files':records,
            'source':'https://hrp.funclub.pro/', 'pages':62, 'scpPages':25, 'images':22,
            'tests':int(passed.group(1)), 'syntaxFiles':audit['files'], 'engineTested':False}
(PACKAGE/'manifest.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
archive = OUT/'HL2RP-HRP-terminal-v8.zip'
with zipfile.ZipFile(archive,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=6) as z:
    for p in PACKAGE.rglob('*'):
        if p.is_file():
            z.write(p,p.relative_to(PACKAGE))
with zipfile.ZipFile(archive) as z:
    assert z.testzip() is None
    for record in records:
        assert hashlib.sha256(z.read('garrysmod/'+record['path'])).hexdigest() == record['sha256']
manifest.update(archive=str(archive),archiveSHA256=sha(archive))
(ROOT/'docs/funclub-v8-deployment.json').write_text(json.dumps(manifest,indent=2),encoding='utf8')
print(json.dumps({'files':len(records), 'archive':str(archive), 'backup':str(BACKUP), 'sha256':sha(archive)},indent=2))
