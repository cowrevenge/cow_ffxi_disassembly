import csv,bisect,struct,capstone as cs
rows=[int(r['rva'],16) for r in csv.DictReader(open('tables_functions.csv'))]
starts=sorted(set(rows)); d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.skipdata=True
def enclosing(rva):
    i=bisect.bisect_right(starts,rva)-1; return starts[i],(starts[i+1] if i+1<len(starts) else rva+1)
def callers_of(t):
    o=[]
    for m in range(0x1000,0x328000-5):
        if d[m]==0xE8 and (m+5+struct.unpack_from('<i',d,m+1)[0])==t: o.append(m)
    return o
def annot(lo,hi,label):
    print(f"\n=== {label}: 0x{lo:X}..0x{hi:X} ===")
    for i in md.disasm(d[lo:hi], BASE+lo):
        extra=''
        for tok in i.op_str.replace(',',' ').split():
            t=tok.strip()
            if t.startswith('dword ptr [0x1'):
                try: v=int(t.split('[0x')[1].rstrip(']'),16)-BASE
                except Exception: continue
                if 0x329000<=v<0x34E595: extra=f'   ; f={struct.unpack_from("<f",d,v)[0]:.9g}'
        print(f"  {i.address-BASE:#08x}  {i.mnemonic} {i.op_str}".rstrip()+extra)
for name,site in [("LockLookAt create site",0x5B18A),("ActorRotation create site",0x5B435)]:
    enc=enclosing(site); cs_list=callers_of(enc[0])
    print(f"\n### {name}: enclosing factory fn 0x{enc[0]:X}..0x{enc[1]:X}; callers={len(cs_list)} {[hex(c) for c in cs_list[:12]]}")
annot(0x5B160,0x5B1C8,"LockLookAt creation window")
annot(0x5B400,0x5B470,"ActorRotation creation window")
