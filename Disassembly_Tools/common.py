"""
common.py - shared helpers for the FFXiMain.dll research scanners.

Static analysis of the on-disk PE. Addresses are reported as RVAs (relative to ImageBase) so
they match the plan's §9 conventions. Runtime addresses seen in wormwatch logs convert as
RVA = VA - 0x04AC0000 (that session's base); on-disk VAs use ImageBase from the PE header.

Requires: pip install pefile capstone
"""
from __future__ import annotations

import bisect
import os
import pickle
import re
import struct
import sys
from dataclasses import dataclass, field
from typing import Iterator

import pefile
from capstone import CS_ARCH_X86, CS_MODE_32, Cs
from capstone.x86 import X86_OP_IMM, X86_OP_MEM

# ---------------------------------------------------------------------------
# Known anchors from Phase L (RVAs). Keep in sync with the plan §4 Phase 1 table.
# ---------------------------------------------------------------------------
KNOWN_RVAS = {
    0x330F40: "CXiSkeletonActor vtable (actor +0)",
    0x075010: "actor +4 / motion object +4 (function or 2nd vtable)",
    0x32BB38: "motion-task scheduler node vtable (clip fourcc +0x3C, frames +0x40)",
    0x32B680: "generic scheduler node vtable (pool, stride 0x140)",
    0x32B654: "motion object vtable (clip fourcc +0x30, model id +0x44)",
    0x32CF5C: "constant at node +0x14/+0x20",
    0x32A5EC: "constant at node +0x6C / motion obj +0x60",
    0x32D69C: "constant at node +0x8C",
    0x32A210: "first-node +0x04",
}

# XiAtelBuff field offsets the 0x0E handler is known to touch (Phase L).
ENT = {"ActorPointer": 0x0A0, "ActionTimer1": 0x11C, "ActionTimer2": 0x11E, "RenderFlags0": 0x120}
# 0x0E packet offsets from packet start incl. 4-byte header (LSB numbering) and body-relative.
PKT = {"animation": 0x1F, "status": 0x20, "animationsub": 0x2A}
PKT_BODY = {"animation": 0x1B, "status": 0x1C, "animationsub": 0x26}

FOURCC_LITERALS = {
    "ini": 0x00696E69,   # 'ini\0'
    "init": 0x74696E69,
    "ini1": 0x31696E69,
    "pop0": 0x30706F70,
    "pop1": 0x31706F70,
    "sp00": 0x30307073,
    "sp10": 0x30317073,
}


def fourcc_str(v: int) -> str:
    out = ""
    for i in range(4):
        c = (v >> (8 * i)) & 0xFF
        out += chr(c) if 0x20 <= c < 0x7F else "."
    return out


def pol1_decode(payload: bytes, expected_size: int | None = None) -> bytes:
    """Decode the POL1 bit-packed LZSS stream used by FFXiMain.dll / FFXi.dll.

    Both DLLs ship with `.text` rawsize 0; the real machine code is compressed in a custom
    `POL1` section and unpacked at load time by an entry stub that lives at the tail of POL1.
    Verified instruction-by-instruction against the in-binary unpacker (FFXiMain rva 0xBB1AFB,
    called from the entry point 0xBB1A60 with src=base+POL1_rva, dst=base+.text_rva):

      - tag byte = 8 ops, MSB first (`shl bl,1; jae` tests bit7 of the original byte)
      - bit=1 -> literal: out[dst++] = *src++
      - bit=0 -> back-ref: b1,b2 = next two bytes; off = (b2 | b1<<8) & 0xFFF;
        off == 0 terminates the stream; len = (b1 >> 4) + 3; byte-wise copy
        out[dst+i] = out[dst+i-off] for i in range(len)
      - the unpacker ignores its size arguments and stops only at off==0; the decoded length
        equals .text vsize exactly on both binaries.
    """
    out: list[int] = []
    src_i = 0
    n = len(payload)
    while src_i < n:
        tag = payload[src_i]
        src_i += 1
        for k in range(8):
            if src_i >= n:
                break
            if tag & (0x80 >> k):  # literal
                out.append(payload[src_i])
                src_i += 1
            else:                  # back-reference
                b1 = payload[src_i]
                b2 = payload[src_i + 1]
                src_i += 2
                off = (b2 | (b1 << 8)) & 0xFFF
                if off == 0:
                    if expected_size is not None and len(out) != expected_size:
                        raise ValueError(
                            f"POL1 stream ended at {len(out):#x} bytes, expected {expected_size:#x}")
                    return bytes(out)
                ln = (b1 >> 4) + 3
                for _ in range(ln):
                    out.append(out[len(out) - off])
    raise ValueError("POL1 payload exhausted before end-of-stream marker")


