import csv,bisect,struct,capstone as cs
rows=[int(r['rva'],16) for r in csv.DictReader(open('tables_functions.csv'))]
starts=sorted(set(rows)); d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.skipdata=True
def bounds(rva):
    i=bisect.bisect_right(starts,rva)-1
    return starts[i], (starts[i+1] if i+1<len(starts) else rva+0x80)
for name,rva in [("fetcher/guard 0x62770",0x62770),("accessor 0x5E590",0x5E590),
                 ("alloc? 0x5E040",0x5E040),("global getter 0x311C2C",0x311C2C)]:
    s,e=bounds(rva); span=min(e-s, 0xA0) if e>s else 0x40
    print(f"\n=== {name}: function 0x{s:X}..{e if e<0x800000 else '?'} (dumping 0x{span:X}) ===")
    n=0
    for i in md.disasm(d[s:s+span], BASE+s):
        extra=''
        for tok in i.op_str.replace(',',' ').split():
            t=tok.strip()
            if 'ptr [0x1' in t or t.startswith('[0x1'):
                try: v=int(t.split('[')[1].rstrip(']'),16)-BASE
                except Exception: continue
                if 0x329000<=v<0x400000:
                    f=struct.unpack_from('<f',d,v)[0]; i2=struct.unpack_from('<i',d,v)[0]
                    extra=f'   ; f={f:.9g} int={i2}'
        print(f"  {i.address-BASE:#08x}  {i.mnemonic} {i.op_str}".rstrip()+extra); n+=1
