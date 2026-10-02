import struct, capstone as cs, collections, re
d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.skipdata=True
GLO,GHI=0x329000,0x34E595
g=re.compile(r'\[0x(1[0-9a-f]{7})\]')
jsink=re.compile(r'\+\s*(0xe[0-9a-f]|0xf[0-9a-f])\b')
def scan(lo,hi,label):
    consts=collections.defaultdict(list); sinks=collections.Counter()
    for i in md.disasm(d[lo:hi], BASE+lo):
        for m in g.finditer(i.op_str):
            v=int(m.group(1),16)-BASE
            if GLO<=v<GHI: consts[v].append(i.address-BASE)
        if jsink.search(i.op_str): sinks[(i.mnemonic,i.op_str)]+=1
    print(f"=== {label} ({lo:#X}..{hi:#X}) ===")
    for v in sorted(consts):
        f=struct.unpack_from('<f', d, v)[0]
        print(f"  const[{BASE+v:#010x}] = {f:<24.9g} used {len(consts[v]):2d}x first={[hex(a) for a in consts[v][:3]]}")
    if sinks:
        print("  -- writes/reads of +0xE0..+0xFF slots --")
        for (mn,op),c in sinks.most_common(10): print(f"     {c:2d} {mn} {op}")
scan(0x5F3C0,0x60980,"DriveTask family (LockLookAt / ActorRotation / Color / Path)")