def h(rva: int) -> str:
    return f"0x{rva:X}"


# ---------------------------------------------------------------------------
# PE image
# ---------------------------------------------------------------------------
class Image:
    def __init__(self, path: str):
        self.path = path
        self.pe = pefile.PE(path, fast_load=True)
        try:
            self.pe.parse_data_directories(directories=[
                pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_IMPORT"],
                pefile.DIRECTORY_ENTRY["IMAGE_DIRECTORY_ENTRY_EXPORT"],
            ])
        except Exception:
            pass
        self.base = self.pe.OPTIONAL_HEADER.ImageBase
        self.data = self.pe.__data__
        # (name, rva, vsize, rawoff, rawsize, characteristics)
        self.sections = [(s.Name.rstrip(b"\0").decode(errors="replace"), s.VirtualAddress,
                          max(s.Misc_VirtualSize, s.SizeOfRawData), s.PointerToRawData,
                          s.SizeOfRawData, s.Characteristics) for s in self.pe.sections]
        # POL1-packed executable section: `.text` rawsize==0 with a `POL1` section present means
        # the code is unpacked at load time (see pol1_decode). Decode it once so every scanner can
        # treat the image as if .text were on disk. packed_text maps text_rva -> (vsize, blob).
        self.packed_text: dict[int, tuple[int, bytes]] = {}
        for name, va, vsize, raw, rawsize, ch in self.sections:
            if (ch & 0x20000000) and rawsize == 0:
                pol1 = next((s for s in self.sections if s[0] == "POL1"), None)
                if pol1 is not None:
                    payload = self.data[pol1[3]:pol1[3] + pol1[4]]
                    blob = pol1_decode(payload, vsize)
                    self.packed_text[va] = (vsize, blob)

    def section_of(self, rva: int):
        for name, va, vsize, raw, rawsize, ch in self.sections:
            if va <= rva < va + vsize:
                return name
        return None

    def rva_to_off(self, rva: int):
        for name, va, vsize, raw, rawsize, ch in self.sections:
            if va <= rva < va + rawsize:
                return raw + (rva - va)
        return None

    def off_to_rva(self, off: int):
        for name, va, vsize, raw, rawsize, ch in self.sections:
            if raw <= off < raw + rawsize:
                return va + (off - raw)
        return None

    def read(self, rva: int, n: int) -> bytes:
        off = self.rva_to_off(rva)
        if off is not None:
            return self.data[off:off + n]
        for va, (vsize, blob) in self.packed_text.items():
            if va <= rva < va + vsize:
                i = rva - va
                return blob[i:i + n]
        return b""

    def u32(self, rva: int):
        b = self.read(rva, 4)
        return struct.unpack("<I", b)[0] if len(b) == 4 else None

    def section_bytes(self, name: str):
        for sname, va, vsize, raw, rawsize, ch in self.sections:
            if sname == name:
                return va, self.data[raw:raw + rawsize]
        raise KeyError(name)

    def text(self):
        for sname, va, vsize, raw, rawsize, ch in self.sections:
            if ch & 0x20000000:  # IMAGE_SCN_MEM_EXECUTE
                packed = self.packed_text.get(va)
                return va, (packed[1] if packed else self.data[raw:raw + rawsize])
        return self.section_bytes(".text")

    def text_name(self):
        for sname, va, vsize, raw, rawsize, ch in self.sections:
            if ch & 0x20000000:
                return sname
        return ".text"

    def find_bytes(self, needle: bytes, section=None) -> list:
        hits = []
        if section:
            va, blob = self.section_bytes(section)
            i = blob.find(needle)
            while i != -1:
                hits.append(va + i)
                i = blob.find(needle, i + 1)
        else:
            i = self.data.find(needle)
            while i != -1:
                r = self.off_to_rva(i)
                if r is not None:
                    hits.append(r)
                i = self.data.find(needle, i + 1)
            for va, (vsize, blob) in self.packed_text.items():
                j = blob.find(needle)
                while j != -1:
                    hits.append(va + j)
                    j = blob.find(needle, j + 1)
        return hits

    def find_u32(self, value: int, section=None) -> list:
        return self.find_bytes(struct.pack("<I", value & 0xFFFFFFFF), section)

    def describe(self) -> str:
        oh = self.pe.OPTIONAL_HEADER
        m = self.pe.FILE_HEADER.Machine
        lines = [f"file: {self.path}  size {len(self.data)} bytes",
                 f"machine: 0x{m:X} ({'i386' if m == 0x14C else 'NOT i386'})",
                 f"ImageBase 0x{self.base:08X}  SizeOfImage 0x{oh.SizeOfImage:X}  EntryPoint rva 0x{oh.AddressOfEntryPoint:X}",
                 f"TimeDateStamp 0x{self.pe.FILE_HEADER.TimeDateStamp:08X}  Characteristics 0x{self.pe.FILE_HEADER.Characteristics:04X}"
                 f"  DllCharacteristics 0x{oh.DllCharacteristics:04X}",
                 "sections:"]
        for name, va, vsize, raw, rawsize, ch in self.sections:
            lines.append(f"  {name:<8} rva 0x{va:08X}  vsize 0x{vsize:08X}  raw 0x{raw:08X}  rawsize 0x{rawsize:08X}  flags 0x{ch:08X}")
        return "\n".join(lines)

    def imports(self):
        out = []
        for entry in getattr(self.pe, "DIRECTORY_ENTRY_IMPORT", []):
            dll = entry.dll.decode(errors="replace")
            for imp in entry.imports:
                out.append((dll, imp.name.decode(errors="replace") if imp.name else f"ord{imp.ordinal}",
                            imp.address - self.base))
        return out

    def exports(self):
        out = []
        exp = getattr(self.pe, "DIRECTORY_ENTRY_EXPORT", None)
        if exp:
            for e in exp.symbols:
                out.append((e.name.decode(errors="replace") if e.name else f"ord{e.ordinal}", e.address))
        return out

    def strings(self, minlen: int = 4, utf16: bool = True) -> Iterator:
        ascii_re = re.compile(rb"[\x20-\x7e]{%d,}" % minlen)
        u16_re = re.compile(rb"(?:[\x20-\x7e]\x00){%d,}" % minlen)
        for name, va, vsize, raw, rawsize, ch in self.sections:
            blob = self.data[raw:raw + rawsize]
            for m in ascii_re.finditer(blob):
                yield va + m.start(), "A", name, m.group().decode("ascii")
            if utf16:
                for m in u16_re.finditer(blob):
                    yield va + m.start(), "U", name, m.group().decode("utf-16le")


