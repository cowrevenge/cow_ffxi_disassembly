"""Rebuild docs/event_evidence.md (next to this script) from the raw dumps in out3/.

Each section embeds one or more out3/*.md files verbatim under its heading; the E-entries in
docs/event_vm.md cite these sections as "evidence doc \u00a7X". The I.2 section carries the
E16 correction block (true VTABLE/FTABLE ids for five of the p9 scan's rows) after the raw output.
Re-running this script regenerates the evidence doc exactly from the current out3/ contents; if you
add new dumps, extend the section lists here and re-run. Usage: python assemble_event_evidence.py
"""
import os
import sys

# Raw dump folder is local working data, never tracked: point FFXI_DISASM_OUT3 at it.
OUT = os.environ.get("FFXI_DISASM_OUT3")
if not OUT:
    sys.exit("set FFXI_DISASM_OUT3 to the local raw event-pass dump folder (out3)")
DEST = os.path.join(os.path.dirname(os.path.abspath(__file__)), "docs", "event_evidence.md")


def rd(name):
    p = os.path.join(OUT, name)
    with open(p, encoding="utf-8", errors="replace") as f:
        return f.read().rstrip("\n")


parts = []
parts.append("""# FFXI Event VM Disassembly - Raw Evidence (Part 1)

Companion to [event_vm.md](event_vm.md). This doc holds the raw scanner
outputs and disassembly dumps that back the E-findings. All addresses are RVAs relative to
`FFXiMain.dll` ImageBase **0x10000000** (on-disk VA = 0x10000000 + RVA). `.text` is POL1-packed on
disk; every dump was produced by the tooling in `ffxi_disassembly/` (this folder) after auto-decoding. Raw
source files live in the local untracked raw dump folder named by FFXI_DISASM_OUT3; the listings below are copies
of those outputs.

Section letters (\u00a7A, \u00a7B, ...) are cited by the E-entries ("evidence doc \u00a7X").""")


def section(letter, title, fname, note):
    out = []
    out.append("\n## %s. %s\n" % (letter, title))
    if note:
        out.append(note + "\n")
    out.append("Source file: `out3/%s`\n" % fname)
    out.append("```text")
    out.append(rd(fname))
    out.append("```\n")
    return "\n".join(out)


parts.append(section("A", "XiEvents pattern search (p7_event_vm.py)", "p7.md",
  "All 20 Part-A patterns matched in this build's `.text`. One row per function with hit RVA, the "
  "heuristic func start it sits in, and the matched bytes. Backs E1."))

parts.append(section("B", "ExecProg switch + jump table (p8_jumptable.py)", "p8.md",
  "The full 219-entry dispatch table at rva 0xBC970: opcode -> entry VA -> thunk RVA -> handler RVA. "
  "Backs E2 and is the source of event_opcode_table.md."))

parts.append(section("B2", "ExecProg prologue + first thunks (disasm.py --func 0xBC27C)", "d_bc27c.md",
  "ExecProg @0xBC290 dispatch instruction (`movsx eax,[esp+4]; cmp eax,0xDA; ja default; jmp "
  "[eax*4+0x100BC970]`) and the `call handler; ret 4` thunk shape with ecx passed through. Backs E2."))

