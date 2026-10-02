import struct, re
d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
RD=(0x329000,0x34E595)
def cstr(rva,n=64):
    j=d.find(b'\0', rva); t=d[rva:min(j,rva+n)]
    return t.decode() if t and all(32<=c<127 for c in t) else None
recs={}
for off in range(RD[0], RD[1]-12, 4):
    p=struct.unpack_from('<I', d, off)[0]; sz=struct.unpack_from('<I', d, off+4)[0]
    if not (BASE+RD[0] <= p < BASE+0x3A0000): continue
    nm=cstr(p-BASE)
    if nm and re.match(r'^C?[A-Za-z][A-Za-z0-9_]{2,}$', nm) and 4<=sz<=0x2000: recs.setdefault(nm, (off,sz))
# names DancingMad asserts; check presence in OUR build's descriptor table AND as a raw string
names=['CMoLockLookAtDriveTask','CMoActorRotationDriveTask','CMoSchedularTask','CMoOtTask','CMoProcessor',
       'CMoSkeletonElem','CXiSkeletonActor','CXiActorDraw','CXiAtelActor','CXiControlActor','CXiCollisionActor',
       'CYyMotionQue','CYySkl','CYyObject','StAvatar','StChannel','StModel','StTrigger',
       'sqskSkeleton','sqmoKeyChannel','sqmoMixerMotion','sqmdModelLookAt','XiZone','KzSKD','CMoTaskMng']
print(f"{'name':28s} descriptor(ours)   raw-string-in-image")
for n in names:
    desc = recs.get(n)
    has_str = (n.encode() in d)
    print(f"{n:28s} {('0x%06X size=0x%X'%desc) if desc else '-':24s} {'yes' if has_str else 'no'}")
# our dancer module file count, verified locally
mods=set(); BS=chr(92)
for m in re.finditer((r'C:'+BS+BS+'dev'+BS+BS+r'dancer'+BS+BS+'modules'+BS+BS+ r'([A-Za-z0-9_]+)'+BS), open('tables_strings.csv', encoding='utf-8', errors='replace').read()):
    mods.add(m.group(1))
print("\nOUR-BUILD dancer modules seen in strings:", len(mods), sorted(mods))