# ---------------------------------------------------------------------------
# Linear sweep with cache
# ---------------------------------------------------------------------------
@dataclass
class Insn:
    rva: int
    size: int
    mn: str
    ops: str
    imms: tuple = ()          # immediate operands (u32)
    mems: tuple = ()          # (base_reg, index_reg, disp, opsize_bytes) per memory operand
    call_target: object = None  # rva for direct call/jmp rel32
    is_ret: bool = False


@dataclass
class Sweep:
    insns: list
    by_rva: dict = field(default_factory=dict)
    rvas: list = field(default_factory=list)
    func_starts: list = field(default_factory=list)

    def index(self):
        self.rvas = [i.rva for i in self.insns]
        self.by_rva = {r: n for n, r in enumerate(self.rvas)}
        starts = []
        for n, ins in enumerate(self.insns):
            if n == 0:
                starts.append(ins.rva)
                continue
            p = self.insns[n - 1]
            gap = ins.rva - (p.rva + p.size)
            boundary = p.is_ret or p.mn == "int3" or p.mn == "jmp" or gap > 0 or p.mn == ".byte"
            if boundary and ins.mn not in ("int3", "nop", ".byte"):
                starts.append(ins.rva)
        self.func_starts = sorted(set(starts))

    def insn_at(self, rva: int):
        n = self.by_rva.get(rva)
        if n is None:
            n = max(bisect.bisect_right(self.rvas, rva) - 1, 0)
        return n

    def func_of(self, rva: int) -> int:
        i = bisect.bisect_right(self.func_starts, rva) - 1
        return self.func_starts[max(i, 0)]

    def func_range(self, start: int):
        i = bisect.bisect_left(self.func_starts, start)
        if i + 1 < len(self.func_starts):
            end = self.func_starts[i + 1]
        else:
            end = self.insns[-1].rva + self.insns[-1].size
        return start, end

    def iter_range(self, start: int, end: int) -> Iterator:
        lo = bisect.bisect_left(self.rvas, start)
        for ins in self.insns[lo:]:
            if ins.rva >= end:
                break
            yield ins

    def callers_of(self, target: int) -> list:
        return [i for i in self.insns if i.call_target == target and i.mn == "call"]

    def refs_to(self, target: int) -> list:
        return [i for i in self.insns if i.call_target == target]


