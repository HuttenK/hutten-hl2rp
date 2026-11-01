"""Author a small editable RP pose library on the archived SD skeleton.

Uses original limb lengths and two-bone IK, then emits local rotations for
Pose Studio. This is an offline mesh check, not a GMod rendering test.
"""
from pathlib import Path
import json, math
import numpy as np

ROOT = Path(__file__).resolve().parent.parent
BONES = json.loads((ROOT/'tools/sectorial-hand-rig.json').read_text())['bones']
PREFIX = 'ValveBiped.Bip01_'
IDS = {b['name'].removeprefix(PREFIX): b['id'] for b in BONES}

def rot(x=0, y=0, z=0):
    x,y,z = map(math.radians, (x,y,z))
    cx,sx,cy,sy,cz,sz = math.cos(x),math.sin(x),math.cos(y),math.sin(y),math.cos(z),math.sin(z)
    return np.array([[cz,-sz,0],[sz,cz,0],[0,0,1]]) @ np.array([[cy,0,sy],[0,1,0],[-sy,0,cy]]) @ np.array([[1,0,0],[0,cx,-sx],[0,sx,cx]])

LOCAL = {}
for b in BONES:
    m=np.eye(4); m[:3,:3]=rot(*np.degrees(b['rotation'])); m[:3,3]=b['position']; LOCAL[b['id']]=m

# The compiled SD reference mesh faces -Y; gameplay idles face +X.
ROOT_TURN=np.eye(4); ROOT_TURN[:3,:3]=rot(z=90)
LOCAL[IDS['Pelvis']]=ROOT_TURN@LOCAL[IDS['Pelvis']]

def worlds(local):
    result={}
    for b in BONES:
        i,p=b['id'],b['parent']; result[i]=result[p]@local[i] if p>=0 else local[i].copy()
    return result

BIND=worlds(LOCAL)
def unit(v):
    return np.array(v)/max(np.linalg.norm(v),1e-12)

def align(a,b):
    a,b=unit(a),unit(b); v=np.cross(a,b); c=np.dot(a,b)
    if c < -.999999:
        axis=unit(np.cross(a,[0,0,1] if abs(a[2])<.9 else [0,1,0]))
        return 2*np.outer(axis,axis)-np.eye(3)
    k=np.array([[0,-v[2],v[1]],[v[2],0,-v[0]],[-v[1],v[0],0]])
    return np.eye(3)+k+k@k/(1+c)

def set_world_rotation(local,name,r):
    i=IDS[name]; p=BONES[i]['parent']; w=worlds(local)
    local[i][:3,:3]=(w[p][:3,:3].T if p>=0 else np.eye(3))@r

def ik(local,chain,target,pole):
    a,b,c=map(IDS.get,chain); w=worlds(local); start=w[a][:3,3]
    l1=np.linalg.norm(local[b][:3,3]); l2=np.linalg.norm(local[c][:3,3])
    v=np.array(target)-start; distance=np.linalg.norm(v)
    assert abs(l1-l2)+.01 < distance < l1+l2-.01, (chain,target,distance,l1+l2)
    axis=unit(v); bend=np.array(pole)-start; bend=unit(bend-axis*np.dot(bend,axis))
    along=(l1*l1-l2*l2+distance*distance)/(2*distance)
    elbow=start+axis*along+bend*math.sqrt(max(0,l1*l1-along*along))
    for i,j,goal in [(a,b,elbow),(b,c,np.array(target))]:
        w=worlds(local); r=align(w[j][:3,3]-w[i][:3,3],goal-w[i][:3,3])@w[i][:3,:3]
        set_world_rotation(local,BONES[i]['name'].removeprefix(PREFIX),r)
    assert np.linalg.norm(worlds(local)[c][:3,3]-target)<.00001

def hand(local,side,direction,palm_normal):
    # SD hand local X points towards the fingers; opposite Z normals mirror palms.
    x=unit(direction); z=unit(np.array(palm_normal)-x*np.dot(palm_normal,x))
    if side=='L': z=-z
    y=unit(np.cross(z,x)); set_world_rotation(local,side+'_Hand',np.column_stack((x,y,z)))

