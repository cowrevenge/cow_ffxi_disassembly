import struct, re, csv
d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
RD=(0x329000,0x34E595)
def cstr(rva,n=64):
    j=d.find(b'\0', rva); t=d[rva:min(j,rva+n)]
    return t.decode(errors='replace') if t and all(32<=c<127 for c in t) else None
recs=[]
for off in range(RD[0], RD[1]-12, 4):
    p=struct.unpack_from('<I', d, off)[0]
    sz=struct.unpack_from('<I', d, off+4)[0]
    par=struct.unpack_from('<I', d, off+8)[0]
    if not (BASE+RD[0] <= p < BASE+RD[1]+0x60000): continue
    nm=cstr(p-BASE)
    if not nm or not re.match(r'^C?[A-Z][A-Za-z0-9_]{2,}$', nm): continue
    if not (4 <= sz <= 0x2000): continue
    recs.append((off,nm,sz,par))
print("descriptor-like records:", len(recs))
byname={n:(o,s,p) for o,n,s,p in recs}
def chain(n, depth=0, seen=None):
    seen=seen or set()
    out=[n]
    if n in byname and n not in seen:
        seen.add(n); par=byname[n][2]-BASE
        for o,m,s,p in recs:
            if p==par+BASE or (o==par):
                return out+chain(m, depth+1, seen)
    return out
for key in ['CMoLockLookAtDriveTask','CMoActorRotationDriveTask','CMoLockColorDriveTask','CMoSchedularTask','CXiSkeletonActor','CMoSkeletonElem']:
    hit=[r for r in recs if r[1]==key]
    for o,n,s,p in hit:
        par=next((x[1] for x in recs if x[0]+BASE==p), hex(p))
        print(f"  {key:28s} desc=0x{o:X} size={s:#x} parent={par}")
print("\n=== all animation/motion-family descriptors (Mo*/Xi*Anim*) ===")
for o,n,s,p in recs:
    if re.match(r'^(CMo|CXi(Anim|Skel|Model)|sq)', n): print(f"  {n:32s} desc=0x{o:X} size={s:#x}")
