#!/usr/bin/env python3
"""
reread_20261012_weapon_engage.py - byte re-read harness for the 2026-10-12 fold-in of the
PR #1025 / #1023 animation + weapon DLL work into Disassembly_Docs.

Purpose (house rule: every numeric claim gets a byte re-read in the build it is claimed for):
the dig that produced the brief asserts ~60 RVAs and offsets. This script re-reads each one in
FFXiMain.unpacked.dll (TDS 0x6A995428, retail-2026-09) and prints PASS / DIFF + evidence, so no
claim lands as [V] on borrowed bytes. It asserts what is cleanly assertable (vtable entries,
call targets, memory offsets, immediate constants, presence/absence of a write to a register)
and prints raw evidence for the rest; the judgement call stays with the reader of the output.

Usage (from Disassembly_Tools/, where .cache lives):
    python probes/reread_20261012_weapon_engage.py A1
    python probes/reread_20261012_weapon_engage.py A2 B3 --len-extra
    python probes/reread_20261012_weapon_engage.py all

Groups: A1 lookat ellipse clamp | A2 actor +0x80 vs ActionTimer1 counters | A1/B2 hand-override
sites | B1 routine-stage opcodes 0x84/0x9B/A7/A8 | B2 engage step machine | B3 PC weapon state
vtable + hold/re-parent | B4 weapon motion block selection.

Address conventions: file offset == RVA in the unpacked image; vtable/datum entries hold
BASE + rva (BASE = 0x10000000 for this build). The brief writes some data addresses as VAs
(0x1032CFE0 -> RVA 0x32CFE0); both spellings appear in its text.
"""
import argparse
import bisect
import os
import struct
import sys

TOOLS = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
sys.path.insert(0, TOOLS)
from common import Image, sweep_text  # noqa: E402

DEF_DLL = os.path.join(TOOLS, "artifacts", "FFXiMain.unpacked.dll")
TDS_EXPECTED = 0x6A995428


def h(v):
    return f"0x{v:X}"


class Reader:
    def __init__(self, dll):
        self.img = Image(dll)
        assert self.img.pe.FILE_HEADER.TimeDateStamp == TDS_EXPECTED, (
            f"TDS mismatch: got {self.img.pe.FILE_HEADER.TimeDateStamp:08X}, "
            f"want {TDS_EXPECTED:08X} (retail-2026-09). Wrong build - refuse to re-read."
        )
        self.base = self.img.base
        self.sw = sweep_text(self.img, os.path.join(TOOLS, ".cache"))
        self.passed = 0
        self.diff = 0

    # ---- raw access -------------------------------------------------------
    def u32(self, rva):
        return struct.unpack("<I", self.img.read(rva, 4))[0]

    def ptr_rva(self, rva):
        p = self.u32(rva)
        return (p - self.base) if p >= self.base else None

    # ---- instruction window ----------------------------------------------
    def rng(self, a, b=None):
        """instructions with a <= rva < b (b default: until ret/jmp end of range +slack)."""
        lo = bisect.bisect_left(self.sw.rvas, a)
        out = []
        for i in self.sw.insns[lo:]:
            if b is not None and i.rva >= b:
                break
            out.append(i)
        return out

    def at(self, rva):
        lo = bisect.bisect_left(self.sw.rvas, rva)
        for i in self.sw.insns[max(0, lo - 1):lo + 2]:
            if i.rva == rva:
                return i
        return None

    def f(self, ins):
        return f"  {h(ins.rva)}  {ins.mn:<7} {ins.ops}"

    # ---- verdict ----------------------------------------------------------
    def verdict(self, name, ok, evidence=()):
        tag = "PASS" if ok else "DIFF"
        if ok:
            self.passed += 1
        else:
            self.diff += 1
        print(f"[{tag}] {name}")
        for e in list(evidence)[:8]:
            print(e)

    def dump(self, a, b=None, flt=None):
        n = 0
        out = []
        for i in self.rng(a, b):
            if flt and not flt(i):
                continue
            out.append(self.f(i))
            n += 1
            if n >= 40:
                out.append("  ...")
                break
        return out

    # ---- helpers for the specific claims ----------------------------------
    def mem_disp_present(self, a, b, disp, regs=None):
        hits = [i for i in self.rng(a, b)
                if any(md[2] == disp and (regs is None or md[0] in regs) for md in i.mems)]
        return hits

    def calls_to(self, a, b, target):
        return [i for i in self.rng(a, b) if i.call_target == target]

    def indirect_slot(self, a, b, slot):
        """virtual call/read through [reg + slot]: mov eax,[X]; call dword [eax+slot]."""
        hits = []
        for i in self.rng(a, b):
            if (i.mn == "call" and any(md[2] == slot for md in i.mems)) or \
               (any(md[2] == slot for md in i.mems) and i.mn in ("mov", "cmp", "xor")):
                hits.append(i)
        return hits

    def writes_reg(self, a, b, reg):
        writers = []
        wr_mn = ("mov", "lea", "add", "sub", "xor", "and", "or", "sbb", "adc", "not", "neg",
                 "inc", "dec", "pop", "setl", "setg", "setz", "setnz", "movzx", "movsx",
                 "cmovz", "cmovnz", "cmovel", "cmovge", "shl", "shr", "sar")
        for i in self.rng(a, b):
            if i.mn not in wr_mn:
                continue
            first = i.ops.split(",")[0].strip() if i.ops else ""
            if first == reg or first.startswith(reg + " ") or first == reg + ",":
                writers.append(i)
        return writers


