import struct, collections
d=open('FFXiMain.unpacked.dll','rb').read(); BASE=0x10000000
TLO,THI=0x1000,0x328000
lo,hi=BASE+0x32B9A0, BASE+0x32BB40   # the DriveTask vtable family region
groups=collections.defaultdict(list)
for m in range(TLO, THI-4):
    v=struct.unpack_from('<I', d, m)[0]
    if lo <= v < hi:
        groups[v].append(m)
for v in sorted(groups):
    print(f"tbl {v-BASE:#08x} referenced at {[hex(x) for x in groups[v][:6]]}  ({len(groups[v])} sites)")