def fingers(local,side,style='relaxed'):
    # Local Z is the flexion axis of the SD finger chains.
    sign=-1 if side=='R' else 1
    for f in range(1,5):
        for joint in ('','1','2'):
            i=IDS[side+'_Finger'+str(f)+joint]
            curl=({'straight':0,'relaxed':12,'closed':48}[style] if joint else {'straight':0,'relaxed':8,'closed':35}[style])
            local[i][:3,:3]=rot(z=sign*curl)
    for joint in ('','1','2'):
        i=IDS[side+'_Finger0'+joint]
        if not joint:
            local[i][:3,:3]=rot(x=-sign*60,y=sign*({'straight':0,'relaxed':10,'closed':25}[style]),z=sign*({'straight':0,'relaxed':5,'closed':20}[style]))
        else:
            local[i][:3,:3]=rot(z=sign*(15 if style=='closed' else 3))

def arms(local,left,right,left_pole,right_pole):
    ik(local,['L_UpperArm','L_Forearm','L_Hand'],left,left_pole)
    ik(local,['R_UpperArm','R_Forearm','R_Hand'],right,right_pole)

POSES=[]
def make(id,name,label,kind):
    local={i:m.copy() for i,m in LOCAL.items()}
    if kind.startswith('sit'):
        local[IDS['Pelvis']][2,3]-=18.5
        for side,s in [('L',1),('R',-1)]:
            ik(local,[side+'_Thigh',side+'_Calf',side+'_Foot'],[18,s*6,4],[25,s*6,23])
            set_world_rotation(local,side+'_Foot',BIND[IDS[side+'_Foot']][:3,:3])
    else:
        # Feet planted, softly unlocked knees, a restrained shoulder-width stance.
        for side,s in [('L',1),('R',-1)]:
            start=BIND[IDS[side+'_Foot']][:3,3].copy(); start[1]=s*4.8; start[2]+=.6
            ik(local,[side+'_Thigh',side+'_Calf',side+'_Foot'],start,[8,s*5,20])
            set_world_rotation(local,side+'_Foot',BIND[IDS[side+'_Foot']][:3,:3])
    if kind=='sit_forward':
        local[IDS['Spine']][:3,:3]=local[IDS['Spine']][:3,:3]@rot(z=14)
    for side in ['L','R']: fingers(local,side)
    # World targets measured in Source units on the actual SD body.
    if kind=='salute':
        arms(local,[0,8,36],[5.5,-8.5,66],[-2,13,44],[0,-22,55])
        hand(local,'R',[0,1,.12],[0,0,-1]); fingers(local,'R','straight')
        hand(local,'L',[0,0,-1],[0,-1,0])
    elif kind in ('cuffed_front','cuffed_back','at_ease'):
        x,z=(8,39) if kind=='cuffed_front' else (-7,37) if kind=='cuffed_back' else (-6,39)
        arms(local,[x,2.5,z],[x,-2.5,z],[x*.4,14,42],[x*.4,-14,42])
        for side,s in [('L',1),('R',-1)]:
            hand(local,side,[0,0,-1],[0,-s,0]); fingers(local,side,'closed' if kind!='at_ease' else 'relaxed')
    elif kind=='standing_relaxed':
        local[IDS['Head1']][:3,:3]=local[IDS['Head1']][:3,:3]@rot(x=6)
        arms(local,[1.5,8,36],[6,-6,39],[-3,13,44],[0,-15,45])
        for side,s in [('L',1),('R',-1)]: hand(local,side,[0,0,-1],[0,-s,0])
    elif kind=='attention':
        arms(local,[0,7.8,36],[0,-7.8,36],[-2,12,44],[-2,-12,44])
        for side,s in [('L',1),('R',-1)]: hand(local,side,[0,0,-1],[0,-s,0]); fingers(local,side,'straight')
    elif kind=='sit_formal':
        arms(local,[10,5.5,26.5],[10,-5.5,26.5],[2,11,30],[2,-11,30])
        for side,s in [('L',1),('R',-1)]: hand(local,side,[1,0,-.15],[0,0,-1]); fingers(local,side,'straight')
    elif kind=='sit_forward':
        arms(local,[15,4,26.5],[15,-4,26.5],[12,9,29],[12,-9,29])
        for side in ['L','R']: hand(local,side,[1,0,-.5],[0,0,-1])
    POSES.append(dict(id=id,name=name,label=label,kind=kind,local=local,world=worlds(local)))

