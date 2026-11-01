"""Import the owner's authorized HRP articles as in-world documents.

Reads inert cached HTML only. Website scripts, styling and outbound navigation
are never executed or included. The user confirmed reproduction permission.
"""
from pathlib import Path
from urllib.parse import urlsplit
from bs4 import BeautifulSoup, Tag, NavigableString
import json, re

ROOT=Path(__file__).resolve().parent.parent
DIR=ROOT/'docs/funclub-source'
sources=json.loads((DIR/'crawl.json').read_text(encoding='utf8'))
old=json.loads((ROOT/'tools/funclub-articles.json').read_text(encoding='utf8'))
# These two documents are instructions for players/software, not Foundation records.
excluded={16:'SCP:SL plugins and console commands',22:'Out-of-character newcomer/server rules guide'}
results=[];audit=[]

def clean(s):
    s=re.sub(r'[\t\r\xa0 ]+',' ',s).strip()
    s=re.sub(r' +([,.;:!?])',r'\1',s)
    return s

def plain(e):
    return clean(e.get_text(' ',strip=True))

for source in old:
    i=source['index']
    if i in excluded: continue
    soup=BeautifulSoup((DIR/f'{i:03}.html').read_text(encoding='utf8'),'html.parser')
    for e in soup.select('script,style,svg,noscript,nav,footer,header,.post-navigation'): e.decompose()
    root=soup.select_one('[data-elementor-type="wp-post"], [data-elementor-type="wp-page"]') or soup.select_one('main')
    lines=[];removed=[];images=[];classification=[]
    def emit(s,heading=False):
        s=clean(s)
        if not s: return
        if s==sources[i]['title']: return
        if heading:
            # Strip only a matching outer pair; do not break embedded labels
            # such as "Уровень 3 [Секретно]".
            if s.startswith('[') and s.endswith(']'): s=s[1:-1].strip()
            s='# '+s
        if not lines or s!=lines[-1]: lines.append(s)
    def walk(e):
        if isinstance(e,NavigableString):
            if clean(str(e)): emit(str(e))
            return
        if not isinstance(e,Tag): return
        kind=e.get('data-widget_type','')
        if kind in ('spacer.default','eael-fancy-text.default'): return
        if kind=='divider.default':
            emit(plain(e),True);return
        if kind=='wpr-button.default':
            # Internal navigation is rebuilt from the source inventory. Personnel
            # names remain in the local roster; external biographies are not fetched.
            if i==5 and plain(e).startswith('Личное дело'): emit(plain(e))
            return
        if kind in ('eael-adv-tabs.default','tabs.default'):
            if kind=='eael-adv-tabs.default':
                titles=[t for t in e.select('.eael-tab-title') if t.find_parent(attrs={'data-widget_type':True}) is e]
                panels=[t for t in e.select('.eael-tabs-content > .eael-tab-content-item') if t.find_parent(attrs={'data-widget_type':True}) is e]
            else:
                titles=e.select('.elementor-tabs-wrapper > .elementor-tab-title')
                panels=e.select('.elementor-tabs-content-wrapper > .elementor-tab-content')
            assert len(titles)==len(panels),(i,len(titles),len(panels))
            for title,panel in zip(titles,panels): emit(plain(title),True);walk_children(panel)
            return
        if kind in ('eael-adv-accordion.default','accordion.default'):
            selector='.eael-accordion-list' if kind.startswith('eael') else '.elementor-accordion-item'
            for item in e.select(selector):
                if item.find_parent(attrs={'data-widget_type':True}) is not e: continue
                title=item.select_one('.eael-accordion-tab-title, .elementor-accordion-title')
                panel=item.select_one('.eael-accordion-content, .elementor-tab-content')
                if title: emit(plain(title),True)
                if panel: walk_children(panel)
            return
        if kind=='image-box.default':
            if i>=37: classification.append(plain(e))
            else: emit(plain(e))
            return
        if e.name=='img':
            url=e.get('src','')
            if urlsplit(url).hostname=='hrp.funclub.pro' and 'x-mark' not in url and url not in images:
                images.append(url)
            return
        if e.name=='table':
            headers=[]
            for tr in e.select('tr'):
                cells=tr.find_all(['th','td'],recursive=False)
                values=[plain(c) for c in cells]
                if cells and all(c.name=='th' for c in cells): headers=values;continue
                emit(' / '.join((headers[j]+': ' if j<len(headers) and headers[j] else '')+v for j,v in enumerate(values) if v))
            return
        if e.name in ('p','h1','h2','h3','h4','h5','h6','li','blockquote'):
            # Paragraphs can contain authored line breaks and inline formatting.
            for br in e.select('br'): br.replace_with('<<<BR>>>')
            parts=e.get_text(' ',strip=True).split('<<<BR>>>')
            for part in parts:
                value=clean(part)
                strong=' '.join(plain(t) for t in e.find_all(['strong','b']))
                heading=e.name.startswith('h') or (len(value)<150 and (value.startswith('[') and value.endswith(']') or value==strong))
                emit(('• ' if e.name=='li' and not value.startswith(('○','•')) else '')+value,heading)
            return
        walk_children(e)
    def walk_children(e):
        # Preserve inline spans as one phrase; recurse only through block containers.
        if not e.find(['div','section','p','h1','h2','h3','h4','ul','ol','table','img','blockquote'],recursive=False):
            emit(plain(e));return
        for child in list(e.children): walk(child)
    walk(root)
    # Authoring corrections below remove website/game context, not in-world rules.
    # Each removed paragraph is retained in the private audit for review.
    if i==0:
        lines=['# Участок Временного Содержания 19F','Внутренняя сеть УВС-19F. Документы участка: объекты на содержании, учебные материалы, процедуры восстановления условий содержания и справочная информация.']
    if i==35:
        lines=['# Подготовка персонала','Материалы по обязанностям, задачам, отношениям и знаниям сотрудников УВС-19F. Выберите документ своей службы в разделе связанных документов.']
    if i==30:
        lines=['# Справочный отдел','Документация по классификации аномалий, системе идентификации персонала, силовым структурам, амнезиакам и мнестикам, меметике, специальному снаряжению и процедурам блокировки.']
    revised=[]
    for line in lines:
        original=line
        # Turn direct role/player framing into a personnel instruction without
        # changing duties, object behavior or recorded events.
        line=line.replace('информации, доступной вашему персонажу','информации, доступной сотруднику')
        line=line.replace('информации, доступной Вашему персонажу','информации, доступной сотруднику')
        line=re.sub(r'считаются нарушением правила 2\.4\.?','недопустимы.',line)
        if i==21 and 'принести живую приманку' in line:
            line='○ Необходимо пройти в камеру содержания данного объекта. Далее в специальную комнату необходимо принести живую приманку и поставить на платформу. После этого около специального терминала инициируется восстановление условий содержания данного объекта.'
        if i==36:
            line=line.replace('Для появления [Штаба] требуется:', 'Установление связи со Штабом').replace('Когда пропадает:', 'Потеря связи со Штабом')
        if re.search(r'Tier\s*4|SERVER SPECIFIC|консоль игр|клавиш|кнопк.*["«].*["»]|администратор[а-яё ]+раунд|плагин|на нашем сервер|игрок|геймплей|дискорд|discord',line,re.I):
            removed.append(original);continue
        if re.search(r'https?://|docs\.google|hrp\.funclub',line,re.I):
            removed.append(original);continue
        revised.append(line)
    # Remove empty headings caused only by out-of-character paragraph exclusions.
    lines=[]
    for j,line in enumerate(revised):
        if line.startswith('# ') and (j==len(revised)-1 or revised[j+1].startswith('# ')): continue
        lines.append(line)
    body='\n'.join(lines).strip()
    results.append(dict(index=i,slug=source['slug'],title=sources[i]['title'],summary='',body=body,images=images,classification=classification))
    audit.append(dict(index=i,slug=source['slug'],sourceBytes=len(sources[i]['text'].encode()),bodyBytes=len(body.encode()),sections=body.count('# '),removed=removed,images=images))

(ROOT/'tools/funclub-full-articles.json').write_text(json.dumps(results,ensure_ascii=False,indent=2),encoding='utf8')
(ROOT/'docs/funclub-import-audit.json').write_text(json.dumps({'permission':'User confirmed full text and image reuse on 2026-10-02','excluded':excluded,'pages':audit},ensure_ascii=False,indent=2),encoding='utf8')
print(json.dumps({'pages':len(results),'bytes':sum(len(a['body'].encode()) for a in results),'maximum':max((len(a['body'].encode()),a['slug']) for a in results),'omissions':sum(len(a['removed']) for a in audit),'images':sum(len(a['images']) for a in audit)}))
