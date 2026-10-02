import pefile, capstone as cs, collections
d=open('FFXiMain.unpacked.dll','rb').read()
BASE=0x10000000; TEXT_RVA=0x1000; TEXT_SZ=0x328000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.detail=True
code=d[TEXT_RVA:TEXT_RVA+TEXT_SZ]
imm=collections.Counter(); seqs=collections.Counter()
prev=[]; addr_at={}
ins=list(md.disasm(code, BASE+TEXT_RVA))
for k,i in enumerate(ins):
    prev.append(i) if False else None
# scan windows for fnstsw ax followed within 3 insns by test ah, imm8
outlets=collections.Counter()
samples={}
fnst=None
i=0
while i < len(ins):
    it=ins[i]
    if it.mnemonic=='fnstsw' or (it.mnemonic=='fstsw' and 'ax' in it.op_str):
        for j in range(i+1, min(i+4, len(ins))):
            t=ins[j]
            if t.mnemonic=='test' and t.op_str.startswith('ah,'):
                try: v=int(t.op_str.split(',')[1].strip(),0)
                except Exception: break
                outlets[v]+=1
                seq=' | '.join(f"{x.mnemonic} {x.op_str}".strip() for x in ins[i:j+1])
                # branch condition after the test
                br=''
                if j+1 < len(ins) and ins[j+1].mnemonic.startswith('j'):
                    br=ins[j+1].mnemonic
                    outlets[(v,br)]+=1
                    seq = seq + ' | ' + ins[j+1].mnemonic
                key=(v,br)
                samples.setdefault(key, (it.address-BASE, seq))
                break
            if t.mnemonic in ('fld','fstp','fmul','fadd'): continue
    i+=1
print("== immediates of `test ah,imm` following fnstsw ax ==")
for k,v in sorted(outlets.items(), key=lambda kv:-kv[1]):
    print(f"  mask={k if isinstance(k,int) else hex(k[0])!s:>6} branch={k[1] if isinstance(k,tuple) else '':<8} count={v}")
print("== one sample per (mask,branch) ==")
for key,(rva,s) in sorted(samples.items(), key=lambda kv:-outlets[kv[0]]):
    print(f"  mask={hex(key[0]) if isinstance(key[0],int) else key[0]} br={key[1]!s:<8} rva=0x{rva:X}: {s}")
