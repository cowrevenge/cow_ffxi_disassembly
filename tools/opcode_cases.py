import struct, capstone as cs
d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
md=cs.Cs(cs.CS_ARCH_X86, cs.CS_MODE_32); md.skipdata=True
# 1) verify their claimed jump table location in OUR build: code pointers near 0x5DC1C
tbl_lo=None
for probe in (0x5DC1C,):
    vals=[struct.unpack_from('<I',d,probe+k*4)[0] for k in range(6)]
    ok=all(BASE+0x1000 < v < BASE+0x328000 for v in vals)
    print(f"their jump table 0x{probe:X} in our build -> {len(vals) if ok else 'NOT a code-ptr table'} sample={[hex(v-BASE) for v in vals[:4]]}")
if not tbl_lo and ok: tbl_lo=probe
# back up to true table start
t=probe
while struct.unpack_from('<I',d,t-4)[0] > BASE+0x1000 and struct.unpack_from('<I',d,t-4)[0] < BASE+0x328000: t-=4
n=0
while struct.unpack_from('<I',d,t+(n)*4)[0] > BASE+0x1000 and struct.unpack_from('<I',d,t+(n)*4)[0] < BASE+0x328000: n+=1
print(f"OUR jump table start 0x{t:X}, {n} entries")
# find the indirect jump using this table to get the index computation (case variable)
hits=[]
for m in range(0x57FB0,0x5E400-4):
    if d[m]==0xFF and (d[m+1]&0xC7)==0x24:  # jmp [reg+disp] / jmp dword[reg*4+disp]
        disp=struct.unpack_from('<i',d,m+3)[0] if (d[m+1]&0xC0)==0x80 else None
        hits.append((m,hex(d[m+1]),disp))
print("ff24-form jumps in interpreter:", [(hex(a),b) for a,b,c in hits][:6])
# map targets -> case index
targets={struct.unpack_from('<I',d,t+k*4)[0]-BASE:k for k in range(n)}
def handler_of(rva):
    # find the nearest table entry <= rva whose target is a function-ish start preceding rva within same handler
    best=None
    for tgt,k in targets.items():
        if tgt<=rva and (best is None or tgt>best[0]): best=(tgt,k)
    return best
for lbl,rva in [("LockLookAt ctor call",0x5B18A),("ActorRotation ctor call",0x5B435)]:
    b=handler_of(rva)
    print(f"{lbl} 0x{rva:X}: handler starts 0x{b[0]:X} = case {b[1]}")
# what is dispatched on: dump the compare/jump sequence right before the table jump
for m,b,disp in hits[:3]:
    print(f"\n--- dispatch prologue before 0x{m:X} ---")
    for i in md.disasm(d[m-40:m+6], BASE+m-40):
        print(f"  {i.address-BASE:#08x}  {i.mnemonic} {i.op_str}".rstrip())
