# Tpc event motion package -> DAT file id table (FFXiMain.dll)

The file-id rule for opcode 0x66 (LOADEXTSCHEDULER2 / "Tpc" motion packages), read out of
`ReadTpcEventMotionRes` @rva **0xD2230** in `FFXiMain.dll`. This is the primary target of the event
pass. See [event_vm.md](event_vm.md) E5, E6 and E17.

## How it works (verified, local)

Pseudo code for `ReadTpcEventMotionRes(actor, val)` @0xD2230 (`ret 4`):

```
n = gate(actor)                          // call 0x84410: sign_extend(entity[+0xEE]) or 0 if no back-ptr
if n not in {0, 1, 6}: return            // out-of-range entity type -> no load (rva 0xD223F/0xD224A)
val = param                              // the Tpc package number (a_2, rva 0xD2253)
if val >= 0x118:                         // out of range (rva 0xD2259)
    vcall [actor->vt + 0xCC](val); log via call 0x17D40; return
flag = (byte at [actor->vt[+0x3D8]()] + 9) == 1     // rva 0xD2281..0xD228E
(A, B) = band_map(val, flag)             // four bands below
// load container for A with tag 1:
containerA = GetContainer(A)            // resource manager global @rva 0x47D168; call 0x730F0 (rva 0xD2319..0xD2325)
attach(actor, containerA, tag=1, A, 2)  // call 0xD4420 (rva 0xD233C); register via 0xD1460 or pending stub
flag2 = re-read the same flag byte       // rva 0xD23AA..0xD23B8
if flag2 <= 0 (signed): return
// load container for B with tag 2:
containerB = GetContainer(B)            // call 0x730F0 (rva 0xD23CC)
attach(actor, containerB, tag=2, B, 2)  // call 0xD4420 (rva 0xD23E3); register via 0xD1460 or pending stub
```

Two file ids are produced per package: **A** (attached with resource tag 1) and **B** (tag 2). Which
of the two B candidates is used depends on `flag`, a byte at offset +9 of the struct returned by the
actor's `[vt+0x3D8]()` vcall. That target is now resolved (E17): slot +0x3D8 holds 0x100D04C0 in this
build, and @rva 0xD04C0 the function is a standalone accessor, `lea eax,[ecx+0x878]; ret`, so the flag
byte is actor+0x881. It is the CIB(0x45) chunk's waist_type byte (offset 9 of the CIB body), written by
@rva 0xCF220 from resource type 0x45; kuluu already carries it as `Cib::body_armour_waist`
(ffxi-dat/src/cib.rs). Semantics: byte == 1 -> B_set column; byte in [2..0x7F] -> B_clear column;
byte 0 or >= 0x80 -> A only (the re-read after loading A skips B when the sign-extended value is
<= 0). Evidence: `out3/probe_vt3d8.md`, `out3/d_d04c0.md`, `out3/x_881.md`, `out3/vt_cf220.md`,
`out3/d_cf34b.md`, `out3/cib_b9_census.md`.

## The four bands (val is u32)

| val range | band-local `v` | A (tag 1) = | B when flag=1 (tag 2) = | B when flag=0 (tag 2) = |
|-----------|----------------|-------------|--------------------------|--------------------------|
| [0, 0x46)   | val          | val + 0x7FC8        (= 32712 base) | val + 0x800E | val + 0x8054 |
| [0x46, 0x8C)| val - 0x46   | v + 0xEF39          (= 61241 base) | v + 0xEF7F | v + 0xEFC5 |
| [0x8C, 0xD2)| val - 0x8C   | v + 0x15711         (= 87825 base) | v + 0x15757 | v + 0x1579D |
| [0xD2, 0x118)| val - 0xD2  | v + 0x18F5F         (= 102239 base)| v + 0x18FA5 | v + 0x18FEB |

RVA citations for each band's compares and adds (all in `out3/d_d2230.md`):
- Band boundary compares: `cmp esi,0x46` @0xD2291, `cmp esi,0x8C` @0xD22B0, `cmp esi,0xD2` @0xD22D5,
  out-of-range `cmp esi,0x118` @0xD2259.
- Band 1 adds: `lea ebp,[esi+0x7FC8]` @0xD2298 (A), `lea ebx,[esi+0x800E]` @0xD22A0 /
  `lea ebx,[esi+0x8054]` @0xD22A8 (B flag=1/0).
- Band 2: `sub esi,0x46` @0xD22B8; A `lea ebp,[esi+0xEF39]` @0xD22BD; B `lea ebx,[esi+0xEF7F]`
  @0xD22C5 / `lea ebx,[esi+0xEFC5]` @0xD22CD.
- Band 3: `sub esi,0x8C` @0xD22DD; A `lea ebp,[esi+0x15711]` @0xD22E5; B `lea ebx,[esi+0x15757]`
  @0xD22ED / `lea ebx,[esi+0x1579D]` @0xD22F5.
- Band 4: `sub esi,0xD2` @0xD22FD; A `lea ebp,[esi+0x18F5F]` @0xD2305; B `lea ebx,[esi+0x18FA5]`
  @0xD230B / `lea ebx,[esi+0x18FEB]` @0xD2313.

## File id -> DAT path

File ids are global FTABLE indices. The on-disk path is `ROM/(id >> 7)/(id & 0x7F).DAT`. (For ids in
the ROM2 range the top bit selects a different root; all Tpc A/B ids here fall in ROM.)

## Worked examples and DAT cross-check (local, PASSED)

| package | band | v | A (tag 1) | B flag=0 | B flag=1 | A -> DAT path |
|---------|------|---|-----------|----------|----------|----------------|
| 12 (0x0C) | 1 | 12 | 12 + 32712 = **32724** | 12 + 32852 = 32864 | 12 + 32814 = 32826 | ROM/72/79.DAT |
| 20 (0x14) | 1 | 20 | 20 + 32712 = **32732** | 20 + 32852 = 32872 | 20 + 32814 = 32834 | ROM/72/87.DAT |

Cross-check against the install's DATs (prior-session scan + `dat_routines.py`):
- **Package 20** (the Sandy opening scene uses 0x66 package 20): A = 32732 = **ROM/72/87.DAT**, which
  contains the talk clips `tlk0` and `thk1`. Matches.
- **Package 12** (cexi: Cornelia's package 12): A = 32724 = **ROM/72/79.DAT**, which contains `kka0`.
  Matches.

This confirms the banded A/B mapping is the real Tpc file-id rule, and that kuluu's current flat
`tpc_motion_dat_id(param) = param + 32104` (in `ffxi-event/src/cue.rs`) is wrong: it neither bands
nor produces the second (tag-2) file id.

## Relationship to ReadEventMotionRes (0x5B, param1=0)

The sibling reader `ReadEventMotionRes` @0xD2120 uses a *different* five-band scheme on
`getworkofs(this, 1)` (bases 32104 / 49135 / 56345 / 59739 / 66339) and is gated by entity Type
(loads for {1,2,7,8}, no-op for {3,4,5,6}; E4). The Tpc reader (this table) is selected when the
shared helper @0xB5220 is called with param1=1 (i.e. opcode 0x66 and 0x5F cases 4/6). Do not conflate
the two: 0x5B uses the event-motion bands, 0x66 uses this Tpc table.
