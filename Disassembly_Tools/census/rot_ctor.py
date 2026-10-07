import struct, capstone as cs
d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.skipdata=True
def dump(lo,hi,label):
    print(f"\n=== {label}: 0x{lo:X}..0x{hi:X} ===")
    for i in md.disasm(d[lo:hi], BASE+lo):
        extra=''
        t=i.op_str
        if 'ptr [0x1' in t:
            tok=t.split('ptr [0x')[1].split(']')[0]
            try: v=int(tok,16)-BASE
            except Exception: v=None
            if v is not None and 0x329000<=v<0x400000:
                extra=f'   ; f={struct.unpack_from("<f",d,v)[0]:.9g}'
        print(f"  {i.address-BASE:#07x}  {i.mnemonic} {i.op_str}".rstrip()+extra)
dump(0x5FA20, 0x5FAE0, "CMoActorRotationDriveTask ctor (holds pi/180 sites)")
