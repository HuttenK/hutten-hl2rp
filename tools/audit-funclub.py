"""Read public same-site pages only; retain a reproducible source inventory offline."""
from pathlib import Path
from urllib.request import Request, urlopen
from urllib.parse import urljoin, urlsplit, urlunsplit, quote, unquote
from concurrent.futures import ThreadPoolExecutor
import json, hashlib, time
from bs4 import BeautifulSoup

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT/'docs/funclub-source'
OUT.mkdir(exist_ok=True)
HOST = 'hrp.funclub.pro'
def canonical(url):
    p = urlsplit(url)
    if p.hostname != HOST or p.query or '/wp-' in p.path or p.path.endswith(('.jpg','.png','.pdf','.zip','.webp')): return None
    return urlunsplit(('https', HOST, quote(unquote(p.path).rstrip('/')+'/', safe='/'), '', ''))
def fetch(url):
    try:
        with urlopen(Request(url, headers={'User-Agent':'Mozilla/5.0'}), timeout=30) as r:
            raw = r.read(); final = canonical(r.url)
        soup = BeautifulSoup(raw.decode('utf-8'), 'html.parser')
        main = soup.select_one('main')
        if not main: raise ValueError('No main content')
        for tag in main.select('script,style,svg'): tag.decompose()
        title = soup.title.get_text(' ',strip=True).removesuffix(' - УВС-19F')
        links = [{'title':a.get_text(' ',strip=True), 'url':urljoin(url,a['href'])} for a in main.select('a[href]')]
        images = [{'url':urljoin(url,i.get('src','')), 'alt':i.get('alt','')} for i in main.select('img[src]')]
        content = main.get_text('\n',strip=True)
        return {'url':final, 'title':title, 'text':content, 'links':links, 'images':images, 'sha256':hashlib.sha256(raw).hexdigest()}
    except Exception as e: return {'url':url,'error':str(e)}
pending = {'https://hrp.funclub.pro/'};seen=set(); pages=[]
while pending:
    batch=sorted(pending-seen);pending=set()
    if not batch: break
    if len(seen)+len(batch)>200: raise RuntimeError('Unexpected crawl size')
    seen.update(batch)
    with ThreadPoolExecutor(max_workers=3) as pool:
        for p in pool.map(fetch,batch):
            pages.append(p)
            print(p['title'] if 'title' in p else p, flush=True)
            for link in p.get('links',[]):
                dest=canonical(link['url'])
                if dest and dest not in seen: pending.add(dest)
    time.sleep(.3)
pages.sort(key=lambda p:p['url'])
(OUT/'crawl.json').write_text(json.dumps(pages,ensure_ascii=False,indent=2),encoding='utf-8')
for i,p in enumerate(pages):
    if 'text' in p: (OUT/f'{i:03}.txt').write_text(p['title']+'\n'+p['url']+'\n\n'+p['text'],encoding='utf-8')
print(json.dumps({'pages':len(pages),'errors':[p for p in pages if 'error' in p]}))