def sweep_text(img: Image, cache_dir: str = ".cache", force: bool = False) -> Sweep:
    """Linear-disassemble the executable section once; cache to disk (takes a few minutes)."""
    os.makedirs(cache_dir, exist_ok=True)
    # v2: .text may be POL1-decoded (blob starts at the section RVA, not 0); invalidates caches
    # built by the original version, which indexed the decoded blob as if byte 0 == rva 0.
    key = f"{os.path.basename(img.path)}_{img.pe.FILE_HEADER.TimeDateStamp:08X}_{len(img.data)}.v2.sweep.pkl"
    cpath = os.path.join(cache_dir, key)
    if not force and os.path.exists(cpath):
        with open(cpath, "rb") as f:
            sw = pickle.load(f)
        sw.index()
        return sw

    va, blob = img.text()
    cs = Cs(CS_ARCH_X86, CS_MODE_32)
    cs.detail = True
    cs.skipdata = True
    insns = []
    total = max(len(blob), 1)
    last = -1
    for ins in cs.disasm(blob, img.base + va):
        rva = ins.address - img.base
        pct = (rva - va) * 100 // total
        if pct != last:
            print(f"  sweep {pct}%   ", file=sys.stderr, end="\r")
            last = pct
        if ins.id == 0:
            insns.append(Insn(rva, ins.size, ".byte", ins.op_str))
            continue
        imms, mems, tgt = [], [], None
        for op in ins.operands:
            if op.type == X86_OP_IMM:
                imms.append(op.imm & 0xFFFFFFFF)
            elif op.type == X86_OP_MEM:
                mems.append((cs.reg_name(op.mem.base) if op.mem.base else "",
                             cs.reg_name(op.mem.index) if op.mem.index else "",
                             op.mem.disp, op.size))
        if ins.mnemonic in ("call", "jmp") and ins.operands and ins.operands[0].type == X86_OP_IMM:
            tgt = (ins.operands[0].imm - img.base) & 0xFFFFFFFF
        insns.append(Insn(rva, ins.size, ins.mnemonic, ins.op_str, tuple(imms), tuple(mems), tgt,
                          ins.mnemonic in ("ret", "retn")))
    print(file=sys.stderr)
    with open(cpath, "wb") as f:
        pickle.dump(Sweep(insns), f, protocol=pickle.HIGHEST_PROTOCOL)
    sw = Sweep(insns)
    sw.index()
    return sw


# ---------------------------------------------------------------------------
# Printing helpers (output is meant to be pasted into §9)
# ---------------------------------------------------------------------------
def annotate(img: Image, ins: Insn) -> str:
    notes = []
    if ins.call_target is not None and ins.call_target in KNOWN_RVAS:
        notes.append(KNOWN_RVAS[ins.call_target])
    for imm in ins.imms:
        r = imm - img.base
        if r in KNOWN_RVAS:
            notes.append(f"VA of {KNOWN_RVAS[r]} (rva {h(r)})")
        elif imm in FOURCC_LITERALS.values():
            notes.append(f"'{fourcc_str(imm)}'")
        elif 0x20202020 <= imm <= 0x7E7E7E7E and fourcc_str(imm).replace(".", "") == fourcc_str(imm):
            notes.append(f"fourcc? '{fourcc_str(imm)}'")
    for base, idx, disp, sz in ins.mems:
        for k, v in ENT.items():
            if disp == v:
                notes.append(f"ent.{k}?")
        for k, v in PKT_BODY.items():
            if disp == v and sz == 1:
                notes.append(f"pkt body {k}?")
        for k, v in PKT.items():
            if disp == v and sz == 1:
                notes.append(f"pkt(hdr) {k}?")
    return "   ; " + "; ".join(notes) if notes else ""


def fmt_insn(img: Image, ins: Insn, mark: str = "  ") -> str:
    b = img.read(ins.rva, ins.size).hex(" ")
    return f"{mark}{ins.rva:08X}  {b:<26} {ins.mn} {ins.ops}{annotate(img, ins)}"


def dump_range(img: Image, sw: Sweep, start: int, end: int, max_lines: int = 500) -> str:
    out = []
    for n, ins in enumerate(sw.iter_range(start, end)):
        if n >= max_lines:
            out.append(f"  ... truncated at {h(ins.rva)} (range end {h(end)})")
            break
        out.append(fmt_insn(img, ins))
    return "\n".join(out)


def dump_context(img: Image, sw: Sweep, rva: int, before: int = 6, after: int = 6) -> str:
    n = sw.insn_at(rva)
    lo, hi = max(n - before, 0), min(n + after + 1, len(sw.insns))
    return "\n".join(fmt_insn(img, sw.insns[i], ">>" if i == n else "  ") for i in range(lo, hi))


def parse_int(s: str) -> int:
    return int(s, 0)
