import capstone as cs, collections
d=open('FFXiMain.unpacked.dll','rb').read()
BASE=0x10000000; T=0x1000; TSZ=0x328000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.skipdata=True
ins=list(md.disasm(d[T:T+TSZ], BASE+T))
print("decoded units:", len(ins))
m=collections.Counter(); br=collections.Counter()
for k in range(len(ins)-2):
    if ins[k].mnemonic=='fnstsw':
        for j in (k+1,k+2,k+3):
            t=ins[j] if j<len(ins) else None
            if not t: break
            if t.mnemonic=='test' and 'ah,' in t.op_str.replace(' ',''):
                try: v=int(t.op_str.split(',')[1],0)
                except Exception: break
                m[v]+=1
                b=ins[j+1].mnemonic if j+1<len(ins) else ''
                br[(v,b)]+=1
                break
            if t.mnemonic in ('mov','fld','fstp','fmul','fadd'): continue
print("mask histogram:", dict(m))
print("mask+branch:", {f"{hex(a)}/{b}":c for (a,b),c in br.items()})
# is mask 0x41 used at all?
print("has 0x41 site:", m.get(0x41,0))
