import capstone as cs
d=open('FFXiMain.unpacked.dll','rb').read()
BASE=0x10000000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.skipdata=True
for name,rva,n in [("0x54500 linear",0x54500,0xA0),("0x547A0 smooth",0x547A0,0xC0),("0x546F0 smooth2",0x546F0,0xB0)]:
    print("="*30,name)
    for i in md.disasm(d[rva:rva+n], BASE+rva):
        line=f"  {i.address-BASE:#07x}  {i.mnemonic} {i.op_str}"
        print(line.rstrip())
