"""Scoped model/catalog update, retaining original files for review and deployment."""
from pathlib import Path
import json
import re
import shutil
import sys

ROOT = Path(__file__).resolve().parent.parent
RUN = ROOT / '.runtime/item-models-20261013'
CONFIG = json.loads((ROOT / 'tools/item-model-replacements.json').read_text(encoding='utf-8'))
FILES = [p for base in ('ixhl2rp', 'helix') for p in (ROOT / base).rglob('*.lua')]
ITEMS = {}
for p in FILES:
    if '/items/' in p.as_posix() and 'items_disabled' not in p.parts and '_old' not in p.parts:
        key = re.sub(r'^(?:sh_|sv_|cl_)', '', p.stem)
        ITEMS.setdefault(key, []).append(p)

def text(p):
    return p.read_text(encoding='utf-8-sig')

def item_path(key):
    candidates = [p for p in ITEMS.get(key, []) if re.search(r'\bITEM\.model\s*=', text(p))]
    assert len(candidates) == 1, (key, candidates)
    return candidates[0]

def backup(p):
    dest = RUN / 'before' / p.relative_to(ROOT)
    if not dest.exists():
        dest.parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(p, dest)

manifest = RUN / 'changes.json'
changes = json.loads(manifest.read_text(encoding='utf-8')) if manifest.exists() else {}
def flush():
    RUN.mkdir(parents=True, exist_ok=True)
    manifest.write_text(json.dumps(changes, indent=2), encoding='utf-8')

def save(p, source):
    if source == text(p): return
    backup(p)
    p.write_text(source, encoding='utf-8', newline='\n')
    changes[p.relative_to(ROOT).as_posix()] = 'modified'
    flush()

def remove(p):
    assert p.resolve().is_relative_to(ROOT)
    backup(p)
    p.unlink()
    changes[p.relative_to(ROOT).as_posix()] = 'removed'
    flush()

def model_source(source, model, skin=0):
    source, count = re.subn(r'(^[ \t]*ITEM\.model\s*=\s*)(?:Model\()?"[^"]+"\)?', lambda m: m[1] + json.dumps(model), source, flags=re.M)
    assert count == 1, count
    # Old camera framing and cover skins belong to the replaced model.
    source = re.sub(r'^[ \t]*ITEM\.iconCam\s*=\s*\{[^{}]*\}[ \t]*(?:\n|$)', '', source, flags=re.M)
    source = re.sub(r'^[ \t]*ITEM\.skin\s*=\s*\d+[^\n]*(?:\n|$)', '', source, flags=re.M)
    if skin:
        source = re.sub(r'(^[ \t]*ITEM\.model[^\n]*\n)', lambda m: m[1] + 'ITEM.skin = ' + str(skin) + '\n', source, count=1, flags=re.M)
    return source

def inspect():
    for key in CONFIG['models']:
        p = item_path(key)
        details = [line for line in text(p).splitlines() if re.search(r'ITEM\.(model|skin|icon_model|name|description|junk|displayID)\s*=', line)]
        print(key, p.relative_to(ROOT).as_posix(), ' | '.join(details))
    for key in CONFIG['retired'].values():
        if key.startswith('selected_eft_'): continue
        item_path(key)