parts.append("\n## C. 0x5B / 0x66 thunks, shared helper @0xB5220, and all six callers\n")
parts.append("Backs E3 (param3 never 1; width always 15) and the T2 helper flow.\n")
for fname, sub in [
    ("d_b5200.md", "C.1 0x5B @0xB5200 and 0x66 @0xB5210 thunks + start of helper @0xB5220 (disasm.py --func 0xB5200)"),
    ("x_b5220.md", "C.2 xref.py --to 0xB5220: all six callers with their push sequences"),
    ("d_b72d0.md", "C.3 0x5F @0xB72D0 sub-scheduler: cases 3 to 6 call the helper (disasm.py --func 0xB72D0)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## D. The two motion resource readers\n")
parts.append("Backs E4 (ReadEventMotionRes Type gate + bands), E5 (ReadTpcEventMotionRes A/B mapping), "
             "and the 0x84410 entity-Type gate.\n")
for fname, sub in [
    ("d_84410.md", "D.1 Entity-Type gate @0x84410 (disasm.py --func 0x84410)"),
    ("d_d2120.md", "D.2 ReadEventMotionRes @0xD2120 (disasm.py --func 0xD2120); the misaligned data at 0xD2218/0xD2220 is the jump + byte tables"),
    ("probe_d2218.md", "D.3 Raw read of the ReadEventMotionRes byte table @0xD2220 and jump table @0xD2218 (confirms load for Type {1,2,7,8})"),
    ("d_d2230.md", "D.4 ReadTpcEventMotionRes @0xD2230 (disasm.py --func 0xD2230); the four-band A/B mapping in tpc_package_table.md"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## E. SetAction @0xCEE50 (T2c)\n")
parts.append("Backs E7 (miss = silent no-op ret 0; hit ret 1).\n")
parts.append("Source file: `out3/d_cee50.md`\n")
parts.append("```text")
parts.append(rd("d_cee50.md"))
parts.append("```\n")

parts.append("\n## F. The request stack (EventIdle, loop wrapper, ReqSet/GetReq*, 0x27 to 0x2A)\n")
parts.append("Backs E8 to E11.\n")
for fname, sub in [
    ("d_bcd20.md", "F.1 EventIdle @0xBCD20 + XiEventInit @0xBCDE0 (disasm.py --func 0xBCD20)"),
    ("d_bcce0.md", "F.2 ExecProg loop wrapper @0xBCCE0 (disasm.py --func 0xBCCE0); clears RetFlag, loops until RetFlag != 0"),
    ("d_b3590.md", "F.3 GetReqLevel @0xB36A0 / GetReqStatus @0xB36E0 / scan helper @0xB3670 + adjacent (disasm.py --func 0xB3590)"),
    ("d_b3730.md", "F.4 ReqSet @0xB3730 (disasm.py --func 0xB3730)"),
    ("d_b3940.md", "F.5 0x27 @0xB3940 request-on-target + helper call site (disasm.py --func 0xB3940)"),
    ("d_b3a2f.md", "F.6 Helper @0xB39B0 tail incl. the ReqSet call on ent+0xD4 (disasm.py --rva 0xB3A2F)"),
    ("d_b3e60.md", "F.7 0x28 @0xB3E60 wait-for-requested-event (disasm.py --func 0xB3E60)"),
    ("d_b4000.md", "F.8 0x29 @0xB4000 request-wait/poll, cases 1 and 2 (disasm.py --func 0xB4000)"),
    ("d_b41f9.md", "F.9 0x29 case-0 new-request path @0xB41F9 (disasm.py --rva 0xB41F9 --len 128)"),
    ("d_b424c.md", "F.10 0x29/0x2A fail-path EP advance @0xB424C and success tails @0xB426C/0xB427C (disasm.py --rva 0xB424C --len 64)"),
    ("d_b4290.md", "F.11 0x2A @0xB4290 req-wait/level check (disasm.py --func 0xB4290)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## G. GetActorIndex @0xAFB10 (full decode)\n")
parts.append("Backs E12.\n")
for fname, sub in [
    ("d_afa8c.md", "G.1 eventgetcode @0xAFAA0 / eventgetcode2 @0xAFAD0 / GetActorIndex @0xAFB10 start (disasm.py --func 0xAFA8C)"),
    ("probe_afb24.md", "G.2 GetActorIndex jumptable @0xAFC18 + first index bytes @0xAFC44"),
    ("probe_afc44.md", "G.3 Full 57 index bytes @0xAFC44 mapped esi -> reserved code -> case"),
    ("d_afb24_full.md", "G.4 GetActorIndex middle @0xAFB24..0xAFC18: all switch cases incl. the event-entity and party paths (disasm.py --rva 0xAFB24 --len 160)"),
    ("d_afbc4.md", "G.5 GetActorIndex default tail @0xAFBC4: literal server id vs event-entity fallback + entity-table lookup (disasm.py --func 0xAFBC4)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## H. 'Still running' predicates (0x52 to 0x55)\n")
parts.append("Backs E13.\n")
for fname, sub in [
    ("d_B4E10.md", "H.1 0x53 @0xB4E10 is-moving-action + adjacent start/stop variants (disasm.py --func 0xB4E10)"),
    ("d_B5100.md", "H.2 0x54 @0xB5100 zone is-moving-action via [zoneObj->vt+0x20] (disasm.py --func 0xB5100)"),
    ("d_B4960.md", "H.3 0x55 @0xB4960 is-moving-scheduler via 0x62EE0 (disasm.py --func 0xB4960)"),
    ("d_B48E0.md", "H.4 0x52 @0xB48E0 start/load-and-run scheduler via 0x62E90 (disasm.py --func 0xB48E0)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## I. Zone scene DAT and 0x2D (T5)\n")
parts.append("Backs E14.\n")
for fname, sub in [
    ("d_b4f20.md", "I.1 0x2D @0xB4F20 zone SetAction via [zoneObj->vt+0x18] (disasm.py --func 0xB4F20)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

# I.2 with the E16 correction block appended after the raw output (see docs/event_vm.md E16).
sub = "I.2 DAT scan: every file with movN / exNN scheduler stages (52869 DATs scanned); only ROM\\0\\23.DAT has both"
parts.append("\n### %s\n" % sub)
parts.append("Source file: `out3/p9_zone_scene_scan.md`\n")
parts.append("```text")
parts.append(rd("p9_zone_scene_scan.md"))
parts.append("```\n")
parts.append(r"""Correction (E16, 2026-09-11): the id column of this run was computed arithmetically ((dir << 7) | file,
plus a 0x8000 offset for ROM2) instead of through VTABLE/FTABLE. The true client file ids are:

| path | recorded id | true table id |
|------|-------------|---------------|
| ROM\62\113.DAT | 8049 | 31004 |
| ROM\62\114.DAT | 8050 | 31005 |
| ROM\62\115.DAT | 8051 | 31006 |
| ROM\62\119.DAT | 8055 | 31010 |
| ROM2\19\126.DAT | 35326 | 31009 |

The ids for ROM\0\23..26.DAT (23 to 26) are correct under both schemes. The hit list itself (which files
carry movN / exNN references, and their name lists) is unchanged; verified by re-running
`p9_zone_scene.py` in this folder, which resolves ids through VTABLE/FTABLE.""")
for fname, sub in [
    ("probe_zone_vt.md", "I.3 All zone-object vcall sites in .text; the [zoneObj->vt+N] pattern at 0xB4FF8 / 0xB50E8 / 0xB7439"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## J. The Tpc B flag chain (E17)\n")
parts.append("Backs E17: the [vt+0x3D8] vcall target, the flag byte at actor+0x881, its writer and "
             "the CIB waist_type identification.\n")
for fname, sub in [
    ("probe_vt3d8.md", "J.1 Vtable slot +0x3D8: raw read of the vtable rows around rva 0x331318; the slot holds 0x100D04C0"),
    ("d_d04c0.md", "J.2 The accessor @rva 0xD04C0: `lea eax,[ecx+0x878]; ret` (disasm.py --func 0xD04C0)"),
    ("x_881.md", "J.3 xref.py --disp 0x881: all twelve disp-0x881 sites in eleven funcs; the two writers are @rva 0xCF419 and 0xD0C5B"),
    ("vt_cf220.md", "J.4 Vtable slots holding the writer @rva 0xCF220: slot +0x290 of four vtables (incl. the skeleton-actor family @0x330F40) plus slots +0x6B0/+0xAD0/+0xEF0 of the larger vtable @0x32E890"),
    ("d_cf180.md", "J.5 Resource-load path pushing types 0x29/0x2A (raw dump from rva 0xCF182)"),
    ("d_cf2c0.md", "J.6 Same path pushing type 0x45 @rva 0xCF2F2 (raw dump from rva 0xCF2C0)"),
    ("d_cf34b.md", "J.7 The CIB merge loop @rva 0xCF34B: source byte +0x39 -> actor+0x881 with the src < 0x80 / dest >= 0x80 sentinel guards (disasm.py --func 0xCF34B)"),
    ("d_cf4a8.md", "J.8 Tail of the CIB merge loop: further guarded byte merges into actor+0x87E.. (raw dump from rva 0xCF498)"),
    ("x_moun.md", "J.9 The 'moun' FourCC branch @rva 0xCF321: different merge base, no +0x881 site"),
    ("cib_b9_census.md", "J.10 ROM census of CIB byte-9 values over 49317 DATs (18128 with CIB chunks)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## K. The global zone scene file ROM\\0\\23.DAT (E18)\n")
parts.append("Backs E18: the full parse of the single global scene file, its routine stage streams and "
             "the camera-name census against vendor zone ids. `d_scene23_full.md` is the canonical report "
             "regenerated by `scene_dat_parse.py`; the other three are earlier exploration dumps kept for "
             "provenance.\n")
for fname, sub in [
    ("d_scene23.md", "K.1 dat_routines.py dump of ROM\\0\\23.DAT: 73872 bytes, 346 chunks, chunk-type census and the `loop` routine's stage stream"),
    ("d_scene23_chunks.md", "K.2 Per-chunk raw view: header bytes, the u32@chunk+0x24 stage pointer and body prefixes for every 0x07 routine chunk"),
    ("d_scene23_stages.md", "K.3 Raw stage-stream byte dumps per routine (the pre-decode exploration)"),
    ("d_scene23_full.md", "K.4 Canonical report from scene_dat_parse.py: per-routine decoded stage streams, camera-name census with hex-prefix zone-id check and channel names from vendor/server/sql/zone_settings.sql, stage-type histogram, routine -> route reference table, and the 0x04-refs-vs-0x06-definitions check"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## L. The 192 probe (E19)\n")
parts.append("Backs E19: the one-probe float search for 192.0f / 280.0f / 350.0f and the dump of the "
             "selecting function.\n")
for fname, sub in [
    ("probe_192.md", "L.1 Raw u32 byte search over the POL1-decoded .text and all data sections: 192.0f has 0 hits whole-image; 280.0f / 350.0f hit lists with context around rva 0x59455/0x5945F"),
    ("d_59455.md", "L.2 The selecting function @rva 0x5940A to 0x5947D: global byte @rva 0x487FC0 picks 280.0f vs 350.0f, fed to the focal setter @rva 0x15290 (disasm.py --func 0x5940A)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

parts.append("\n## M. The CHAR_NPC Type sweep (E20)\n")
parts.append("Backs E20: every disp-0xEE site, the SubKind dispatch and its jump table, and the per-Type "
             "setter regions of the s2c 0x0E handler.\n")
for fname, sub in [
    ("x_ee.md", "M.1 All 84 memory operands with disp 0xEE across .text (lean capstone scanner), each with a few context lines"),
    ("d_9c8e0.md", "M.2 The CHAR_NPC handler region incl. the SubKind dispatch @rva 0x9C917 (`byte [esi+0x30] & 7` -> jumptable @rva 0x9CE98) and the SubKind-1 Type=0/1 path (raw dump from rva 0x9C8E0)"),
    ("d_9c840.md", "M.3 Adjacent field-packing region of the same handler (raw dump from rva 0x9C843)"),
    ("d_9c780.md", "M.4 Another ent+0x12C consumer: bit-14 write @rva 0x9C78B and the bit-30 read gate @rva 0x9C7A1 to 0x9C7AD (raw dump from rva 0x9C785)"),
    ("d_9c940.md", "M.5 Type setters for SubKind 0 to 3: Type=2 @rva 0x9C9C7, Type=3 @rva 0x9CB82, Type=4 @rva 0x9CC21 (raw dump from rva 0x9C940)"),
    ("d_9cc28.md", "M.6 Type setters for SubKind 4 to 7: Type=5 @rva 0x9CC8E, Type=6 @rva 0x9CD57, Type=7 @rva 0x9CDC1 (model-range check), Type=8 @rva 0x9CE6D; the jumptable bytes at rva 0x9CE98 decode as data here (raw dump from rva 0x9CC28)"),
    ("x_12c_w.md", "M.7 All write/test sites of ent+0x12C (the flag word whose bit 30 splits Type 0 vs 1)"),
]:
    parts.append("\n### %s\n" % sub)
    parts.append("Source file: `out3/%s`\n" % fname)
    parts.append("```text")
    parts.append(rd(fname))
    parts.append("```\n")

doc = "\n".join(parts) + "\n"
with open(DEST, "w", encoding="utf-8") as f:
    f.write(doc)
print("wrote event_evidence.md, lines:", doc.count("\n"), "chars:", len(doc))