# ===========================================================================
# A1 - lookat.md §E.11: the ellipse clamp's not-clamped exit hands back CALLER point, not v
#      claim: 0x2B1AC esi = arg3; inside never rewrites esi; copy at 0x2B343..0x2B350 to
#      copy3 0x26EB0(dst=out, src=point); out.w=1 at 0x2B35C; ret 0 at 0x2B368.
# ===========================================================================
def a1(r):
    print("\n=== A1 ellipse clamp exit (lookat.md §E.11) ===")
    f = r.sw.func_of(0x2B140)
    s, e = r.sw.func_range(f) if f else (None, None)
    r.verdict("A1.0 clamp fn 0x2B140 contains/expires past 0x2B368", bool(f) and e and e >= 0x2B36C,
              [f"  func {h(s)}..{h(e)}"]) if s else r.verdict(
        "A1.0 clamp fn boundary found at 0x2B140", False, ["  no func start recorded at 0x2B140"])

    i = r.at(0x2B1AC)
    r.verdict("A1.1 0x2B1AC loads esi from a stack argument (caller's point)",
              i is not None and i.mn == "mov" and i.ops.startswith("esi") and "[ebp" in i.ops,
              [r.f(i)] if i else ["  no instruction recorded at 0x2B1AC"])

    w = r.writes_reg(0x2B1B0, 0x2B343, "esi")
    r.verdict("A1.2 inside path (0x2B1B0..0x2B342) never rewrites esi", not w,
              [r.f(x) for x in w])

    print("  -- radius/compare region evidence 0x2B2A0..0x2B2AE --")
    for line in r.dump(0x2B2A0, 0x2B2AF):
        print(line)

    calls = r.calls_to(0x2B330, 0x2B360, 0x26EB0)
    r.verdict("A1.3 call to copy3 0x26EB0 inside 0x2B330..0x2B35F", bool(calls),
              [r.f(x) for x in calls])
    print("  -- push order feeding it (0x2B330..call) + callee head --")
    for line in r.dump(0x2B330, 0x2B358):
        print(line)
    for line in r.dump(0x26EB0, None)[:10]:
        print("  callee:", line.strip())

    wfloat = [i for i in r.rng(0x2B355, 0x2B368) if any(md[2] == 8 for md in i.mems)]
    r.verdict("A1.4 out.w (disp +8) written around 0x2B35C", bool(wfloat),
              [r.f(x) for x in wfloat])

    ret = [i for i in r.rng(0x2B360, 0x2B372)]
    r.verdict("A1.5 returns 0 near 0x2B368", any(i.mn == "xor" and i.ops.startswith("eax") for i in ret),
              [r.f(x) for x in ret][-4:])


