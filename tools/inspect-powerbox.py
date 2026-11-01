"""Read installed archive indexes and inspect powerbox model data without changing game assets."""
from pathlib import Path
import struct, io, json, hashlib
ROOT=Path(__file__).resolve().parent.parent
GAME=Path('C:/Program Files (x86)/Steam/steamapps/common/GarrysMod')
OUT=ROOT/'docs/powerbox-inspection'
OUT.mkdir(exist_ok=True)
TARGET='models/props_c17/powerbox'
def cstr(f):
    value=bytearray()
    while True:
        c=f.read(1)
        if not c or c==b'\0': return value.decode('utf-8',errors='replace')
        value.extend(c)
        if len(value)>1000000: raise ValueError('Invalid archive string')
def u32(f): return struct.unpack('<I',f.read(4))[0]
found=[]
def save(source,name,data,title=''):
    folder=OUT/str(len(found));folder.mkdir(exist_ok=True)
    file=folder/Path(name).name;file.write_bytes(data)
    row=dict(source=str(source),title=title,path=name,sha256=hashlib.sha256(data).hexdigest(),extracted=str(file))
    if name.endswith('.mdl'):
        def at(fmt,o): return struct.unpack_from('<'+fmt,data,o)
        def string(o): return data[o:data.index(b'\0',o)].decode(errors='replace')
        n,b=at('2i',156)
        row.update(version=at('i',4)[0],hullMin=at('3f',104),hullMax=at('3f',116),viewMin=at('3f',128),viewMax=at('3f',140),bones=[])
        for i in range(n):
            base=b+216*i
            row['bones'].append(dict(id=i,name=string(base+at('i',base)[0]),parent=at('i',base+4)[0],pos=at('3f',base+32),rot=at('3f',base+60),poseToBone=at('12f',base+96)))
    found.append(row)
for directory in [GAME/'garrysmod/cache/workshop',GAME/'garrysmod/addons',GAME/'garrysmod/data',Path('C:/Program Files (x86)/Steam/steamapps/workshop/content/4000')]:
    for path in directory.rglob('*.gma'):
        try:
            with path.open('rb') as f:
                if f.read(4)!=b'GMAD': continue
                f.seek(21)
                while cstr(f): pass
                title=cstr(f);cstr(f);cstr(f);u32(f)
                matches=[];offset=0
                while u32(f):
                    name=cstr(f);size=struct.unpack('<Q',f.read(8))[0];u32(f)
                    if name.lower().startswith(TARGET+'.'): matches.append((name,size,offset))
                    offset+=size
                start=f.tell()
                for name,size,offset in matches:
                    f.seek(start+offset);save(path,name,f.read(size),title)
        except (ValueError,struct.error) as e: print('Skip',path.name,str(e))
for path in GAME.rglob('*_dir.vpk'):
    with path.open('rb') as f:
        signature,version,length=struct.unpack('<III',f.read(12))
        if signature!=0x55aa1234: continue
        header=12 if version==1 else 28;f.seek(header);tree=io.BytesIO(f.read(length))
        while (ext:=cstr(tree)):
            while (directory:=cstr(tree)):
                while (base:=cstr(tree)):
                    crc,preload,archive,offset,size,term=struct.unpack('<IHHIIH',tree.read(18));prefix=tree.read(preload)
                    name=(directory+'/' if directory!=' ' else '')+base+'.'+ext
                    if name.lower().startswith(TARGET+'.'):
                        archivePath=path if archive==0x7fff else path.with_name(path.name.replace('_dir.vpk',f'_{archive:03}.vpk'))
                        with archivePath.open('rb') as data:
                            data.seek(offset+(header+length if archive==0x7fff else 0));save(path,name,prefix+data.read(size),'Valve VPK')
(OUT/'index.json').write_text(json.dumps(found,ensure_ascii=False,indent=2),encoding='utf-8')
for row in found:
    if 'bones' in row: print(json.dumps(row,ensure_ascii=False,indent=2))
print('Files:',len(found))
