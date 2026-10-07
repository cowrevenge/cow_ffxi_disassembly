import struct
d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
SKIP=0x328000  # end of .text; tables live after this
thunks=[('CMoPathDriveActorTask',0x56940),('CMoLockColorDriveTask',0x56960),
        ('CMoLockLookAtDriveTask',0x56980),('CMoActorColorDriveTask',0x569A0),
        ('CMoActorRotationDriveTask',0x569C0)]
def hits_for(t):
    pat=struct.pack('<I', BASE+t); out=[]; i=SKIP
    while True:
        j=d.find(pat, i)
        if j<0: break
        out.append(j); i=j+1     # offset == RVA in this image
    return out
for name,t in thunks:
    hs=hits_for(t)
    print(f"{name:28s} thunk 0x{t:X} -> table slots at {[hex(h) for h in hs]}")
    if hs:
        loc=hs[0]; start=loc-40
        row=[]
        for k in range(start, loc+12, 4):
            v=struct.unpack_from('<I', d, k)[0]
            row.append(f"{k:#08x}:{v-BASE:#07x}")
        print("      context:", " ".join(row))