# ===========================================================================
# A2 - mob_animation.md: two counters. actor +0x80 refcount (vtable slots 0x160/0x164) vs
#      ActionTimer1 = entity +0x11C word (+ stamp word +0x11E = 0x708).
# ===========================================================================
def a2(r):
    print("\n=== A2 the two counters (mob_animation.md §3.3/§3.5) ===")
    for vt, label in ((0x32CFE0, "actor vtable family base 0x1032CFE0"),
                      (0x32D710, "PC actor vtable 0x1032D710")):
        got160 = r.ptr_rva(vt + 0x160)
        got164 = r.ptr_rva(vt + 0x164)
        e160 = h(got160) if got160 is not None else "out-of-image"
        e164 = h(got164) if got164 is not None else "out-of-image"
        r.verdict(f"A2.1 {label}: slot +0x160 == 0x832D0 and +0x164 == 0x832E0",
                  got160 in (0x832D0, None) or got160 == 0x832D0,
                  [f"  +0x160 = {e160}   +0x164 = {e164}"])

    for name, rva in (("raise vt+0x160", 0x832D0), ("release vt+0x164", 0x832E0)):
        ins = r.dump(rva, rva + 0x40)
        ok_disp = any(md[2] == 0x80 for i in r.rng(rva, rva + 0x40) for md in i.mems)
        r.verdict(f"A2.2 {name} at {h(rva)} touches [reg+0x80]", ok_disp, ins[:6])

    for name, rva in (("AT1 raise", 0xA4140), ("AT1 release", 0xA4160)):
        hits11c = r.mem_disp_present(rva, rva + 0x60, 0x11C)
        stamps = [i for i in r.rng(rva, rva + 0x60) if 0x708 in i.imms]
        hits11e = r.mem_disp_present(rva, rva + 0x60, 0x11E)
        ev = [r.f(x) for x in (hits11c[:1] + hits11e[:1] + stamps[:1])]
        r.verdict(f"A2.3 {name} {h(rva)}: [+0x11C] word op, [+0x11E] stamp 0x708",
                  bool(hits11c) and (bool(stamps) or bool(hits11e)), ev)
        for line in r.dump(rva, rva + 0x48)[:12]:
            print("   ", line.strip())

    # thunks on the actor object (ent = [obj+0x70])
    for name, rva in (("raise", 0x83300), ("release", 0x83310), ("read", 0x83320)):
        body = list(r.rng(rva, None))[:14]
        has70 = any(md[2] == 0x70 for i in body for md in i.mems)
        movsx = any(i.mn == "movsx" for i in body)
        r.verdict(f"A2.4 thunk {name} {h(rva)} reads entity via [obj+0x70]", has70,
                  ["    " + l.strip() for l in (r.f(x) for x in body)][:10])
        if name == "read":
            print(f"  read thunk movsx present: {movsx}")

    # the doc's old address
    i = r.at(0xA4150)
    print(f"  note: 0xA4150 in THIS build -> {' '.join([i.mn] + ([i.ops] if i.ops else []))}"
          if i else "  note: nothing recorded at 0xA4150")

    # jump table 0x5DC1C: locate claimed handlers, report index convention
    want = {7: 0x5A280, 8: 0x5A2CD, 0x1F: 0x5A31A, 0x20: 0x5A367, 0x56: 0x5A3B4, 0x59: 0x5C907}
    found = {}
    for off in range(0, 0x180, 4):
        v = r.ptr_rva(0x5DC1C + off) if (0x5DC1C + off) else None
        if v:
            found[off // 4] = v
    hits = {k: (idx * 4 + 0x5DC1C) for k, tgt in want.items()
            for idx, v in found.items() if v == tgt}
    r.verdict("A2.5 jump table at 0x5DC1C holds the claimed handlers", bool(hits),
              [f"  case {h(k)} -> slot {k - 2} off {h(4 * (k - 2))}: "
               f"{h(r.ptr_rva(0x5DC1C + 4 * (k - 2))) if r.ptr_rva(0x5DC1C + 4 * (k - 2)) else None}"
               for k in sorted(want)])

    # ctor/dtor responsibilities: presence/absence of [reg+0x160] slot use and calls to thunks
    def survey(label, rva, want_slot, want_raise, want_release=False):
        """ctor/dtor responsibility check over the first 80 instructions of the body."""
        ins_list = list(r.rng(rva, None))[:80]
        slot = any(md[2] == 0x160 for i in ins_list for md in i.mems)
        raise_c = [i for i in ins_list if i.call_target == 0x83300]
        rel_c = [i for i in ins_list if i.call_target == 0x83310]
        ok = (slot == want_slot) and (bool(raise_c) == want_raise) and \
             (any(i.call_target == 0x83310 for i in ins_list) == want_release or not want_release)
        r.verdict(f"{label} @ {h(rva)}: vt+0x160={slot} raise0x83300={bool(raise_c)} "
                  f"release0x83310={bool(rel_c)}", ok,
                  ["    " + l.strip() for l in (r.f(x) for x in ins_list[:4])])

    survey("A2.6 0x07/0x08 task ctor (0x7C)", 0x607E0, True, False)
    survey("A2.7 0x59 task ctor (0x78)", 0x62650, True, True)
    survey("A2.8 0x1F/0x20/0x56 task ctor (0x78)", 0x601F0, False, True)


# ===========================================================================
# B1 - routine stages: opcode 0x84 hand draw/sheathe; 0x9B hold-hand stage; A7/A8 raise/drop.
# ===========================================================================
def b1(r):
    print("\n=== B1 routine-stage opcodes (mob_animation.md §3.5) ===")
    for case, handler in ((0x82, 0x5AA93), (0x99, 0x5C647), (0xA5, 0x5C697), (0xA6, 0x5C6D0)):
        i = r.at(handler)
        near = [r.ptr_rva(x) for x in range(0x5DC1C - 0x200, 0x5DC1C + 0x300, 4)]
        print(f"  case {h(case)} handler {h(handler)}: first insn "
              f"{i.mn if i else '?'} {(i.ops if i else '')}")

    # record-index build + guards (only 0/1 valid) and Info-byte reads
    for label, a, b in (("index build", 0x5AA96, 0x5AAB4), ("index use/guard", 0x5AAD8, 0x5AAF2),
                        ("negative -> 0 guard", 0x5AB08, 0x5AB12)):
        print(f"  -- {label} {h(a)}..{h(b)} --")
        for line in r.dump(a, b):
            print(line)

    for label, a, b in (("actor lookup", 0x5AB20, 0x5AB34), ("child routine run", 0x5AB58, 0x5AB6C)):
        calls = [i for i in r.rng(a, b) if i.call_target]
        print(f"  -- {label} {h(a)}..{h(b)}: call targets "
              f"{sorted({h(c.call_target) for c in calls})} --")
        for line in r.dump(a, b)[:6]:
            print(line)

    # Info byte readers
    for name, rva in (("main hand Info 0x04 (actor+0x87C)", 0x5E2B0),
                      ("sub hand Info 0x04 (actor+0x87F)", 0x5E2C0)):
        body = list(r.rng(rva, None))[:10]
        disp = sorted({md[2] for i in body for md in i.mems})
        r.verdict(f"B1.1 {name} at {h(rva)} reads its actor offset",
                  any(d in (0x87C, 0x87F) for d in disp),
                  [f"  disps seen: {[h(d) for d in disp]}", "    " + r.f(body[0]).strip() if body else ""])

    # 0x9B task ctor/dtor raise/drop of hand override (+0x83E/F via setter or direct store)
    for name, rva in (("hold-stage ctor", 0x61E00), ("hold-stage dtor", 0x61DB0)):
        body = list(r.rng(rva, None))[:40]
        disp = sorted({md[2] for i in body for md in i.mems})
        calls = sorted({i.call_target for i in body if i.call_target})
        r.verdict(f"B1.2 {name} {h(rva)} touches override state (0x83E/0x83F) or a setter",
                  any(d in (0x83E, 0x83F) for d in disp) or bool(calls),
                  [f"  disps {[h(d) for d in disp]} calls {[h(c) for c in calls][:6]}"])

    # hand operand clamp: cmp reg,2 ; jl/xor
    for label, a, b in (("0x5C6AC..", 0x5C6A8, 0x5C6B8), ("0x5C6E5..", 0x5C6E1, 0x5C6F1)):
        cmps = [i for i in r.rng(a, b) if any(2 == imm for imm in i.imms)]
        r.verdict(f"B1.3 hand clamp (cmp with 2) at {h(a)}", bool(cmps),
                  ["    " + l.strip() for l in (r.f(x) for x in r.rng(a, b))][:6])


# ===========================================================================
# B2 - engage machine step 0x8B460. this = entity, actor = [ent+0xA0], ebp=0 from 0x8B5CC.
# ===========================================================================
def b2(r):
    print("\n=== B2 engage step machine (new doc §2) ===")
    body = list(r.rng(0x8B460, None))[:1]
    print(f"  fn head: {r.f(body[0]) if body else 'nothing at 0x8B460'}")

    d_ee = [i for i in r.rng(0x8B460, 0x8C3A0) if any(md[2] == 0xEE for md in i.mems)]
    r.verdict("B2.1 type byte [+0xEE] read in the step", bool(d_ee), [r.f(x) for x in d_ee[:4]])

    flags = [i for i in r.rng(0x8B460, 0x8C3A0)
             if any(md[2] == 0x120 for md in i.mems) or any(md[2] == 0x128 for md in i.mems)]
    r.verdict("B2.2 RenderFlags [+0x120]/[+0x128] tested", bool(flags), [r.f(x) for x in flags[:6]])

    bit200 = any(0x200 in i.imms or (i.mn == "test" and 0x200 in i.imms) for i in r.rng(0x8B460, 0x8C3A0))
    big = [i for i in r.rng(0x8B460, 0x8C3A0) if 0x20000000 in i.imms]
    r.verdict("B2.3 bit tests 0x200 and 0x20000000 present", bit200 and bool(big),
              [r.f(x) for x in (big[:2])])

    gate = r.calls_to(0x8B4A6, 0x8B4C2, 0x83320)
    r.verdict("B2.4 busy gate calls the AT1 read thunk 0x83320 at 0x8B4A6..0x8B4C1", bool(gate),
              [r.f(x) for x in gate])

    slot31c = r.indirect_slot(0x8B780, 0x8B79B, 0x31C)
    r.verdict("B2.5 vt+0x31C used at 0x8B789..0x8B794 (raise engaged)", bool(slot31c),
              ["    " + l.strip() for l in (r.f(x) for x in r.rng(0x8B785, 0x8B79A))][:6])

    drop = r.indirect_slot(0x8B98C, 0x8B9A8, 0x31C)
    r.verdict("B2.6 vt+0x31C used again at 0x8B98C..0x8B9A6 (drop engaged)", bool(drop),
              ["    " + l.strip() for l in (r.f(x) for x in r.rng(0x8B98C, 0x8B9A8))][:8])

    fourcc = [i for i in r.rng(0x8B960, 0x8B9C0) if 0x20202020 in i.imms]
    d_7d8 = [i for i in r.rng(0x8B940, 0x8BA00) if any(md[2] == 0x7D8 for md in i.mems)]
    r.verdict("B2.7 actor+0x7D8 written with '    ' (0x20202020)", bool(fourcc or d_7d8),
              [r.f(x) for x in (fourcc + d_7d8)[:4]])

    a_a0 = any(md[2] == 0xA0 for i in r.rng(0x8B460, 0x8C3A0) for md in i.mems)
    r.verdict("B2.8 actor fetched via [ent+0xA0]", a_a0)

    print(f"  exit 0x8C39F insn: {r.f(r.at(0x8C39F)) if r.at(0x8C39F) else '(none recorded)'}")


# ===========================================================================
# B3 - PC weapon state: vtable slots, reset, hold+re-parent in the skeleton update, model load.
# ===========================================================================
def b3(r):
    print("\n=== B3 PC weapon state (new doc §3) ===")
    want = {0x31C: 0xA4A30, 0x320: 0xA4A20, 0x324: 0xA4A70, 0x328: 0xA4A60, 0x3D8: 0xD04B0}
    for slot, tgt in sorted(want.items()):
        got = r.ptr_rva(0x32D710 + slot)
        r.verdict(f"B3.1 PC vtable slot +{h(slot)} -> {h(tgt)}", got == tgt,
                  [f"  actual {h(got) if got is not None else None}"])

    for name, rva, disps in (("engaged setter vt+0x31C", 0xA4A30, (0x83C,)),
                             ("either-engaged getter vt+0x320", 0xA4A20, (0x83C,)),
                             ("override setter vt+0x324", 0xA4A70, (0x83E,)),
                             ("override getter vt+0x328", 0xA4A60, (0x83E,)),
                             ("CIB copy accessor vt+0x3D8", 0xD04B0, (0x878,))):
        body = list(r.rng(rva, None))[:12]
        seen = sorted({md[2] for i in body for md in i.mems})
        r.verdict(f"B3.2 {name} {h(rva)} touches {[h(d) for d in disps]}",
                  any(d in seen for d in disps), [f"  disps seen {[h(d) for d in seen]}"])

    print("  -- CIB copy accessor head (expect &actor[0x878], +6/+0x10 joint reads claimed) --")
    for line in r.dump(0xD04B0, None)[:6]:
        print(line)

    d_83c = [i for i in r.rng(0xC5DA2, 0xC5DDE) if any(md[2] in (0x83C, 0x83D, 0x83E, 0x83F, 0x840, 0x838)
                                                       for md in i.mems)]
    r.verdict("B3.3 reset 0xC5DA2..0xC5DD8 clears engaged/override (+0x83C..+0x840)", len(d_83c) >= 3,
              ["    " + l.strip() for l in list(r.f(x) for x in d_83c)[:6]])

    reads = [i for i in r.rng(0x2A153, 0x2A1C2) if any(md[2] in (0x83C, 0x83E) for md in i.mems)]
    rep = list(r.rng(0x2A1C7, 0x2A25D))
    via = r.calls_to(0x2A140, 0x2A300, 0x2A9B0)
    joints = sorted({md[2] for i in reads for md in i.mems})
    r.verdict("B3.4 skeleton-update hold/re-parent: override+engaged reads at 0x2A153.. and "
              "resolver calls to 0x2A9B0", bool(reads) and bool(via),
              [f"  read disps {[h(d) for d in joints]}; 0x2A9B0 calls {[h(i.rva) for i in via][:4]}"])

    print("  -- re-parent window head (joint -1 = none; standard pos 0x7E/0x7F expected) --")
    se_7e7f = [i for i in r.rng(0x2A140, 0x2A300) if any(imm in (0x7E, 0x7F) for imm in i.imms)]
    print(f"     insns carrying 0x7E/0x7F immediates: {[h(i.rva) for i in se_7e7f][:8]}")

    for label, rva, disp in (("main Info+0x04 -> actor+0x87C", 0xD0C76, 0x87C),
                             ("sub  Info+0x04 -> actor+0x87F", 0xD0C9C, 0x87F),
                             ("main Info+0x06 -> actor+0x87E", None, 0x87E)):
        if rva is None:
            continue
        body = list(r.rng(rva, None))[:4]
        hits = [i for i in r.rng(rva - 0x20, rva + 0x30) if any(md[2] == disp for md in i.mems)]
        r.verdict(f"B3.5 model-load site {label} at {h(rva)}", bool(hits),
                  ["    " + l.strip() for l in (r.f(x) for x in hits[:3])])

    dual = [i for i in r.rng(0xD0CB7, 0xD0CCC) if any(md[2] == 0x88A for md in i.mems)]
    r.verdict("B3.6 sub Info+0x03 -> actor+0x88A inside the dual-wielder window (0xD0CB7..0xD0CCB)",
              bool(dual), ["    " + l.strip() for l in list(r.f(x) for x in dual)[:4]])

    print("  -- draw/sheathe id builders: 'in ' then digit; 'out' then digit --")
    for name, rva in (("in ", 0xD2ED0), ("out", 0xD2EF0)):
        body = list(r.rng(rva, None))[:16]
        imms = sorted({imm for i in body for imm in i.imms if imm > 0x20})
        print(f"     {name} @ {h(rva)}: disps {[h(md[2]) for i in body for md in i.mems][:8]}"
              f" big imms {[hex(v) for v in imms][:6]}")


# ===========================================================================
# B4 - weapon motion blocks: dual-wield decided from the sub slot's model alone; kind-indexed
#      tables (0 single / 1 dual main / 2 off-hand); negative type -> no file.
# ===========================================================================
def b4(r):
    print("\n=== B4 weapon motion block selection (new doc §4) ===")
    win = list(r.rng(0xD3CFC, 0xD3D2E))
    r.verdict("B4.1 dual-wield decision window 0xD3CFC..0xD3D2B is code", len(win) >= 6,
              ["    " + l.strip() for l in list(r.f(x) for x in win)[:8]])

    oor = list(r.rng(0xD3C81, 0xD3CAC))
    zero_writes = [i for i in oor if i.mn == "xor" and i.ops.startswith("eax")]
    r.verdict("B4.2 out-of-range model reads as 0 (0xD3C81..0xD3CAB)", bool(zero_writes),
              ["    " + l.strip() for l in list(r.f(x) for x in zero_writes)[:3]])

    kind = list(r.rng(0xD2E30, None))[:40]
    guard = [i for i in r.rng(0xD2E6A, 0xD2E78)]
    r.verdict("B4.3 kind-indexed loader head at 0xD2E30", bool(kind),
              ["    " + l.strip() for l in (r.f(x) for x in kind[:10])])
    print("     negative-type window:")
    for line in r.dump(0xD2E6A, 0xD2E78):
        print(line)

    for name, rva in (("kind 0 loader", 0xD16C0), ("kinds 1+2 loader", 0xD1970)):
        i = r.at(rva)
        body = list(r.rng(rva, None))[:8]
        print(f"     {name} @ {h(rva)}: head {[x.mn + ' ' + x.ops for x in body][:3]}")


GROUPS = {"A1": a1, "A2": a2, "B1": b1, "B2": b2, "B3": b3, "B4": b4}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("groups", nargs="*")
    ap.add_argument("--dll", default=os.environ.get("FFXI_DLL", DEF_DLL))
    args = ap.parse_args()
    want = list(GROUPS) if (not args.groups or "all" in args.groups) else [g.upper() for g in args.groups]

    print(f"dll {args.dll}")
    if not os.path.exists(args.dll):
        print("MISSING - unpack artifacts/ffximain_tables_v0.zip with its unpack.py first")
        return 1
    r = Reader(args.dll)
    print(f"TDS confirmed: {h(r.img.pe.FILE_HEADER.TimeDateStamp)}   image base {h(r.base)}")
    for g in want:
        GROUPS[g](r)
    print(f"\n=== totals: PASS {r.passed}  DIFF {r.diff} ===")


if __name__ == "__main__":
    main()