if __name__=='__main__':
    for args in [
        ('salute','Салют — воинское приветствие','SALUTE','salute'),
        ('cuffed_front','Наручники — руки спереди','CUFFED / FRONT','cuffed_front'),
        ('cuffed_back','Наручники — руки за спиной','CUFFED / BEHIND','cuffed_back'),
        ('attention','Стоя — смирно','ATTENTION','attention'),
        ('at_ease','Стоя — руки за спиной','AT EASE','at_ease'),
        ('standing_relaxed','Стоя — рука у пояса','RELAXED','standing_relaxed'),
        ('sit_formal','Сидя — руки на бёдрах','SEATED / UPRIGHT','sit_formal'),
        ('sit_forward','Сидя — наклон вперёд','SEATED / FORWARD','sit_forward')]: make(*args)
    # Keep exact matrices as authoring data. Conversion to editor Euler deltas
    # happens against a real sampled idle, avoiding guessed animation offsets.
    lines=['-- Generated by tools/build-starter-poses.py; SD male04 authoring rig.',
           'ix.PoseStudio.starterPoses = {']
    export=[]
    for pose in POSES:
        seated=pose['kind'].startswith('sit')
        lines.append(' {id="%s",name="%s",seated=%s,base="%s",rootPosition={%s},bones={'%(pose['id'],pose['name'],'true' if seated else 'false','custom_male_sit06' if seated else 'ragdoll',','.join('%.9f'%v for v in pose['local'][IDS['Pelvis']][:3,3])))
        for b in BONES:
            name=b['name']
            if not name.startswith(PREFIX) or any(x in name for x in ['Forward','attachment','Anim_Attachment']): continue
            m=pose['local'][b['id']]
            # Only the exact 53 editor anatomical bones belong in the preset.
            short=name.removeprefix(PREFIX)
            import re
            if not re.fullmatch(r'(Pelvis|Spine[124]?|Neck1|Head1|[LR]_(Clavicle|UpperArm|Forearm|Hand|Thigh|Calf|Foot|Toe0|Finger[0-4][12]?))',short): continue
            lines.append('  ["%s"]={%s},'%(name,','.join('%.9f'%v for v in m[:3,:3].flatten())))
        lines.append(' }},')
        export.append({k:v for k,v in pose.items() if k not in ['local','world']} | {'world':{str(i):m.tolist() for i,m in pose['world'].items()}})
    lines.append('}')
    lines.append('ix.PoseStudio.starterAnatomy = {')
    for b in BONES:
        m=np.eye(4);m[:3,:3]=rot(*np.degrees(b['rotation']));m[:3,3]=b['position']
        lines.append(' {name="%s",parent=%d,m={%s}},'%(b['name'],b['parent'],','.join('%.9f'%v for v in m[:3,:].flatten())))
    lines.append('}')
    (ROOT/'ixhl2rp/plugins/pose_studio/cl_starter_data.lua').write_text('\n'.join(lines)+'\n',encoding='utf-8')
    (ROOT/'docs/pose-starter-matrices.json').write_text(json.dumps(export),encoding='utf-8')
    # Small reusable fixture from the original SD animation sources. Tests use
    # real base rotations, not identity matrices that hide Euler/order errors.
    animdir=Path('E:/Codex-Archives/HL2RP-2026-09-26/Desktop/SD-DClass-work/source/male04/citizen_male_04_hair4_anims')
    samples={}
    for base in ['ragdoll','custom_male_sit06']:
        text=(animdir/(base+'.smd')).read_text().split('skeleton')[1].split('time 0')[1]
        matrices={}
        for line in text.splitlines():
            values=line.split()
            if not values: continue
            if values[0] in ['end','time']: break
            i=int(values[0]); pos=list(map(float,values[1:4])); angles=list(map(float,values[4:7]))
            m=np.eye(4);m[:3,:3]=rot(*np.degrees(angles));m[:3,3]=pos
            matrices[str(i)]=m[:3,:].flatten().round(9).tolist()
        samples[base]=matrices
    fixture={'bones':BONES,'samples':samples}
    (ROOT/'tools/fixtures/pose-starter-source.json').write_text(json.dumps(fixture,separators=(',',':')),encoding='utf-8')
    print('Authored',len(POSES),'poses; all IK targets reachable; original limb lengths preserved.')
