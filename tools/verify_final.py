import pefile, capstone as cs
d=open('FFXiMain.unpacked.dll','rb').read()
pe=pefile.PE(data=d, fast_load=True)
def rb(rva,n): return d[rva:rva+n]
print("bytes @0x5EA03:", rb(0x5EA03,8).hex())
print("bytes @0x5EF03:", rb(0x5EF03,8).hex())
print("bytes 0x5EA7F..0x5EA96:", rb(0x5EA7F,0x1A).hex())
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.detail=True
def dis(rva,n):
    for i in md.disasm(rb(rva,n), 0x10000000+rva):
        print(f"  {i.address-0x10000000:#07x}  {i.mnemonic} {i.op_str}")
print("-- linear stream at 0x5EA7F (26 bytes) --"); dis(0x5EA7F,0x1A)
# synthetic x87 escapes: confirm capstone correctness on the disputed cells
tests=["DE C1","D9 F3","D9 F9","D9 FA","DB F0","DF F0","DD C1","DA E9","DB E8","DF E8","DB F8","D9 C1","D9 CA"]
print("-- synthetic x87 --")
for t in tests:
    b=bytes.fromhex(t.replace(' ',''))
    ins=list(md.disasm(b,0x10000000))
    print(f"  {t:<6} -> " + ("; ".join(f"{i.mnemonic} {i.op_str}".strip() for i in ins) if ins else "<undecoded>"))
