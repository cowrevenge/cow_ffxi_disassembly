import csv, bisect, struct
rows=[int(r['rva'],16) for r in csv.DictReader(open('tables_functions.csv'))]
starts=sorted(set(rows))
def enclosing(rva):
    i=bisect.bisect_right(starts,rva)-1
    if i<0: return None
    s=starts[i]; e=starts[i+1] if i+1<len(starts) else rva+1
    return (s,e)
def callers_of(target, text_lo=0x1000, text_hi=0x328000):
    d=open('FFXiMain.unpacked.dll','rb').read()
    out=[]
    for m in range(text_lo, text_hi-5):
        if d[m]==0xE8:
            rel=struct.unpack_from('<i', d, m+1)[0]
            if (m+5+rel) == target: out.append(m)
    return out
for label,rva in [("LockLookAt vtable-store A",0x5F476),("LockLookAt vtable-store B",0x5F47F),
                  ("ActorRotation vtable-store A",0x5FA49),("ActorRotation vtable-store B",0x5FA4F),
                  ("sqmdModelLookAt err tail",0x2790A2)]:
    enc=enclosing(rva)
    print(f"{label:32s} 0x{rva:X} -> enclosing function 0x{enc[0]:X}..0x{enc[1]:X}")
print()
for tgt_name,rva in [("LockLookAt ctor?",None),("ActorRotation ctor?",None)]: pass
# xref: who calls the enclosing functions
d=open('FFXiMain.unpacked.dll','rb').read()
def show(tgt):
    cs=callers_of(tgt)
    print(f"  callers of 0x{tgt:X}: {[hex(c) for c in cs]}  ({len(cs)})")
for rva_lbl,rva in [("LockLookAt enclosing",None)]: pass