def apply():
    for key, model in CONFIG['models'].items():
        p=item_path(key)
        source=model_source(text(p), model, CONFIG['skins'].get(key,0))
        if key=='canned_squash':
            source=source.replace('ITEM.stats.container = true','ITEM.stats.container = false')
            source=re.sub(r'^ITEM\.junk[^\n]*(?:\n|$)','',source,flags=re.M)
        if key in ('junk_zippo','xen_extract'):
            for field,suffix in (('name',''),('description','.desc')):
                source=re.sub(r'^(ITEM\.'+field+r'\s*=\s*)"[^"\n]*"',lambda m:m[1]+json.dumps('item.'+key+suffix),source,flags=re.M)
        if key=='bag_cp': source=source.replace('ITEM.displayID = "backpack_cp"','ITEM.displayID = "backpack"')
        save(p,source)
    for p in (ROOT / 'ixhl2rp/plugins/skill_books/items/skillbook').glob('*.lua'):
        save(p,model_source(text(p),CONFIG['learningBookModel']))
    p=ROOT / 'ixhl2rp/plugins/languages/sh_plugin.lua'
    save(p,model_source(text(p),CONFIG['learningBookModel']))
    p=ROOT / 'ixhl2rp/plugins/arccw_item_atts/entities/entities/ix_gunsmith.lua'
    save(p,re.sub(r'ENT.Model = "[^"]+"','ENT.Model = '+json.dumps(CONFIG['models']['gunsmith_bench']),text(p),count=1))
    p=ROOT / 'ixhl2rp/plugins/paperwork/items/book.lua'
    save(p,text(p).replace('return L("item.book")','return (SERVER and l or L)("item.book")'))

    locales=json.loads((ROOT/'tools/item-model-locales.json').read_text(encoding='utf-8'))
    for key,values in locales.items():
        owner=item_path(key)
        prefix=owner.as_posix().split('/items/')[0]
        for language,(name,description) in values.items():
            p=Path(prefix)/'languages'/f'{language}.lua'
            # Transvil items use the schema locale tables.
            if not p.exists(): p=ROOT/'ixhl2rp/schema/languages'/f'{language}.lua'
            source=text(p)
            for phrase,value in (('item.'+key,name),('item.'+key+'.desc',description)):
                pattern=r'^'+re.escape(phrase)+r'\s*=.*$'
                line=phrase+' = '+json.dumps(value,ensure_ascii=False)
                if re.search(pattern,source,re.M): source=re.sub(pattern,lambda _:line,source,flags=re.M)
                else: source=source.rstrip()+'\n'+line+'\n'
            save(p,source)
    # Matching recipe captions must use the new names too.
    for p in FILES:
        if '/recipes_' not in p.as_posix() or '/languages/' not in p.as_posix(): continue
        source=text(p);language=p.stem
        for key,values in locales.items():
            if language not in values: continue
            source=re.sub(r'^(recipe\.(?:crafting|cooking|electric)\.'+re.escape(key)+r'\s*=).*$',lambda m:m[1]+' '+json.dumps(values[language][0],ensure_ascii=False),source,flags=re.M)
        save(p,source)

    p=ROOT/'helix/gamemode/game/items/cl_spawn.items.lua'
    save(p,re.sub(r'^\s*\["item.category.weapon_parts"\][^\n]*\n','',text(p),flags=re.M))
    # Ketchup no longer requires another bottle of ketchup as its seasoning.
    p=ROOT/'ixhl2rp/plugins/recipes_cooking/cooking/ketchup.lua'
    save(p,text(p).replace('cook_spices = 1','cook_sugar = 1'))
    for relative in ('ixhl2rp/plugins/transvil/items/sh_tranq_injector.lua',
                     'ixhl2rp/plugins/transvil/items/weapon/sh_transvilisator.lua'):
        p=ROOT/relative
        save(p,text(p).replace('нейротоксином Зен-флоры','растительным нейротоксином').replace('нейротоксином из Зен-флоры','растительным нейротоксином'))
    p=ROOT/'ixhl2rp/plugins/recipes_crafting/crafting/5/neurotoxin.lua'
    save(p,text(p).replace('-- очищенная вытяжка','-- нейротоксичное растение'))
    for p in FILES:
        if '/recipes_' not in p.as_posix() or p.stem not in CONFIG['models']: continue
        save(p,re.sub(r'^(RECIPE.preview\s*=\s*)"[^"]+"',lambda m:m[1]+json.dumps(CONFIG['models'][p.stem]),text(p),flags=re.M))

    retired=CONFIG['retired']
    removed=set()
    for key in retired:
        candidates=[p for p in ITEMS.get(key,[]) if p.exists() and ('ITEM.category = "Инструменты и материалы"' in text(p) or 'ITEM.category = "item.category.weapon_parts"' in text(p))]
        for p in candidates: removed.add(p);remove(p)
    for p in FILES:
        if not p.exists() or '/recipes_crafting/' not in p.as_posix() or '/languages/' in p.as_posix(): continue
        source=text(p)
        results=re.search(r'RECIPE.results\s*=\s*\{([^}]+)\}',source)
        if results:
            ids=re.findall(r'\b([a-z_0-9]+)\s*=',results[1])
            if ids and all(key.startswith('gun_') and key in retired for key in ids):
                removed.add(p);remove(p)
    # The old mace recipe itself is obsolete; its legacy saved item maps to the
    # maintained melee catalog, while current melee recipes remain authoritative.
    p=ROOT/'ixhl2rp/plugins/recipes_crafting/crafting/4/melee_mace.lua'
    if p.exists(): removed.add(p);remove(p)

    aliases=ROOT/'ixhl2rp/plugins/ammo_cringe/sh_legacy_items.lua'
    for p in FILES:
        if not p.exists() or p==aliases or '_old' in p.parts or 'items_disabled' in p.parts: continue
        raw=p.read_bytes()
        if not any(key.encode('ascii') in raw for key in retired) and b'item.category.weapon_parts' not in raw: continue
        source=text(p)
        if '/languages/' in p.as_posix():
            # No remaining catalog item may resurrect either retired category.
            source=re.sub(r'^item\.category\.weapon_parts\s*=.*\n','',source,flags=re.M)
            for key in retired:
                source=re.sub(r'^item\.'+re.escape(key)+r'(?:\.desc)?\s*=.*\n','',source,flags=re.M)
        elif p.name=='ix_factory_recycler.lua':
            # Existing replacement material rates take priority; combining nine
            # obsolete part rates would inflate the yield of one generic item.
            for key,target in retired.items():
                line=re.compile(r'^[ \t]*'+re.escape(key)+r'\s*=.*\n',re.M)
                if key.startswith('gun_'): source=line.sub('',source)
                else: source=re.sub(r'\b'+re.escape(key)+r'(?=\s*=)',target,source)
        else:
            for key,target in retired.items():
                source=re.sub(r'(["\'])'+re.escape(key)+r'\1',lambda m:m[1]+target+m[1],source)
                source=re.sub(r'(?<![\w.])'+re.escape(key)+r'(?=\s*=)',target,source)
            # Several removed weapon parts can collapse into the same ingredient.
            def merge_requirements(match):
                body=match[1];totals={};order=[]
                rows=re.findall(r'^[ \t]*(\w+)\s*=\s*(\d+)\s*,?\s*(?:--[^\n]*)?$',body,re.M)
                if len(rows)!=len(re.findall(r'\b\w+\s*=',body)): return match[0]
                for key,value in rows:
                    if key not in totals: order.append(key);totals[key]=0
                    totals[key]+=int(value)
                if len(rows)==len(order): return match[0]
                return 'RECIPE.requirements = {\n'+''.join('\t'+k+' = '+str(totals[k])+',\n' for k in order)+'}'
            source=re.sub(r'RECIPE.requirements\s*=\s*\{([^{}]*)\}',merge_requirements,source)
            source=re.sub(r'(\w+:HasItem\("tool_screw"\)) or \1',r'\1',source)
            source=re.sub(r'((?:has|item)\(p,"tool_screw"\)) or \1',r'\1',source)
        save(p,source)
    source=text(aliases)
    for key,target in retired.items():
        line='ix.Item.legacyIDs['+json.dumps(key)+'] = '+json.dumps(target)
        pattern=r'^ix\.Item\.legacyIDs\["'+re.escape(key)+r'"\].*$'
        if re.search(pattern,source,re.M): source=re.sub(pattern,lambda _:line,source,flags=re.M)
        else: source=source.rstrip()+'\n'+line+'\n'
    save(aliases,source)
    print(json.dumps({'modelItems':len(CONFIG['models']),'changedFiles':len(changes),'removedFiles':[p for p,a in changes.items() if a=='removed']},ensure_ascii=False,indent=2))

if __name__ == '__main__':
    apply() if '--apply' in sys.argv else inspect()
