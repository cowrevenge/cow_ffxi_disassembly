# Event VM pass evidence (§A to §M)

Raw scanner outputs and disassembly dumps backing E1-E20 in [event_vm.md](event_vm.md). Conventions in
[../README.md](../README.md). Sources are copies of the local untracked `out3/*` dumps.

## A. XiEvents pattern search (p7_event_vm.py)

All 20 Part-A patterns matched in this build's `.text`. One row per function with hit RVA, the heuristic func start it sits in, and the matched bytes. Backs E1.

Source file: `out3/p7.md`

```text
# p7_event_vm: XiEvents pattern search in FFXiMain.dll

searched section `.text` rva 0x1000, 0x32762e bytes (POL1-decoded, F24); sweep cache: 1175095 insns / 34634 funcs

| name | hit RVA | func start | matched bytes |
|---|---|---|---|
| EventStartWait | 0xAEA50 | 0xAEA2A | `a0 88 7e 48 10 c7 05 4c 99 48 10 00 00 00 00 84 c0 75 03 b0 01 c3 e8 05 02 00 00 83 f8 ff` |
| InitEvent2 | 0xAEEB0 | 0xAECF0 | `83 ec 14 53 55 56 8b 35 44 99 48 10 57 c7 44 24 18 00 00 00 00 8b 06 83 c6 04 89 44 24 20 89 74 24 1c 8d 1c 85 00 00 00 00 c1 eb 02 85 c0 0f 8e` |
| XiAtelBuff::EventNew | 0x8EDD0 | 0x8EDC5 | `56 57 8b f9 8a 87 20 01 00 00 84 c0 78 5b 68 68 02 00 00 e8 13 2e 28 00 83 c4 04 85 c0 74` |
| XiEvent::XiEvent | 0xBD1B0 | 0xBD17D | `53 55 56 57 68 88 01 00 00 8b f1 e8 3b 4a 25 00 33 db 83 c4 04 3b c3 74 09 8b c8 e8` |
| ~XiEvent | 0xBD600 | 0xBD5B8 | `56 8b f1 57 8b 46 04 66 8b 0e 89 46 08 8b 86 5c 02 00 00 85 c0 66 89 4e 02` |
| XiEventInit | 0xBCDE0 | 0xBCC1A | `53 55 56 8b f1 33 c0 33 db 66 8b 46 02 57 8b 04 85 30 0b 48 10 3b c3 0f 84 ad 01 00 00 8b 8e 60` |
| EventIdle | 0xBCD20 | 0xBCC1A | `56 8b f1 8b 46 08 85 c0 0f 84 a3 00 00 00 57 ba ff 00 00 00 33 c0 8d 7e 24 0f bf 0f 3b ca` |
| ExecProg | 0xBC290 | 0xBC27C | `0f bf 44 24 04 3d da 00 00 00 0f 87 c7 06 00 00 ff` |
| eventgetcode | 0xAFAA0 | 0xAFA8C | `8b 51 20 33 c0 66 8b 81 56 02 00 00 8b 4c 24 04 03 c2 33 d2 8a 14 01 03 c8 33 c0 8a 41 01 c1 e0 08 03 c2 c2 04 00` |
| eventgetcode2 | 0xAFAD0 | 0xAFA8C | `8b 51 20 33 c0 66 8b 81 56 02 00 00 8b 4c 24 04 03 c2 33 d2 8a 54 01 02 03 c8 33 c0 8a 41 03 c1` |
| getworkofs (forward wrapper) | 0xAF4C0 | 0xAF4B0 | `8b 44 24 04 6a 00 50 e8 04 00 00 00 c2 04 00` |
| getworkofs (forward wrapper) | 0xAF970 | 0xAF952 | `8b 44 24 04 6a 00 50 e8 04 00 00 00 c2 04 00` |
| getworkofs / getworkstrofs (shared body; first hit = getworkofs, second = getworkstrofs) | 0xAF4D0 | 0xAF4B0 | `8b 44 24 04 56 50 8b f1 e8 c3 05 00 00 03 44 24 0c 84 e4 0f 88 96 02 00 00 3d 00 08 00 00 7d 26 83 f8 50 7c 14 50 68 e4 d1 35 10 e8` |
| getworkofs / getworkstrofs (shared body; first hit = getworkofs, second = getworkstrofs) | 0xAF980 | 0xAF952 | `8b 44 24 04 56 50 8b f1 e8 13 01 00 00 03 44 24 0c 84 e4 0f 88 f3 00 00 00 3d 00 08 00 00 7d 27 83 f8 50 7c 14 50 68 e4 d1 35 10 e8` |
| setworkofs | 0xAF340 | 0xAF26A | `8b 44 24 04 56 50 8b f1 e8 53 07 00 00 03 44 24 10 84 e4 0f 88 53 01 00 00 3d 00 08 00 00 7d 28 83 f8 50 7c 12 50 68 58 d1 35 10 e8` |
| setworkofs (forward wrapper) | 0xAF320 | 0xAF26A | `8b 44 24 08 8b 54 24 04 6a 00 50 52 e8 0f 00 00 00 c2 08 00` |
| setworkofs (forward wrapper) | 0xAF7F0 | 0xAF7AD | `8b 44 24 08 8b 54 24 04 6a 00 50 52 e8 0f 00 00 00 c2 08 00` |
| setworkstrofs | 0xAF810 | 0xAF7AD | `8b 44 24 04 56 50 8b f1 e8 83 02 00 00 03 44 24 10 84 e4 0f 88 29 01 00 00 3d 00 08 00 00 7d 3e 83 f8 40 7c 12 50 68 58 d1 35 10 e8` |
| GetActorIndex | 0xAFB10 | 0xAFA8C | `8b 44 24 04 56 8d b0 40 00 00 80 83 fe 39` |
| GetReqLevel | 0xB36A0 | 0xB3590 | `33 c0 8b 54 24 04 66 8b 81 58 02 00 00 56 c1 e0 05 0f bf 44 08 24 3b c2 7f 06 33 c0 5e c2 04 00` |
| GetReqStatus | 0xB36E0 | 0xB36C0 | `33 c0 8b 54 24 04 66 8b 81 58 02 00 00 56 c1 e0 05 0f be 44 08 3a 3b c2 75 06 33 c0 5e c2 04 00` |
| ReqSet | 0xB3730 | 0xB371C | `55 56 57 8b f9 8b 4c 24 14 83 ce ff 33 c0 8d 57 3a 66 81 7a ea ff 00` |
| lookatone | 0xB8820 | 0xB86FB | `8b 54 24 04 83 ec 08 8d 44 24 0c 56 8b f1 8d 4c 24 04 50 51 52 8b ce e8 d4 72 ff ff 3c 01` |

Notes: `func start` is the heuristic function containing the hit (F34: hot funcs are
entered at mid-function offsets, so a handler RVA may sit inside another func). The
shared getworkofs/getworkstrofs body pattern lists both hits in RVA order; XiEvents says
the first is getworkofs and the second getworkstrofs.
```

## B. ExecProg switch + jump table (p8_jumptable.py)

The full 219-entry dispatch table at rva 0xBC970: opcode -> entry VA -> thunk RVA -> handler RVA. Backs E2 and is the source of event_opcode_table.md.

Source file: `out3/p8.md`

```text
# p8_jumptable: switch table at rva 0xBC970 (219 entries)

| opcode | entry VA | handler RVA | thunk target | section |
|---|---|---|---|---|
| 0x00 | 0x100BC967 | 0xBC967 | 0xAFC90 | .text |
| 0x01 | 0x100BC2A7 | 0xBC2A7 | 0xAFD00 | .text |
| 0x02 | 0x100BC2AF | 0xBC2AF | 0xAFD20 | .text |
| 0x03 | 0x100BC2B7 | 0xBC2B7 | 0xAFED0 | .text |
| 0x04 | 0x100BC2BF | 0xBC2BF | 0xB0130 | .text |
| 0x05 | 0x100BC2C7 | 0xBC2C7 | 0xB0140 | .text |
| 0x06 | 0x100BC2CF | 0xBC2CF | 0xB0160 | .text |
| 0x07 | 0x100BC2D7 | 0xBC2D7 | 0xB0180 | .text |
| 0x08 | 0x100BC2DF | 0xBC2DF | 0xB01B0 | .text |
| 0x09 | 0x100BC2E7 | 0xBC2E7 | 0xB01E0 | .text |
| 0x0A | 0x100BC2EF | 0xBC2EF | 0xB0220 | .text |
| 0x0B | 0x100BC2F7 | 0xBC2F7 | 0xB03A0 | .text |
| 0x0C | 0x100BC2FF | 0xBC2FF | 0xB03C0 | .text |
| 0x0D | 0x100BC307 | 0xBC307 | 0xB03E0 | .text |
| 0x0E | 0x100BC30F | 0xBC30F | 0xB0410 | .text |
| 0x0F | 0x100BC317 | 0xBC317 | 0xB0440 | .text |
| 0x10 | 0x100BC31F | 0xBC31F | 0xB0470 | .text |
| 0x11 | 0x100BC327 | 0xBC327 | 0xB04A0 | .text |
| 0x12 | 0x100BC32F | 0xBC32F | 0xB04D0 | .text |
| 0x13 | 0x100BC337 | 0xBC337 | 0xB04F0 | .text |
| 0x14 | 0x100BC33F | 0xBC33F | 0xB05A0 | .text |
| 0x15 | 0x100BC347 | 0xBC347 | 0xB05D0 | .text |
| 0x16 | 0x100BC34F | 0xBC34F | 0xB0610 | .text |
| 0x17 | 0x100BC357 | 0xBC357 | 0xB0670 | .text |
| 0x18 | 0x100BC35F | 0xBC35F | 0xB06D0 | .text |
| 0x19 | 0x100BC367 | 0xBC367 | 0xB0730 | .text |
| 0x1A | 0x100BC36F | 0xBC36F | 0xB0580 | .text |
| 0x1B | 0x100BC377 | 0xBC377 | 0xB0770 | .text |
| 0x1C | 0x100BC37F | 0xBC37F | 0xB0880 | .text |
| 0x1D | 0x100BC387 | 0xBC387 | 0xB2110 | .text |
| 0x1E | 0x100BC38F | 0xBC38F | 0xB2D30 | .text |
| 0x1F | 0x100BC397 | 0xBC397 | 0xB2EB0 | .text |
| 0x20 | 0x100BC39F | 0xBC39F | 0xB34D0 | .text |
| 0x21 | 0x100BC3A7 | 0xBC3A7 | 0xB34F0 | .text |
| 0x22 | 0x100BC3AF | 0xBC3AF | 0xB3510 | .text |
| 0x23 | 0x100BC3B7 | 0xBC3B7 | 0xB2DE0 | .text |
| 0x24 | 0x100BC3BF | 0xBC3BF | 0xB2280 | .text |
| 0x25 | 0x100BC3C7 | 0xBC3C7 | 0xB2950 | .text |
| 0x26 | 0x100BC3CF | 0xBC3CF | 0xAFC80 | .text |
| 0x27 | 0x100BC3D7 | 0xBC3D7 | 0xB3940 | .text |
| 0x28 | 0x100BC3DF | 0xBC3DF | 0xB3E60 | .text |
| 0x29 | 0x100BC3E7 | 0xBC3E7 | 0xB4000 | .text |
| 0x2A | 0x100BC3EF | 0xBC3EF | 0xB4290 | .text |
| 0x2B | 0x100BC3F7 | 0xBC3F7 | 0xB1E90 | .text |
| 0x2C | 0x100BC3FF | 0xBC3FF | 0xB4C30 | .text |
| 0x2D | 0x100BC407 | 0xBC407 | 0xB4F20 | .text |
| 0x2E | 0x100BC40F | 0xBC40F | 0xB55E0 | .text |
| 0x2F | 0x100BC417 | 0xBC417 | 0xB35F0 | .text |
| 0x30 | 0x100BC41F | 0xBC41F | 0xB5630 | .text |
| 0x31 | 0x100BC427 | 0xBC427 | 0xB5640 | .text |
| 0x32 | 0x100BC42F | 0xBC42F | 0xB5A20 | .text |
| 0x33 | 0x100BC437 | 0xBC437 | 0xB5A50 | .text |
| 0x34 | 0x100BC43F | 0xBC43F | 0xB5AA0 | .text |
| 0x35 | 0x100BC447 | 0xBC447 | 0xB5B80 | .text |
| 0x36 | 0x100BC44F | 0xBC44F | 0xB5C60 | .text |
| 0x37 | 0x100BC457 | 0xBC457 | 0xB5DE0 | .text |
| 0x38 | 0x100BC45F | 0xBC45F | 0xB6190 | .text |
| 0x39 | 0x100BC467 | 0xBC467 | 0xB6150 | .text |
| 0x3A | 0x100BC46F | 0xBC46F | 0xB2C90 | .text |
| 0x3B | 0x100BC477 | 0xBC477 | 0xB2BA0 | .text |
| 0x3C | 0x100BC47F | 0xBC47F | 0xB02B0 | .text |
| 0x3D | 0x100BC487 | 0xBC487 | 0xB0300 | .text |
| 0x3E | 0x100BC48F | 0xBC48F | 0xB0260 | .text |
| 0x3F | 0x100BC497 | 0xBC497 | 0xB61B0 | .text |
| 0x40 | 0x100BC49F | 0xBC49F | 0xB61F0 | .text |
| 0x41 | 0x100BC4A7 | 0xBC4A7 | 0xB6260 | .text |
| 0x42 | 0x100BC4AF | 0xBC4AF | 0xB5610 | .text |
| 0x43 | 0x100BC4B7 | 0xBC4B7 | 0xB63B0 | .text |
| 0x44 | 0x100BC4BF | 0xBC4BF | 0xB6410 | .text |
| 0x45 | 0x100BC4C7 | 0xBC4C7 | 0xB44D0 | .text |
| 0x46 | 0x100BC4CF | 0xBC4CF | 0xB6450 | .text |
| 0x47 | 0x100BC4D7 | 0xBC4D7 | 0xB62C0 | .text |
| 0x48 | 0x100BC4DF | 0xBC4DF | 0xB2210 | .text |
| 0x49 | 0x100BC4E7 | 0xBC4E7 | 0xB1DF0 | .text |
| 0x4A | 0x100BC4EF | 0xBC4EF | 0xB6710 | .text |
| 0x4B | 0x100BC4F7 | 0xBC4F7 | 0xB6880 | .text |
| 0x4C | 0x100BC4FF | 0xBC4FF | 0xB6960 | .text |
| 0x4D | 0x100BC507 | 0xBC507 | 0xB6A10 | .text |
| 0x4E | 0x100BC50F | 0xBC50F | 0xB3590 | .text |
| 0x4F | 0x100BC517 | 0xBC517 | 0xB69C0 | .text |
| 0x50 | 0x100BC51F | 0xBC51F | 0xB4D20 | .text |
| 0x51 | 0x100BC527 | 0xBC527 | 0xB5010 | .text |
| 0x52 | 0x100BC52F | 0xBC52F | 0xB48E0 | .text |
| 0x53 | 0x100BC537 | 0xBC537 | 0xB4E10 | .text |
| 0x54 | 0x100BC53F | 0xBC53F | 0xB5100 | .text |
| 0x55 | 0x100BC547 | 0xBC547 | 0xB4960 | .text |
| 0x56 | 0x100BC54F | 0xBC54F | 0xB66D0 | .text |
| 0x57 | 0x100BC557 | 0xBC557 | 0xB0360 | .text |
| 0x58 | 0x100BC55F | 0xBC55F | 0xB0390 | .text |
| 0x59 | 0x100BC567 | 0xBC567 | 0xB6A70 | .text |
| 0x5A | 0x100BC56F | 0xBC56F | 0xB3200 | .text |
| 0x5B | 0x100BC577 | 0xBC577 | 0xB5200 | .text |
| 0x5C | 0x100BC57F | 0xBC57F | 0xB6E40 | .text |
| 0x5D | 0x100BC587 | 0xBC587 | 0xB7050 | .text |
| 0x5E | 0x100BC58F | 0xBC58F | 0xB71F0 | .text |
| 0x5F | 0x100BC597 | 0xBC597 | 0xB72D0 | .text |
| 0x60 | 0x100BC59F | 0xBC59F | 0xB7400 | .text |
| 0x61 | 0x100BC5A7 | 0xBC5A7 | 0xB74F0 | .text |
| 0x62 | 0x100BC5AF | 0xBC5AF | 0xB44E0 | .text |
| 0x63 | 0x100BC5B7 | 0xBC5B7 | 0xB7560 | .text |
| 0x64 | 0x100BC5BF | 0xBC5BF | 0xB75D0 | .text |
| 0x65 | 0x100BC5C7 | 0xBC5C7 | 0xB7870 | .text |
| 0x66 | 0x100BC5CF | 0xBC5CF | 0xB5210 | .text |
| 0x67 | 0x100BC5D7 | 0xBC5D7 | 0xB79D0 | .text |
| 0x68 | 0x100BC5DF | 0xBC5DF | 0xB7A30 | .text |
| 0x69 | 0x100BC5E7 | 0xBC5E7 | 0xB7A70 | .text |
| 0x6A | 0x100BC5EF | 0xBC5EF | 0xB7B00 | .text |
| 0x6B | 0x100BC5F7 | 0xBC5F7 | 0xB7080 | .text |
| 0x6C | 0x100BC5FF | 0xBC5FF | 0xB7640 | .text |
| 0x6D | 0x100BC607 | 0xBC607 | 0xB7860 | .text |
| 0x6E | 0x100BC60F | 0xBC60F | 0xB7C50 | .text |
| 0x6F | 0x100BC617 | 0xBC617 | 0xB0800 | .text |
| 0x70 | 0x100BC61F | 0xBC61F | 0xB7DE0 | .text |
| 0x71 | 0x100BC627 | 0xBC627 | 0xB7E20 | .text |
| 0x72 | 0x100BC62F | 0xBC62F | 0xB84C0 | .text |
| 0x73 | 0x100BC637 | 0xBC637 | 0xB4550 | .text |
| 0x74 | 0x100BC63F | 0xBC63F | 0xB74A0 | .text |
| 0x75 | 0x100BC647 | 0xBC647 | 0xB8670 | .text |
| 0x76 | 0x100BC64F | 0xBC64F | 0xB7D60 | .text |
| 0x77 | 0x100BC657 | 0xBC657 | 0xB8720 | .text |
| 0x78 | 0x100BC65F | 0xBC65F | 0xB87C0 | .text |
| 0x79 | 0x100BC667 | 0xBC667 | 0xB88F0 | .text |
| 0x7A | 0x100BC66F | 0xBC66F | 0xB3A60 | .text |
| 0x7B | 0x100BC677 | 0xBC677 | 0xB8A10 | .text |
| 0x7C | 0x100BC67F | 0xBC67F | 0xB8A90 | .text |
| 0x7D | 0x100BC687 | 0xBC687 | 0xB8B30 | .text |
| 0x7E | 0x100BC68F | 0xBC68F | 0xB8B90 | .text |
| 0x7F | 0x100BC697 | 0xBC697 | 0xB2AB0 | .text |
| 0x80 | 0x100BC69F | 0xBC69F | 0xB8EA0 | .text |
| 0x81 | 0x100BC6A7 | 0xBC6A7 | 0xB8FC0 | .text |
| 0x82 | 0x100BC6AF | 0xBC6AF | 0xB9050 | .text |
| 0x83 | 0x100BC6B7 | 0xBC6B7 | 0xB90F0 | .text |
| 0x84 | 0x100BC6BF | 0xBC6BF | 0xB9110 | .text |
| 0x85 | 0x100BC6C7 | 0xBC6C7 | 0xB9130 | .text |
| 0x86 | 0x100BC6CF | 0xBC6CF | 0xB8F40 | .text |
| 0x87 | 0x100BC6D7 | 0xBC6D7 | 0xB9150 | .text |
| 0x88 | 0x100BC6DF | 0xBC6DF | 0xB9230 | .text |
| 0x89 | 0x100BC6E7 | 0xBC6E7 | 0xB9310 | .text |
| 0x8A | 0x100BC6EF | 0xBC6EF | 0xB93D0 | .text |
| 0x8B | 0x100BC6F7 | 0xBC6F7 | 0xB94A0 | .text |
| 0x8C | 0x100BC6FF | 0xBC6FF | 0xB98F0 | .text |
| 0x8D | 0x100BC707 | 0xBC707 | 0xB9340 | .text |
| 0x8E | 0x100BC70F | 0xBC70F | 0xB6990 | .text |
| 0x8F | 0x100BC717 | 0xBC717 | 0xB6A40 | .text |
| 0x90 | 0x100BC71F | 0xBC71F | 0xB3550 | .text |
| 0x91 | 0x100BC727 | 0xBC727 | 0xB9B80 | .text |
| 0x92 | 0x100BC72F | 0xBC72F | 0xB9BB0 | .text |
| 0x93 | 0x100BC737 | 0xBC737 | 0xB9D40 | .text |
| 0x94 | 0x100BC73F | 0xBC73F | 0xB9CC0 | .text |
| 0x95 | 0x100BC747 | 0xBC747 | 0xB9C30 | .text |
| 0x96 | 0x100BC74F | 0xBC74F | 0xB9C80 | .text |
| 0x97 | 0x100BC757 | 0xBC757 | 0xBA0D0 | .text |
| 0x98 | 0x100BC75F | 0xBC75F | 0xB8640 | .text |
| 0x99 | 0x100BC767 | 0xBC767 | 0xB7CF0 | .text |
| 0x9A | 0x100BC76F | 0xBC76F | 0xB6E00 | .text |
| 0x9B | 0x100BC777 | 0xBC777 | 0xB7530 | .text |
| 0x9C | 0x100BC77F | 0xBC77F | 0xBA110 | .text |
| 0x9D | 0x100BC787 | 0xBC787 | 0xBA1A0 | .text |
| 0x9E | 0x100BC78F | 0xBC78F | 0xBA8B0 | .text |
| 0x9F | 0x100BC797 | 0xBC797 | 0xB44F0 | .text |
| 0xA0 | 0x100BC79F | 0xBC79F | 0xB4970 | .text |
| 0xA1 | 0x100BC7A7 | 0xBC7A7 | 0xB48F0 | .text |
| 0xA2 | 0x100BC7AF | 0xBC7AF | 0xB4980 | .text |
| 0xA3 | 0x100BC7B7 | 0xBC7B7 | 0xB4900 | .text |
| 0xA4 | 0x100BC7BF | 0xBC7BF | 0xBA8E0 | .text |
| 0xA5 | 0x100BC7C7 | 0xBC7C7 | 0xBA930 | .text |
| 0xA6 | 0x100BC7CF | 0xBC7CF | 0xBA9D0 | .text |
| 0xA7 | 0x100BC7D7 | 0xBC7D7 | 0xBAA70 | .text |
| 0xA8 | 0x100BC7DF | 0xBC7DF | 0xB9790 | .text |
| 0xA9 | 0x100BC7E7 | 0xBC7E7 | 0xBAB60 | .text |
| 0xAA | 0x100BC7EF | 0xBC7EF | 0xBABF0 | .text |
| 0xAB | 0x100BC7F7 | 0xBC7F7 | 0xBACA0 | .text |
| 0xAC | 0x100BC7FF | 0xBC7FF | 0xBB190 | .text |
| 0xAD | 0x100BC807 | 0xBC807 | 0xBB350 | .text |
| 0xAE | 0x100BC80F | 0xBC80F | 0xBB630 | .text |
| 0xAF | 0x100BC817 | 0xBC817 | 0xBB9D0 | .text |
| 0xB0 | 0x100BC81F | 0xBC81F | 0xB1FB0 | .text |
| 0xB1 | 0x100BC827 | 0xBC827 | 0xBBA80 | .text |
| 0xB2 | 0x100BC82F | 0xBC82F | 0xB0920 | .text |
| 0xB3 | 0x100BC837 | 0xBC837 | 0xBBB00 | .text |
| 0xB4 | 0x100BC83F | 0xBC83F | 0xB0A10 | .text |
| 0xB5 | 0x100BC847 | 0xBC847 | 0xB1100 | .text |
| 0xB6 | 0x100BC84F | 0xBC84F | 0xB1160 | .text |
| 0xB7 | 0x100BC857 | 0xBC857 | 0xAFEF0 | .text |
| 0xB8 | 0x100BC85F | 0xBC85F | 0xB9610 | .text |
| 0xB9 | 0x100BC867 | 0xBC867 | 0xB9830 | .text |
| 0xBA | 0x100BC86F | 0xBC86F | 0xB5F80 | .text |
| 0xBB | 0x100BC877 | 0xBC877 | 0xB4500 | .text |
| 0xBC | 0x100BC87F | 0xBC87F | 0xB4990 | .text |
| 0xBD | 0x100BC887 | 0xBC887 | 0xB4910 | .text |
| 0xBE | 0x100BC88F | 0xBC88F | 0xB3E30 | .text |
| 0xBF | 0x100BC897 | 0xBC897 | 0xBBD90 | .text |
| 0xC0 | 0x100BC89F | 0xBC89F | 0xBA980 | .text |
| 0xC1 | 0x100BC8A7 | 0xBC8A7 | 0xB5510 | .text |
| 0xC2 | 0x100BC8AF | 0xBC8AF | 0xBBF90 | .text |
| 0xC3 | 0x100BC8B7 | 0xBC8B7 | 0xBC010 | .text |
| 0xC4 | 0x100BC8BF | 0xBC8BF | 0xB4560 | .text |
| 0xC5 | 0x100BC8C7 | 0xBC8C7 | 0xB4510 | .text |
| 0xC6 | 0x100BC8CF | 0xBC8CF | 0xB49A0 | .text |
| 0xC7 | 0x100BC8D7 | 0xBC8D7 | 0xB4920 | .text |
| 0xC8 | 0x100BC8DF | 0xBC8DF | 0xB9380 | .text |
| 0xC9 | 0x100BC8E7 | 0xBC8E7 | 0xB87F0 | .text |
| 0xCA | 0x100BC967 | 0xBC967 | 0xAFC90 | .text |
| 0xCB | 0x100BC967 | 0xBC967 | 0xAFC90 | .text |
| 0xCC | 0x100BC8EF | 0xBC8EF | 0xB9DA0 | .text |
| 0xCD | 0x100BC8F7 | 0xBC8F7 | 0xB4520 | .text |
| 0xCE | 0x100BC8FF | 0xBC8FF | 0xB49B0 | .text |
| 0xCF | 0x100BC907 | 0xBC907 | 0xB4930 | .text |
| 0xD0 | 0x100BC90F | 0xBC90F | 0xB4530 | .text |
| 0xD1 | 0x100BC917 | 0xBC917 | 0xB49C0 | .text |
| 0xD2 | 0x100BC91F | 0xBC91F | 0xB4940 | .text |
| 0xD3 | 0x100BC927 | 0xBC927 | 0xB7150 | .text |
| 0xD4 | 0x100BC92F | 0xBC92F | 0xB2290 | .text |
| 0xD5 | 0x100BC937 | 0xBC937 | 0xB4540 | .text |
| 0xD6 | 0x100BC93F | 0xBC93F | 0xB49D0 | .text |
| 0xD7 | 0x100BC947 | 0xBC947 | 0xB4950 | .text |
| 0xD8 | 0x100BC94F | 0xBC94F | 0xBC070 | .text |
| 0xD9 | 0x100BC957 | 0xBC957 | 0xB7BF0 | .text |
| 0xDA | 0x100BC95F | 0xBC95F | 0xB7C20 | .text |
```

## B2. ExecProg prologue + first thunks (disasm.py --func 0xBC27C)

ExecProg @0xBC290 dispatch instruction (`movsx eax,[esp+4]; cmp eax,0xDA; ja default; jmp [eax*4+0x100BC970]`) and the `call handler; ret 4` thunk shape with ecx passed through. Backs E2.

Source file: `out3/d_bc27c.md`

```text
  000BC27C  a1 3c 99 48 10             mov eax, dword ptr [0x1048993c]
  000BC281  85 c0                      test eax, eax
  000BC283  0f 94 c0                   sete al
  000BC286  c3                         ret 
  000BC287  90                         nop 
  000BC288  90                         nop 
  000BC289  90                         nop 
  000BC28A  90                         nop 
  000BC28B  90                         nop 
  000BC28C  90                         nop 
  000BC28D  90                         nop 
  000BC28E  90                         nop 
  000BC28F  90                         nop 
  000BC290  0f bf 44 24 04             movsx eax, word ptr [esp + 4]
  000BC295  3d da 00 00 00             cmp eax, 0xda
  000BC29A  0f 87 c7 06 00 00          ja 0x100bc967
  000BC2A0  ff 24 85 70 c9 0b 10       jmp dword ptr [eax*4 + 0x100bc970]
  000BC2A7  e8 54 3a ff ff             call 0x100afd00
  000BC2AC  c2 04 00                   ret 4
  000BC2AF  e8 6c 3a ff ff             call 0x100afd20
  000BC2B4  c2 04 00                   ret 4
  000BC2B7  e8 14 3c ff ff             call 0x100afed0
  000BC2BC  c2 04 00                   ret 4
  000BC2BF  e8 6c 3e ff ff             call 0x100b0130
  000BC2C4  c2 04 00                   ret 4
  000BC2C7  e8 74 3e ff ff             call 0x100b0140
  000BC2CC  c2 04 00                   ret 4
  000BC2CF  e8 8c 3e ff ff             call 0x100b0160
  000BC2D4  c2 04 00                   ret 4
  000BC2D7  e8 a4 3e ff ff             call 0x100b0180
```

## C. 0x5B / 0x66 thunks, shared helper @0xB5220, and all six callers

Backs E3 (param3 never 1; width always 15) and the T2 helper flow.

### C.1 0x5B @0xB5200 and 0x66 @0xB5210 thunks + start of helper @0xB5220 (disasm.py --func 0xB5200)

Source file: `out3/d_b5200.md`

```text
  000B5200  6a 00                      push 0
  000B5202  6a 01                      push 1
  000B5204  6a 00                      push 0
  000B5206  e8 15 00 00 00             call 0x100b5220
  000B520B  c3                         ret 
  000B520C  90                         nop 
  000B520D  90                         nop 
  000B520E  90                         nop 
  000B520F  90                         nop 
  000B5210  6a 00                      push 0
  000B5212  6a 01                      push 1
  000B5214  6a 01                      push 1
  000B5216  e8 05 00 00 00             call 0x100b5220
  000B521B  c3                         ret 
  000B521C  90                         nop 
  000B521D  90                         nop 
  000B521E  90                         nop 
  000B521F  90                         nop 
  000B5220  83 ec 14                   sub esp, 0x14
  000B5223  8d 44 24 00                lea eax, [esp]
  000B5227  53                         push ebx
  000B5228  55                         push ebp
  000B5229  56                         push esi
  000B522A  8b f1                      mov esi, ecx
  000B522C  57                         push edi
  000B522D  8d 4c 24 1c                lea ecx, [esp + 0x1c]
  000B5231  50                         push eax
  000B5232  51                         push ecx
  000B5233  6a 03                      push 3
  000B5235  8b ce                      mov ecx, esi
  000B5237  e8 94 a8 ff ff             call 0x100afad0
  000B523C  50                         push eax
  000B523D  8b ce                      mov ecx, esi
  000B523F  e8 cc a8 ff ff             call 0x100afb10
```

### C.2 xref.py --to 0xB5220: all six callers with their push sequences

Source file: `out3/x_b5220.md`

```text
references to 0xB5220 (func 0xB51EE): 6
- 0xB5206 in func 0xB51EE
  000B5200  6a 00                      push 0
  000B5202  6a 01                      push 1
  000B5204  6a 00                      push 0
>>000B5206  e8 15 00 00 00             call 0x100b5220
  000B520B  c3                         ret 
  000B520C  90                         nop 
  000B520D  90                         nop 
- 0xB5216 in func 0xB51EE
  000B5210  6a 00                      push 0
  000B5212  6a 01                      push 1
  000B5214  6a 01                      push 1
>>000B5216  e8 05 00 00 00             call 0x100b5220
  000B521B  c3                         ret 
  000B521C  90                         nop 
  000B521D  90                         nop 
- 0xB735F in func 0xB734D
  000B7354  6a 00                      push 0
  000B7356  8b ce                      mov ecx, esi
  000B7358  66 89 86 56 02 00 00       mov word ptr [esi + 0x256], ax
>>000B735F  e8 bc de ff ff             call 0x100b5220
  000B7364  eb 60                      jmp 0x100b73c6
  000B7366  8d 4f 01                   lea ecx, [edi + 1]
  000B7369  6a 00                      push 0
- 0xB7378 in func 0xB7366
  000B7372  6a 00                      push 0
  000B7374  6a 01                      push 1
  000B7376  8b ce                      mov ecx, esi
>>000B7378  e8 a3 de ff ff             call 0x100b5220
  000B737D  eb 47                      jmp 0x100b73c6
  000B737F  6a 01                      push 1
  000B7381  8d 57 01                   lea edx, [edi + 1]
- 0xB7391 in func 0xB737F
  000B7386  6a 00                      push 0
  000B7388  8b ce                      mov ecx, esi
  000B738A  66 89 96 56 02 00 00       mov word ptr [esi + 0x256], dx
>>000B7391  e8 8a de ff ff             call 0x100b5220
  000B7396  eb 2e                      jmp 0x100b73c6
  000B7398  6a 01                      push 1
  000B739A  8d 47 01                   lea eax, [edi + 1]
- 0xB73AA in func 0xB7398
  000B739F  6a 01                      push 1
  000B73A1  8b ce                      mov ecx, esi
  000B73A3  66 89 86 56 02 00 00       mov word ptr [esi + 0x256], ax
>>000B73AA  e8 71 de ff ff             call 0x100b5220
  000B73AF  eb 15                      jmp 0x100b73c6
  000B73B1  8d 4f 01                   lea ecx, [edi + 1]
  000B73B4  6a 01                      push 1
```

### C.3 0x5F @0xB72D0 sub-scheduler: cases 3 to 6 call the helper (disasm.py --func 0xB72D0)

Source file: `out3/d_b72d0.md`

```text
  000B72D0  56                         push esi
  000B72D1  8b f1                      mov esi, ecx
  000B72D3  57                         push edi
  000B72D4  66 8b be 56 02 00 00       mov di, word ptr [esi + 0x256]
  000B72DB  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  000B72DE  8b c7                      mov eax, edi
  000B72E0  25 ff ff 00 00             and eax, 0xffff
  000B72E5  8a 4c 01 01                mov cl, byte ptr [ecx + eax + 1]
  000B72E9  8b c1                      mov eax, ecx
  000B72EB  25 ff 00 00 00             and eax, 0xff
  000B72F0  83 f8 07                   cmp eax, 7
  000B72F3  0f 87 d8 00 00 00          ja 0x100b73d1
  000B72F9  ff 24 85 d4 73 0b 10       jmp dword ptr [eax*4 + 0x100b73d4]
  000B7300  33 d2                      xor edx, edx
  000B7302  66 8b 56 02                mov dx, word ptr [esi + 2]
  000B7306  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B730D  85 c0                      test eax, eax
  000B730F  74 1c                      je 0x100b732d
  000B7311  8b 90 24 01 00 00          mov edx, dword ptr [eax + 0x124]
  000B7317  0f be c9                   movsx ecx, cl
  000B731A  c1 e1 1d                   shl ecx, 0x1d
  000B731D  33 ca                      xor ecx, edx
  000B731F  81 e1 00 00 00 20          and ecx, 0x20000000
  000B7325  33 d1                      xor edx, ecx
  000B7327  89 90 24 01 00 00          mov dword ptr [eax + 0x124], edx
  000B732D  66 83 86 56 02 00 00 02    add word ptr [esi + 0x256], 2
  000B7335  5f                         pop edi
  000B7336  5e                         pop esi
  000B7337  c3                         ret 
  000B7338  8d 57 01                   lea edx, [edi + 1]
  000B733B  6a 00                      push 0
  000B733D  8b ce                      mov ecx, esi
  000B733F  66 89 96 56 02 00 00       mov word ptr [esi + 0x256], dx
  000B7346  e8 d5 e1 ff ff             call 0x100b5520
  000B734B  eb 79                      jmp 0x100b73c6
  000B734D  6a 00                      push 0
  000B734F  8d 47 01                   lea eax, [edi + 1]
  000B7352  6a 00                      push 0
  000B7354  6a 00                      push 0
  000B7356  8b ce                      mov ecx, esi
  000B7358  66 89 86 56 02 00 00       mov word ptr [esi + 0x256], ax
  000B735F  e8 bc de ff ff             call 0x100b5220
  000B7364  eb 60                      jmp 0x100b73c6
  000B7366  8d 4f 01                   lea ecx, [edi + 1]
  000B7369  6a 00                      push 0
  000B736B  66 89 8e 56 02 00 00       mov word ptr [esi + 0x256], cx
  000B7372  6a 00                      push 0
  000B7374  6a 01                      push 1
  000B7376  8b ce                      mov ecx, esi
  000B7378  e8 a3 de ff ff             call 0x100b5220
  000B737D  eb 47                      jmp 0x100b73c6
  000B737F  6a 01                      push 1
  000B7381  8d 57 01                   lea edx, [edi + 1]
  000B7384  6a 00                      push 0
  000B7386  6a 00                      push 0
  000B7388  8b ce                      mov ecx, esi
  000B738A  66 89 96 56 02 00 00       mov word ptr [esi + 0x256], dx
  000B7391  e8 8a de ff ff             call 0x100b5220
  000B7396  eb 2e                      jmp 0x100b73c6
  000B7398  6a 01                      push 1
  000B739A  8d 47 01                   lea eax, [edi + 1]
  000B739D  6a 00                      push 0
  000B739F  6a 01                      push 1
  000B73A1  8b ce                      mov ecx, esi
  000B73A3  66 89 86 56 02 00 00       mov word ptr [esi + 0x256], ax
  000B73AA  e8 71 de ff ff             call 0x100b5220
  000B73AF  eb 15                      jmp 0x100b73c6
  000B73B1  8d 4f 01                   lea ecx, [edi + 1]
  000B73B4  6a 01                      push 1
  000B73B6  66 89 8e 56 02 00 00       mov word ptr [esi + 0x256], cx
  000B73BD  6a 00                      push 0
  000B73BF  8b ce                      mov ecx, esi
  000B73C1  e8 5a da ff ff             call 0x100b4e20
  000B73C6  84 c0                      test al, al
  000B73C8  75 07                      jne 0x100b73d1
  000B73CA  66 89 be 56 02 00 00       mov word ptr [esi + 0x256], di
  000B73D1  5f                         pop edi
  000B73D2  5e                         pop esi
  000B73D3  c3                         ret 
  000B73D4  00 73 0b                   add byte ptr [ebx + 0xb], dh
  000B73D7  10 00                      adc byte ptr [eax], al
  000B73D9  73 0b                      jae 0x100b73e6
  000B73DB  10 38                      adc byte ptr [eax], bh
  000B73DD  73 0b                      jae 0x100b73ea
  000B73DF  10 4d 73                   adc byte ptr [ebp + 0x73], cl
  000B73E2  0b 10                      or edx, dword ptr [eax]
  000B73E4  66 73 0b                   jae 0x100b73f2
  000B73E7  10 7f 73                   adc byte ptr [edi + 0x73], bh
  000B73EA  0b 10                      or edx, dword ptr [eax]
  000B73EC  98                         cwde 
  000B73ED  73 0b                      jae 0x100b73fa
  000B73EF  10 b1 73 0b 10 90          adc byte ptr [ecx - 0x6feff48d], dh
  000B73F5  90                         nop 
  000B73F6  90                         nop 
  000B73F7  90                         nop 
  000B73F8  90                         nop 
  000B73F9  90                         nop 
  000B73FA  90                         nop 
  000B73FB  90                         nop 
  000B73FC  90                         nop 
  000B73FD  90                         nop 
  000B73FE  90                         nop 
  000B73FF  90                         nop 
  000B7400  53                         push ebx
  000B7401  56                         push esi
  000B7402  8b f1                      mov esi, ecx
  000B7404  33 c0                      xor eax, eax
  000B7406  b9 02 00 00 00             mov ecx, 2
  000B740B  66 8b 86 56 02 00 00       mov ax, word ptr [esi + 0x256]
```

## D. The two motion resource readers

Backs E4 (ReadEventMotionRes Type gate + bands), E5 (ReadTpcEventMotionRes A/B mapping), and the 0x84410 entity-Type gate.

### D.1 Entity-Type gate @0x84410 (disasm.py --func 0x84410)

Source file: `out3/d_84410.md`

```text
; func 0x84403..0x8441F (28 bytes), callers: 0
  00084403  32 c0                      xor al, al
  00084405  c3                         ret 
  00084406  90                         nop 
  00084407  90                         nop 
  00084408  90                         nop 
  00084409  90                         nop 
  0008440A  90                         nop 
  0008440B  90                         nop 
  0008440C  90                         nop 
  0008440D  90                         nop 
  0008440E  90                         nop 
  0008440F  90                         nop 
  00084410  8b 41 70                   mov eax, dword ptr [ecx + 0x70]
  00084413  85 c0                      test eax, eax
  00084415  74 08                      je 0x1008441f
  00084417  0f be 80 ee 00 00 00       movsx eax, byte ptr [eax + 0xee]
  0008441E  c3                         ret 
```

### D.2 ReadEventMotionRes @0xD2120 (disasm.py --func 0xD2120); the misaligned data at 0xD2218/0xD2220 is the jump + byte tables

Source file: `out3/d_d2120.md`

```text
  000D2102  33 ff                      xor edi, edi
  000D2104  6a 00                      push 0
  000D2106  56                         push esi
  000D2107  57                         push edi
  000D2108  68 10 14 0d 10             push 0x100d1410
  000D210D  8d 4c 24 1c                lea ecx, [esp + 0x1c]
  000D2111  e8 ea ef f9 ff             call 0x10071100
  000D2116  5f                         pop edi
  000D2117  5e                         pop esi
  000D2118  5b                         pop ebx
  000D2119  83 c4 0c                   add esp, 0xc
  000D211C  c3                         ret 
  000D211D  90                         nop 
  000D211E  90                         nop 
  000D211F  90                         nop 
  000D2120  83 ec 08                   sub esp, 8
  000D2123  56                         push esi
  000D2124  57                         push edi
  000D2125  8b f1                      mov esi, ecx
  000D2127  c7 44 24 08 00 00 00 00    mov dword ptr [esp + 8], 0
  000D212F  e8 dc 22 fb ff             call 0x10084410
  000D2134  48                         dec eax
  000D2135  83 f8 07                   cmp eax, 7
  000D2138  0f 87 c7 00 00 00          ja 0x100d2205
  000D213E  33 c9                      xor ecx, ecx
  000D2140  8a 88 20 22 0d 10          mov cl, byte ptr [eax + 0x100d2220]
  000D2146  ff 24 8d 18 22 0d 10       jmp dword ptr [ecx*4 + 0x100d2218]
  000D214D  8b 7c 24 18                mov edi, dword ptr [esp + 0x18]
  000D2151  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  000D2157  8d 54 24 0c                lea edx, [esp + 0xc]
  000D215B  57                         push edi
  000D215C  52                         push edx
  000D215D  e8 8e 0f fa ff             call 0x100730f0
  000D2162  8b 00                      mov eax, dword ptr [eax]
  000D2164  85 c0                      test eax, eax
  000D2166  89 44 24 08                mov dword ptr [esp + 8], eax
  000D216A  0f 84 95 00 00 00          je 0x100d2205
  000D2170  6a 02                      push 2
  000D2172  57                         push edi
  000D2173  6a 01                      push 1
  000D2175  50                         push eax
  000D2176  8b ce                      mov ecx, esi
  000D2178  e8 a3 22 00 00             call 0x100d4420
  000D217D  8d 4c 24 08                lea ecx, [esp + 8]
  000D2181  e8 ea ee f9 ff             call 0x10071070
  000D2186  84 c0                      test al, al
  000D2188  74 25                      je 0x100d21af
  000D218A  8b 86 ec 09 00 00          mov eax, dword ptr [esi + 0x9ec]
  000D2190  8b 4c 24 08                mov ecx, dword ptr [esp + 8]
  000D2194  50                         push eax
  000D2195  51                         push ecx
  000D2196  8b ce                      mov ecx, esi
  000D2198  e8 c3 f2 ff ff             call 0x100d1460
  000D219D  8b 44 24 14                mov eax, dword ptr [esp + 0x14]
  000D21A1  8b 4c 24 08                mov ecx, dword ptr [esp + 8]
  000D21A5  5f                         pop edi
  000D21A6  5e                         pop esi
  000D21A7  89 08                      mov dword ptr [eax], ecx
  000D21A9  83 c4 08                   add esp, 8
  000D21AC  c2 08 00                   ret 8
  000D21AF  6a 14                      push 0x14
  000D21B1  e8 45 fa 23 00             call 0x10311bfb
  000D21B6  8b f8                      mov edi, eax
  000D21B8  83 c4 04                   add esp, 4
  000D21BB  85 ff                      test edi, edi
  000D21BD  74 32                      je 0x100d21f1
  000D21BF  53                         push ebx
  000D21C0  8d 5f 04                   lea ebx, [edi + 4]
  000D21C3  8b cb                      mov ecx, ebx
  000D21C5  e8 e6 f2 fa ff             call 0x100814b0
  000D21CA  85 f6                      test esi, esi
  000D21CC  74 0a                      je 0x100d21d8
  000D21CE  8b 96 ec 09 00 00          mov edx, dword ptr [esi + 0x9ec]
  000D21D4  89 17                      mov dword ptr [edi], edx
  000D21D6  eb 07                      jmp 0x100d21df
  000D21D8  a1 8c a3 48 10             mov eax, dword ptr [0x1048a38c]
  000D21DD  89 07                      mov dword ptr [edi], eax
  000D21DF  56                         push esi
  000D21E0  8b cb                      mov ecx, ebx
  000D21E2  e8 19 f3 fa ff             call 0x10081500
  000D21E7  c7 47 10 01 00 00 00       mov dword ptr [edi + 0x10], 1
  000D21EE  5b                         pop ebx
  000D21EF  eb 02                      jmp 0x100d21f3
  000D21F1  33 ff                      xor edi, edi
  000D21F3  6a 00                      push 0
  000D21F5  56                         push esi
  000D21F6  57                         push edi
  000D21F7  68 10 14 0d 10             push 0x100d1410
  000D21FC  8d 4c 24 18                lea ecx, [esp + 0x18]
  000D2200  e8 fb ee f9 ff             call 0x10071100
  000D2205  8b 44 24 14                mov eax, dword ptr [esp + 0x14]
  000D2209  8b 4c 24 08                mov ecx, dword ptr [esp + 8]
  000D220D  5f                         pop edi
  000D220E  5e                         pop esi
  000D220F  89 08                      mov dword ptr [eax], ecx
  000D2211  83 c4 08                   add esp, 8
  000D2214  c2 08 00                   ret 8
  000D2217  90                         nop 
  000D2218  4d                         dec ebp
  000D2219  21 0d 10 05 22 0d          and dword ptr [0xd220510], ecx
  000D221F  10 00                      adc byte ptr [eax], al
  000D2221  00 01                      add byte ptr [ecx], al
  000D2223  01 01                      add dword ptr [ecx], eax
  000D2225  01 00                      add dword ptr [eax], eax
  000D2227  00 90 90 90 90 90          add byte ptr [eax - 0x6f6f6f70], dl
  000D222D  90                         nop 
  000D222E  90                         nop 
  000D222F  90                         nop 
  000D2230  83 ec 0c                   sub esp, 0xc
```

### D.3 Raw read of the ReadEventMotionRes byte table @0xD2220 and jump table @0xD2218 (confirms load for Type {1,2,7,8})

Source file: `out3/probe_d2218.md`

```text
byte index table @rva 0xD2220: 00 00 01 01 01 01 00 00
jump table @rva 0xD2218 (8 dwords):
  case 0: VA 0x100D214D rva 0xD214D
  case 1: VA 0x100D2205 rva 0xD2205
  case 2: VA 0x01010000 rva 0x-EFF0000
  case 3: VA 0x00000101 rva 0x-FFFFEFF
  case 4: VA 0x90909090 rva 0x80909090
  case 5: VA 0x90909090 rva 0x80909090
  case 6: VA 0x530CEC83 rva 0x430CEC83
  case 7: VA 0xF98B5756 rva 0xE98B5756

Type(n) -> idx -> byte -> case
  n=1 idx=0 byte=0x00 case=0
  n=2 idx=1 byte=0x00 case=0
  n=3 idx=2 byte=0x01 case=1
  n=4 idx=3 byte=0x01 case=1
  n=5 idx=4 byte=0x01 case=1
  n=6 idx=5 byte=0x01 case=1
  n=7 idx=6 byte=0x00 case=0
  n=8 idx=7 byte=0x00 case=0
```

### D.4 ReadTpcEventMotionRes @0xD2230 (disasm.py --func 0xD2230); the four-band A/B mapping in tpc_package_table.md

Source file: `out3/d_d2230.md`

```text
  000D2230  83 ec 0c                   sub esp, 0xc
  000D2233  53                         push ebx
  000D2234  56                         push esi
  000D2235  57                         push edi
  000D2236  8b f9                      mov edi, ecx
  000D2238  e8 d3 21 fb ff             call 0x10084410
  000D223D  85 c0                      test eax, eax
  000D223F  0f 8c 13 02 00 00          jl 0x100d2458
  000D2245  83 f8 01                   cmp eax, 1
  000D2248  7e 09                      jle 0x100d2253
  000D224A  83 f8 06                   cmp eax, 6
  000D224D  0f 85 05 02 00 00          jne 0x100d2458
  000D2253  8b 74 24 1c                mov esi, dword ptr [esp + 0x1c]
  000D2257  8b cf                      mov ecx, edi
  000D2259  81 fe 18 01 00 00          cmp esi, 0x118
  000D225F  7c 20                      jl 0x100d2281
  000D2261  8b 07                      mov eax, dword ptr [edi]
  000D2263  56                         push esi
  000D2264  ff 90 cc 00 00 00          call dword ptr [eax + 0xcc]
  000D226A  50                         push eax
  000D226B  68 d0 f9 35 10             push 0x1035f9d0
  000D2270  e8 cb 5a f4 ff             call 0x10017d40
  000D2275  83 c4 0c                   add esp, 0xc
  000D2278  5f                         pop edi
  000D2279  5e                         pop esi
  000D227A  5b                         pop ebx
  000D227B  83 c4 0c                   add esp, 0xc
  000D227E  c2 04 00                   ret 4
  000D2281  8b 17                      mov edx, dword ptr [edi]
  000D2283  55                         push ebp
  000D2284  ff 92 d8 03 00 00          call dword ptr [edx + 0x3d8]
  000D228A  80 78 09 01                cmp byte ptr [eax + 9], 1
  000D228E  0f 94 c0                   sete al
  000D2291  83 fe 46                   cmp esi, 0x46
  000D2294  7d 1a                      jge 0x100d22b0
  000D2296  84 c0                      test al, al
  000D2298  8d ae c8 7f 00 00          lea ebp, [esi + 0x7fc8]
  000D229E  74 08                      je 0x100d22a8
  000D22A0  8d 9e 0e 80 00 00          lea ebx, [esi + 0x800e]
  000D22A6  eb 71                      jmp 0x100d2319
  000D22A8  8d 9e 54 80 00 00          lea ebx, [esi + 0x8054]
  000D22AE  eb 69                      jmp 0x100d2319
  000D22B0  81 fe 8c 00 00 00          cmp esi, 0x8c
  000D22B6  7d 1d                      jge 0x100d22d5
  000D22B8  83 ee 46                   sub esi, 0x46
  000D22BB  84 c0                      test al, al
  000D22BD  8d ae 39 ef 00 00          lea ebp, [esi + 0xef39]
  000D22C3  74 08                      je 0x100d22cd
  000D22C5  8d 9e 7f ef 00 00          lea ebx, [esi + 0xef7f]
  000D22CB  eb 4c                      jmp 0x100d2319
  000D22CD  8d 9e c5 ef 00 00          lea ebx, [esi + 0xefc5]
  000D22D3  eb 44                      jmp 0x100d2319
  000D22D5  81 fe d2 00 00 00          cmp esi, 0xd2
  000D22DB  7d 20                      jge 0x100d22fd
  000D22DD  81 ee 8c 00 00 00          sub esi, 0x8c
  000D22E3  84 c0                      test al, al
  000D22E5  8d ae 11 57 01 00          lea ebp, [esi + 0x15711]
  000D22EB  74 08                      je 0x100d22f5
  000D22ED  8d 9e 57 57 01 00          lea ebx, [esi + 0x15757]
  000D22F3  eb 24                      jmp 0x100d2319
  000D22F5  8d 9e 9d 57 01 00          lea ebx, [esi + 0x1579d]
  000D22FB  eb 1c                      jmp 0x100d2319
  000D22FD  81 ee d2 00 00 00          sub esi, 0xd2
  000D2303  84 c0                      test al, al
  000D2305  8d ae 5f 8f 01 00          lea ebp, [esi + 0x18f5f]
  000D230B  8d 9e a5 8f 01 00          lea ebx, [esi + 0x18fa5]
  000D2311  75 06                      jne 0x100d2319
  000D2313  8d 9e eb 8f 01 00          lea ebx, [esi + 0x18feb]
  000D2319  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  000D231F  8d 44 24 14                lea eax, [esp + 0x14]
  000D2323  55                         push ebp
  000D2324  50                         push eax
  000D2325  e8 c6 0d fa ff             call 0x100730f0
  000D232A  8b 00                      mov eax, dword ptr [eax]
  000D232C  85 c0                      test eax, eax
  000D232E  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000D2332  74 76                      je 0x100d23aa
  000D2334  6a 02                      push 2
  000D2336  55                         push ebp
  000D2337  6a 01                      push 1
  000D2339  50                         push eax
  000D233A  8b cf                      mov ecx, edi
  000D233C  e8 df 20 00 00             call 0x100d4420
  000D2341  8d 4c 24 10                lea ecx, [esp + 0x10]
  000D2345  e8 26 ed f9 ff             call 0x10071070
  000D234A  84 c0                      test al, al
  000D234C  74 15                      je 0x100d2363
  000D234E  8b 8f ec 09 00 00          mov ecx, dword ptr [edi + 0x9ec]
  000D2354  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000D2358  51                         push ecx
  000D2359  52                         push edx
  000D235A  8b cf                      mov ecx, edi
  000D235C  e8 ff f0 ff ff             call 0x100d1460
  000D2361  eb 47                      jmp 0x100d23aa
  000D2363  6a 14                      push 0x14
  000D2365  e8 91 f8 23 00             call 0x10311bfb
  000D236A  8b f0                      mov esi, eax
  000D236C  83 c4 04                   add esp, 4
  000D236F  85 f6                      test esi, esi
  000D2371  74 23                      je 0x100d2396
  000D2373  8d 6e 04                   lea ebp, [esi + 4]
  000D2376  8b cd                      mov ecx, ebp
  000D2378  e8 33 f1 fa ff             call 0x100814b0
  000D237D  8b 87 ec 09 00 00          mov eax, dword ptr [edi + 0x9ec]
  000D2383  57                         push edi
  000D2384  8b cd                      mov ecx, ebp
  000D2386  89 06                      mov dword ptr [esi], eax
  000D2388  e8 73 f1 fa ff             call 0x10081500
  000D238D  c7 46 10 01 00 00 00       mov dword ptr [esi + 0x10], 1
  000D2394  eb 02                      jmp 0x100d2398
  000D2396  33 f6                      xor esi, esi
  000D2398  6a 00                      push 0
  000D239A  57                         push edi
  000D239B  56                         push esi
  000D239C  68 10 14 0d 10             push 0x100d1410
  000D23A1  8d 4c 24 20                lea ecx, [esp + 0x20]
  000D23A5  e8 56 ed f9 ff             call 0x10071100
  000D23AA  8b 17                      mov edx, dword ptr [edi]
  000D23AC  8b cf                      mov ecx, edi
  000D23AE  ff 92 d8 03 00 00          call dword ptr [edx + 0x3d8]
  000D23B4  8a 48 09                   mov cl, byte ptr [eax + 9]
  000D23B7  5d                         pop ebp
  000D23B8  84 c9                      test cl, cl
  000D23BA  0f 8e 98 00 00 00          jle 0x100d2458
  000D23C0  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  000D23C6  8d 44 24 14                lea eax, [esp + 0x14]
  000D23CA  53                         push ebx
  000D23CB  50                         push eax
  000D23CC  e8 1f 0d fa ff             call 0x100730f0
  000D23D1  8b 00                      mov eax, dword ptr [eax]
  000D23D3  85 c0                      test eax, eax
  000D23D5  89 44 24 0c                mov dword ptr [esp + 0xc], eax
  000D23D9  74 7d                      je 0x100d2458
  000D23DB  6a 02                      push 2
  000D23DD  53                         push ebx
  000D23DE  6a 02                      push 2
  000D23E0  50                         push eax
  000D23E1  8b cf                      mov ecx, edi
  000D23E3  e8 38 20 00 00             call 0x100d4420
  000D23E8  8d 4c 24 0c                lea ecx, [esp + 0xc]
  000D23EC  e8 7f ec f9 ff             call 0x10071070
  000D23F1  84 c0                      test al, al
  000D23F3  74 1c                      je 0x100d2411
  000D23F5  8b 8f ec 09 00 00          mov ecx, dword ptr [edi + 0x9ec]
  000D23FB  8b 54 24 0c                mov edx, dword ptr [esp + 0xc]
  000D23FF  51                         push ecx
  000D2400  52                         push edx
  000D2401  8b cf                      mov ecx, edi
  000D2403  e8 58 f0 ff ff             call 0x100d1460
  000D2408  5f                         pop edi
  000D2409  5e                         pop esi
  000D240A  5b                         pop ebx
  000D240B  83 c4 0c                   add esp, 0xc
  000D240E  c2 04 00                   ret 4
  000D2411  6a 14                      push 0x14
  000D2413  e8 e3 f7 23 00             call 0x10311bfb
  000D2418  8b f0                      mov esi, eax
  000D241A  83 c4 04                   add esp, 4
  000D241D  85 f6                      test esi, esi
  000D241F  74 23                      je 0x100d2444
  000D2421  8d 5e 04                   lea ebx, [esi + 4]
  000D2424  8b cb                      mov ecx, ebx
  000D2426  e8 85 f0 fa ff             call 0x100814b0
  000D242B  8b 87 ec 09 00 00          mov eax, dword ptr [edi + 0x9ec]
  000D2431  57                         push edi
  000D2432  8b cb                      mov ecx, ebx
  000D2434  89 06                      mov dword ptr [esi], eax
  000D2436  e8 c5 f0 fa ff             call 0x10081500
  000D243B  c7 46 10 02 00 00 00       mov dword ptr [esi + 0x10], 2
  000D2442  eb 02                      jmp 0x100d2446
  000D2444  33 f6                      xor esi, esi
  000D2446  6a 00                      push 0
  000D2448  57                         push edi
  000D2449  56                         push esi
  000D244A  68 10 14 0d 10             push 0x100d1410
  000D244F  8d 4c 24 1c                lea ecx, [esp + 0x1c]
  000D2453  e8 a8 ec f9 ff             call 0x10071100
  000D2458  5f                         pop edi
  000D2459  5e                         pop esi
  000D245A  5b                         pop ebx
  000D245B  83 c4 0c                   add esp, 0xc
  000D245E  c2 04 00                   ret 4
  000D2461  90                         nop 
  000D2462  90                         nop 
  000D2463  90                         nop 
  000D2464  90                         nop 
  000D2465  90                         nop 
  000D2466  90                         nop 
  000D2467  90                         nop 
  000D2468  90                         nop 
  000D2469  90                         nop 
  000D246A  90                         nop 
  000D246B  90                         nop 
  000D246C  90                         nop 
  000D246D  90                         nop 
  000D246E  90                         nop 
  000D246F  90                         nop 
  000D2470  83 ec 08                   sub esp, 8
  000D2473  53                         push ebx
  000D2474  56                         push esi
  000D2475  8b f1                      mov esi, ecx
  000D2477  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  000D247D  57                         push edi
  000D247E  8d 44 24 10                lea eax, [esp + 0x10]
  000D2482  8b 9e a0 08 00 00          mov ebx, dword ptr [esi + 0x8a0]
  000D2488  8d bb 68 7f 00 00          lea edi, [ebx + 0x7f68]
  000D248E  57                         push edi
  000D248F  50                         push eax
  000D2490  e8 5b 0c fa ff             call 0x100730f0
  000D2495  8b 00                      mov eax, dword ptr [eax]
  000D2497  85 c0                      test eax, eax
  000D2499  89 44 24 0c                mov dword ptr [esp + 0xc], eax
  000D249D  74 78                      je 0x100d2517
  000D249F  6a 00                      push 0
  000D24A1  57                         push edi
  000D24A2  6a 01                      push 1
  000D24A4  50                         push eax
  000D24A5  8b ce                      mov ecx, esi
  000D24A7  e8 74 1f 00 00             call 0x100d4420
  000D24AC  8d 4c 24 0c                lea ecx, [esp + 0xc]
  000D24B0  e8 bb eb f9 ff             call 0x10071070
  000D24B5  84 c0                      test al, al
  000D24B7  74 15                      je 0x100d24ce
  000D24B9  8b 8e ec 09 00 00          mov ecx, dword ptr [esi + 0x9ec]
  000D24BF  8b 54 24 0c                mov edx, dword ptr [esp + 0xc]
  000D24C3  51                         push ecx
  000D24C4  52                         push edx
  000D24C5  8b ce                      mov ecx, esi
  000D24C7  e8 94 ef ff ff             call 0x100d1460
  000D24CC  eb 49                      jmp 0x100d2517
  000D24CE  6a 14                      push 0x14
  000D24D0  e8 26 f7 23 00             call 0x10311bfb
  000D24D5  8b f8                      mov edi, eax
  000D24D7  83 c4 04                   add esp, 4
  000D24DA  85 ff                      test edi, edi
  000D24DC  74 25                      je 0x100d2503
  000D24DE  55                         push ebp
  000D24DF  8d 6f 04                   lea ebp, [edi + 4]
  000D24E2  8b cd                      mov ecx, ebp
  000D24E4  e8 c7 ef fa ff             call 0x100814b0
  000D24E9  8b 86 ec 09 00 00          mov eax, dword ptr [esi + 0x9ec]
  000D24EF  56                         push esi
  000D24F0  8b cd                      mov ecx, ebp
  000D24F2  89 07                      mov dword ptr [edi], eax
  000D24F4  e8 07 f0 fa ff             call 0x10081500
  000D24F9  c7 47 10 01 00 00 00       mov dword ptr [edi + 0x10], 1
  000D2500  5d                         pop ebp
  000D2501  eb 02                      jmp 0x100d2505
  000D2503  33 ff                      xor edi, edi
  000D2505  6a 00                      push 0
  000D2507  56                         push esi
  000D2508  57                         push edi
  000D2509  68 10 14 0d 10             push 0x100d1410
  000D250E  8d 4c 24 1c                lea ecx, [esp + 0x1c]
  000D2512  e8 e9 eb f9 ff             call 0x10071100
  000D2517  8b 16                      mov edx, dword ptr [esi]
  000D2519  8b ce                      mov ecx, esi
  000D251B  ff 92 d8 03 00 00          call dword ptr [edx + 0x3d8]
  000D2521  8a 48 09                   mov cl, byte ptr [eax + 9]
  000D2524  84 c9                      test cl, cl
  000D2526  0f 8e b4 00 00 00          jle 0x100d25e0
  000D252C  8b 06                      mov eax, dword ptr [esi]
  000D252E  8b ce                      mov ecx, esi
```

## E. SetAction @0xCEE50 (T2c)

Backs E7 (miss = silent no-op ret 0; hit ret 1).

Source file: `out3/d_cee50.md`

```text
; func 0xCEE50..0xCEE9C (76 bytes), callers: 0
  000CEE50  51                         push ecx
  000CEE51  56                         push esi
  000CEE52  57                         push edi
  000CEE53  8b 7c 24 10                mov edi, dword ptr [esp + 0x10]
  000CEE57  6a 00                      push 0
  000CEE59  6a 00                      push 0
  000CEE5B  6a ff                      push -1
  000CEE5D  57                         push edi
  000CEE5E  8d 44 24 20                lea eax, [esp + 0x20]
  000CEE62  6a 07                      push 7
  000CEE64  50                         push eax
  000CEE65  8b f1                      mov esi, ecx
  000CEE67  e8 24 f6 ff ff             call 0x100ce490
  000CEE6C  8b 44 24 10                mov eax, dword ptr [esp + 0x10]
  000CEE70  85 c0                      test eax, eax
  000CEE72  74 28                      je 0x100cee9c
  000CEE74  8b 4c 24 18                mov ecx, dword ptr [esp + 0x18]
  000CEE78  8b 54 24 14                mov edx, dword ptr [esp + 0x14]
  000CEE7C  51                         push ecx
  000CEE7D  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  000CEE83  6a 00                      push 0
  000CEE85  52                         push edx
  000CEE86  56                         push esi
  000CEE87  50                         push eax
  000CEE88  e8 33 41 fa ff             call 0x10072fc0
  000CEE8D  8b c8                      mov ecx, eax
  000CEE8F  e8 ec 7d f8 ff             call 0x10056c80
  000CEE94  5f                         pop edi
  000CEE95  b0 01                      mov al, 1
  000CEE97  5e                         pop esi
  000CEE98  59                         pop ecx
  000CEE99  c2 0c 00                   ret 0xc
```

## F. The request stack (EventIdle, loop wrapper, ReqSet/GetReq*, 0x27 to 0x2A)

Backs E8 to E11.

### F.1 EventIdle @0xBCD20 + XiEventInit @0xBCDE0 (disasm.py --func 0xBCD20)

Source file: `out3/d_bcd20.md`

```text
  000BCD20  56                         push esi
  000BCD21  8b f1                      mov esi, ecx
  000BCD23  8b 46 08                   mov eax, dword ptr [esi + 8]
  000BCD26  85 c0                      test eax, eax
  000BCD28  0f 84 a3 00 00 00          je 0x100bcdd1
  000BCD2E  57                         push edi
  000BCD2F  ba ff 00 00 00             mov edx, 0xff
  000BCD34  33 c0                      xor eax, eax
  000BCD36  8d 7e 24                   lea edi, [esi + 0x24]
  000BCD39  0f bf 0f                   movsx ecx, word ptr [edi]
  000BCD3C  3b ca                      cmp ecx, edx
  000BCD3E  7f 09                      jg 0x100bcd49
  000BCD40  8b d1                      mov edx, ecx
  000BCD42  66 89 86 58 02 00 00       mov word ptr [esi + 0x258], ax
  000BCD49  40                         inc eax
  000BCD4A  83 c7 20                   add edi, 0x20
  000BCD4D  83 f8 10                   cmp eax, 0x10
  000BCD50  7c e7                      jl 0x100bcd39
  000BCD52  a0 02 05 48 10             mov al, byte ptr [0x10480502]
  000BCD57  5f                         pop edi
  000BCD58  84 c0                      test al, al
  000BCD5A  75 09                      jne 0x100bcd65
  000BCD5C  a0 74 70 48 10             mov al, byte ptr [0x10487074]
  000BCD61  84 c0                      test al, al
  000BCD63  74 09                      je 0x100bcd6e
  000BCD65  a0 30 09 48 10             mov al, byte ptr [0x10480930]
  000BCD6A  84 c0                      test al, al
  000BCD6C  74 63                      je 0x100bcdd1
  000BCD6E  81 fa ff 00 00 00          cmp edx, 0xff
  000BCD74  74 5b                      je 0x100bcdd1
  000BCD76  33 c0                      xor eax, eax
  000BCD78  68 80 00 00 00             push 0x80
  000BCD7D  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCD81  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000BCD88  8b 88 24 01 00 00          mov ecx, dword ptr [eax + 0x124]
  000BCD8E  81 e1 ff ff fd ff          and ecx, 0xfffdffff
  000BCD94  89 88 24 01 00 00          mov dword ptr [eax + 0x124], ecx
  000BCD9A  33 c9                      xor ecx, ecx
  000BCD9C  66 8b 8e 58 02 00 00       mov cx, word ptr [esi + 0x258]
  000BCDA3  c1 e1 05                   shl ecx, 5
  000BCDA6  66 8b 54 31 26             mov dx, word ptr [ecx + esi + 0x26]
  000BCDAB  8b ce                      mov ecx, esi
  000BCDAD  66 89 96 56 02 00 00       mov word ptr [esi + 0x256], dx
  000BCDB4  e8 27 ff ff ff             call 0x100bcce0
  000BCDB9  66 8b 8e 56 02 00 00       mov cx, word ptr [esi + 0x256]
  000BCDC0  33 c0                      xor eax, eax
  000BCDC2  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000BCDC9  c1 e0 05                   shl eax, 5
  000BCDCC  66 89 4c 30 26             mov word ptr [eax + esi + 0x26], cx
  000BCDD1  5e                         pop esi
  000BCDD2  c3                         ret 
  000BCDD3  90                         nop 
  000BCDD4  90                         nop 
  000BCDD5  90                         nop 
  000BCDD6  90                         nop 
  000BCDD7  90                         nop 
  000BCDD8  90                         nop 
  000BCDD9  90                         nop 
  000BCDDA  90                         nop 
  000BCDDB  90                         nop 
  000BCDDC  90                         nop 
  000BCDDD  90                         nop 
  000BCDDE  90                         nop 
  000BCDDF  90                         nop 
  000BCDE0  53                         push ebx
  000BCDE1  55                         push ebp
  000BCDE2  56                         push esi
  000BCDE3  8b f1                      mov esi, ecx
  000BCDE5  33 c0                      xor eax, eax
  000BCDE7  33 db                      xor ebx, ebx
  000BCDE9  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCDED  57                         push edi
  000BCDEE  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000BCDF5  3b c3                      cmp eax, ebx
  000BCDF7  0f 84 ad 01 00 00          je 0x100bcfaa
  000BCDFD  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE03  8b 50 04                   mov edx, dword ptr [eax + 4]
  000BCE06  89 91 40 01 00 00          mov dword ptr [ecx + 0x140], edx
  000BCE0C  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE12  8b 50 08                   mov edx, dword ptr [eax + 8]
  000BCE15  89 91 44 01 00 00          mov dword ptr [ecx + 0x144], edx
  000BCE1B  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE21  8b 50 0c                   mov edx, dword ptr [eax + 0xc]
  000BCE24  89 91 48 01 00 00          mov dword ptr [ecx + 0x148], edx
  000BCE2A  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE30  8b 50 10                   mov edx, dword ptr [eax + 0x10]
  000BCE33  33 c0                      xor eax, eax
  000BCE35  89 91 4c 01 00 00          mov dword ptr [ecx + 0x14c], edx
  000BCE3B  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCE3F  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE45  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000BCE4C  83 c0 14                   add eax, 0x14
  000BCE4F  8b 10                      mov edx, dword ptr [eax]
  000BCE51  89 91 50 01 00 00          mov dword ptr [ecx + 0x150], edx
  000BCE57  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE5D  8b 50 04                   mov edx, dword ptr [eax + 4]
  000BCE60  89 91 54 01 00 00          mov dword ptr [ecx + 0x154], edx
  000BCE66  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE6C  8b 50 08                   mov edx, dword ptr [eax + 8]
  000BCE6F  89 91 58 01 00 00          mov dword ptr [ecx + 0x158], edx
  000BCE75  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE7B  8b 50 0c                   mov edx, dword ptr [eax + 0xc]
  000BCE7E  33 c0                      xor eax, eax
  000BCE80  89 91 5c 01 00 00          mov dword ptr [ecx + 0x15c], edx
  000BCE86  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCE8A  8b 96 60 02 00 00          mov edx, dword ptr [esi + 0x260]
  000BCE90  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  000BCE97  33 c0                      xor eax, eax
  000BCE99  d9 81 9c 00 00 00          fld dword ptr [ecx + 0x9c]
  000BCE9F  d9 9a 6c 01 00 00          fstp dword ptr [edx + 0x16c]
  000BCEA5  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCEA9  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  000BCEB0  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000BCEB6  3b cb                      cmp ecx, ebx
  000BCEB8  74 40                      je 0x100bcefa
  000BCEBA  68 bc 0e 33 10             push 0x10330ebc
  000BCEBF  e8 3c fa f6 ff             call 0x1002c900
  000BCEC4  84 c0                      test al, al
  000BCEC6  74 32                      je 0x100bcefa
  000BCEC8  33 d2                      xor edx, edx
  000BCECA  66 8b 56 02                mov dx, word ptr [esi + 2]
  000BCECE  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000BCED5  8b 88 2c 01 00 00          mov ecx, dword ptr [eax + 0x12c]
  000BCEDB  80 e5 fc                   and ch, 0xfc
  000BCEDE  89 88 2c 01 00 00          mov dword ptr [eax + 0x12c], ecx
  000BCEE4  33 c0                      xor eax, eax
  000BCEE6  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCEEA  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  000BCEF1  66 c7 81 48 01 00 00 ff ff mov word ptr [ecx + 0x148], 0xffff
  000BCEFA  33 d2                      xor edx, edx
  000BCEFC  66 8b 56 02                mov dx, word ptr [esi + 2]
  000BCF00  8b 0c 95 30 0b 48 10       mov ecx, dword ptr [edx*4 + 0x10480b30]
  000BCF07  8a 81 ee 00 00 00          mov al, byte ptr [ecx + 0xee]
  000BCF0D  3a c3                      cmp al, bl
  000BCF0F  74 2e                      je 0x100bcf3f
  000BCF11  3c 06                      cmp al, 6
  000BCF13  74 2a                      je 0x100bcf3f
  000BCF15  3c 07                      cmp al, 7
  000BCF17  74 26                      je 0x100bcf3f
  000BCF19  3c 01                      cmp al, 1
  000BCF1B  74 22                      je 0x100bcf3f
  000BCF1D  3c 02                      cmp al, 2
  000BCF1F  74 1e                      je 0x100bcf3f
  000BCF21  f6 81 20 01 00 00 04       test byte ptr [ecx + 0x120], 4   ; ent.RenderFlags0?
  000BCF28  0f 85 c4 00 00 00          jne 0x100bcff2
  000BCF2E  8b 81 70 01 00 00          mov eax, dword ptr [ecx + 0x170]
  000BCF34  89 81 74 01 00 00          mov dword ptr [ecx + 0x174], eax
  000BCF3A  e9 b3 00 00 00             jmp 0x100bcff2
  000BCF3F  83 b9 70 01 00 00 2f       cmp dword ptr [ecx + 0x170], 0x2f
  000BCF46  74 24                      je 0x100bcf6c
  000BCF48  68 ff 00 00 00             push 0xff
  000BCF4D  e8 4e 88 fd ff             call 0x100957a0
  000BCF52  84 c0                      test al, al
  000BCF54  75 16                      jne 0x100bcf6c
  000BCF56  33 c9                      xor ecx, ecx
  000BCF58  66 8b 4e 02                mov cx, word ptr [esi + 2]
  000BCF5C  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  000BCF63  83 b8 70 01 00 00 30       cmp dword ptr [eax + 0x170], 0x30
  000BCF6A  75 2d                      jne 0x100bcf99
  000BCF6C  33 d2                      xor edx, edx
  000BCF6E  66 8b 56 02                mov dx, word ptr [esi + 2]
  000BCF72  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000BCF79  80 b8 ee 00 00 00 01       cmp byte ptr [eax + 0xee], 1
  000BCF80  75 17                      jne 0x100bcf99
  000BCF82  f6 80 20 01 00 00 04       test byte ptr [eax + 0x120], 4   ; ent.RenderFlags0?
  000BCF89  75 67                      jne 0x100bcff2
  000BCF8B  8b 88 70 01 00 00          mov ecx, dword ptr [eax + 0x170]
  000BCF91  89 88 74 01 00 00          mov dword ptr [eax + 0x174], ecx
  000BCF97  eb 59                      jmp 0x100bcff2
  000BCF99  f6 80 20 01 00 00 04       test byte ptr [eax + 0x120], 4   ; ent.RenderFlags0?
  000BCFA0  75 50                      jne 0x100bcff2
  000BCFA2  89 98 74 01 00 00          mov dword ptr [eax + 0x174], ebx
  000BCFA8  eb 48                      jmp 0x100bcff2
  000BCFAA  8b 96 60 02 00 00          mov edx, dword ptr [esi + 0x260]
  000BCFB0  89 9a 40 01 00 00          mov dword ptr [edx + 0x140], ebx
  000BCFB6  8b 86 60 02 00 00          mov eax, dword ptr [esi + 0x260]
  000BCFBC  89 98 44 01 00 00          mov dword ptr [eax + 0x144], ebx
  000BCFC2  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCFC8  89 99 48 01 00 00          mov dword ptr [ecx + 0x148], ebx
  000BCFCE  8b 96 60 02 00 00          mov edx, dword ptr [esi + 0x260]
  000BCFD4  89 9a 50 01 00 00          mov dword ptr [edx + 0x150], ebx
  000BCFDA  8b 86 60 02 00 00          mov eax, dword ptr [esi + 0x260]
  000BCFE0  89 98 54 01 00 00          mov dword ptr [eax + 0x154], ebx
  000BCFE6  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCFEC  89 99 58 01 00 00          mov dword ptr [ecx + 0x158], ebx
  000BCFF2  8b 96 60 02 00 00          mov edx, dword ptr [esi + 0x260]
  000BCFF8  66 89 9e 44 02 00 00       mov word ptr [esi + 0x244], bx
  000BCFFF  88 9e 5a 02 00 00          mov byte ptr [esi + 0x25a], bl
  000BD005  68 80 00 00 00             push 0x80
  000BD00A  88 9a 62 01 00 00          mov byte ptr [edx + 0x162], bl
  000BD010  8b 46 10                   mov eax, dword ptr [esi + 0x10]
  000BD013  8b 56 08                   mov edx, dword ptr [esi + 8]
  000BD016  66 c7 86 24 02 00 00 ff 00 mov word ptr [esi + 0x224], 0xff
  000BD01F  66 8b 08                   mov cx, word ptr [eax]
  000BD022  33 c0                      xor eax, eax
  000BD024  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000BD02B  66 89 4e 26                mov word ptr [esi + 0x26], cx
  000BD02F  c1 e0 05                   shl eax, 5
  000BD032  88 5e 3a                   mov byte ptr [esi + 0x3a], bl
  000BD035  66 c7 46 24 80 00          mov word ptr [esi + 0x24], 0x80
  000BD03B  89 56 40                   mov dword ptr [esi + 0x40], edx
  000BD03E  66 8b 4c 30 26             mov cx, word ptr [eax + esi + 0x26]
  000BD043  66 89 8e 56 02 00 00       mov word ptr [esi + 0x256], cx
  000BD04A  8b ce                      mov ecx, esi
  000BD04C  e8 8f fc ff ff             call 0x100bcce0
  000BD051  66 8b 86 56 02 00 00       mov ax, word ptr [esi + 0x256]
  000BD058  33 d2                      xor edx, edx
  000BD05A  66 8b 96 58 02 00 00       mov dx, word ptr [esi + 0x258]
  000BD061  c1 e2 05                   shl edx, 5
  000BD064  66 89 44 32 26             mov word ptr [edx + esi + 0x26], ax
  000BD069  33 c0                      xor eax, eax
  000BD06B  0f bf 4e 0c                movsx ecx, word ptr [esi + 0xc]
  000BD06F  3b cb                      cmp ecx, ebx
  000BD071  7e 1a                      jle 0x100bd08d
  000BD073  8b 56 14                   mov edx, dword ptr [esi + 0x14]
  000BD076  8b 3d 1c 87 48 10          mov edi, dword ptr [0x1048871c]
  000BD07C  33 ed                      xor ebp, ebp
  000BD07E  66 8b 2a                   mov bp, word ptr [edx]
  000BD081  3b ef                      cmp ebp, edi
  000BD083  74 2c                      je 0x100bd0b1
  000BD085  40                         inc eax
  000BD086  83 c2 02                   add edx, 2
  000BD089  3b c1                      cmp eax, ecx
  000BD08B  7c ef                      jl 0x100bd07c
  000BD08D  33 c0                      xor eax, eax
  000BD08F  3b cb                      cmp ecx, ebx
  000BD091  7e 50                      jle 0x100bd0e3
  000BD093  8b 56 14                   mov edx, dword ptr [esi + 0x14]
  000BD096  66 81 3a fe ff             cmp word ptr [edx], 0xfffe
  000BD09B  74 14                      je 0x100bd0b1
  000BD09D  40                         inc eax
  000BD09E  83 c2 02                   add edx, 2
  000BD0A1  3b c1                      cmp eax, ecx
  000BD0A3  7c f1                      jl 0x100bd096
  000BD0A5  c6 86 5b 02 00 00 01       mov byte ptr [esi + 0x25b], 1
  000BD0AC  5f                         pop edi
  000BD0AD  5e                         pop esi
  000BD0AE  5d                         pop ebp
  000BD0AF  5b                         pop ebx
  000BD0B0  c3                         ret 
  000BD0B1  8b 4e 10                   mov ecx, dword ptr [esi + 0x10]
  000BD0B4  66 8b 14 41                mov dx, word ptr [ecx + eax*2]
  000BD0B8  33 c9                      xor ecx, ecx
  000BD0BA  66 8b 8e 58 02 00 00       mov cx, word ptr [esi + 0x258]
  000BD0C1  88 46 3a                   mov byte ptr [esi + 0x3a], al
  000BD0C4  8b 46 08                   mov eax, dword ptr [esi + 8]
  000BD0C7  66 c7 46 24 10 00          mov word ptr [esi + 0x24], 0x10
  000BD0CD  c1 e1 05                   shl ecx, 5
  000BD0D0  89 46 40                   mov dword ptr [esi + 0x40], eax
  000BD0D3  66 89 56 26                mov word ptr [esi + 0x26], dx
  000BD0D7  66 8b 54 31 26             mov dx, word ptr [ecx + esi + 0x26]
  000BD0DC  66 89 96 56 02 00 00       mov word ptr [esi + 0x256], dx
  000BD0E3  c6 86 5b 02 00 00 01       mov byte ptr [esi + 0x25b], 1
  000BD0EA  5f                         pop edi
  000BD0EB  5e                         pop esi
  000BD0EC  5d                         pop ebp
  000BD0ED  5b                         pop ebx
  000BD0EE  c3                         ret 
  000BD0EF  90                         nop 
  000BD0F0  53                         push ebx
  000BD0F1  8b d9                      mov ebx, ecx
  000BD0F3  8a 83 5b 02 00 00          mov al, byte ptr [ebx + 0x25b]
  000BD0F9  84 c0                      test al, al
  000BD0FB  74 3b                      je 0x100bd138
  000BD0FD  e8 ae 67 ff ff             call 0x100b38b0
  000BD102  66 81 bb 24 02 00 00 ff 00 cmp word ptr [ebx + 0x224], 0xff
  000BD10B  8d 83 24 02 00 00          lea eax, [ebx + 0x224]
  000BD111  74 25                      je 0x100bd138
  000BD113  56                         push esi
  000BD114  57                         push edi
  000BD115  8d 7b 24                   lea edi, [ebx + 0x24]
  000BD118  b9 08 00 00 00             mov ecx, 8
  000BD11D  8b f0                      mov esi, eax
  000BD11F  66 c7 83 58 02 00 00 00 00 mov word ptr [ebx + 0x258], 0
  000BD128  f3 a5                      rep movsd dword ptr es:[edi], dword ptr [esi]
  000BD12A  5f                         pop edi
  000BD12B  66 c7 00 ff 00             mov word ptr [eax], 0xff
  000BD130  5e                         pop esi
  000BD131  b8 01 00 00 00             mov eax, 1
  000BD136  5b                         pop ebx
  000BD137  c3                         ret 
  000BD138  33 c0                      xor eax, eax
  000BD13A  5b                         pop ebx
  000BD13B  c3                         ret 
  000BD13C  90                         nop 
  000BD13D  90                         nop 
  000BD13E  90                         nop 
  000BD13F  90                         nop 
  000BD140  8b 44 24 0c                mov eax, dword ptr [esp + 0xc]
  000BD144  53                         push ebx
  000BD145  83 c0 04                   add eax, 4
  000BD148  33 c9                      xor ecx, ecx
  000BD14A  56                         push esi
  000BD14B  57                         push edi
  000BD14C  8b 10                      mov edx, dword ptr [eax]
  000BD14E  85 d2                      test edx, edx
  000BD150  8d 74 50 04                lea esi, [eax + edx*2 + 4]
  000BD154  76 21                      jbe 0x100bd177
  000BD156  8b 3d 1c 87 48 10          mov edi, dword ptr [0x1048871c]
  000BD15C  66 8b 04 4e                mov ax, word ptr [esi + ecx*2]
  000BD160  8b d8                      mov ebx, eax
  000BD162  81 e3 ff ff 00 00          and ebx, 0xffff
  000BD168  3b df                      cmp ebx, edi
  000BD16A  74 11                      je 0x100bd17d
  000BD16C  66 3d fe ff                cmp ax, 0xfffe
  000BD170  74 0b                      je 0x100bd17d
  000BD172  41                         inc ecx
  000BD173  3b ca                      cmp ecx, edx
  000BD175  72 e5                      jb 0x100bd15c
  000BD177  5f                         pop edi
  000BD178  5e                         pop esi
  000BD179  32 c0                      xor al, al
  000BD17B  5b                         pop ebx
  000BD17C  c3                         ret 
  000BD17D  5f                         pop edi
  000BD17E  5e                         pop esi
  000BD17F  b0 01                      mov al, 1
```

### F.2 ExecProg loop wrapper @0xBCCE0 (disasm.py --func 0xBCCE0); clears RetFlag, loops until RetFlag != 0

Source file: `out3/d_bcce0.md`

```text
; func 0xBCC1A..0xBCF3F (805 bytes), callers: 0
  000BCC1A  0b 10                      or edx, dword ptr [eax]
  000BCC1C  f7 c7 0b 10 ff c7          test edi, 0xc7ff100b
  000BCC22  0b 10                      or edx, dword ptr [eax]
  000BCC24  07                         pop es
  000BCC25  c8 0b 10 0f                enter 0x100b, 0xf
  000BCC29  c8 0b 10 17                enter 0x100b, 0x17
  000BCC2D  c8 0b 10 1f                enter 0x100b, 0x1f
  000BCC31  c8 0b 10 27                enter 0x100b, 0x27
  000BCC35  c8 0b 10 2f                enter 0x100b, 0x2f
  000BCC39  c8 0b 10 37                enter 0x100b, 0x37
  000BCC3D  c8 0b 10 3f                enter 0x100b, 0x3f
  000BCC41  c8 0b 10 47                enter 0x100b, 0x47
  000BCC45  c8 0b 10 4f                enter 0x100b, 0x4f
  000BCC49  c8 0b 10 57                enter 0x100b, 0x57
  000BCC4D  c8 0b 10 5f                enter 0x100b, 0x5f
  000BCC51  c8 0b 10 67                enter 0x100b, 0x67
  000BCC55  c8 0b 10 6f                enter 0x100b, 0x6f
  000BCC59  c8 0b 10 77                enter 0x100b, 0x77
  000BCC5D  c8 0b 10 7f                enter 0x100b, 0x7f
  000BCC61  c8 0b 10 87                enter 0x100b, -0x79
  000BCC65  c8 0b 10 8f                enter 0x100b, -0x71
  000BCC69  c8 0b 10 97                enter 0x100b, -0x69
  000BCC6D  c8 0b 10 9f                enter 0x100b, -0x61
  000BCC71  c8 0b 10 a7                enter 0x100b, -0x59
  000BCC75  c8 0b 10 af                enter 0x100b, -0x51
  000BCC79  c8 0b 10 b7                enter 0x100b, -0x49
  000BCC7D  c8 0b 10 bf                enter 0x100b, -0x41
  000BCC81  c8 0b 10 c7                enter 0x100b, -0x39
  000BCC85  c8 0b 10 cf                enter 0x100b, -0x31
  000BCC89  c8 0b 10 d7                enter 0x100b, -0x29
  000BCC8D  c8 0b 10 df                enter 0x100b, -0x21
  000BCC91  c8 0b 10 e7                enter 0x100b, -0x19
  000BCC95  c8 0b 10 67                enter 0x100b, 0x67
  000BCC99  c9                         leave 
  000BCC9A  0b 10                      or edx, dword ptr [eax]
  000BCC9C  67 c9                      leave 
  000BCC9E  0b 10                      or edx, dword ptr [eax]
  000BCCA0  ef                         out dx, eax
  000BCCA1  c8 0b 10 f7                enter 0x100b, -9
  000BCCA5  c8 0b 10 ff                enter 0x100b, -1
  000BCCA9  c8 0b 10 07                enter 0x100b, 7
  000BCCAD  c9                         leave 
  000BCCAE  0b 10                      or edx, dword ptr [eax]
  000BCCB0  0f c9                      bswap ecx
  000BCCB2  0b 10                      or edx, dword ptr [eax]
  000BCCB4  17                         pop ss
  000BCCB5  c9                         leave 
  000BCCB6  0b 10                      or edx, dword ptr [eax]
  000BCCB8  1f                         pop ds
  000BCCB9  c9                         leave 
  000BCCBA  0b 10                      or edx, dword ptr [eax]
  000BCCBC  27                         daa 
  000BCCBD  c9                         leave 
  000BCCBE  0b 10                      or edx, dword ptr [eax]
  000BCCC0  2f                         das 
  000BCCC1  c9                         leave 
  000BCCC2  0b 10                      or edx, dword ptr [eax]
  000BCCC4  37                         aaa 
  000BCCC5  c9                         leave 
  000BCCC6  0b 10                      or edx, dword ptr [eax]
  000BCCC8  3f                         aas 
  000BCCC9  c9                         leave 
  000BCCCA  0b 10                      or edx, dword ptr [eax]
  000BCCCC  47                         inc edi
  000BCCCD  c9                         leave 
  000BCCCE  0b 10                      or edx, dword ptr [eax]
  000BCCD0  4f                         dec edi
  000BCCD1  c9                         leave 
  000BCCD2  0b 10                      or edx, dword ptr [eax]
  000BCCD4  57                         push edi
  000BCCD5  c9                         leave 
  000BCCD6  0b 10                      or edx, dword ptr [eax]
  000BCCD8  5f                         pop edi
  000BCCD9  c9                         leave 
  000BCCDA  0b 10                      or edx, dword ptr [eax]
  000BCCDC  90                         nop 
  000BCCDD  90                         nop 
  000BCCDE  90                         nop 
  000BCCDF  90                         nop 
  000BCCE0  56                         push esi
  000BCCE1  8b f1                      mov esi, ecx
  000BCCE3  c6 86 5a 02 00 00 00       mov byte ptr [esi + 0x25a], 0
  000BCCEA  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  000BCCED  85 c0                      test eax, eax
  000BCCEF  74 16                      je 0x100bcd07
  000BCCF1  33 c9                      xor ecx, ecx
  000BCCF3  66 8b 8e 56 02 00 00       mov cx, word ptr [esi + 0x256]
  000BCCFA  66 0f b6 14 01             movzx dx, byte ptr [ecx + eax]
  000BCCFF  52                         push edx
  000BCD00  8b ce                      mov ecx, esi
  000BCD02  e8 89 f5 ff ff             call 0x100bc290
  000BCD07  8a 86 5a 02 00 00          mov al, byte ptr [esi + 0x25a]
  000BCD0D  84 c0                      test al, al
  000BCD0F  74 d9                      je 0x100bccea
  000BCD11  5e                         pop esi
  000BCD12  c2 04 00                   ret 4
  000BCD15  90                         nop 
  000BCD16  90                         nop 
  000BCD17  90                         nop 
  000BCD18  90                         nop 
  000BCD19  90                         nop 
  000BCD1A  90                         nop 
  000BCD1B  90                         nop 
  000BCD1C  90                         nop 
  000BCD1D  90                         nop 
  000BCD1E  90                         nop 
  000BCD1F  90                         nop 
  000BCD20  56                         push esi
  000BCD21  8b f1                      mov esi, ecx
  000BCD23  8b 46 08                   mov eax, dword ptr [esi + 8]
  000BCD26  85 c0                      test eax, eax
  000BCD28  0f 84 a3 00 00 00          je 0x100bcdd1
  000BCD2E  57                         push edi
  000BCD2F  ba ff 00 00 00             mov edx, 0xff
  000BCD34  33 c0                      xor eax, eax
  000BCD36  8d 7e 24                   lea edi, [esi + 0x24]
  000BCD39  0f bf 0f                   movsx ecx, word ptr [edi]
  000BCD3C  3b ca                      cmp ecx, edx
  000BCD3E  7f 09                      jg 0x100bcd49
  000BCD40  8b d1                      mov edx, ecx
  000BCD42  66 89 86 58 02 00 00       mov word ptr [esi + 0x258], ax
  000BCD49  40                         inc eax
  000BCD4A  83 c7 20                   add edi, 0x20
  000BCD4D  83 f8 10                   cmp eax, 0x10
  000BCD50  7c e7                      jl 0x100bcd39
  000BCD52  a0 02 05 48 10             mov al, byte ptr [0x10480502]
  000BCD57  5f                         pop edi
  000BCD58  84 c0                      test al, al
  000BCD5A  75 09                      jne 0x100bcd65
  000BCD5C  a0 74 70 48 10             mov al, byte ptr [0x10487074]
  000BCD61  84 c0                      test al, al
  000BCD63  74 09                      je 0x100bcd6e
  000BCD65  a0 30 09 48 10             mov al, byte ptr [0x10480930]
  000BCD6A  84 c0                      test al, al
  000BCD6C  74 63                      je 0x100bcdd1
  000BCD6E  81 fa ff 00 00 00          cmp edx, 0xff
  000BCD74  74 5b                      je 0x100bcdd1
  000BCD76  33 c0                      xor eax, eax
  000BCD78  68 80 00 00 00             push 0x80
  000BCD7D  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCD81  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000BCD88  8b 88 24 01 00 00          mov ecx, dword ptr [eax + 0x124]
  000BCD8E  81 e1 ff ff fd ff          and ecx, 0xfffdffff
  000BCD94  89 88 24 01 00 00          mov dword ptr [eax + 0x124], ecx
  000BCD9A  33 c9                      xor ecx, ecx
  000BCD9C  66 8b 8e 58 02 00 00       mov cx, word ptr [esi + 0x258]
  000BCDA3  c1 e1 05                   shl ecx, 5
  000BCDA6  66 8b 54 31 26             mov dx, word ptr [ecx + esi + 0x26]
  000BCDAB  8b ce                      mov ecx, esi
  000BCDAD  66 89 96 56 02 00 00       mov word ptr [esi + 0x256], dx
  000BCDB4  e8 27 ff ff ff             call 0x100bcce0
  000BCDB9  66 8b 8e 56 02 00 00       mov cx, word ptr [esi + 0x256]
  000BCDC0  33 c0                      xor eax, eax
  000BCDC2  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000BCDC9  c1 e0 05                   shl eax, 5
  000BCDCC  66 89 4c 30 26             mov word ptr [eax + esi + 0x26], cx
  000BCDD1  5e                         pop esi
  000BCDD2  c3                         ret 
  000BCDD3  90                         nop 
  000BCDD4  90                         nop 
  000BCDD5  90                         nop 
  000BCDD6  90                         nop 
  000BCDD7  90                         nop 
  000BCDD8  90                         nop 
  000BCDD9  90                         nop 
  000BCDDA  90                         nop 
  000BCDDB  90                         nop 
  000BCDDC  90                         nop 
  000BCDDD  90                         nop 
  000BCDDE  90                         nop 
  000BCDDF  90                         nop 
  000BCDE0  53                         push ebx
  000BCDE1  55                         push ebp
  000BCDE2  56                         push esi
  000BCDE3  8b f1                      mov esi, ecx
  000BCDE5  33 c0                      xor eax, eax
  000BCDE7  33 db                      xor ebx, ebx
  000BCDE9  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCDED  57                         push edi
  000BCDEE  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000BCDF5  3b c3                      cmp eax, ebx
  000BCDF7  0f 84 ad 01 00 00          je 0x100bcfaa
  000BCDFD  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE03  8b 50 04                   mov edx, dword ptr [eax + 4]
  000BCE06  89 91 40 01 00 00          mov dword ptr [ecx + 0x140], edx
  000BCE0C  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE12  8b 50 08                   mov edx, dword ptr [eax + 8]
  000BCE15  89 91 44 01 00 00          mov dword ptr [ecx + 0x144], edx
  000BCE1B  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE21  8b 50 0c                   mov edx, dword ptr [eax + 0xc]
  000BCE24  89 91 48 01 00 00          mov dword ptr [ecx + 0x148], edx
  000BCE2A  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE30  8b 50 10                   mov edx, dword ptr [eax + 0x10]
  000BCE33  33 c0                      xor eax, eax
  000BCE35  89 91 4c 01 00 00          mov dword ptr [ecx + 0x14c], edx
  000BCE3B  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCE3F  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE45  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000BCE4C  83 c0 14                   add eax, 0x14
  000BCE4F  8b 10                      mov edx, dword ptr [eax]
  000BCE51  89 91 50 01 00 00          mov dword ptr [ecx + 0x150], edx
  000BCE57  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE5D  8b 50 04                   mov edx, dword ptr [eax + 4]
  000BCE60  89 91 54 01 00 00          mov dword ptr [ecx + 0x154], edx
  000BCE66  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE6C  8b 50 08                   mov edx, dword ptr [eax + 8]
  000BCE6F  89 91 58 01 00 00          mov dword ptr [ecx + 0x158], edx
  000BCE75  8b 8e 60 02 00 00          mov ecx, dword ptr [esi + 0x260]
  000BCE7B  8b 50 0c                   mov edx, dword ptr [eax + 0xc]
  000BCE7E  33 c0                      xor eax, eax
  000BCE80  89 91 5c 01 00 00          mov dword ptr [ecx + 0x15c], edx
  000BCE86  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCE8A  8b 96 60 02 00 00          mov edx, dword ptr [esi + 0x260]
  000BCE90  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  000BCE97  33 c0                      xor eax, eax
  000BCE99  d9 81 9c 00 00 00          fld dword ptr [ecx + 0x9c]
  000BCE9F  d9 9a 6c 01 00 00          fstp dword ptr [edx + 0x16c]
  000BCEA5  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCEA9  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  000BCEB0  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000BCEB6  3b cb                      cmp ecx, ebx
  000BCEB8  74 40                      je 0x100bcefa
  000BCEBA  68 bc 0e 33 10             push 0x10330ebc
  000BCEBF  e8 3c fa f6 ff             call 0x1002c900
  000BCEC4  84 c0                      test al, al
  000BCEC6  74 32                      je 0x100bcefa
  000BCEC8  33 d2                      xor edx, edx
  000BCECA  66 8b 56 02                mov dx, word ptr [esi + 2]
  000BCECE  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000BCED5  8b 88 2c 01 00 00          mov ecx, dword ptr [eax + 0x12c]
  000BCEDB  80 e5 fc                   and ch, 0xfc
  000BCEDE  89 88 2c 01 00 00          mov dword ptr [eax + 0x12c], ecx
  000BCEE4  33 c0                      xor eax, eax
  000BCEE6  66 8b 46 02                mov ax, word ptr [esi + 2]
  000BCEEA  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  000BCEF1  66 c7 81 48 01 00 00 ff ff mov word ptr [ecx + 0x148], 0xffff
  000BCEFA  33 d2                      xor edx, edx
  000BCEFC  66 8b 56 02                mov dx, word ptr [esi + 2]
  000BCF00  8b 0c 95 30 0b 48 10       mov ecx, dword ptr [edx*4 + 0x10480b30]
  000BCF07  8a 81 ee 00 00 00          mov al, byte ptr [ecx + 0xee]
  000BCF0D  3a c3                      cmp al, bl
  000BCF0F  74 2e                      je 0x100bcf3f
  000BCF11  3c 06                      cmp al, 6
  000BCF13  74 2a                      je 0x100bcf3f
  000BCF15  3c 07                      cmp al, 7
  000BCF17  74 26                      je 0x100bcf3f
  000BCF19  3c 01                      cmp al, 1
  000BCF1B  74 22                      je 0x100bcf3f
  000BCF1D  3c 02                      cmp al, 2
  000BCF1F  74 1e                      je 0x100bcf3f
  000BCF21  f6 81 20 01 00 00 04       test byte ptr [ecx + 0x120], 4   ; ent.RenderFlags0?
  000BCF28  0f 85 c4 00 00 00          jne 0x100bcff2
  000BCF2E  8b 81 70 01 00 00          mov eax, dword ptr [ecx + 0x170]
  000BCF34  89 81 74 01 00 00          mov dword ptr [ecx + 0x174], eax
  000BCF3A  e9 b3 00 00 00             jmp 0x100bcff2
```

### F.3 GetReqLevel @0xB36A0 / GetReqStatus @0xB36E0 / scan helper @0xB3670 + adjacent (disasm.py --func 0xB3590)

Source file: `out3/d_b3590.md`

```text
  000B3590  83 ec 08                   sub esp, 8
  000B3593  8d 44 24 00                lea eax, [esp]
  000B3597  56                         push esi
  000B3598  8b f1                      mov esi, ecx
  000B359A  8d 4c 24 08                lea ecx, [esp + 8]
  000B359E  50                         push eax
  000B359F  51                         push ecx
  000B35A0  6a 02                      push 2
  000B35A2  8b ce                      mov ecx, esi
  000B35A4  e8 27 c5 ff ff             call 0x100afad0
  000B35A9  50                         push eax
  000B35AA  8b ce                      mov ecx, esi
  000B35AC  e8 5f c5 ff ff             call 0x100afb10
  000B35B1  3c 01                      cmp al, 1
  000B35B3  75 2b                      jne 0x100b35e0
  000B35B5  8b 54 24 04                mov edx, dword ptr [esp + 4]
  000B35B9  81 e2 ff ff 00 00          and edx, 0xffff
  000B35BF  8b 0c 95 30 0b 48 10       mov ecx, dword ptr [edx*4 + 0x10480b30]
  000B35C6  85 c9                      test ecx, ecx
  000B35C8  74 16                      je 0x100b35e0
  000B35CA  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  000B35CD  33 c0                      xor eax, eax
  000B35CF  66 8b 86 56 02 00 00       mov ax, word ptr [esi + 0x256]
  000B35D6  8a 44 10 01                mov al, byte ptr [eax + edx + 1]
  000B35DA  50                         push eax
  000B35DB  e8 e0 ae fd ff             call 0x1008e4c0
  000B35E0  66 83 86 56 02 00 00 06    add word ptr [esi + 0x256], 6
  000B35E8  5e                         pop esi
  000B35E9  83 c4 08                   add esp, 8
  000B35EC  c3                         ret 
  000B35ED  90                         nop 
  000B35EE  90                         nop 
  000B35EF  90                         nop 
  000B35F0  83 ec 08                   sub esp, 8
  000B35F3  8d 44 24 00                lea eax, [esp]
  000B35F7  56                         push esi
  000B35F8  8b f1                      mov esi, ecx
  000B35FA  8d 4c 24 08                lea ecx, [esp + 8]
  000B35FE  50                         push eax
  000B35FF  51                         push ecx
  000B3600  6a 02                      push 2
  000B3602  8b ce                      mov ecx, esi
  000B3604  e8 c7 c4 ff ff             call 0x100afad0
  000B3609  50                         push eax
  000B360A  8b ce                      mov ecx, esi
  000B360C  e8 ff c4 ff ff             call 0x100afb10
  000B3611  3c 01                      cmp al, 1
  000B3613  75 42                      jne 0x100b3657
  000B3615  8b 54 24 04                mov edx, dword ptr [esp + 4]
  000B3619  81 e2 ff ff 00 00          and edx, 0xffff
  000B361F  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B3626  85 c0                      test eax, eax
  000B3628  74 2d                      je 0x100b3657
  000B362A  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  000B362D  33 c9                      xor ecx, ecx
  000B362F  66 8b 8e 56 02 00 00       mov cx, word ptr [esi + 0x256]
  000B3636  53                         push ebx
  000B3637  33 db                      xor ebx, ebx
  000B3639  8a 5c 11 01                mov bl, byte ptr [ecx + edx + 1]
  000B363D  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B3643  c1 e3 13                   shl ebx, 0x13
  000B3646  33 d9                      xor ebx, ecx
  000B3648  81 e3 00 00 08 00          and ebx, 0x80000
  000B364E  33 cb                      xor ecx, ebx
  000B3650  5b                         pop ebx
  000B3651  89 88 20 01 00 00          mov dword ptr [eax + 0x120], ecx   ; ent.RenderFlags0?
  000B3657  66 83 86 56 02 00 00 06    add word ptr [esi + 0x256], 6
  000B365F  5e                         pop esi
  000B3660  83 c4 08                   add esp, 8
  000B3663  c3                         ret 
  000B3664  90                         nop 
  000B3665  90                         nop 
  000B3666  90                         nop 
  000B3667  90                         nop 
  000B3668  90                         nop 
  000B3669  90                         nop 
  000B366A  90                         nop 
  000B366B  90                         nop 
  000B366C  90                         nop 
  000B366D  90                         nop 
  000B366E  90                         nop 
  000B366F  90                         nop 
  000B3670  56                         push esi
  000B3671  57                         push edi
  000B3672  8b 7c 24 0c                mov edi, dword ptr [esp + 0xc]
  000B3676  be 30 0b 48 10             mov esi, 0x10480b30
  000B367B  8b 0e                      mov ecx, dword ptr [esi]
  000B367D  85 c9                      test ecx, ecx
  000B367F  74 0a                      je 0x100b368b
  000B3681  57                         push edi
  000B3682  e8 09 7d fd ff             call 0x1008b390
  000B3687  85 c0                      test eax, eax
  000B3689  75 0d                      jne 0x100b3698
  000B368B  83 c6 04                   add esi, 4
  000B368E  81 fe 30 2f 48 10          cmp esi, 0x10482f30
  000B3694  7c e5                      jl 0x100b367b
  000B3696  33 c0                      xor eax, eax
  000B3698  5f                         pop edi
  000B3699  5e                         pop esi
  000B369A  c3                         ret 
  000B369B  90                         nop 
  000B369C  90                         nop 
  000B369D  90                         nop 
  000B369E  90                         nop 
  000B369F  90                         nop 
  000B36A0  33 c0                      xor eax, eax
  000B36A2  8b 54 24 04                mov edx, dword ptr [esp + 4]
  000B36A6  66 8b 81 58 02 00 00       mov ax, word ptr [ecx + 0x258]
  000B36AD  56                         push esi
  000B36AE  c1 e0 05                   shl eax, 5
  000B36B1  0f bf 44 08 24             movsx eax, word ptr [eax + ecx + 0x24]
  000B36B6  3b c2                      cmp eax, edx
  000B36B8  7f 06                      jg 0x100b36c0
  000B36BA  33 c0                      xor eax, eax
  000B36BC  5e                         pop esi
  000B36BD  c2 04 00                   ret 4
  000B36C0  33 c0                      xor eax, eax
  000B36C2  83 c1 24                   add ecx, 0x24
  000B36C5  0f bf 31                   movsx esi, word ptr [ecx]
  000B36C8  3b f2                      cmp esi, edx
  000B36CA  7e ee                      jle 0x100b36ba
  000B36CC  40                         inc eax
  000B36CD  83 c1 20                   add ecx, 0x20
  000B36D0  83 f8 10                   cmp eax, 0x10
  000B36D3  7c f0                      jl 0x100b36c5
  000B36D5  b8 01 00 00 00             mov eax, 1
  000B36DA  5e                         pop esi
  000B36DB  c2 04 00                   ret 4
  000B36DE  90                         nop 
  000B36DF  90                         nop 
  000B36E0  33 c0                      xor eax, eax
  000B36E2  8b 54 24 04                mov edx, dword ptr [esp + 4]
  000B36E6  66 8b 81 58 02 00 00       mov ax, word ptr [ecx + 0x258]
  000B36ED  56                         push esi
  000B36EE  c1 e0 05                   shl eax, 5
  000B36F1  0f be 44 08 3a             movsx eax, byte ptr [eax + ecx + 0x3a]
  000B36F6  3b c2                      cmp eax, edx
  000B36F8  75 06                      jne 0x100b3700
  000B36FA  33 c0                      xor eax, eax
  000B36FC  5e                         pop esi
  000B36FD  c2 04 00                   ret 4
  000B3700  33 c0                      xor eax, eax
  000B3702  83 c1 3a                   add ecx, 0x3a
  000B3705  0f be 31                   movsx esi, byte ptr [ecx]
  000B3708  3b f2                      cmp esi, edx
  000B370A  74 10                      je 0x100b371c
  000B370C  40                         inc eax
  000B370D  83 c1 20                   add ecx, 0x20
  000B3710  83 f8 10                   cmp eax, 0x10
  000B3713  7c f0                      jl 0x100b3705
  000B3715  83 c8 ff                   or eax, 0xffffffff
  000B3718  5e                         pop esi
  000B3719  c2 04 00                   ret 4
  000B371C  b8 01 00 00 00             mov eax, 1
  000B3721  5e                         pop esi
  000B3722  c2 04 00                   ret 4
  000B3725  90                         nop 
  000B3726  90                         nop 
  000B3727  90                         nop 
  000B3728  90                         nop 
  000B3729  90                         nop 
  000B372A  90                         nop 
  000B372B  90                         nop 
  000B372C  90                         nop 
  000B372D  90                         nop 
  000B372E  90                         nop 
  000B372F  90                         nop 
  000B3730  55                         push ebp
  000B3731  56                         push esi
  000B3732  57                         push edi
  000B3733  8b f9                      mov edi, ecx
  000B3735  8b 4c 24 14                mov ecx, dword ptr [esp + 0x14]
  000B3739  83 ce ff                   or esi, 0xffffffff
  000B373C  33 c0                      xor eax, eax
  000B373E  8d 57 3a                   lea edx, [edi + 0x3a]
  000B3741  66 81 7a ea ff 00          cmp word ptr [edx - 0x16], 0xff
  000B3747  75 04                      jne 0x100b374d
  000B3749  8b f0                      mov esi, eax
  000B374B  eb 07                      jmp 0x100b3754
  000B374D  0f be 2a                   movsx ebp, byte ptr [edx]
  000B3750  3b e9                      cmp ebp, ecx
  000B3752  74 44                      je 0x100b3798
  000B3754  40                         inc eax
  000B3755  83 c2 20                   add edx, 0x20
  000B3758  83 f8 10                   cmp eax, 0x10
  000B375B  7c e4                      jl 0x100b3741
  000B375D  83 fe ff                   cmp esi, -1
  000B3760  74 3e                      je 0x100b37a0
  000B3762  66 8b 54 24 18             mov dx, word ptr [esp + 0x18]
  000B3767  8b c6                      mov eax, esi
  000B3769  c1 e0 05                   shl eax, 5
  000B376C  03 c7                      add eax, edi
  000B376E  83 c6 02                   add esi, 2
  000B3771  c1 e6 05                   shl esi, 5
  000B3774  66 89 50 24                mov word ptr [eax + 0x24], dx
  000B3778  8b 57 10                   mov edx, dword ptr [edi + 0x10]
  000B377B  66 8b 14 4a                mov dx, word ptr [edx + ecx*2]
  000B377F  88 48 3a                   mov byte ptr [eax + 0x3a], cl
  000B3782  66 89 50 26                mov word ptr [eax + 0x26], dx
  000B3786  8b 44 24 10                mov eax, dword ptr [esp + 0x10]
  000B378A  89 04 3e                   mov dword ptr [esi + edi], eax
  000B378D  5f                         pop edi
  000B378E  5e                         pop esi
  000B378F  b8 01 00 00 00             mov eax, 1
  000B3794  5d                         pop ebp
  000B3795  c2 0c 00                   ret 0xc
  000B3798  5f                         pop edi
  000B3799  5e                         pop esi
  000B379A  33 c0                      xor eax, eax
  000B379C  5d                         pop ebp
  000B379D  c2 0c 00                   ret 0xc
  000B37A0  5f                         pop edi
  000B37A1  5e                         pop esi
  000B37A2  b8 02 00 00 00             mov eax, 2
  000B37A7  5d                         pop ebp
  000B37A8  c2 0c 00                   ret 0xc
  000B37AB  90                         nop 
  000B37AC  90                         nop 
  000B37AD  90                         nop 
  000B37AE  90                         nop 
  000B37AF  90                         nop 
  000B37B0  33 c0                      xor eax, eax
  000B37B2  66 8b 81 58 02 00 00       mov ax, word ptr [ecx + 0x258]
  000B37B9  c1 e0 05                   shl eax, 5
  000B37BC  03 c1                      add eax, ecx
  000B37BE  66 81 78 24 ff 00          cmp word ptr [eax + 0x24], 0xff
  000B37C4  75 04                      jne 0x100b37ca
  000B37C6  83 c8 ff                   or eax, 0xffffffff
  000B37C9  c3                         ret 
  000B37CA  8a 40 3a                   mov al, byte ptr [eax + 0x3a]
  000B37CD  8a 91 3a 02 00 00          mov dl, byte ptr [ecx + 0x23a]
  000B37D3  2a c2                      sub al, dl
  000B37D5  f6 d8                      neg al
  000B37D7  1b c0                      sbb eax, eax
  000B37D9  c3                         ret 
  000B37DA  90                         nop 
  000B37DB  90                         nop 
  000B37DC  90                         nop 
  000B37DD  90                         nop 
  000B37DE  90                         nop 
  000B37DF  90                         nop 
  000B37E0  66 81 b9 24 02 00 00 ff 00 cmp word ptr [ecx + 0x224], 0xff
  000B37E9  74 08                      je 0x100b37f3
  000B37EB  b8 02 00 00 00             mov eax, 2
  000B37F0  c2 0c 00                   ret 0xc
  000B37F3  66 8b 44 24 0c             mov ax, word ptr [esp + 0xc]
  000B37F8  8b 51 10                   mov edx, dword ptr [ecx + 0x10]
  000B37FB  66 89 81 24 02 00 00       mov word ptr [ecx + 0x224], ax
  000B3802  8b 44 24 08                mov eax, dword ptr [esp + 8]
  000B3806  66 8b 14 42                mov dx, word ptr [edx + eax*2]
  000B380A  88 81 3a 02 00 00          mov byte ptr [ecx + 0x23a], al
  000B3810  8b 44 24 04                mov eax, dword ptr [esp + 4]
  000B3814  66 89 91 26 02 00 00       mov word ptr [ecx + 0x226], dx
  000B381B  89 81 40 02 00 00          mov dword ptr [ecx + 0x240], eax
  000B3821  b8 01 00 00 00             mov eax, 1
  000B3826  c2 0c 00                   ret 0xc
  000B3829  90                         nop 
  000B382A  90                         nop 
  000B382B  90                         nop 
  000B382C  90                         nop 
  000B382D  90                         nop 
  000B382E  90                         nop 
  000B382F  90                         nop 
```

### F.4 ReqSet @0xB3730 (disasm.py --func 0xB3730)

Source file: `out3/d_b3730.md`

```text
; func 0xB371C..0xB374D (49 bytes), callers: 0
  000B371C  b8 01 00 00 00             mov eax, 1
  000B3721  5e                         pop esi
  000B3722  c2 04 00                   ret 4
  000B3725  90                         nop 
  000B3726  90                         nop 
  000B3727  90                         nop 
  000B3728  90                         nop 
  000B3729  90                         nop 
  000B372A  90                         nop 
  000B372B  90                         nop 
  000B372C  90                         nop 
  000B372D  90                         nop 
  000B372E  90                         nop 
  000B372F  90                         nop 
  000B3730  55                         push ebp
  000B3731  56                         push esi
  000B3732  57                         push edi
  000B3733  8b f9                      mov edi, ecx
  000B3735  8b 4c 24 14                mov ecx, dword ptr [esp + 0x14]
  000B3739  83 ce ff                   or esi, 0xffffffff
  000B373C  33 c0                      xor eax, eax
  000B373E  8d 57 3a                   lea edx, [edi + 0x3a]
  000B3741  66 81 7a ea ff 00          cmp word ptr [edx - 0x16], 0xff
  000B3747  75 04                      jne 0x100b374d
  000B3749  8b f0                      mov esi, eax
  000B374B  eb 07                      jmp 0x100b3754
```

### F.5 0x27 @0xB3940 request-on-target + helper call site (disasm.py --func 0xB3940)

Source file: `out3/d_b3940.md`

```text
; func 0xB386F..0xB39A1 (306 bytes), callers: 0
  000B386F  83 f8 ff                   cmp eax, -1
  000B3872  74 2b                      je 0x100b389f
  000B3874  8b d0                      mov edx, eax
  000B3876  83 c0 02                   add eax, 2
  000B3879  c1 e2 05                   shl edx, 5
  000B387C  03 d1                      add edx, ecx
  000B387E  c1 e0 05                   shl eax, 5
  000B3881  66 c7 42 26 00 00          mov word ptr [edx + 0x26], 0
  000B3887  66 c7 42 24 ff 00          mov word ptr [edx + 0x24], 0xff
  000B388D  c7 42 3c 00 00 80 bf       mov dword ptr [edx + 0x3c], 0xbf800000
  000B3894  c7 04 08 00 00 00 00       mov dword ptr [eax + ecx], 0
  000B389B  c6 42 3a 00                mov byte ptr [edx + 0x3a], 0
  000B389F  5f                         pop edi
  000B38A0  33 c0                      xor eax, eax
  000B38A2  5e                         pop esi
  000B38A3  c2 04 00                   ret 4
  000B38A6  90                         nop 
  000B38A7  90                         nop 
  000B38A8  90                         nop 
  000B38A9  90                         nop 
  000B38AA  90                         nop 
  000B38AB  90                         nop 
  000B38AC  90                         nop 
  000B38AD  90                         nop 
  000B38AE  90                         nop 
  000B38AF  90                         nop 
  000B38B0  33 d2                      xor edx, edx
  000B38B2  33 c0                      xor eax, eax
  000B38B4  66 89 91 56 02 00 00       mov word ptr [ecx + 0x256], dx
  000B38BB  66 89 91 58 02 00 00       mov word ptr [ecx + 0x258], dx
  000B38C2  66 89 91 44 02 00 00       mov word ptr [ecx + 0x244], dx
  000B38C9  89 81 46 02 00 00          mov dword ptr [ecx + 0x246], eax
  000B38CF  89 81 4a 02 00 00          mov dword ptr [ecx + 0x24a], eax
  000B38D5  57                         push edi
  000B38D6  89 81 4e 02 00 00          mov dword ptr [ecx + 0x24e], eax
  000B38DC  89 81 52 02 00 00          mov dword ptr [ecx + 0x252], eax
  000B38E2  8d 41 24                   lea eax, [ecx + 0x24]
  000B38E5  b9 10 00 00 00             mov ecx, 0x10
  000B38EA  66 89 50 02                mov word ptr [eax + 2], dx
  000B38EE  66 c7 00 ff 00             mov word ptr [eax], 0xff
  000B38F3  c7 40 18 00 00 80 bf       mov dword ptr [eax + 0x18], 0xbf800000
  000B38FA  89 50 1c                   mov dword ptr [eax + 0x1c], edx
  000B38FD  88 50 16                   mov byte ptr [eax + 0x16], dl
  000B3900  88 50 17                   mov byte ptr [eax + 0x17], dl
  000B3903  8b 3d f0 cf 35 10          mov edi, dword ptr [0x1035cff0]
  000B3909  89 78 04                   mov dword ptr [eax + 4], edi
  000B390C  8b 3d f4 cf 35 10          mov edi, dword ptr [0x1035cff4]
  000B3912  89 78 08                   mov dword ptr [eax + 8], edi
  000B3915  8b 3d f8 cf 35 10          mov edi, dword ptr [0x1035cff8]
  000B391B  89 78 0c                   mov dword ptr [eax + 0xc], edi
  000B391E  8b 3d fc cf 35 10          mov edi, dword ptr [0x1035cffc]
  000B3924  89 78 10                   mov dword ptr [eax + 0x10], edi
  000B3927  83 c0 20                   add eax, 0x20
  000B392A  49                         dec ecx
  000B392B  75 bd                      jne 0x100b38ea
  000B392D  33 c0                      xor eax, eax
  000B392F  5f                         pop edi
  000B3930  c3                         ret 
  000B3931  90                         nop 
  000B3932  90                         nop 
  000B3933  90                         nop 
  000B3934  90                         nop 
  000B3935  90                         nop 
  000B3936  90                         nop 
  000B3937  90                         nop 
  000B3938  90                         nop 
  000B3939  90                         nop 
  000B393A  90                         nop 
  000B393B  90                         nop 
  000B393C  90                         nop 
  000B393D  90                         nop 
  000B393E  90                         nop 
  000B393F  90                         nop 
  000B3940  83 ec 08                   sub esp, 8
  000B3943  8d 44 24 02                lea eax, [esp + 2]
  000B3947  56                         push esi
  000B3948  8b f1                      mov esi, ecx
  000B394A  8d 4c 24 08                lea ecx, [esp + 8]
  000B394E  50                         push eax
  000B394F  51                         push ecx
  000B3950  6a 02                      push 2
  000B3952  8b ce                      mov ecx, esi
  000B3954  e8 77 c1 ff ff             call 0x100afad0
  000B3959  50                         push eax
  000B395A  8b ce                      mov ecx, esi
  000B395C  e8 af c1 ff ff             call 0x100afb10
  000B3961  3c 01                      cmp al, 1
  000B3963  75 3c                      jne 0x100b39a1
  000B3965  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  000B3968  33 d2                      xor edx, edx
  000B396A  66 8b 96 56 02 00 00       mov dx, word ptr [esi + 0x256]
  000B3971  33 c9                      xor ecx, ecx
  000B3973  03 c2                      add eax, edx
  000B3975  33 d2                      xor edx, edx
  000B3977  8a 48 01                   mov cl, byte ptr [eax + 1]
  000B397A  8a 50 06                   mov dl, byte ptr [eax + 6]
  000B397D  8b 46 08                   mov eax, dword ptr [esi + 8]
  000B3980  51                         push ecx
  000B3981  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B3985  52                         push edx
  000B3986  50                         push eax
  000B3987  51                         push ecx
  000B3988  e8 23 00 00 00             call 0x100b39b0
  000B398D  83 c4 10                   add esp, 0x10
  000B3990  83 e8 02                   sub eax, 2
  000B3993  75 0c                      jne 0x100b39a1
  000B3995  c6 86 5a 02 00 00 01       mov byte ptr [esi + 0x25a], 1
  000B399C  5e                         pop esi
  000B399D  83 c4 08                   add esp, 8
  000B39A0  c3                         ret 
```

### F.6 Helper @0xB39B0 tail incl. the ReqSet call on ent+0xD4 (disasm.py --rva 0xB3A2F)

Source file: `out3/d_b3a2f.md`

```text
  000B3A2F  8a 81 20 01 00 00          mov al, byte ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B3A35  84 c0                      test al, al
  000B3A37  78 06                      js 0x100b3a3f
  000B3A39  5f                         pop edi
  000B3A3A  83 c8 ff                   or eax, 0xffffffff
  000B3A3D  5e                         pop esi
  000B3A3E  c3                         ret 
  000B3A3F  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000B3A43  8b 44 24 14                mov eax, dword ptr [esp + 0x14]
  000B3A47  8b 89 d4 00 00 00          mov ecx, dword ptr [ecx + 0xd4]
  000B3A4D  52                         push edx
  000B3A4E  50                         push eax
  000B3A4F  57                         push edi
  000B3A50  e8 db fc ff ff             call 0x100b3730
  000B3A55  5f                         pop edi
  000B3A56  5e                         pop esi
  000B3A57  c3                         ret 
  000B3A58  90                         nop 
  000B3A59  90                         nop 
  000B3A5A  90                         nop 
  000B3A5B  90                         nop 
  000B3A5C  90                         nop 
  000B3A5D  90                         nop 
  000B3A5E  90                         nop 
  000B3A5F  90                         nop 
  000B3A60  83 ec 08                   sub esp, 8
  000B3A63  33 c0                      xor eax, eax
  000B3A65  33 d2                      xor edx, edx
  000B3A67  56                         push esi
  000B3A68  8b f1                      mov esi, ecx
  000B3A6A  66 8b 86 56 02 00 00       mov ax, word ptr [esi + 0x256]
  000B3A71  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  000B3A74  8a 54 08 01                mov dl, byte ptr [eax + ecx + 1]
  000B3A78  8b c2                      mov eax, edx
  000B3A7A  83 f8 05                   cmp eax, 5
  000B3A7D  77 3d                      ja 0x100b3abc
  000B3A7F  ff 24 85 b8 3c 0b 10       jmp dword ptr [eax*4 + 0x100b3cb8]
  000B3A86  8d 44 24 04                lea eax, [esp + 4]
  000B3A8A  8d 4c 24 08                lea ecx, [esp + 8]
  000B3A8E  50                         push eax
  000B3A8F  51                         push ecx
  000B3A90  6a 02                      push 2
  000B3A92  8b ce                      mov ecx, esi
  000B3A94  e8 37 c0 ff ff             call 0x100afad0
  000B3A99  50                         push eax
  000B3A9A  8b ce                      mov ecx, esi
  000B3A9C  e8 6f c0 ff ff             call 0x100afb10
  000B3AA1  3c 01                      cmp al, 1
  000B3AA3  75 0f                      jne 0x100b3ab4
  000B3AA5  8b 54 24 08                mov edx, dword ptr [esp + 8]
  000B3AA9  6a ff                      push -1
  000B3AAB  52                         push edx
  000B3AAC  e8 1f 03 00 00             call 0x100b3dd0
  000B3AB1  83 c4 08                   add esp, 8
  000B3AB4  66 83 86 56 02 00 00 06    add word ptr [esi + 0x256], 6
  000B3ABC  5e                         pop esi
  000B3ABD  83 c4 08                   add esp, 8
  000B3AC0  c3                         ret 
  000B3AC1  8d 44 24 04                lea eax, [esp + 4]
  000B3AC5  8d 4c 24 08                lea ecx, [esp + 8]
  000B3AC9  50                         push eax
  000B3ACA  51                         push ecx
  000B3ACB  6a 02                      push 2
  000B3ACD  8b ce                      mov ecx, esi
  000B3ACF  e8 fc bf ff ff             call 0x100afad0
  000B3AD4  50                         push eax
  000B3AD5  8b ce                      mov ecx, esi
  000B3AD7  e8 34 c0 ff ff             call 0x100afb10
  000B3ADC  3c 01                      cmp al, 1
  000B3ADE  75 20                      jne 0x100b3b00
  000B3AE0  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  000B3AE3  33 d2                      xor edx, edx
  000B3AE5  66 8b 96 56 02 00 00       mov dx, word ptr [esi + 0x256]
  000B3AEC  33 c9                      xor ecx, ecx
  000B3AEE  8a 4c 02 06                mov cl, byte ptr [edx + eax + 6]
  000B3AF2  8b 54 24 08                mov edx, dword ptr [esp + 8]
  000B3AF6  51                         push ecx
  000B3AF7  52                         push edx
  000B3AF8  e8 d3 02 00 00             call 0x100b3dd0
  000B3AFD  83 c4 08                   add esp, 8
  000B3B00  66 83 86 56 02 00 00 07    add word ptr [esi + 0x256], 7
  000B3B08  5e                         pop esi
  000B3B09  83 c4 08                   add esp, 8
  000B3B0C  c3                         ret 
  000B3B0D  8d 44 24 08                lea eax, [esp + 8]
  000B3B11  8d 4c 24 04                lea ecx, [esp + 4]
  000B3B15  50                         push eax
  000B3B16  51                         push ecx
  000B3B17  6a 02                      push 2
  000B3B19  8b ce                      mov ecx, esi
  000B3B1B  e8 b0 bf ff ff             call 0x100afad0
  000B3B20  50                         push eax
  000B3B21  8b ce                      mov ecx, esi
  000B3B23  e8 e8 bf ff ff             call 0x100afb10
  000B3B28  3c 01                      cmp al, 1
  000B3B2A  75 6f                      jne 0x100b3b9b
  000B3B2C  8b 54 24 08                mov edx, dword ptr [esp + 8]
```

### F.7 0x28 @0xB3E60 wait-for-requested-event (disasm.py --func 0xB3E60)

Source file: `out3/d_b3e60.md`

```text
; func 0xB3E16..0xB3F67 (337 bytes), callers: 0
  000B3E16  8b 4c 24 08                mov ecx, dword ptr [esp + 8]
  000B3E1A  51                         push ecx
  000B3E1B  8b 88 d4 00 00 00          mov ecx, dword ptr [eax + 0xd4]
  000B3E21  e8 1a fa ff ff             call 0x100b3840
  000B3E26  c3                         ret 
  000B3E27  90                         nop 
  000B3E28  90                         nop 
  000B3E29  90                         nop 
  000B3E2A  90                         nop 
  000B3E2B  90                         nop 
  000B3E2C  90                         nop 
  000B3E2D  90                         nop 
  000B3E2E  90                         nop 
  000B3E2F  90                         nop 
  000B3E30  56                         push esi
  000B3E31  8b f1                      mov esi, ecx
  000B3E33  33 c0                      xor eax, eax
  000B3E35  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000B3E3C  83 c0 02                   add eax, 2
  000B3E3F  c1 e0 05                   shl eax, 5
  000B3E42  8b 0c 30                   mov ecx, dword ptr [eax + esi]
  000B3E45  51                         push ecx
  000B3E46  6a 01                      push 1
  000B3E48  8b ce                      mov ecx, esi
  000B3E4A  e8 d1 b4 ff ff             call 0x100af320
  000B3E4F  66 83 86 56 02 00 00 03    add word ptr [esi + 0x256], 3
  000B3E57  5e                         pop esi
  000B3E58  c3                         ret 
  000B3E59  90                         nop 
  000B3E5A  90                         nop 
  000B3E5B  90                         nop 
  000B3E5C  90                         nop 
  000B3E5D  90                         nop 
  000B3E5E  90                         nop 
  000B3E5F  90                         nop 
  000B3E60  83 ec 08                   sub esp, 8
  000B3E63  33 c0                      xor eax, eax
  000B3E65  53                         push ebx
  000B3E66  56                         push esi
  000B3E67  8b f1                      mov esi, ecx
  000B3E69  57                         push edi
  000B3E6A  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000B3E71  c1 e0 05                   shl eax, 5
  000B3E74  0f be 44 30 3b             movsx eax, byte ptr [eax + esi + 0x3b]
  000B3E79  83 e8 00                   sub eax, 0
  000B3E7C  0f 84 e5 00 00 00          je 0x100b3f67
  000B3E82  48                         dec eax
  000B3E83  0f 85 30 01 00 00          jne 0x100b3fb9
  000B3E89  8d 4c 24 0e                lea ecx, [esp + 0xe]
  000B3E8D  8d 54 24 10                lea edx, [esp + 0x10]
  000B3E91  51                         push ecx
  000B3E92  52                         push edx
  000B3E93  6a 02                      push 2
  000B3E95  8b ce                      mov ecx, esi
  000B3E97  e8 34 bc ff ff             call 0x100afad0
  000B3E9C  50                         push eax
  000B3E9D  8b ce                      mov ecx, esi
  000B3E9F  e8 6c bc ff ff             call 0x100afb10
  000B3EA4  b3 01                      mov bl, 1
  000B3EA6  3a c3                      cmp al, bl
  000B3EA8  0f 85 0b 01 00 00          jne 0x100b3fb9
  000B3EAE  8b 44 24 10                mov eax, dword ptr [esp + 0x10]
  000B3EB2  50                         push eax
  000B3EB3  e8 b8 f7 ff ff             call 0x100b3670
  000B3EB8  8b f8                      mov edi, eax
  000B3EBA  83 c4 04                   add esp, 4
  000B3EBD  85 ff                      test edi, edi
  000B3EBF  0f 84 f4 00 00 00          je 0x100b3fb9
  000B3EC5  8b 4e 08                   mov ecx, dword ptr [esi + 8]
  000B3EC8  51                         push ecx
  000B3EC9  e8 a2 f7 ff ff             call 0x100b3670
  000B3ECE  83 c4 04                   add esp, 4
  000B3ED1  85 c0                      test eax, eax
  000B3ED3  0f 84 e0 00 00 00          je 0x100b3fb9
  000B3ED9  8b 17                      mov edx, dword ptr [edi]
  000B3EDB  8b 0c 95 30 0b 48 10       mov ecx, dword ptr [edx*4 + 0x10480b30]
  000B3EE2  85 c9                      test ecx, ecx
  000B3EE4  0f 84 cf 00 00 00          je 0x100b3fb9
  000B3EEA  8b 00                      mov eax, dword ptr [eax]
  000B3EEC  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000B3EF3  85 c0                      test eax, eax
  000B3EF5  0f 84 be 00 00 00          je 0x100b3fb9
  000B3EFB  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B3F01  c1 ea 07                   shr edx, 7
  000B3F04  84 d3                      test bl, dl
  000B3F06  0f 84 ad 00 00 00          je 0x100b3fb9
  000B3F0C  8b 80 20 01 00 00          mov eax, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B3F12  c1 e8 07                   shr eax, 7
  000B3F15  84 c3                      test bl, al
  000B3F17  0f 84 9c 00 00 00          je 0x100b3fb9
  000B3F1D  8a 81 20 01 00 00          mov al, byte ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B3F23  84 c0                      test al, al
  000B3F25  0f 89 8e 00 00 00          jns 0x100b3fb9
  000B3F2B  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  000B3F2E  8b 89 d4 00 00 00          mov ecx, dword ptr [ecx + 0xd4]
  000B3F34  33 d2                      xor edx, edx
  000B3F36  89 5c 24 10                mov dword ptr [esp + 0x10], ebx
  000B3F3A  66 8b 96 56 02 00 00       mov dx, word ptr [esi + 0x256]
  000B3F41  33 db                      xor ebx, ebx
  000B3F43  8a 5c 02 06                mov bl, byte ptr [edx + eax + 6]
  000B3F47  53                         push ebx
  000B3F48  e8 93 f7 ff ff             call 0x100b36e0
  000B3F4D  8b 5c 24 10                mov ebx, dword ptr [esp + 0x10]
  000B3F51  85 c0                      test eax, eax
  000B3F53  74 64                      je 0x100b3fb9
  000B3F55  83 f8 ff                   cmp eax, -1
  000B3F58  74 5f                      je 0x100b3fb9
  000B3F5A  88 9e 5a 02 00 00          mov byte ptr [esi + 0x25a], bl
  000B3F60  5f                         pop edi
  000B3F61  5e                         pop esi
  000B3F62  5b                         pop ebx
  000B3F63  83 c4 08                   add esp, 8
  000B3F66  c3                         ret 
```

### F.8 0x29 @0xB4000 request-wait/poll, cases 1 and 2 (disasm.py --func 0xB4000)

Source file: `out3/d_b4000.md`

```text
; func 0xB3FD9..0xB410E (309 bytes), callers: 0
  000B3FD9  33 c9                      xor ecx, ecx
  000B3FDB  66 8b 8e 58 02 00 00       mov cx, word ptr [esi + 0x258]
  000B3FE2  c1 e1 05                   shl ecx, 5
  000B3FE5  88 5c 31 3b                mov byte ptr [ecx + esi + 0x3b], bl
  000B3FE9  88 9e 5a 02 00 00          mov byte ptr [esi + 0x25a], bl
  000B3FEF  5f                         pop edi
  000B3FF0  5e                         pop esi
  000B3FF1  5b                         pop ebx
  000B3FF2  83 c4 08                   add esp, 8
  000B3FF5  c3                         ret 
  000B3FF6  90                         nop 
  000B3FF7  90                         nop 
  000B3FF8  90                         nop 
  000B3FF9  90                         nop 
  000B3FFA  90                         nop 
  000B3FFB  90                         nop 
  000B3FFC  90                         nop 
  000B3FFD  90                         nop 
  000B3FFE  90                         nop 
  000B3FFF  90                         nop 
  000B4000  83 ec 08                   sub esp, 8
  000B4003  33 c0                      xor eax, eax
  000B4005  53                         push ebx
  000B4006  56                         push esi
  000B4007  8b f1                      mov esi, ecx
  000B4009  57                         push edi
  000B400A  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000B4011  c1 e0 05                   shl eax, 5
  000B4014  0f be 44 30 3b             movsx eax, byte ptr [eax + esi + 0x3b]
  000B4019  83 e8 00                   sub eax, 0
  000B401C  0f 84 d7 01 00 00          je 0x100b41f9
  000B4022  48                         dec eax
  000B4023  0f 84 e5 00 00 00          je 0x100b410e
  000B4029  48                         dec eax
  000B402A  0f 85 1c 02 00 00          jne 0x100b424c
  000B4030  8d 4c 24 0e                lea ecx, [esp + 0xe]
  000B4034  8d 54 24 10                lea edx, [esp + 0x10]
  000B4038  51                         push ecx
  000B4039  52                         push edx
  000B403A  6a 02                      push 2
  000B403C  8b ce                      mov ecx, esi
  000B403E  e8 8d ba ff ff             call 0x100afad0
  000B4043  50                         push eax
  000B4044  8b ce                      mov ecx, esi
  000B4046  e8 c5 ba ff ff             call 0x100afb10
  000B404B  b3 01                      mov bl, 1
  000B404D  3a c3                      cmp al, bl
  000B404F  0f 85 f7 01 00 00          jne 0x100b424c
  000B4055  8b 44 24 10                mov eax, dword ptr [esp + 0x10]
  000B4059  50                         push eax
  000B405A  e8 11 f6 ff ff             call 0x100b3670
  000B405F  8b f8                      mov edi, eax
  000B4061  83 c4 04                   add esp, 4
  000B4064  85 ff                      test edi, edi
  000B4066  0f 84 e0 01 00 00          je 0x100b424c
  000B406C  8b 4e 08                   mov ecx, dword ptr [esi + 8]
  000B406F  51                         push ecx
  000B4070  e8 fb f5 ff ff             call 0x100b3670
  000B4075  83 c4 04                   add esp, 4
  000B4078  85 c0                      test eax, eax
  000B407A  0f 84 cc 01 00 00          je 0x100b424c
  000B4080  8b 17                      mov edx, dword ptr [edi]
  000B4082  8b 0c 95 30 0b 48 10       mov ecx, dword ptr [edx*4 + 0x10480b30]
  000B4089  85 c9                      test ecx, ecx
  000B408B  0f 84 bb 01 00 00          je 0x100b424c
  000B4091  8b 00                      mov eax, dword ptr [eax]
  000B4093  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  000B409A  85 c0                      test eax, eax
  000B409C  0f 84 aa 01 00 00          je 0x100b424c
  000B40A2  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B40A8  c1 ea 07                   shr edx, 7
  000B40AB  84 d3                      test bl, dl
  000B40AD  0f 84 99 01 00 00          je 0x100b424c
  000B40B3  8b 80 20 01 00 00          mov eax, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B40B9  c1 e8 07                   shr eax, 7
  000B40BC  84 c3                      test bl, al
  000B40BE  0f 84 88 01 00 00          je 0x100b424c
  000B40C4  8a 81 20 01 00 00          mov al, byte ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B40CA  84 c0                      test al, al
  000B40CC  0f 89 7a 01 00 00          jns 0x100b424c
  000B40D2  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  000B40D5  8b 89 d4 00 00 00          mov ecx, dword ptr [ecx + 0xd4]
  000B40DB  33 d2                      xor edx, edx
  000B40DD  89 5c 24 10                mov dword ptr [esp + 0x10], ebx
  000B40E1  66 8b 96 56 02 00 00       mov dx, word ptr [esi + 0x256]
  000B40E8  33 db                      xor ebx, ebx
  000B40EA  8a 5c 02 06                mov bl, byte ptr [edx + eax + 6]
  000B40EE  53                         push ebx
  000B40EF  e8 ec f5 ff ff             call 0x100b36e0
  000B40F4  8b 5c 24 10                mov ebx, dword ptr [esp + 0x10]
  000B40F8  83 f8 ff                   cmp eax, -1
  000B40FB  0f 84 4b 01 00 00          je 0x100b424c
  000B4101  88 9e 5a 02 00 00          mov byte ptr [esi + 0x25a], bl
  000B4107  5f                         pop edi
  000B4108  5e                         pop esi
  000B4109  5b                         pop ebx
  000B410A  83 c4 08                   add esp, 8
  000B410D  c3                         ret 
```

### F.9 0x29 case-0 new-request path @0xB41F9 (disasm.py --rva 0xB41F9 --len 128)

Source file: `out3/d_b41f9.md`

```text
  000B41F9  8d 54 24 0e                lea edx, [esp + 0xe]
  000B41FD  8d 44 24 10                lea eax, [esp + 0x10]
  000B4201  52                         push edx
  000B4202  50                         push eax
  000B4203  6a 02                      push 2
  000B4205  8b ce                      mov ecx, esi
  000B4207  e8 c4 b8 ff ff             call 0x100afad0
  000B420C  50                         push eax
  000B420D  8b ce                      mov ecx, esi
  000B420F  e8 fc b8 ff ff             call 0x100afb10
  000B4214  b3 01                      mov bl, 1
  000B4216  3a c3                      cmp al, bl
  000B4218  75 32                      jne 0x100b424c
  000B421A  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  000B421D  33 c9                      xor ecx, ecx
  000B421F  66 8b 8e 56 02 00 00       mov cx, word ptr [esi + 0x256]
  000B4226  8d 04 11                   lea eax, [ecx + edx]
  000B4229  33 c9                      xor ecx, ecx
  000B422B  33 d2                      xor edx, edx
  000B422D  8a 48 01                   mov cl, byte ptr [eax + 1]
  000B4230  8a 50 06                   mov dl, byte ptr [eax + 6]
  000B4233  8b 46 08                   mov eax, dword ptr [esi + 8]
  000B4236  51                         push ecx
  000B4237  8b 4c 24 14                mov ecx, dword ptr [esp + 0x14]
  000B423B  52                         push edx
  000B423C  50                         push eax
  000B423D  51                         push ecx
  000B423E  e8 6d f7 ff ff             call 0x100b39b0
  000B4243  83 c4 10                   add esp, 0x10
  000B4246  48                         dec eax
  000B4247  74 23                      je 0x100b426c
  000B4249  48                         dec eax
  000B424A  74 30                      je 0x100b427c
  000B424C  33 c0                      xor eax, eax
  000B424E  5f                         pop edi
  000B424F  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000B4256  c1 e0 05                   shl eax, 5
  000B4259  c6 44 30 3b 00             mov byte ptr [eax + esi + 0x3b], 0
  000B425E  66 83 86 56 02 00 00 07    add word ptr [esi + 0x256], 7
  000B4266  5e                         pop esi
  000B4267  5b                         pop ebx
  000B4268  83 c4 08                   add esp, 8
  000B426B  c3                         ret 
  000B426C  33 d2                      xor edx, edx
  000B426E  66 8b 96 58 02 00 00       mov dx, word ptr [esi + 0x258]
  000B4275  c1 e2 05                   shl edx, 5
  000B4278  88 5c 32 3b                mov byte ptr [edx + esi + 0x3b], bl
```

### F.10 0x29/0x2A fail-path EP advance @0xB424C and success tails @0xB426C/0xB427C (disasm.py --rva 0xB424C --len 64)

Source file: `out3/d_b424c.md`

```text
  000B424C  33 c0                      xor eax, eax
  000B424E  5f                         pop edi
  000B424F  66 8b 86 58 02 00 00       mov ax, word ptr [esi + 0x258]
  000B4256  c1 e0 05                   shl eax, 5
  000B4259  c6 44 30 3b 00             mov byte ptr [eax + esi + 0x3b], 0
  000B425E  66 83 86 56 02 00 00 07    add word ptr [esi + 0x256], 7
  000B4266  5e                         pop esi
  000B4267  5b                         pop ebx
  000B4268  83 c4 08                   add esp, 8
  000B426B  c3                         ret 
  000B426C  33 d2                      xor edx, edx
  000B426E  66 8b 96 58 02 00 00       mov dx, word ptr [esi + 0x258]
  000B4275  c1 e2 05                   shl edx, 5
  000B4278  88 5c 32 3b                mov byte ptr [edx + esi + 0x3b], bl
  000B427C  88 9e 5a 02 00 00          mov byte ptr [esi + 0x25a], bl
  000B4282  5f                         pop edi
  000B4283  5e                         pop esi
  000B4284  5b                         pop ebx
  000B4285  83 c4 08                   add esp, 8
  000B4288  c3                         ret 
  000B4289  90                         nop 
  000B428A  90                         nop 
  000B428B  90                         nop 
```

### F.11 0x2A @0xB4290 req-wait/level check (disasm.py --func 0xB4290)

Source file: `out3/d_b4290.md`

```text
; func 0xB426C..0xB434A (222 bytes), callers: 0
  000B426C  33 d2                      xor edx, edx
  000B426E  66 8b 96 58 02 00 00       mov dx, word ptr [esi + 0x258]
  000B4275  c1 e2 05                   shl edx, 5
  000B4278  88 5c 32 3b                mov byte ptr [edx + esi + 0x3b], bl
  000B427C  88 9e 5a 02 00 00          mov byte ptr [esi + 0x25a], bl
  000B4282  5f                         pop edi
  000B4283  5e                         pop esi
  000B4284  5b                         pop ebx
  000B4285  83 c4 08                   add esp, 8
  000B4288  c3                         ret 
  000B4289  90                         nop 
  000B428A  90                         nop 
  000B428B  90                         nop 
  000B428C  90                         nop 
  000B428D  90                         nop 
  000B428E  90                         nop 
  000B428F  90                         nop 
  000B4290  83 ec 08                   sub esp, 8
  000B4293  8d 44 24 02                lea eax, [esp + 2]
  000B4297  56                         push esi
  000B4298  8b f1                      mov esi, ecx
  000B429A  57                         push edi
  000B429B  8d 4c 24 0c                lea ecx, [esp + 0xc]
  000B429F  50                         push eax
  000B42A0  51                         push ecx
  000B42A1  6a 02                      push 2
  000B42A3  8b ce                      mov ecx, esi
  000B42A5  e8 26 b8 ff ff             call 0x100afad0
  000B42AA  50                         push eax
  000B42AB  8b ce                      mov ecx, esi
  000B42AD  e8 5e b8 ff ff             call 0x100afb10
  000B42B2  3c 01                      cmp al, 1
  000B42B4  0f 85 90 00 00 00          jne 0x100b434a
  000B42BA  8b 54 24 0c                mov edx, dword ptr [esp + 0xc]
  000B42BE  52                         push edx
  000B42BF  e8 ac f3 ff ff             call 0x100b3670
  000B42C4  8b f8                      mov edi, eax
  000B42C6  8b 46 08                   mov eax, dword ptr [esi + 8]
  000B42C9  50                         push eax
  000B42CA  e8 a1 f3 ff ff             call 0x100b3670
  000B42CF  83 c4 08                   add esp, 8
  000B42D2  85 ff                      test edi, edi
  000B42D4  74 74                      je 0x100b434a
  000B42D6  85 c0                      test eax, eax
  000B42D8  74 70                      je 0x100b434a
  000B42DA  8b 0f                      mov ecx, dword ptr [edi]
  000B42DC  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  000B42E3  85 c9                      test ecx, ecx
  000B42E5  74 63                      je 0x100b434a
  000B42E7  8b 10                      mov edx, dword ptr [eax]
  000B42E9  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B42F0  85 c0                      test eax, eax
  000B42F2  74 56                      je 0x100b434a
  000B42F4  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B42FA  c1 ea 07                   shr edx, 7
  000B42FD  f6 c2 01                   test dl, 1
  000B4300  74 48                      je 0x100b434a
  000B4302  8b 80 20 01 00 00          mov eax, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B4308  c1 e8 07                   shr eax, 7
  000B430B  a8 01                      test al, 1
  000B430D  74 3b                      je 0x100b434a
  000B430F  8a 81 20 01 00 00          mov al, byte ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B4315  84 c0                      test al, al
  000B4317  79 31                      jns 0x100b434a
  000B4319  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  000B431C  8b 89 d4 00 00 00          mov ecx, dword ptr [ecx + 0xd4]
  000B4322  33 d2                      xor edx, edx
  000B4324  53                         push ebx
  000B4325  66 8b 96 56 02 00 00       mov dx, word ptr [esi + 0x256]
  000B432C  33 db                      xor ebx, ebx
  000B432E  8a 5c 02 01                mov bl, byte ptr [edx + eax + 1]
  000B4332  53                         push ebx
  000B4333  e8 68 f3 ff ff             call 0x100b36a0
  000B4338  85 c0                      test eax, eax
  000B433A  5b                         pop ebx
  000B433B  75 0d                      jne 0x100b434a
  000B433D  c6 86 5a 02 00 00 01       mov byte ptr [esi + 0x25a], 1
  000B4344  5f                         pop edi
  000B4345  5e                         pop esi
  000B4346  83 c4 08                   add esp, 8
  000B4349  c3                         ret 
```

## G. GetActorIndex @0xAFB10 (full decode)

Backs E12.

### G.1 eventgetcode @0xAFAA0 / eventgetcode2 @0xAFAD0 / GetActorIndex @0xAFB10 start (disasm.py --func 0xAFA8C)

Source file: `out3/d_afa8c.md`

```text
  000AFA8C  b8 c4 3c 3d 10             mov eax, 0x103d3cc4
  000AFA91  5e                         pop esi
  000AFA92  c2 08 00                   ret 8
  000AFA95  90                         nop 
  000AFA96  90                         nop 
  000AFA97  90                         nop 
  000AFA98  90                         nop 
  000AFA99  90                         nop 
  000AFA9A  90                         nop 
  000AFA9B  90                         nop 
  000AFA9C  90                         nop 
  000AFA9D  90                         nop 
  000AFA9E  90                         nop 
  000AFA9F  90                         nop 
  000AFAA0  8b 51 20                   mov edx, dword ptr [ecx + 0x20]
  000AFAA3  33 c0                      xor eax, eax
  000AFAA5  66 8b 81 56 02 00 00       mov ax, word ptr [ecx + 0x256]
  000AFAAC  8b 4c 24 04                mov ecx, dword ptr [esp + 4]
  000AFAB0  03 c2                      add eax, edx
  000AFAB2  33 d2                      xor edx, edx
  000AFAB4  8a 14 01                   mov dl, byte ptr [ecx + eax]
  000AFAB7  03 c8                      add ecx, eax
  000AFAB9  33 c0                      xor eax, eax
  000AFABB  8a 41 01                   mov al, byte ptr [ecx + 1]
  000AFABE  c1 e0 08                   shl eax, 8
  000AFAC1  03 c2                      add eax, edx
  000AFAC3  c2 04 00                   ret 4
  000AFAC6  90                         nop 
  000AFAC7  90                         nop 
  000AFAC8  90                         nop 
  000AFAC9  90                         nop 
  000AFACA  90                         nop 
  000AFACB  90                         nop 
  000AFACC  90                         nop 
  000AFACD  90                         nop 
  000AFACE  90                         nop 
  000AFACF  90                         nop 
  000AFAD0  8b 51 20                   mov edx, dword ptr [ecx + 0x20]
  000AFAD3  33 c0                      xor eax, eax
  000AFAD5  66 8b 81 56 02 00 00       mov ax, word ptr [ecx + 0x256]
  000AFADC  8b 4c 24 04                mov ecx, dword ptr [esp + 4]
  000AFAE0  03 c2                      add eax, edx
  000AFAE2  33 d2                      xor edx, edx
  000AFAE4  8a 54 01 02                mov dl, byte ptr [ecx + eax + 2]
  000AFAE8  03 c8                      add ecx, eax
  000AFAEA  33 c0                      xor eax, eax
  000AFAEC  8a 41 03                   mov al, byte ptr [ecx + 3]
  000AFAEF  c1 e0 08                   shl eax, 8
  000AFAF2  03 c2                      add eax, edx
  000AFAF4  33 d2                      xor edx, edx
  000AFAF6  8a 51 01                   mov dl, byte ptr [ecx + 1]
  000AFAF9  c1 e0 08                   shl eax, 8
  000AFAFC  03 c2                      add eax, edx
  000AFAFE  33 d2                      xor edx, edx
  000AFB00  8a 11                      mov dl, byte ptr [ecx]
  000AFB02  c1 e0 08                   shl eax, 8
  000AFB05  03 c2                      add eax, edx
  000AFB07  c2 04 00                   ret 4
  000AFB0A  90                         nop 
  000AFB0B  90                         nop 
  000AFB0C  90                         nop 
  000AFB0D  90                         nop 
  000AFB0E  90                         nop 
  000AFB0F  90                         nop 
  000AFB10  8b 44 24 04                mov eax, dword ptr [esp + 4]
  000AFB14  56                         push esi
  000AFB15  8d b0 40 00 00 80          lea esi, [eax - 0x7fffffc0]
  000AFB1B  83 fe 39                   cmp esi, 0x39
  000AFB1E  0f 87 a0 00 00 00          ja 0x100afbc4
  000AFB24  33 d2                      xor edx, edx
  000AFB26  8a 96 44 fc 0a 10          mov dl, byte ptr [esi + 0x100afc44]
  000AFB2C  ff 24 95 18 fc 0a 10       jmp dword ptr [edx*4 + 0x100afc18]
  000AFB33  e8 e8 c9 04 00             call 0x100fc520
  000AFB38  8b 74 24 0c                mov esi, dword ptr [esp + 0xc]
  000AFB3C  8b 40 04                   mov eax, dword ptr [eax + 4]
  000AFB3F  89 06                      mov dword ptr [esi], eax
  000AFB41  e8 aa c7 04 00             call 0x100fc2f0
  000AFB46  e9 9d 00 00 00             jmp 0x100afbe8
  000AFB4B  6a 01                      push 1
```

### G.2 GetActorIndex jumptable @0xAFC18 + first index bytes @0xAFC44

Source file: `out3/probe_afb24.md`

```text
bytes @rva 0xAFB20: a0 00 00 00 33 d2 8a 96 44 fc 0a 10 ff 24 95 18 fc 0a 10 e8 e8 c9 04 00 8b 74 24 0c 8b 40 04 89 06 e8 aa c7
jumptable @0xAFC18:
  case 0: VA 0x100afb33 rva 0xafb33
  case 1: VA 0x100afb8e rva 0xafb8e
  case 2: VA 0x100afb93 rva 0xafb93
  case 3: VA 0x100afb98 rva 0xafb98
  case 4: VA 0x100afb4b rva 0xafb4b
  case 5: VA 0x100afb54 rva 0xafb54
  case 6: VA 0x100afb5d rva 0xafb5d
  case 7: VA 0x100afb66 rva 0xafb66
  case 8: VA 0x100afb6f rva 0xafb6f
  case 9: VA 0x100afb78 rva 0xafb78
  case 10: VA 0x100afbc4 rva 0xafbc4
  case 11: VA 0x1010100 rva -0xefeff00
  case 12: VA 0x2020101 rva -0xdfdfeff
  case 13: VA 0x2020202 rva -0xdfdfdfe
  case 14: VA 0x3030303 rva -0xcfcfcfd
  case 15: VA 0xa0a0303 rva -0x5f5fcfd
index bytes @0xAFC44: 00 01 01 01 01 01 02 02 02 02 02 02 03 03 03 03
```

### G.3 Full 57 index bytes @0xAFC44 mapped esi -> reserved code -> case

Source file: `out3/probe_afc44.md`

```text
index bytes @rva 0xAFC44 (64 bytes):
00 01 01 01 01 01 02 02 02 02 02 02 03 03 03 03 03 03 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 0a 00 04 05 06 07 08 0a 0a 09 00 90 90 c6 81 5a 02

esi : code(0x7FFFFFC0+esi) : case
 0 : 0x7FFFFFC0 : 0
 1 : 0x7FFFFFC1 : 1
 2 : 0x7FFFFFC2 : 1
 3 : 0x7FFFFFC3 : 1
 4 : 0x7FFFFFC4 : 1
 5 : 0x7FFFFFC5 : 1
 6 : 0x7FFFFFC6 : 2
 7 : 0x7FFFFFC7 : 2
 8 : 0x7FFFFFC8 : 2
 9 : 0x7FFFFFC9 : 2
10 : 0x7FFFFFCA : 2
11 : 0x7FFFFFCB : 2
12 : 0x7FFFFFCC : 3
13 : 0x7FFFFFCD : 3
14 : 0x7FFFFFCE : 3
15 : 0x7FFFFFCF : 3
16 : 0x7FFFFFD0 : 3
17 : 0x7FFFFFD1 : 3
18 : 0x7FFFFFD2 : 10
19 : 0x7FFFFFD3 : 10
20 : 0x7FFFFFD4 : 10
21 : 0x7FFFFFD5 : 10
22 : 0x7FFFFFD6 : 10
23 : 0x7FFFFFD7 : 10
24 : 0x7FFFFFD8 : 10
25 : 0x7FFFFFD9 : 10
26 : 0x7FFFFFDA : 10
27 : 0x7FFFFFDB : 10
28 : 0x7FFFFFDC : 10
29 : 0x7FFFFFDD : 10
30 : 0x7FFFFFDE : 10
31 : 0x7FFFFFDF : 10
32 : 0x7FFFFFE0 : 10
33 : 0x7FFFFFE1 : 10
34 : 0x7FFFFFE2 : 10
35 : 0x7FFFFFE3 : 10
36 : 0x7FFFFFE4 : 10
37 : 0x7FFFFFE5 : 10
38 : 0x7FFFFFE6 : 10
39 : 0x7FFFFFE7 : 10
40 : 0x7FFFFFE8 : 10
41 : 0x7FFFFFE9 : 10
42 : 0x7FFFFFEA : 10
43 : 0x7FFFFFEB : 10
44 : 0x7FFFFFEC : 10
45 : 0x7FFFFFED : 10
46 : 0x7FFFFFEE : 10
47 : 0x7FFFFFEF : 10
48 : 0x7FFFFFF0 : 0
49 : 0x7FFFFFF1 : 4
50 : 0x7FFFFFF2 : 5
51 : 0x7FFFFFF3 : 6
52 : 0x7FFFFFF4 : 7
53 : 0x7FFFFFF5 : 8
54 : 0x7FFFFFF6 : 10
55 : 0x7FFFFFF7 : 10
56 : 0x7FFFFFF8 : 9
```

### G.4 GetActorIndex middle @0xAFB24..0xAFC18: all switch cases incl. the event-entity and party paths (disasm.py --rva 0xAFB24 --len 160)

Source file: `out3/d_afb24_full.md`

```text
  000AFB24  33 d2                      xor edx, edx
  000AFB26  8a 96 44 fc 0a 10          mov dl, byte ptr [esi + 0x100afc44]
  000AFB2C  ff 24 95 18 fc 0a 10       jmp dword ptr [edx*4 + 0x100afc18]
  000AFB33  e8 e8 c9 04 00             call 0x100fc520
  000AFB38  8b 74 24 0c                mov esi, dword ptr [esp + 0xc]
  000AFB3C  8b 40 04                   mov eax, dword ptr [eax + 4]
  000AFB3F  89 06                      mov dword ptr [esi], eax
  000AFB41  e8 aa c7 04 00             call 0x100fc2f0
  000AFB46  e9 9d 00 00 00             jmp 0x100afbe8
  000AFB4B  6a 01                      push 1
  000AFB4D  e8 9e ee ff ff             call 0x100ae9f0
  000AFB52  eb 4d                      jmp 0x100afba1
  000AFB54  6a 02                      push 2
  000AFB56  e8 95 ee ff ff             call 0x100ae9f0
  000AFB5B  eb 44                      jmp 0x100afba1
  000AFB5D  6a 03                      push 3
  000AFB5F  e8 8c ee ff ff             call 0x100ae9f0
  000AFB64  eb 3b                      jmp 0x100afba1
  000AFB66  6a 04                      push 4
  000AFB68  e8 83 ee ff ff             call 0x100ae9f0
  000AFB6D  eb 32                      jmp 0x100afba1
  000AFB6F  6a 05                      push 5
  000AFB71  e8 7a ee ff ff             call 0x100ae9f0
  000AFB76  eb 29                      jmp 0x100afba1
  000AFB78  8b 74 24 0c                mov esi, dword ptr [esp + 0xc]
  000AFB7C  8b 41 08                   mov eax, dword ptr [ecx + 8]
  000AFB7F  89 06                      mov dword ptr [esi], eax
  000AFB81  66 8b 51 02                mov dx, word ptr [ecx + 2]
  000AFB85  8b 4c 24 10                mov ecx, dword ptr [esp + 0x10]
  000AFB89  66 89 11                   mov word ptr [ecx], dx
  000AFB8C  eb 61                      jmp 0x100afbef
  000AFB8E  83 c0 40                   add eax, 0x40
  000AFB91  eb 08                      jmp 0x100afb9b
  000AFB93  83 c0 44                   add eax, 0x44
  000AFB96  eb 03                      jmp 0x100afb9b
  000AFB98  83 c0 48                   add eax, 0x48
  000AFB9B  50                         push eax
  000AFB9C  e8 5f 92 03 00             call 0x100e8e00
  000AFBA1  83 c4 04                   add esp, 4
  000AFBA4  85 c0                      test eax, eax
  000AFBA6  75 06                      jne 0x100afbae
  000AFBA8  32 c0                      xor al, al
  000AFBAA  5e                         pop esi
  000AFBAB  c2 0c 00                   ret 0xc
  000AFBAE  8b 74 24 0c                mov esi, dword ptr [esp + 0xc]
  000AFBB2  8b 48 14                   mov ecx, dword ptr [eax + 0x14]
  000AFBB5  89 0e                      mov dword ptr [esi], ecx
  000AFBB7  8b 4c 24 10                mov ecx, dword ptr [esp + 0x10]
  000AFBBB  66 8b 50 18                mov dx, word ptr [eax + 0x18]
  000AFBBF  66 89 11                   mov word ptr [ecx], dx
  000AFBC2  eb 2b                      jmp 0x100afbef
```

### G.5 GetActorIndex default tail @0xAFBC4: literal server id vs event-entity fallback + entity-table lookup (disasm.py --func 0xAFBC4)

Source file: `out3/d_afbc4.md`

```text
  000AFBC4  8b 74 24 0c                mov esi, dword ptr [esp + 0xc]
  000AFBC8  a9 00 00 00 ff             test eax, 0xff000000
  000AFBCD  75 12                      jne 0x100afbe1
  000AFBCF  8b 41 08                   mov eax, dword ptr [ecx + 8]
  000AFBD2  89 06                      mov dword ptr [esi], eax
  000AFBD4  66 8b 51 02                mov dx, word ptr [ecx + 2]
  000AFBD8  8b 4c 24 10                mov ecx, dword ptr [esp + 0x10]
  000AFBDC  66 89 11                   mov word ptr [ecx], dx
  000AFBDF  eb 0e                      jmp 0x100afbef
  000AFBE1  89 06                      mov dword ptr [esi], eax
  000AFBE3  25 ff 03 00 00             and eax, 0x3ff
  000AFBE8  8b 4c 24 10                mov ecx, dword ptr [esp + 0x10]
  000AFBEC  66 89 01                   mov word ptr [ecx], ax
  000AFBEF  33 c0                      xor eax, eax
  000AFBF1  66 8b 01                   mov ax, word ptr [ecx]
  000AFBF4  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  000AFBFB  85 c9                      test ecx, ecx
  000AFBFD  75 06                      jne 0x100afc05
  000AFBFF  32 c0                      xor al, al
  000AFC01  5e                         pop esi
  000AFC02  c2 0c 00                   ret 0xc
  000AFC05  8b 16                      mov edx, dword ptr [esi]
  000AFC07  52                         push edx
  000AFC08  e8 83 b7 fd ff             call 0x1008b390
  000AFC0D  85 c0                      test eax, eax
  000AFC0F  0f 95 c0                   setne al
  000AFC12  5e                         pop esi
  000AFC13  c2 0c 00                   ret 0xc
```

## H. 'Still running' predicates (0x52 to 0x55)

Backs E13.

### H.1 0x53 @0xB4E10 is-moving-action + adjacent start/stop variants (disasm.py --func 0xB4E10)

Source file: `out3/d_B4E10.md`

```text
; func 0xB4C15..0xB4EDC (711 bytes), callers: 0
  000B4C15  66 83 86 56 02 00 00 0f    add word ptr [esi + 0x256], 0xf
  000B4C1D  5f                         pop edi
  000B4C1E  5e                         pop esi
  000B4C1F  5b                         pop ebx
  000B4C20  83 c4 14                   add esp, 0x14
  000B4C23  c2 04 00                   ret 4
  000B4C26  90                         nop 
  000B4C27  90                         nop 
  000B4C28  90                         nop 
  000B4C29  90                         nop 
  000B4C2A  90                         nop 
  000B4C2B  90                         nop 
  000B4C2C  90                         nop 
  000B4C2D  90                         nop 
  000B4C2E  90                         nop 
  000B4C2F  90                         nop 
  000B4C30  83 ec 14                   sub esp, 0x14
  000B4C33  8d 44 24 00                lea eax, [esp]
  000B4C37  53                         push ebx
  000B4C38  56                         push esi
  000B4C39  57                         push edi
  000B4C3A  8b f9                      mov edi, ecx
  000B4C3C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B4C40  50                         push eax
  000B4C41  51                         push ecx
  000B4C42  6a 01                      push 1
  000B4C44  8b cf                      mov ecx, edi
  000B4C46  e8 85 ae ff ff             call 0x100afad0
  000B4C4B  50                         push eax
  000B4C4C  8b cf                      mov ecx, edi
  000B4C4E  e8 bd ae ff ff             call 0x100afb10
  000B4C53  3c 01                      cmp al, 1
  000B4C55  0f 85 ae 00 00 00          jne 0x100b4d09
  000B4C5B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4C5F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4C63  52                         push edx
  000B4C64  50                         push eax
  000B4C65  6a 05                      push 5
  000B4C67  8b cf                      mov ecx, edi
  000B4C69  e8 62 ae ff ff             call 0x100afad0
  000B4C6E  50                         push eax
  000B4C6F  8b cf                      mov ecx, edi
  000B4C71  e8 9a ae ff ff             call 0x100afb10
  000B4C76  3c 01                      cmp al, 1
  000B4C78  0f 85 8b 00 00 00          jne 0x100b4d09
  000B4C7E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4C82  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4C88  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  000B4C8F  85 c9                      test ecx, ecx
  000B4C91  74 76                      je 0x100b4d09
  000B4C93  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4C97  81 e2 ff ff 00 00          and edx, 0xffff
  000B4C9D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B4CA4  85 c0                      test eax, eax
  000B4CA6  74 61                      je 0x100b4d09
  000B4CA8  8b 51 74                   mov edx, dword ptr [ecx + 0x74]
  000B4CAB  8b 70 74                   mov esi, dword ptr [eax + 0x74]
  000B4CAE  8b 5c 24 18                mov ebx, dword ptr [esp + 0x18]
  000B4CB2  89 54 24 10                mov dword ptr [esp + 0x10], edx
  000B4CB6  8b 51 78                   mov edx, dword ptr [ecx + 0x78]
  000B4CB9  89 74 24 10                mov dword ptr [esp + 0x10], esi
  000B4CBD  8b 70 78                   mov esi, dword ptr [eax + 0x78]
  000B4CC0  3b d3                      cmp edx, ebx
  000B4CC2  75 45                      jne 0x100b4d09
  000B4CC4  3b 74 24 1c                cmp esi, dword ptr [esp + 0x1c]
  000B4CC8  75 3f                      jne 0x100b4d09
  000B4CCA  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B4CD0  c1 ea 09                   shr edx, 9
  000B4CD3  f6 c2 01                   test dl, 1
  000B4CD6  74 31                      je 0x100b4d09
  000B4CD8  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B4CDE  c1 ea 09                   shr edx, 9
  000B4CE1  f6 c2 01                   test dl, 1
  000B4CE4  74 23                      je 0x100b4d09
  000B4CE6  8b 80 a0 00 00 00          mov eax, dword ptr [eax + 0xa0]   ; ent.ActorPointer?
  000B4CEC  8b b1 a0 00 00 00          mov esi, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B4CF2  6a 00                      push 0
  000B4CF4  50                         push eax
  000B4CF5  8b 1e                      mov ebx, dword ptr [esi]
  000B4CF7  6a 09                      push 9
  000B4CF9  8b cf                      mov ecx, edi
  000B4CFB  e8 d0 ad ff ff             call 0x100afad0
  000B4D00  50                         push eax
  000B4D01  8b ce                      mov ecx, esi
  000B4D03  ff 93 98 02 00 00          call dword ptr [ebx + 0x298]
  000B4D09  66 83 87 56 02 00 00 0d    add word ptr [edi + 0x256], 0xd
  000B4D11  5f                         pop edi
  000B4D12  5e                         pop esi
  000B4D13  5b                         pop ebx
  000B4D14  83 c4 14                   add esp, 0x14
  000B4D17  c3                         ret 
  000B4D18  90                         nop 
  000B4D19  90                         nop 
  000B4D1A  90                         nop 
  000B4D1B  90                         nop 
  000B4D1C  90                         nop 
  000B4D1D  90                         nop 
  000B4D1E  90                         nop 
  000B4D1F  90                         nop 
  000B4D20  83 ec 14                   sub esp, 0x14
  000B4D23  8d 44 24 00                lea eax, [esp]
  000B4D27  53                         push ebx
  000B4D28  56                         push esi
  000B4D29  57                         push edi
  000B4D2A  8b f9                      mov edi, ecx
  000B4D2C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B4D30  50                         push eax
  000B4D31  51                         push ecx
  000B4D32  6a 01                      push 1
  000B4D34  8b cf                      mov ecx, edi
  000B4D36  e8 95 ad ff ff             call 0x100afad0
  000B4D3B  50                         push eax
  000B4D3C  8b cf                      mov ecx, edi
  000B4D3E  e8 cd ad ff ff             call 0x100afb10
  000B4D43  3c 01                      cmp al, 1
  000B4D45  0f 85 ac 00 00 00          jne 0x100b4df7
  000B4D4B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4D4F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4D53  52                         push edx
  000B4D54  50                         push eax
  000B4D55  6a 05                      push 5
  000B4D57  8b cf                      mov ecx, edi
  000B4D59  e8 72 ad ff ff             call 0x100afad0
  000B4D5E  50                         push eax
  000B4D5F  8b cf                      mov ecx, edi
  000B4D61  e8 aa ad ff ff             call 0x100afb10
  000B4D66  3c 01                      cmp al, 1
  000B4D68  0f 85 89 00 00 00          jne 0x100b4df7
  000B4D6E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4D72  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4D78  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  000B4D7F  85 c9                      test ecx, ecx
  000B4D81  74 74                      je 0x100b4df7
  000B4D83  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4D87  81 e2 ff ff 00 00          and edx, 0xffff
  000B4D8D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B4D94  85 c0                      test eax, eax
  000B4D96  74 5f                      je 0x100b4df7
  000B4D98  8b 51 74                   mov edx, dword ptr [ecx + 0x74]
  000B4D9B  8b 70 74                   mov esi, dword ptr [eax + 0x74]
  000B4D9E  8b 5c 24 18                mov ebx, dword ptr [esp + 0x18]
  000B4DA2  89 54 24 10                mov dword ptr [esp + 0x10], edx
  000B4DA6  8b 51 78                   mov edx, dword ptr [ecx + 0x78]
  000B4DA9  89 74 24 10                mov dword ptr [esp + 0x10], esi
  000B4DAD  8b 70 78                   mov esi, dword ptr [eax + 0x78]
  000B4DB0  3b d3                      cmp edx, ebx
  000B4DB2  75 43                      jne 0x100b4df7
  000B4DB4  3b 74 24 1c                cmp esi, dword ptr [esp + 0x1c]
  000B4DB8  75 3d                      jne 0x100b4df7
  000B4DBA  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B4DC0  c1 ea 09                   shr edx, 9
  000B4DC3  f6 c2 01                   test dl, 1
  000B4DC6  74 2f                      je 0x100b4df7
  000B4DC8  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B4DCE  c1 ea 09                   shr edx, 9
  000B4DD1  f6 c2 01                   test dl, 1
  000B4DD4  74 21                      je 0x100b4df7
  000B4DD6  8b 80 a0 00 00 00          mov eax, dword ptr [eax + 0xa0]   ; ent.ActorPointer?
  000B4DDC  8b b1 a0 00 00 00          mov esi, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B4DE2  50                         push eax
  000B4DE3  6a 09                      push 9
  000B4DE5  8b 1e                      mov ebx, dword ptr [esi]
  000B4DE7  8b cf                      mov ecx, edi
  000B4DE9  e8 e2 ac ff ff             call 0x100afad0
  000B4DEE  50                         push eax
  000B4DEF  8b ce                      mov ecx, esi
  000B4DF1  ff 93 9c 02 00 00          call dword ptr [ebx + 0x29c]
  000B4DF7  66 83 87 56 02 00 00 0d    add word ptr [edi + 0x256], 0xd
  000B4DFF  5f                         pop edi
  000B4E00  5e                         pop esi
  000B4E01  5b                         pop ebx
  000B4E02  83 c4 14                   add esp, 0x14
  000B4E05  c3                         ret 
  000B4E06  90                         nop 
  000B4E07  90                         nop 
  000B4E08  90                         nop 
  000B4E09  90                         nop 
  000B4E0A  90                         nop 
  000B4E0B  90                         nop 
  000B4E0C  90                         nop 
  000B4E0D  90                         nop 
  000B4E0E  90                         nop 
  000B4E0F  90                         nop 
  000B4E10  6a 00                      push 0
  000B4E12  6a 00                      push 0
  000B4E14  e8 07 00 00 00             call 0x100b4e20
  000B4E19  c3                         ret 
  000B4E1A  90                         nop 
  000B4E1B  90                         nop 
  000B4E1C  90                         nop 
  000B4E1D  90                         nop 
  000B4E1E  90                         nop 
  000B4E1F  90                         nop 
  000B4E20  83 ec 0c                   sub esp, 0xc
  000B4E23  8d 44 24 00                lea eax, [esp]
  000B4E27  55                         push ebp
  000B4E28  56                         push esi
  000B4E29  8b f1                      mov esi, ecx
  000B4E2B  57                         push edi
  000B4E2C  8d 4c 24 10                lea ecx, [esp + 0x10]
  000B4E30  50                         push eax
  000B4E31  51                         push ecx
  000B4E32  6a 01                      push 1
  000B4E34  8b ce                      mov ecx, esi
  000B4E36  e8 95 ac ff ff             call 0x100afad0
  000B4E3B  50                         push eax
  000B4E3C  8b ce                      mov ecx, esi
  000B4E3E  e8 cd ac ff ff             call 0x100afb10
  000B4E43  3c 01                      cmp al, 1
  000B4E45  0f 85 b7 00 00 00          jne 0x100b4f02
  000B4E4B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4E4F  8d 44 24 14                lea eax, [esp + 0x14]
  000B4E53  52                         push edx
  000B4E54  50                         push eax
  000B4E55  6a 05                      push 5
  000B4E57  8b ce                      mov ecx, esi
  000B4E59  e8 72 ac ff ff             call 0x100afad0
  000B4E5E  50                         push eax
  000B4E5F  8b ce                      mov ecx, esi
  000B4E61  e8 aa ac ff ff             call 0x100afb10
  000B4E66  3c 01                      cmp al, 1
  000B4E68  0f 85 94 00 00 00          jne 0x100b4f02
  000B4E6E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4E72  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4E78  8b 2c 8d 30 0b 48 10       mov ebp, dword ptr [ecx*4 + 0x10480b30]
  000B4E7F  85 ed                      test ebp, ebp
  000B4E81  74 7f                      je 0x100b4f02
  000B4E83  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4E87  81 e2 ff ff 00 00          and edx, 0xffff
  000B4E8D  8b 3c 95 30 0b 48 10       mov edi, dword ptr [edx*4 + 0x10480b30]
  000B4E94  85 ff                      test edi, edi
  000B4E96  74 6a                      je 0x100b4f02
  000B4E98  8b 85 20 01 00 00          mov eax, dword ptr [ebp + 0x120]   ; ent.RenderFlags0?
  000B4E9E  c1 e8 09                   shr eax, 9
  000B4EA1  a8 01                      test al, 1
  000B4EA3  74 5d                      je 0x100b4f02
  000B4EA5  8b 8f 20 01 00 00          mov ecx, dword ptr [edi + 0x120]   ; ent.RenderFlags0?
  000B4EAB  c1 e9 09                   shr ecx, 9
  000B4EAE  f6 c1 01                   test cl, 1
  000B4EB1  74 4f                      je 0x100b4f02
  000B4EB3  6a 09                      push 9
  000B4EB5  8b ce                      mov ecx, esi
  000B4EB7  e8 14 ac ff ff             call 0x100afad0
  000B4EBC  8b 8d a0 00 00 00          mov ecx, dword ptr [ebp + 0xa0]   ; ent.ActorPointer?
  000B4EC2  8b bf a0 00 00 00          mov edi, dword ptr [edi + 0xa0]   ; ent.ActorPointer?
  000B4EC8  8a 54 24 20                mov dl, byte ptr [esp + 0x20]   ; pkt(hdr) status?
  000B4ECC  57                         push edi
  000B4ECD  84 d2                      test dl, dl
  000B4ECF  8b 11                      mov edx, dword ptr [ecx]
  000B4ED1  50                         push eax
  000B4ED2  74 08                      je 0x100b4edc
  000B4ED4  ff 92 ac 02 00 00          call dword ptr [edx + 0x2ac]
  000B4EDA  eb 06                      jmp 0x100b4ee2
```

### H.2 0x54 @0xB5100 zone is-moving-action via [zoneObj->vt+0x20] (disasm.py --func 0xB5100)

Source file: `out3/d_B5100.md`

```text
; func 0xB4F02..0xB51EE (748 bytes), callers: 0
  000B4F02  8a 44 24 1c                mov al, byte ptr [esp + 0x1c]   ; pkt body status?
  000B4F06  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B4F0E  88 86 5a 02 00 00          mov byte ptr [esi + 0x25a], al
  000B4F14  5f                         pop edi
  000B4F15  5e                         pop esi
  000B4F16  b0 01                      mov al, 1
  000B4F18  5d                         pop ebp
  000B4F19  83 c4 0c                   add esp, 0xc
  000B4F1C  c2 08 00                   ret 8
  000B4F1F  90                         nop 
  000B4F20  83 ec 14                   sub esp, 0x14
  000B4F23  8d 44 24 00                lea eax, [esp]
  000B4F27  53                         push ebx
  000B4F28  56                         push esi
  000B4F29  8b f1                      mov esi, ecx
  000B4F2B  57                         push edi
  000B4F2C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B4F30  50                         push eax
  000B4F31  51                         push ecx
  000B4F32  6a 01                      push 1
  000B4F34  8b ce                      mov ecx, esi
  000B4F36  e8 95 ab ff ff             call 0x100afad0
  000B4F3B  50                         push eax
  000B4F3C  8b ce                      mov ecx, esi
  000B4F3E  e8 cd ab ff ff             call 0x100afb10
  000B4F43  3c 01                      cmp al, 1
  000B4F45  0f 85 b0 00 00 00          jne 0x100b4ffb
  000B4F4B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4F4F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4F53  52                         push edx
  000B4F54  50                         push eax
  000B4F55  6a 05                      push 5
  000B4F57  8b ce                      mov ecx, esi
  000B4F59  e8 72 ab ff ff             call 0x100afad0
  000B4F5E  50                         push eax
  000B4F5F  8b ce                      mov ecx, esi
  000B4F61  e8 aa ab ff ff             call 0x100afb10
  000B4F66  3c 01                      cmp al, 1
  000B4F68  0f 85 8d 00 00 00          jne 0x100b4ffb
  000B4F6E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4F72  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4F78  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  000B4F7F  85 c9                      test ecx, ecx
  000B4F81  74 78                      je 0x100b4ffb
  000B4F83  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4F87  81 e2 ff ff 00 00          and edx, 0xffff
  000B4F8D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B4F94  85 c0                      test eax, eax
  000B4F96  74 63                      je 0x100b4ffb
  000B4F98  8b 51 74                   mov edx, dword ptr [ecx + 0x74]
  000B4F9B  8b 78 74                   mov edi, dword ptr [eax + 0x74]
  000B4F9E  8b 5c 24 18                mov ebx, dword ptr [esp + 0x18]
  000B4FA2  89 54 24 10                mov dword ptr [esp + 0x10], edx
  000B4FA6  8b 51 78                   mov edx, dword ptr [ecx + 0x78]
  000B4FA9  89 7c 24 10                mov dword ptr [esp + 0x10], edi
  000B4FAD  8b 78 78                   mov edi, dword ptr [eax + 0x78]
  000B4FB0  3b d3                      cmp edx, ebx
  000B4FB2  75 47                      jne 0x100b4ffb
  000B4FB4  3b 7c 24 1c                cmp edi, dword ptr [esp + 0x1c]
  000B4FB8  75 41                      jne 0x100b4ffb
  000B4FBA  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B4FC0  c1 ea 09                   shr edx, 9
  000B4FC3  f6 c2 01                   test dl, 1
  000B4FC6  74 33                      je 0x100b4ffb
  000B4FC8  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B4FCE  c1 ea 09                   shr edx, 9
  000B4FD1  f6 c2 01                   test dl, 1
  000B4FD4  74 25                      je 0x100b4ffb
  000B4FD6  8b 80 a0 00 00 00          mov eax, dword ptr [eax + 0xa0]   ; ent.ActorPointer?
  000B4FDC  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B4FE2  8b 3d 24 a0 62 10          mov edi, dword ptr [0x1062a024]
  000B4FE8  50                         push eax
  000B4FE9  51                         push ecx
  000B4FEA  6a 09                      push 9
  000B4FEC  8b 1f                      mov ebx, dword ptr [edi]
  000B4FEE  8b ce                      mov ecx, esi
  000B4FF0  e8 db aa ff ff             call 0x100afad0
  000B4FF5  50                         push eax
  000B4FF6  8b cf                      mov ecx, edi
  000B4FF8  ff 53 18                   call dword ptr [ebx + 0x18]
  000B4FFB  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B5003  5f                         pop edi
  000B5004  5e                         pop esi
  000B5005  5b                         pop ebx
  000B5006  83 c4 14                   add esp, 0x14
  000B5009  c3                         ret 
  000B500A  90                         nop 
  000B500B  90                         nop 
  000B500C  90                         nop 
  000B500D  90                         nop 
  000B500E  90                         nop 
  000B500F  90                         nop 
  000B5010  83 ec 14                   sub esp, 0x14
  000B5013  8d 44 24 00                lea eax, [esp]
  000B5017  53                         push ebx
  000B5018  56                         push esi
  000B5019  8b f1                      mov esi, ecx
  000B501B  57                         push edi
  000B501C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B5020  50                         push eax
  000B5021  51                         push ecx
  000B5022  6a 01                      push 1
  000B5024  8b ce                      mov ecx, esi
  000B5026  e8 a5 aa ff ff             call 0x100afad0
  000B502B  50                         push eax
  000B502C  8b ce                      mov ecx, esi
  000B502E  e8 dd aa ff ff             call 0x100afb10
  000B5033  3c 01                      cmp al, 1
  000B5035  0f 85 b0 00 00 00          jne 0x100b50eb
  000B503B  8d 54 24 10                lea edx, [esp + 0x10]
  000B503F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B5043  52                         push edx
  000B5044  50                         push eax
  000B5045  6a 05                      push 5
  000B5047  8b ce                      mov ecx, esi
  000B5049  e8 82 aa ff ff             call 0x100afad0
  000B504E  50                         push eax
  000B504F  8b ce                      mov ecx, esi
  000B5051  e8 ba aa ff ff             call 0x100afb10
  000B5056  3c 01                      cmp al, 1
  000B5058  0f 85 8d 00 00 00          jne 0x100b50eb
  000B505E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B5062  81 e1 ff ff 00 00          and ecx, 0xffff
  000B5068  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  000B506F  85 c9                      test ecx, ecx
  000B5071  74 78                      je 0x100b50eb
  000B5073  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B5077  81 e2 ff ff 00 00          and edx, 0xffff
  000B507D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B5084  85 c0                      test eax, eax
  000B5086  74 63                      je 0x100b50eb
  000B5088  8b 51 74                   mov edx, dword ptr [ecx + 0x74]
  000B508B  8b 78 74                   mov edi, dword ptr [eax + 0x74]
  000B508E  8b 5c 24 18                mov ebx, dword ptr [esp + 0x18]
  000B5092  89 54 24 10                mov dword ptr [esp + 0x10], edx
  000B5096  8b 51 78                   mov edx, dword ptr [ecx + 0x78]
  000B5099  89 7c 24 10                mov dword ptr [esp + 0x10], edi
  000B509D  8b 78 78                   mov edi, dword ptr [eax + 0x78]
  000B50A0  3b d3                      cmp edx, ebx
  000B50A2  75 47                      jne 0x100b50eb
  000B50A4  3b 7c 24 1c                cmp edi, dword ptr [esp + 0x1c]
  000B50A8  75 41                      jne 0x100b50eb
  000B50AA  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B50B0  c1 ea 09                   shr edx, 9
  000B50B3  f6 c2 01                   test dl, 1
  000B50B6  74 33                      je 0x100b50eb
  000B50B8  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B50BE  c1 ea 09                   shr edx, 9
  000B50C1  f6 c2 01                   test dl, 1
  000B50C4  74 25                      je 0x100b50eb
  000B50C6  8b 80 a0 00 00 00          mov eax, dword ptr [eax + 0xa0]   ; ent.ActorPointer?
  000B50CC  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B50D2  8b 3d 24 a0 62 10          mov edi, dword ptr [0x1062a024]
  000B50D8  50                         push eax
  000B50D9  51                         push ecx
  000B50DA  6a 09                      push 9
  000B50DC  8b 1f                      mov ebx, dword ptr [edi]
  000B50DE  8b ce                      mov ecx, esi
  000B50E0  e8 eb a9 ff ff             call 0x100afad0
  000B50E5  50                         push eax
  000B50E6  8b cf                      mov ecx, edi
  000B50E8  ff 53 1c                   call dword ptr [ebx + 0x1c]
  000B50EB  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B50F3  5f                         pop edi
  000B50F4  5e                         pop esi
  000B50F5  5b                         pop ebx
  000B50F6  83 c4 14                   add esp, 0x14
  000B50F9  c3                         ret 
  000B50FA  90                         nop 
  000B50FB  90                         nop 
  000B50FC  90                         nop 
  000B50FD  90                         nop 
  000B50FE  90                         nop 
  000B50FF  90                         nop 
  000B5100  83 ec 14                   sub esp, 0x14
  000B5103  8d 44 24 00                lea eax, [esp]
  000B5107  53                         push ebx
  000B5108  56                         push esi
  000B5109  8b d9                      mov ebx, ecx
  000B510B  57                         push edi
  000B510C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B5110  50                         push eax
  000B5111  51                         push ecx
  000B5112  6a 01                      push 1
  000B5114  8b cb                      mov ecx, ebx
  000B5116  e8 b5 a9 ff ff             call 0x100afad0
  000B511B  50                         push eax
  000B511C  8b cb                      mov ecx, ebx
  000B511E  e8 ed a9 ff ff             call 0x100afb10
  000B5123  3c 01                      cmp al, 1
  000B5125  0f 85 c3 00 00 00          jne 0x100b51ee
  000B512B  8d 54 24 10                lea edx, [esp + 0x10]
  000B512F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B5133  52                         push edx
  000B5134  50                         push eax
  000B5135  6a 05                      push 5
  000B5137  8b cb                      mov ecx, ebx
  000B5139  e8 92 a9 ff ff             call 0x100afad0
  000B513E  50                         push eax
  000B513F  8b cb                      mov ecx, ebx
  000B5141  e8 ca a9 ff ff             call 0x100afb10
  000B5146  3c 01                      cmp al, 1
  000B5148  0f 85 a0 00 00 00          jne 0x100b51ee
  000B514E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B5152  81 e1 ff ff 00 00          and ecx, 0xffff
  000B5158  8b 3c 8d 30 0b 48 10       mov edi, dword ptr [ecx*4 + 0x10480b30]
  000B515F  85 ff                      test edi, edi
  000B5161  0f 84 87 00 00 00          je 0x100b51ee
  000B5167  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B516B  81 e2 ff ff 00 00          and edx, 0xffff
  000B5171  8b 34 95 30 0b 48 10       mov esi, dword ptr [edx*4 + 0x10480b30]
  000B5178  85 f6                      test esi, esi
  000B517A  74 72                      je 0x100b51ee
  000B517C  8b 47 74                   mov eax, dword ptr [edi + 0x74]
  000B517F  8b 4e 74                   mov ecx, dword ptr [esi + 0x74]
  000B5182  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000B5186  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000B518A  8b 47 78                   mov eax, dword ptr [edi + 0x78]
  000B518D  89 4c 24 10                mov dword ptr [esp + 0x10], ecx
  000B5191  8b 4e 78                   mov ecx, dword ptr [esi + 0x78]
  000B5194  3b c2                      cmp eax, edx
  000B5196  75 56                      jne 0x100b51ee
  000B5198  3b 4c 24 1c                cmp ecx, dword ptr [esp + 0x1c]
  000B519C  75 50                      jne 0x100b51ee
  000B519E  8b 97 20 01 00 00          mov edx, dword ptr [edi + 0x120]   ; ent.RenderFlags0?
  000B51A4  c1 ea 09                   shr edx, 9
  000B51A7  f6 c2 01                   test dl, 1
  000B51AA  74 42                      je 0x100b51ee
  000B51AC  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  000B51B2  c1 e8 09                   shr eax, 9
  000B51B5  a8 01                      test al, 1
  000B51B7  74 35                      je 0x100b51ee
  000B51B9  6a 09                      push 9
  000B51BB  8b cb                      mov ecx, ebx
  000B51BD  e8 0e a9 ff ff             call 0x100afad0
  000B51C2  8b b6 a0 00 00 00          mov esi, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  000B51C8  8b 0d 24 a0 62 10          mov ecx, dword ptr [0x1062a024]
  000B51CE  8b bf a0 00 00 00          mov edi, dword ptr [edi + 0xa0]   ; ent.ActorPointer?
  000B51D4  56                         push esi
  000B51D5  8b 11                      mov edx, dword ptr [ecx]
  000B51D7  57                         push edi
  000B51D8  50                         push eax
  000B51D9  ff 52 20                   call dword ptr [edx + 0x20]
  000B51DC  84 c0                      test al, al
  000B51DE  74 0e                      je 0x100b51ee
  000B51E0  5f                         pop edi
  000B51E1  c6 83 5a 02 00 00 01       mov byte ptr [ebx + 0x25a], 1
  000B51E8  5e                         pop esi
  000B51E9  5b                         pop ebx
  000B51EA  83 c4 14                   add esp, 0x14
  000B51ED  c3                         ret 
```

### H.3 0x55 @0xB4960 is-moving-scheduler via 0x62EE0 (disasm.py --func 0xB4960)

Source file: `out3/d_B4960.md`

```text
; func 0xB4886..0xB4C15 (911 bytes), callers: 0
  000B4886  8b ff                      mov edi, edi
  000B4888  a1 46 0b 10 c6             mov eax, dword ptr [0xc6100b46]
  000B488D  46                         inc esi
  000B488E  0b 10                      or edx, dword ptr [eax]
  000B4890  ef                         out dx, eax
  000B4891  46                         inc esi
  000B4892  0b 10                      or edx, dword ptr [eax]
  000B4894  14 47                      adc al, 0x47
  000B4896  0b 10                      or edx, dword ptr [eax]
  000B4898  39 47 0b                   cmp dword ptr [edi + 0xb], eax
  000B489B  10 5e 47                   adc byte ptr [esi + 0x47], bl
  000B489E  0b 10                      or edx, dword ptr [eax]
  000B48A0  83 47 0b 10                add dword ptr [edi + 0xb], 0x10
  000B48A4  a8 47                      test al, 0x47
  000B48A6  0b 10                      or edx, dword ptr [eax]
  000B48A8  cd 47                      int 0x47
  000B48AA  0b 10                      or edx, dword ptr [eax]
  000B48AC  f2 47                      inc edi
  000B48AE  0b 10                      or edx, dword ptr [eax]
  000B48B0  72 48                      jb 0x100b48fa
  000B48B2  0b 10                      or edx, dword ptr [eax]
  000B48B4  72 48                      jb 0x100b48fe
  000B48B6  0b 10                      or edx, dword ptr [eax]
  000B48B8  72 48                      jb 0x100b4902
  000B48BA  0b 10                      or edx, dword ptr [eax]
  000B48BC  72 48                      jb 0x100b4906
  000B48BE  0b 10                      or edx, dword ptr [eax]
  000B48C0  72 48                      jb 0x100b490a
  000B48C2  0b 10                      or edx, dword ptr [eax]
  000B48C4  72 48                      jb 0x100b490e
  000B48C6  0b 10                      or edx, dword ptr [eax]
  000B48C8  17                         pop ss
  000B48C9  48                         dec eax
  000B48CA  0b 10                      or edx, dword ptr [eax]
  000B48CC  3c 48                      cmp al, 0x48
  000B48CE  0b 10                      or edx, dword ptr [eax]
  000B48D0  61                         popal 
  000B48D1  48                         dec eax
  000B48D2  0b 10                      or edx, dword ptr [eax]
  000B48D4  90                         nop 
  000B48D5  90                         nop 
  000B48D6  90                         nop 
  000B48D7  90                         nop 
  000B48D8  90                         nop 
  000B48D9  90                         nop 
  000B48DA  90                         nop 
  000B48DB  90                         nop 
  000B48DC  90                         nop 
  000B48DD  90                         nop 
  000B48DE  90                         nop 
  000B48DF  90                         nop 
  000B48E0  68 f0 77 00 00             push 0x77f0
  000B48E5  e8 f6 00 00 00             call 0x100b49e0
  000B48EA  c3                         ret 
  000B48EB  90                         nop 
  000B48EC  90                         nop 
  000B48ED  90                         nop 
  000B48EE  90                         nop 
  000B48EF  90                         nop 
  000B48F0  68 94 13 00 00             push 0x1394
  000B48F5  e8 e6 00 00 00             call 0x100b49e0
  000B48FA  c3                         ret 
  000B48FB  90                         nop 
  000B48FC  90                         nop 
  000B48FD  90                         nop 
  000B48FE  90                         nop 
  000B48FF  90                         nop 
  000B4900  68 ef c7 00 00             push 0xc7ef
  000B4905  e8 d6 00 00 00             call 0x100b49e0
  000B490A  c3                         ret 
  000B490B  90                         nop 
  000B490C  90                         nop 
  000B490D  90                         nop 
  000B490E  90                         nop 
  000B490F  90                         nop 
  000B4910  68 6d dd 00 00             push 0xdd6d
  000B4915  e8 c6 00 00 00             call 0x100b49e0
  000B491A  c3                         ret 
  000B491B  90                         nop 
  000B491C  90                         nop 
  000B491D  90                         nop 
  000B491E  90                         nop 
  000B491F  90                         nop 
  000B4920  68 1b 07 01 00             push 0x1071b
  000B4925  e8 b6 00 00 00             call 0x100b49e0
  000B492A  c3                         ret 
  000B492B  90                         nop 
  000B492C  90                         nop 
  000B492D  90                         nop 
  000B492E  90                         nop 
  000B492F  90                         nop 
  000B4930  68 23 13 01 00             push 0x11323
  000B4935  e8 a6 00 00 00             call 0x100b49e0
  000B493A  c3                         ret 
  000B493B  90                         nop 
  000B493C  90                         nop 
  000B493D  90                         nop 
  000B493E  90                         nop 
  000B493F  90                         nop 
  000B4940  68 23 14 01 00             push 0x11423
  000B4945  e8 96 00 00 00             call 0x100b49e0
  000B494A  c3                         ret 
  000B494B  90                         nop 
  000B494C  90                         nop 
  000B494D  90                         nop 
  000B494E  90                         nop 
  000B494F  90                         nop 
  000B4950  68 31 90 01 00             push 0x19031
  000B4955  e8 86 00 00 00             call 0x100b49e0
  000B495A  c3                         ret 
  000B495B  90                         nop 
  000B495C  90                         nop 
  000B495D  90                         nop 
  000B495E  90                         nop 
  000B495F  90                         nop 
  000B4960  68 f0 77 00 00             push 0x77f0
  000B4965  e8 96 01 00 00             call 0x100b4b00
  000B496A  c3                         ret 
  000B496B  90                         nop 
  000B496C  90                         nop 
  000B496D  90                         nop 
  000B496E  90                         nop 
  000B496F  90                         nop 
  000B4970  68 94 13 00 00             push 0x1394
  000B4975  e8 86 01 00 00             call 0x100b4b00
  000B497A  c3                         ret 
  000B497B  90                         nop 
  000B497C  90                         nop 
  000B497D  90                         nop 
  000B497E  90                         nop 
  000B497F  90                         nop 
  000B4980  68 ef c7 00 00             push 0xc7ef
  000B4985  e8 76 01 00 00             call 0x100b4b00
  000B498A  c3                         ret 
  000B498B  90                         nop 
  000B498C  90                         nop 
  000B498D  90                         nop 
  000B498E  90                         nop 
  000B498F  90                         nop 
  000B4990  68 6d dd 00 00             push 0xdd6d
  000B4995  e8 66 01 00 00             call 0x100b4b00
  000B499A  c3                         ret 
  000B499B  90                         nop 
  000B499C  90                         nop 
  000B499D  90                         nop 
  000B499E  90                         nop 
  000B499F  90                         nop 
  000B49A0  68 1b 07 01 00             push 0x1071b
  000B49A5  e8 56 01 00 00             call 0x100b4b00
  000B49AA  c3                         ret 
  000B49AB  90                         nop 
  000B49AC  90                         nop 
  000B49AD  90                         nop 
  000B49AE  90                         nop 
  000B49AF  90                         nop 
  000B49B0  68 23 13 01 00             push 0x11323
  000B49B5  e8 46 01 00 00             call 0x100b4b00
  000B49BA  c3                         ret 
  000B49BB  90                         nop 
  000B49BC  90                         nop 
  000B49BD  90                         nop 
  000B49BE  90                         nop 
  000B49BF  90                         nop 
  000B49C0  68 23 14 01 00             push 0x11423
  000B49C5  e8 36 01 00 00             call 0x100b4b00
  000B49CA  c3                         ret 
  000B49CB  90                         nop 
  000B49CC  90                         nop 
  000B49CD  90                         nop 
  000B49CE  90                         nop 
  000B49CF  90                         nop 
  000B49D0  68 31 90 01 00             push 0x19031
  000B49D5  e8 26 01 00 00             call 0x100b4b00
  000B49DA  c3                         ret 
  000B49DB  90                         nop 
  000B49DC  90                         nop 
  000B49DD  90                         nop 
  000B49DE  90                         nop 
  000B49DF  90                         nop 
  000B49E0  83 ec 14                   sub esp, 0x14
  000B49E3  8d 44 24 00                lea eax, [esp]
  000B49E7  53                         push ebx
  000B49E8  56                         push esi
  000B49E9  8b d9                      mov ebx, ecx
  000B49EB  57                         push edi
  000B49EC  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B49F0  50                         push eax
  000B49F1  51                         push ecx
  000B49F2  6a 03                      push 3
  000B49F4  8b cb                      mov ecx, ebx
  000B49F6  e8 d5 b0 ff ff             call 0x100afad0
  000B49FB  50                         push eax
  000B49FC  8b cb                      mov ecx, ebx
  000B49FE  e8 0d b1 ff ff             call 0x100afb10
  000B4A03  3c 01                      cmp al, 1
  000B4A05  0f 85 d6 00 00 00          jne 0x100b4ae1
  000B4A0B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4A0F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4A13  52                         push edx
  000B4A14  50                         push eax
  000B4A15  6a 07                      push 7
  000B4A17  8b cb                      mov ecx, ebx
  000B4A19  e8 b2 b0 ff ff             call 0x100afad0
  000B4A1E  50                         push eax
  000B4A1F  8b cb                      mov ecx, ebx
  000B4A21  e8 ea b0 ff ff             call 0x100afb10
  000B4A26  3c 01                      cmp al, 1
  000B4A28  0f 85 b3 00 00 00          jne 0x100b4ae1
  000B4A2E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4A32  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4A38  8b 3c 8d 30 0b 48 10       mov edi, dword ptr [ecx*4 + 0x10480b30]
  000B4A3F  85 ff                      test edi, edi
  000B4A41  0f 84 9a 00 00 00          je 0x100b4ae1
  000B4A47  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4A4B  81 e2 ff ff 00 00          and edx, 0xffff
  000B4A51  8b 34 95 30 0b 48 10       mov esi, dword ptr [edx*4 + 0x10480b30]
  000B4A58  85 f6                      test esi, esi
  000B4A5A  0f 84 81 00 00 00          je 0x100b4ae1
  000B4A60  8b 47 74                   mov eax, dword ptr [edi + 0x74]
  000B4A63  8b 4e 74                   mov ecx, dword ptr [esi + 0x74]
  000B4A66  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000B4A6A  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000B4A6E  8b 47 78                   mov eax, dword ptr [edi + 0x78]
  000B4A71  89 4c 24 10                mov dword ptr [esp + 0x10], ecx
  000B4A75  8b 4e 78                   mov ecx, dword ptr [esi + 0x78]
  000B4A78  3b c2                      cmp eax, edx
  000B4A7A  75 65                      jne 0x100b4ae1
  000B4A7C  3b 4c 24 1c                cmp ecx, dword ptr [esp + 0x1c]
  000B4A80  75 5f                      jne 0x100b4ae1
  000B4A82  8b 97 20 01 00 00          mov edx, dword ptr [edi + 0x120]   ; ent.RenderFlags0?
  000B4A88  c1 ea 09                   shr edx, 9
  000B4A8B  f6 c2 01                   test dl, 1
  000B4A8E  74 51                      je 0x100b4ae1
  000B4A90  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  000B4A96  c1 e8 09                   shr eax, 9
  000B4A99  a8 01                      test al, 1
  000B4A9B  74 44                      je 0x100b4ae1
  000B4A9D  55                         push ebp
  000B4A9E  6a 0b                      push 0xb
  000B4AA0  8b cb                      mov ecx, ebx
  000B4AA2  e8 29 b0 ff ff             call 0x100afad0
  000B4AA7  8b bf a0 00 00 00          mov edi, dword ptr [edi + 0xa0]   ; ent.ActorPointer?
  000B4AAD  8b b6 a0 00 00 00          mov esi, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  000B4AB3  6a 01                      push 1
  000B4AB5  8b cb                      mov ecx, ebx
  000B4AB7  8b e8                      mov ebp, eax
  000B4AB9  e8 02 aa ff ff             call 0x100af4c0
  000B4ABE  8b 54 24 28                mov edx, dword ptr [esp + 0x28]
  000B4AC2  81 fa f0 77 00 00          cmp edx, 0x77f0
  000B4AC8  75 08                      jne 0x100b4ad2
  000B4ACA  50                         push eax
  000B4ACB  8b cb                      mov ecx, ebx
  000B4ACD  e8 8e f8 ff ff             call 0x100b4360
  000B4AD2  56                         push esi
  000B4AD3  57                         push edi
  000B4AD4  03 c2                      add eax, edx
  000B4AD6  55                         push ebp
  000B4AD7  50                         push eax
  000B4AD8  e8 b3 e3 fa ff             call 0x10062e90
  000B4ADD  83 c4 10                   add esp, 0x10
  000B4AE0  5d                         pop ebp
  000B4AE1  66 83 83 56 02 00 00 0f    add word ptr [ebx + 0x256], 0xf
  000B4AE9  5f                         pop edi
  000B4AEA  5e                         pop esi
  000B4AEB  5b                         pop ebx
  000B4AEC  83 c4 14                   add esp, 0x14
  000B4AEF  c2 04 00                   ret 4
  000B4AF2  90                         nop 
  000B4AF3  90                         nop 
  000B4AF4  90                         nop 
  000B4AF5  90                         nop 
  000B4AF6  90                         nop 
  000B4AF7  90                         nop 
  000B4AF8  90                         nop 
  000B4AF9  90                         nop 
  000B4AFA  90                         nop 
  000B4AFB  90                         nop 
  000B4AFC  90                         nop 
  000B4AFD  90                         nop 
  000B4AFE  90                         nop 
  000B4AFF  90                         nop 
  000B4B00  83 ec 14                   sub esp, 0x14
  000B4B03  8d 44 24 00                lea eax, [esp]
  000B4B07  53                         push ebx
  000B4B08  56                         push esi
  000B4B09  8b f1                      mov esi, ecx
  000B4B0B  57                         push edi
  000B4B0C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B4B10  50                         push eax
  000B4B11  51                         push ecx
  000B4B12  6a 03                      push 3
  000B4B14  8b ce                      mov ecx, esi
  000B4B16  e8 b5 af ff ff             call 0x100afad0
  000B4B1B  50                         push eax
  000B4B1C  8b ce                      mov ecx, esi
  000B4B1E  e8 ed af ff ff             call 0x100afb10
  000B4B23  3c 01                      cmp al, 1
  000B4B25  0f 85 ea 00 00 00          jne 0x100b4c15
  000B4B2B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4B2F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4B33  52                         push edx
  000B4B34  50                         push eax
  000B4B35  6a 07                      push 7
  000B4B37  8b ce                      mov ecx, esi
  000B4B39  e8 92 af ff ff             call 0x100afad0
  000B4B3E  50                         push eax
  000B4B3F  8b ce                      mov ecx, esi
  000B4B41  e8 ca af ff ff             call 0x100afb10
  000B4B46  3c 01                      cmp al, 1
  000B4B48  0f 85 c7 00 00 00          jne 0x100b4c15
  000B4B4E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4B52  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4B58  8b 1c 8d 30 0b 48 10       mov ebx, dword ptr [ecx*4 + 0x10480b30]
  000B4B5F  85 db                      test ebx, ebx
  000B4B61  0f 84 ae 00 00 00          je 0x100b4c15
  000B4B67  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4B6B  81 e2 ff ff 00 00          and edx, 0xffff
  000B4B71  8b 3c 95 30 0b 48 10       mov edi, dword ptr [edx*4 + 0x10480b30]
  000B4B78  85 ff                      test edi, edi
  000B4B7A  0f 84 95 00 00 00          je 0x100b4c15
  000B4B80  8b 43 74                   mov eax, dword ptr [ebx + 0x74]
  000B4B83  8b 4f 74                   mov ecx, dword ptr [edi + 0x74]
  000B4B86  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000B4B8A  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000B4B8E  8b 43 78                   mov eax, dword ptr [ebx + 0x78]
  000B4B91  89 4c 24 10                mov dword ptr [esp + 0x10], ecx
  000B4B95  8b 4f 78                   mov ecx, dword ptr [edi + 0x78]
  000B4B98  3b c2                      cmp eax, edx
  000B4B9A  75 79                      jne 0x100b4c15
  000B4B9C  3b 4c 24 1c                cmp ecx, dword ptr [esp + 0x1c]
  000B4BA0  75 73                      jne 0x100b4c15
  000B4BA2  8b 93 20 01 00 00          mov edx, dword ptr [ebx + 0x120]   ; ent.RenderFlags0?
  000B4BA8  c1 ea 09                   shr edx, 9
  000B4BAB  f6 c2 01                   test dl, 1
  000B4BAE  74 65                      je 0x100b4c15
  000B4BB0  8b 87 20 01 00 00          mov eax, dword ptr [edi + 0x120]   ; ent.RenderFlags0?
  000B4BB6  c1 e8 09                   shr eax, 9
  000B4BB9  a8 01                      test al, 1
  000B4BBB  74 58                      je 0x100b4c15
  000B4BBD  55                         push ebp
  000B4BBE  6a 0b                      push 0xb
  000B4BC0  8b ce                      mov ecx, esi
  000B4BC2  e8 09 af ff ff             call 0x100afad0
  000B4BC7  8b 9b a0 00 00 00          mov ebx, dword ptr [ebx + 0xa0]   ; ent.ActorPointer?
  000B4BCD  8b bf a0 00 00 00          mov edi, dword ptr [edi + 0xa0]   ; ent.ActorPointer?
  000B4BD3  6a 01                      push 1
  000B4BD5  8b ce                      mov ecx, esi
  000B4BD7  8b e8                      mov ebp, eax
  000B4BD9  e8 e2 a8 ff ff             call 0x100af4c0
  000B4BDE  8b 54 24 28                mov edx, dword ptr [esp + 0x28]
  000B4BE2  81 fa f0 77 00 00          cmp edx, 0x77f0
  000B4BE8  75 08                      jne 0x100b4bf2
  000B4BEA  50                         push eax
  000B4BEB  8b ce                      mov ecx, esi
  000B4BED  e8 6e f7 ff ff             call 0x100b4360
  000B4BF2  57                         push edi
  000B4BF3  53                         push ebx
  000B4BF4  03 c2                      add eax, edx
  000B4BF6  55                         push ebp
  000B4BF7  50                         push eax
  000B4BF8  e8 e3 e2 fa ff             call 0x10062ee0
  000B4BFD  83 c4 10                   add esp, 0x10
  000B4C00  84 c0                      test al, al
  000B4C02  5d                         pop ebp
  000B4C03  74 10                      je 0x100b4c15
  000B4C05  c6 86 5a 02 00 00 01       mov byte ptr [esi + 0x25a], 1
  000B4C0C  5f                         pop edi
  000B4C0D  5e                         pop esi
  000B4C0E  5b                         pop ebx
  000B4C0F  83 c4 14                   add esp, 0x14
  000B4C12  c2 04 00                   ret 4
```

### H.4 0x52 @0xB48E0 start/load-and-run scheduler via 0x62E90 (disasm.py --func 0xB48E0)

Source file: `out3/d_B48E0.md`

```text
; func 0xB4886..0xB4C15 (911 bytes), callers: 0
  000B4886  8b ff                      mov edi, edi
  000B4888  a1 46 0b 10 c6             mov eax, dword ptr [0xc6100b46]
  000B488D  46                         inc esi
  000B488E  0b 10                      or edx, dword ptr [eax]
  000B4890  ef                         out dx, eax
  000B4891  46                         inc esi
  000B4892  0b 10                      or edx, dword ptr [eax]
  000B4894  14 47                      adc al, 0x47
  000B4896  0b 10                      or edx, dword ptr [eax]
  000B4898  39 47 0b                   cmp dword ptr [edi + 0xb], eax
  000B489B  10 5e 47                   adc byte ptr [esi + 0x47], bl
  000B489E  0b 10                      or edx, dword ptr [eax]
  000B48A0  83 47 0b 10                add dword ptr [edi + 0xb], 0x10
  000B48A4  a8 47                      test al, 0x47
  000B48A6  0b 10                      or edx, dword ptr [eax]
  000B48A8  cd 47                      int 0x47
  000B48AA  0b 10                      or edx, dword ptr [eax]
  000B48AC  f2 47                      inc edi
  000B48AE  0b 10                      or edx, dword ptr [eax]
  000B48B0  72 48                      jb 0x100b48fa
  000B48B2  0b 10                      or edx, dword ptr [eax]
  000B48B4  72 48                      jb 0x100b48fe
  000B48B6  0b 10                      or edx, dword ptr [eax]
  000B48B8  72 48                      jb 0x100b4902
  000B48BA  0b 10                      or edx, dword ptr [eax]
  000B48BC  72 48                      jb 0x100b4906
  000B48BE  0b 10                      or edx, dword ptr [eax]
  000B48C0  72 48                      jb 0x100b490a
  000B48C2  0b 10                      or edx, dword ptr [eax]
  000B48C4  72 48                      jb 0x100b490e
  000B48C6  0b 10                      or edx, dword ptr [eax]
  000B48C8  17                         pop ss
  000B48C9  48                         dec eax
  000B48CA  0b 10                      or edx, dword ptr [eax]
  000B48CC  3c 48                      cmp al, 0x48
  000B48CE  0b 10                      or edx, dword ptr [eax]
  000B48D0  61                         popal 
  000B48D1  48                         dec eax
  000B48D2  0b 10                      or edx, dword ptr [eax]
  000B48D4  90                         nop 
  000B48D5  90                         nop 
  000B48D6  90                         nop 
  000B48D7  90                         nop 
  000B48D8  90                         nop 
  000B48D9  90                         nop 
  000B48DA  90                         nop 
  000B48DB  90                         nop 
  000B48DC  90                         nop 
  000B48DD  90                         nop 
  000B48DE  90                         nop 
  000B48DF  90                         nop 
  000B48E0  68 f0 77 00 00             push 0x77f0
  000B48E5  e8 f6 00 00 00             call 0x100b49e0
  000B48EA  c3                         ret 
  000B48EB  90                         nop 
  000B48EC  90                         nop 
  000B48ED  90                         nop 
  000B48EE  90                         nop 
  000B48EF  90                         nop 
  000B48F0  68 94 13 00 00             push 0x1394
  000B48F5  e8 e6 00 00 00             call 0x100b49e0
  000B48FA  c3                         ret 
  000B48FB  90                         nop 
  000B48FC  90                         nop 
  000B48FD  90                         nop 
  000B48FE  90                         nop 
  000B48FF  90                         nop 
  000B4900  68 ef c7 00 00             push 0xc7ef
  000B4905  e8 d6 00 00 00             call 0x100b49e0
  000B490A  c3                         ret 
  000B490B  90                         nop 
  000B490C  90                         nop 
  000B490D  90                         nop 
  000B490E  90                         nop 
  000B490F  90                         nop 
  000B4910  68 6d dd 00 00             push 0xdd6d
  000B4915  e8 c6 00 00 00             call 0x100b49e0
  000B491A  c3                         ret 
  000B491B  90                         nop 
  000B491C  90                         nop 
  000B491D  90                         nop 
  000B491E  90                         nop 
  000B491F  90                         nop 
  000B4920  68 1b 07 01 00             push 0x1071b
  000B4925  e8 b6 00 00 00             call 0x100b49e0
  000B492A  c3                         ret 
  000B492B  90                         nop 
  000B492C  90                         nop 
  000B492D  90                         nop 
  000B492E  90                         nop 
  000B492F  90                         nop 
  000B4930  68 23 13 01 00             push 0x11323
  000B4935  e8 a6 00 00 00             call 0x100b49e0
  000B493A  c3                         ret 
  000B493B  90                         nop 
  000B493C  90                         nop 
  000B493D  90                         nop 
  000B493E  90                         nop 
  000B493F  90                         nop 
  000B4940  68 23 14 01 00             push 0x11423
  000B4945  e8 96 00 00 00             call 0x100b49e0
  000B494A  c3                         ret 
  000B494B  90                         nop 
  000B494C  90                         nop 
  000B494D  90                         nop 
  000B494E  90                         nop 
  000B494F  90                         nop 
  000B4950  68 31 90 01 00             push 0x19031
  000B4955  e8 86 00 00 00             call 0x100b49e0
  000B495A  c3                         ret 
  000B495B  90                         nop 
  000B495C  90                         nop 
  000B495D  90                         nop 
  000B495E  90                         nop 
  000B495F  90                         nop 
  000B4960  68 f0 77 00 00             push 0x77f0
  000B4965  e8 96 01 00 00             call 0x100b4b00
  000B496A  c3                         ret 
  000B496B  90                         nop 
  000B496C  90                         nop 
  000B496D  90                         nop 
  000B496E  90                         nop 
  000B496F  90                         nop 
  000B4970  68 94 13 00 00             push 0x1394
  000B4975  e8 86 01 00 00             call 0x100b4b00
  000B497A  c3                         ret 
  000B497B  90                         nop 
  000B497C  90                         nop 
  000B497D  90                         nop 
  000B497E  90                         nop 
  000B497F  90                         nop 
  000B4980  68 ef c7 00 00             push 0xc7ef
  000B4985  e8 76 01 00 00             call 0x100b4b00
  000B498A  c3                         ret 
  000B498B  90                         nop 
  000B498C  90                         nop 
  000B498D  90                         nop 
  000B498E  90                         nop 
  000B498F  90                         nop 
  000B4990  68 6d dd 00 00             push 0xdd6d
  000B4995  e8 66 01 00 00             call 0x100b4b00
  000B499A  c3                         ret 
  000B499B  90                         nop 
  000B499C  90                         nop 
  000B499D  90                         nop 
  000B499E  90                         nop 
  000B499F  90                         nop 
  000B49A0  68 1b 07 01 00             push 0x1071b
  000B49A5  e8 56 01 00 00             call 0x100b4b00
  000B49AA  c3                         ret 
  000B49AB  90                         nop 
  000B49AC  90                         nop 
  000B49AD  90                         nop 
  000B49AE  90                         nop 
  000B49AF  90                         nop 
  000B49B0  68 23 13 01 00             push 0x11323
  000B49B5  e8 46 01 00 00             call 0x100b4b00
  000B49BA  c3                         ret 
  000B49BB  90                         nop 
  000B49BC  90                         nop 
  000B49BD  90                         nop 
  000B49BE  90                         nop 
  000B49BF  90                         nop 
  000B49C0  68 23 14 01 00             push 0x11423
  000B49C5  e8 36 01 00 00             call 0x100b4b00
  000B49CA  c3                         ret 
  000B49CB  90                         nop 
  000B49CC  90                         nop 
  000B49CD  90                         nop 
  000B49CE  90                         nop 
  000B49CF  90                         nop 
  000B49D0  68 31 90 01 00             push 0x19031
  000B49D5  e8 26 01 00 00             call 0x100b4b00
  000B49DA  c3                         ret 
  000B49DB  90                         nop 
  000B49DC  90                         nop 
  000B49DD  90                         nop 
  000B49DE  90                         nop 
  000B49DF  90                         nop 
  000B49E0  83 ec 14                   sub esp, 0x14
  000B49E3  8d 44 24 00                lea eax, [esp]
  000B49E7  53                         push ebx
  000B49E8  56                         push esi
  000B49E9  8b d9                      mov ebx, ecx
  000B49EB  57                         push edi
  000B49EC  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B49F0  50                         push eax
  000B49F1  51                         push ecx
  000B49F2  6a 03                      push 3
  000B49F4  8b cb                      mov ecx, ebx
  000B49F6  e8 d5 b0 ff ff             call 0x100afad0
  000B49FB  50                         push eax
  000B49FC  8b cb                      mov ecx, ebx
  000B49FE  e8 0d b1 ff ff             call 0x100afb10
  000B4A03  3c 01                      cmp al, 1
  000B4A05  0f 85 d6 00 00 00          jne 0x100b4ae1
  000B4A0B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4A0F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4A13  52                         push edx
  000B4A14  50                         push eax
  000B4A15  6a 07                      push 7
  000B4A17  8b cb                      mov ecx, ebx
  000B4A19  e8 b2 b0 ff ff             call 0x100afad0
  000B4A1E  50                         push eax
  000B4A1F  8b cb                      mov ecx, ebx
  000B4A21  e8 ea b0 ff ff             call 0x100afb10
  000B4A26  3c 01                      cmp al, 1
  000B4A28  0f 85 b3 00 00 00          jne 0x100b4ae1
  000B4A2E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4A32  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4A38  8b 3c 8d 30 0b 48 10       mov edi, dword ptr [ecx*4 + 0x10480b30]
  000B4A3F  85 ff                      test edi, edi
  000B4A41  0f 84 9a 00 00 00          je 0x100b4ae1
  000B4A47  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4A4B  81 e2 ff ff 00 00          and edx, 0xffff
  000B4A51  8b 34 95 30 0b 48 10       mov esi, dword ptr [edx*4 + 0x10480b30]
  000B4A58  85 f6                      test esi, esi
  000B4A5A  0f 84 81 00 00 00          je 0x100b4ae1
  000B4A60  8b 47 74                   mov eax, dword ptr [edi + 0x74]
  000B4A63  8b 4e 74                   mov ecx, dword ptr [esi + 0x74]
  000B4A66  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000B4A6A  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000B4A6E  8b 47 78                   mov eax, dword ptr [edi + 0x78]
  000B4A71  89 4c 24 10                mov dword ptr [esp + 0x10], ecx
  000B4A75  8b 4e 78                   mov ecx, dword ptr [esi + 0x78]
  000B4A78  3b c2                      cmp eax, edx
  000B4A7A  75 65                      jne 0x100b4ae1
  000B4A7C  3b 4c 24 1c                cmp ecx, dword ptr [esp + 0x1c]
  000B4A80  75 5f                      jne 0x100b4ae1
  000B4A82  8b 97 20 01 00 00          mov edx, dword ptr [edi + 0x120]   ; ent.RenderFlags0?
  000B4A88  c1 ea 09                   shr edx, 9
  000B4A8B  f6 c2 01                   test dl, 1
  000B4A8E  74 51                      je 0x100b4ae1
  000B4A90  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  000B4A96  c1 e8 09                   shr eax, 9
  000B4A99  a8 01                      test al, 1
  000B4A9B  74 44                      je 0x100b4ae1
  000B4A9D  55                         push ebp
  000B4A9E  6a 0b                      push 0xb
  000B4AA0  8b cb                      mov ecx, ebx
  000B4AA2  e8 29 b0 ff ff             call 0x100afad0
  000B4AA7  8b bf a0 00 00 00          mov edi, dword ptr [edi + 0xa0]   ; ent.ActorPointer?
  000B4AAD  8b b6 a0 00 00 00          mov esi, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  000B4AB3  6a 01                      push 1
  000B4AB5  8b cb                      mov ecx, ebx
  000B4AB7  8b e8                      mov ebp, eax
  000B4AB9  e8 02 aa ff ff             call 0x100af4c0
  000B4ABE  8b 54 24 28                mov edx, dword ptr [esp + 0x28]
  000B4AC2  81 fa f0 77 00 00          cmp edx, 0x77f0
  000B4AC8  75 08                      jne 0x100b4ad2
  000B4ACA  50                         push eax
  000B4ACB  8b cb                      mov ecx, ebx
  000B4ACD  e8 8e f8 ff ff             call 0x100b4360
  000B4AD2  56                         push esi
  000B4AD3  57                         push edi
  000B4AD4  03 c2                      add eax, edx
  000B4AD6  55                         push ebp
  000B4AD7  50                         push eax
  000B4AD8  e8 b3 e3 fa ff             call 0x10062e90
  000B4ADD  83 c4 10                   add esp, 0x10
  000B4AE0  5d                         pop ebp
  000B4AE1  66 83 83 56 02 00 00 0f    add word ptr [ebx + 0x256], 0xf
  000B4AE9  5f                         pop edi
  000B4AEA  5e                         pop esi
  000B4AEB  5b                         pop ebx
  000B4AEC  83 c4 14                   add esp, 0x14
  000B4AEF  c2 04 00                   ret 4
  000B4AF2  90                         nop 
  000B4AF3  90                         nop 
  000B4AF4  90                         nop 
  000B4AF5  90                         nop 
  000B4AF6  90                         nop 
  000B4AF7  90                         nop 
  000B4AF8  90                         nop 
  000B4AF9  90                         nop 
  000B4AFA  90                         nop 
  000B4AFB  90                         nop 
  000B4AFC  90                         nop 
  000B4AFD  90                         nop 
  000B4AFE  90                         nop 
  000B4AFF  90                         nop 
  000B4B00  83 ec 14                   sub esp, 0x14
  000B4B03  8d 44 24 00                lea eax, [esp]
  000B4B07  53                         push ebx
  000B4B08  56                         push esi
  000B4B09  8b f1                      mov esi, ecx
  000B4B0B  57                         push edi
  000B4B0C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B4B10  50                         push eax
  000B4B11  51                         push ecx
  000B4B12  6a 03                      push 3
  000B4B14  8b ce                      mov ecx, esi
  000B4B16  e8 b5 af ff ff             call 0x100afad0
  000B4B1B  50                         push eax
  000B4B1C  8b ce                      mov ecx, esi
  000B4B1E  e8 ed af ff ff             call 0x100afb10
  000B4B23  3c 01                      cmp al, 1
  000B4B25  0f 85 ea 00 00 00          jne 0x100b4c15
  000B4B2B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4B2F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4B33  52                         push edx
  000B4B34  50                         push eax
  000B4B35  6a 07                      push 7
  000B4B37  8b ce                      mov ecx, esi
  000B4B39  e8 92 af ff ff             call 0x100afad0
  000B4B3E  50                         push eax
  000B4B3F  8b ce                      mov ecx, esi
  000B4B41  e8 ca af ff ff             call 0x100afb10
  000B4B46  3c 01                      cmp al, 1
  000B4B48  0f 85 c7 00 00 00          jne 0x100b4c15
  000B4B4E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4B52  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4B58  8b 1c 8d 30 0b 48 10       mov ebx, dword ptr [ecx*4 + 0x10480b30]
  000B4B5F  85 db                      test ebx, ebx
  000B4B61  0f 84 ae 00 00 00          je 0x100b4c15
  000B4B67  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4B6B  81 e2 ff ff 00 00          and edx, 0xffff
  000B4B71  8b 3c 95 30 0b 48 10       mov edi, dword ptr [edx*4 + 0x10480b30]
  000B4B78  85 ff                      test edi, edi
  000B4B7A  0f 84 95 00 00 00          je 0x100b4c15
  000B4B80  8b 43 74                   mov eax, dword ptr [ebx + 0x74]
  000B4B83  8b 4f 74                   mov ecx, dword ptr [edi + 0x74]
  000B4B86  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000B4B8A  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000B4B8E  8b 43 78                   mov eax, dword ptr [ebx + 0x78]
  000B4B91  89 4c 24 10                mov dword ptr [esp + 0x10], ecx
  000B4B95  8b 4f 78                   mov ecx, dword ptr [edi + 0x78]
  000B4B98  3b c2                      cmp eax, edx
  000B4B9A  75 79                      jne 0x100b4c15
  000B4B9C  3b 4c 24 1c                cmp ecx, dword ptr [esp + 0x1c]
  000B4BA0  75 73                      jne 0x100b4c15
  000B4BA2  8b 93 20 01 00 00          mov edx, dword ptr [ebx + 0x120]   ; ent.RenderFlags0?
  000B4BA8  c1 ea 09                   shr edx, 9
  000B4BAB  f6 c2 01                   test dl, 1
  000B4BAE  74 65                      je 0x100b4c15
  000B4BB0  8b 87 20 01 00 00          mov eax, dword ptr [edi + 0x120]   ; ent.RenderFlags0?
  000B4BB6  c1 e8 09                   shr eax, 9
  000B4BB9  a8 01                      test al, 1
  000B4BBB  74 58                      je 0x100b4c15
  000B4BBD  55                         push ebp
  000B4BBE  6a 0b                      push 0xb
  000B4BC0  8b ce                      mov ecx, esi
  000B4BC2  e8 09 af ff ff             call 0x100afad0
  000B4BC7  8b 9b a0 00 00 00          mov ebx, dword ptr [ebx + 0xa0]   ; ent.ActorPointer?
  000B4BCD  8b bf a0 00 00 00          mov edi, dword ptr [edi + 0xa0]   ; ent.ActorPointer?
  000B4BD3  6a 01                      push 1
  000B4BD5  8b ce                      mov ecx, esi
  000B4BD7  8b e8                      mov ebp, eax
  000B4BD9  e8 e2 a8 ff ff             call 0x100af4c0
  000B4BDE  8b 54 24 28                mov edx, dword ptr [esp + 0x28]
  000B4BE2  81 fa f0 77 00 00          cmp edx, 0x77f0
  000B4BE8  75 08                      jne 0x100b4bf2
  000B4BEA  50                         push eax
  000B4BEB  8b ce                      mov ecx, esi
  000B4BED  e8 6e f7 ff ff             call 0x100b4360
  000B4BF2  57                         push edi
  000B4BF3  53                         push ebx
  000B4BF4  03 c2                      add eax, edx
  000B4BF6  55                         push ebp
  000B4BF7  50                         push eax
  000B4BF8  e8 e3 e2 fa ff             call 0x10062ee0
  000B4BFD  83 c4 10                   add esp, 0x10
  000B4C00  84 c0                      test al, al
  000B4C02  5d                         pop ebp
  000B4C03  74 10                      je 0x100b4c15
  000B4C05  c6 86 5a 02 00 00 01       mov byte ptr [esi + 0x25a], 1
  000B4C0C  5f                         pop edi
  000B4C0D  5e                         pop esi
  000B4C0E  5b                         pop ebx
  000B4C0F  83 c4 14                   add esp, 0x14
  000B4C12  c2 04 00                   ret 4
```

## I. Zone scene DAT and 0x2D (T5)

Backs E14.

### I.1 0x2D @0xB4F20 zone SetAction via [zoneObj->vt+0x18] (disasm.py --func 0xB4F20)

Source file: `out3/d_b4f20.md`

```text
; func 0xB4F02..0xB51EE (748 bytes), callers: 0
  000B4F02  8a 44 24 1c                mov al, byte ptr [esp + 0x1c]   ; pkt body status?
  000B4F06  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B4F0E  88 86 5a 02 00 00          mov byte ptr [esi + 0x25a], al
  000B4F14  5f                         pop edi
  000B4F15  5e                         pop esi
  000B4F16  b0 01                      mov al, 1
  000B4F18  5d                         pop ebp
  000B4F19  83 c4 0c                   add esp, 0xc
  000B4F1C  c2 08 00                   ret 8
  000B4F1F  90                         nop 
  000B4F20  83 ec 14                   sub esp, 0x14
  000B4F23  8d 44 24 00                lea eax, [esp]
  000B4F27  53                         push ebx
  000B4F28  56                         push esi
  000B4F29  8b f1                      mov esi, ecx
  000B4F2B  57                         push edi
  000B4F2C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B4F30  50                         push eax
  000B4F31  51                         push ecx
  000B4F32  6a 01                      push 1
  000B4F34  8b ce                      mov ecx, esi
  000B4F36  e8 95 ab ff ff             call 0x100afad0
  000B4F3B  50                         push eax
  000B4F3C  8b ce                      mov ecx, esi
  000B4F3E  e8 cd ab ff ff             call 0x100afb10
  000B4F43  3c 01                      cmp al, 1
  000B4F45  0f 85 b0 00 00 00          jne 0x100b4ffb
  000B4F4B  8d 54 24 10                lea edx, [esp + 0x10]
  000B4F4F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B4F53  52                         push edx
  000B4F54  50                         push eax
  000B4F55  6a 05                      push 5
  000B4F57  8b ce                      mov ecx, esi
  000B4F59  e8 72 ab ff ff             call 0x100afad0
  000B4F5E  50                         push eax
  000B4F5F  8b ce                      mov ecx, esi
  000B4F61  e8 aa ab ff ff             call 0x100afb10
  000B4F66  3c 01                      cmp al, 1
  000B4F68  0f 85 8d 00 00 00          jne 0x100b4ffb
  000B4F6E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B4F72  81 e1 ff ff 00 00          and ecx, 0xffff
  000B4F78  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  000B4F7F  85 c9                      test ecx, ecx
  000B4F81  74 78                      je 0x100b4ffb
  000B4F83  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B4F87  81 e2 ff ff 00 00          and edx, 0xffff
  000B4F8D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B4F94  85 c0                      test eax, eax
  000B4F96  74 63                      je 0x100b4ffb
  000B4F98  8b 51 74                   mov edx, dword ptr [ecx + 0x74]
  000B4F9B  8b 78 74                   mov edi, dword ptr [eax + 0x74]
  000B4F9E  8b 5c 24 18                mov ebx, dword ptr [esp + 0x18]
  000B4FA2  89 54 24 10                mov dword ptr [esp + 0x10], edx
  000B4FA6  8b 51 78                   mov edx, dword ptr [ecx + 0x78]
  000B4FA9  89 7c 24 10                mov dword ptr [esp + 0x10], edi
  000B4FAD  8b 78 78                   mov edi, dword ptr [eax + 0x78]
  000B4FB0  3b d3                      cmp edx, ebx
  000B4FB2  75 47                      jne 0x100b4ffb
  000B4FB4  3b 7c 24 1c                cmp edi, dword ptr [esp + 0x1c]
  000B4FB8  75 41                      jne 0x100b4ffb
  000B4FBA  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B4FC0  c1 ea 09                   shr edx, 9
  000B4FC3  f6 c2 01                   test dl, 1
  000B4FC6  74 33                      je 0x100b4ffb
  000B4FC8  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B4FCE  c1 ea 09                   shr edx, 9
  000B4FD1  f6 c2 01                   test dl, 1
  000B4FD4  74 25                      je 0x100b4ffb
  000B4FD6  8b 80 a0 00 00 00          mov eax, dword ptr [eax + 0xa0]   ; ent.ActorPointer?
  000B4FDC  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B4FE2  8b 3d 24 a0 62 10          mov edi, dword ptr [0x1062a024]
  000B4FE8  50                         push eax
  000B4FE9  51                         push ecx
  000B4FEA  6a 09                      push 9
  000B4FEC  8b 1f                      mov ebx, dword ptr [edi]
  000B4FEE  8b ce                      mov ecx, esi
  000B4FF0  e8 db aa ff ff             call 0x100afad0
  000B4FF5  50                         push eax
  000B4FF6  8b cf                      mov ecx, edi
  000B4FF8  ff 53 18                   call dword ptr [ebx + 0x18]
  000B4FFB  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B5003  5f                         pop edi
  000B5004  5e                         pop esi
  000B5005  5b                         pop ebx
  000B5006  83 c4 14                   add esp, 0x14
  000B5009  c3                         ret 
  000B500A  90                         nop 
  000B500B  90                         nop 
  000B500C  90                         nop 
  000B500D  90                         nop 
  000B500E  90                         nop 
  000B500F  90                         nop 
  000B5010  83 ec 14                   sub esp, 0x14
  000B5013  8d 44 24 00                lea eax, [esp]
  000B5017  53                         push ebx
  000B5018  56                         push esi
  000B5019  8b f1                      mov esi, ecx
  000B501B  57                         push edi
  000B501C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B5020  50                         push eax
  000B5021  51                         push ecx
  000B5022  6a 01                      push 1
  000B5024  8b ce                      mov ecx, esi
  000B5026  e8 a5 aa ff ff             call 0x100afad0
  000B502B  50                         push eax
  000B502C  8b ce                      mov ecx, esi
  000B502E  e8 dd aa ff ff             call 0x100afb10
  000B5033  3c 01                      cmp al, 1
  000B5035  0f 85 b0 00 00 00          jne 0x100b50eb
  000B503B  8d 54 24 10                lea edx, [esp + 0x10]
  000B503F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B5043  52                         push edx
  000B5044  50                         push eax
  000B5045  6a 05                      push 5
  000B5047  8b ce                      mov ecx, esi
  000B5049  e8 82 aa ff ff             call 0x100afad0
  000B504E  50                         push eax
  000B504F  8b ce                      mov ecx, esi
  000B5051  e8 ba aa ff ff             call 0x100afb10
  000B5056  3c 01                      cmp al, 1
  000B5058  0f 85 8d 00 00 00          jne 0x100b50eb
  000B505E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B5062  81 e1 ff ff 00 00          and ecx, 0xffff
  000B5068  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  000B506F  85 c9                      test ecx, ecx
  000B5071  74 78                      je 0x100b50eb
  000B5073  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B5077  81 e2 ff ff 00 00          and edx, 0xffff
  000B507D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  000B5084  85 c0                      test eax, eax
  000B5086  74 63                      je 0x100b50eb
  000B5088  8b 51 74                   mov edx, dword ptr [ecx + 0x74]
  000B508B  8b 78 74                   mov edi, dword ptr [eax + 0x74]
  000B508E  8b 5c 24 18                mov ebx, dword ptr [esp + 0x18]
  000B5092  89 54 24 10                mov dword ptr [esp + 0x10], edx
  000B5096  8b 51 78                   mov edx, dword ptr [ecx + 0x78]
  000B5099  89 7c 24 10                mov dword ptr [esp + 0x10], edi
  000B509D  8b 78 78                   mov edi, dword ptr [eax + 0x78]
  000B50A0  3b d3                      cmp edx, ebx
  000B50A2  75 47                      jne 0x100b50eb
  000B50A4  3b 7c 24 1c                cmp edi, dword ptr [esp + 0x1c]
  000B50A8  75 41                      jne 0x100b50eb
  000B50AA  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  000B50B0  c1 ea 09                   shr edx, 9
  000B50B3  f6 c2 01                   test dl, 1
  000B50B6  74 33                      je 0x100b50eb
  000B50B8  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  000B50BE  c1 ea 09                   shr edx, 9
  000B50C1  f6 c2 01                   test dl, 1
  000B50C4  74 25                      je 0x100b50eb
  000B50C6  8b 80 a0 00 00 00          mov eax, dword ptr [eax + 0xa0]   ; ent.ActorPointer?
  000B50CC  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B50D2  8b 3d 24 a0 62 10          mov edi, dword ptr [0x1062a024]
  000B50D8  50                         push eax
  000B50D9  51                         push ecx
  000B50DA  6a 09                      push 9
  000B50DC  8b 1f                      mov ebx, dword ptr [edi]
  000B50DE  8b ce                      mov ecx, esi
  000B50E0  e8 eb a9 ff ff             call 0x100afad0
  000B50E5  50                         push eax
  000B50E6  8b cf                      mov ecx, edi
  000B50E8  ff 53 1c                   call dword ptr [ebx + 0x1c]
  000B50EB  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B50F3  5f                         pop edi
  000B50F4  5e                         pop esi
  000B50F5  5b                         pop ebx
  000B50F6  83 c4 14                   add esp, 0x14
  000B50F9  c3                         ret 
  000B50FA  90                         nop 
  000B50FB  90                         nop 
  000B50FC  90                         nop 
  000B50FD  90                         nop 
  000B50FE  90                         nop 
  000B50FF  90                         nop 
  000B5100  83 ec 14                   sub esp, 0x14
  000B5103  8d 44 24 00                lea eax, [esp]
  000B5107  53                         push ebx
  000B5108  56                         push esi
  000B5109  8b d9                      mov ebx, ecx
  000B510B  57                         push edi
  000B510C  8d 4c 24 18                lea ecx, [esp + 0x18]
  000B5110  50                         push eax
  000B5111  51                         push ecx
  000B5112  6a 01                      push 1
  000B5114  8b cb                      mov ecx, ebx
  000B5116  e8 b5 a9 ff ff             call 0x100afad0
  000B511B  50                         push eax
  000B511C  8b cb                      mov ecx, ebx
  000B511E  e8 ed a9 ff ff             call 0x100afb10
  000B5123  3c 01                      cmp al, 1
  000B5125  0f 85 c3 00 00 00          jne 0x100b51ee
  000B512B  8d 54 24 10                lea edx, [esp + 0x10]
  000B512F  8d 44 24 1c                lea eax, [esp + 0x1c]
  000B5133  52                         push edx
  000B5134  50                         push eax
  000B5135  6a 05                      push 5
  000B5137  8b cb                      mov ecx, ebx
  000B5139  e8 92 a9 ff ff             call 0x100afad0
  000B513E  50                         push eax
  000B513F  8b cb                      mov ecx, ebx
  000B5141  e8 ca a9 ff ff             call 0x100afb10
  000B5146  3c 01                      cmp al, 1
  000B5148  0f 85 a0 00 00 00          jne 0x100b51ee
  000B514E  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000B5152  81 e1 ff ff 00 00          and ecx, 0xffff
  000B5158  8b 3c 8d 30 0b 48 10       mov edi, dword ptr [ecx*4 + 0x10480b30]
  000B515F  85 ff                      test edi, edi
  000B5161  0f 84 87 00 00 00          je 0x100b51ee
  000B5167  8b 54 24 10                mov edx, dword ptr [esp + 0x10]
  000B516B  81 e2 ff ff 00 00          and edx, 0xffff
  000B5171  8b 34 95 30 0b 48 10       mov esi, dword ptr [edx*4 + 0x10480b30]
  000B5178  85 f6                      test esi, esi
  000B517A  74 72                      je 0x100b51ee
  000B517C  8b 47 74                   mov eax, dword ptr [edi + 0x74]
  000B517F  8b 4e 74                   mov ecx, dword ptr [esi + 0x74]
  000B5182  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000B5186  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000B518A  8b 47 78                   mov eax, dword ptr [edi + 0x78]
  000B518D  89 4c 24 10                mov dword ptr [esp + 0x10], ecx
  000B5191  8b 4e 78                   mov ecx, dword ptr [esi + 0x78]
  000B5194  3b c2                      cmp eax, edx
  000B5196  75 56                      jne 0x100b51ee
  000B5198  3b 4c 24 1c                cmp ecx, dword ptr [esp + 0x1c]
  000B519C  75 50                      jne 0x100b51ee
  000B519E  8b 97 20 01 00 00          mov edx, dword ptr [edi + 0x120]   ; ent.RenderFlags0?
  000B51A4  c1 ea 09                   shr edx, 9
  000B51A7  f6 c2 01                   test dl, 1
  000B51AA  74 42                      je 0x100b51ee
  000B51AC  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  000B51B2  c1 e8 09                   shr eax, 9
  000B51B5  a8 01                      test al, 1
  000B51B7  74 35                      je 0x100b51ee
  000B51B9  6a 09                      push 9
  000B51BB  8b cb                      mov ecx, ebx
  000B51BD  e8 0e a9 ff ff             call 0x100afad0
  000B51C2  8b b6 a0 00 00 00          mov esi, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  000B51C8  8b 0d 24 a0 62 10          mov ecx, dword ptr [0x1062a024]
  000B51CE  8b bf a0 00 00 00          mov edi, dword ptr [edi + 0xa0]   ; ent.ActorPointer?
  000B51D4  56                         push esi
  000B51D5  8b 11                      mov edx, dword ptr [ecx]
  000B51D7  57                         push edi
  000B51D8  50                         push eax
  000B51D9  ff 52 20                   call dword ptr [edx + 0x20]
  000B51DC  84 c0                      test al, al
  000B51DE  74 0e                      je 0x100b51ee
  000B51E0  5f                         pop edi
  000B51E1  c6 83 5a 02 00 00 01       mov byte ptr [ebx + 0x25a], 1
  000B51E8  5e                         pop esi
  000B51E9  5b                         pop ebx
  000B51EA  83 c4 14                   add esp, 0x14
  000B51ED  c3                         ret 
```

### I.2 DAT scan: every file with movN / exNN scheduler stages (52869 DATs scanned); only ROM\0\23.DAT has both

Source file: `out3/p9_zone_scene_scan.md`

```text
# p9_zone_scene_scan: DATs with movN / exNN scheduler stage names

scanned 52869 DAT files under C:\PhoenixXI\SquareEnix\FINAL FANTASY XI
9 files carry movN or exNN stages:

- id=    23  ROM\0\23.DAT  mov=['mov1', 'mov2', 'mov3', 'mov4', 'mov5', 'mov6', 'mov7', 'mov8'] ex=['ex1a', 'ex1b', 'ex1c', 'ex2a', 'ex2b', 'ex2c', 'ex2d', 'ex3a', 'ex3c', 'ex3d', 'ex3e'] routines=['loop']
- id=    24  ROM\0\24.DAT  mov=['mov1'] ex=[] routines=['loop']
- id=    25  ROM\0\25.DAT  mov=['mov1'] ex=[] routines=['loop']
- id=    26  ROM\0\26.DAT  mov=['mov1'] ex=[] routines=['loop']
- id=  8049  ROM\62\113.DAT  mov=['mov1', 'mov2', 'mov3', 'mov4', 'mov5', 'mov6'] ex=[] routines=['mai1', 'main', 'move', 'seq0', 'seq1', 'sloa', 'slob', 'stop']
- id=  8050  ROM\62\114.DAT  mov=['mov1', 'mov2', 'mov3', 'mov4', 'mov5', 'mov6'] ex=[] routines=['mai1', 'main', 'move', 'seq0', 'seq1', 'sloa', 'slob', 'stop']
- id=  8051  ROM\62\115.DAT  mov=['mov1', 'mov2', 'mov3', 'mov4', 'mov5', 'mov6'] ex=[] routines=['mai1', 'main', 'move', 'seq0', 'seq1', 'sloa', 'slob', 'stop']
- id=  8055  ROM\62\119.DAT  mov=['mov1', 'mov2', 'mov3', 'mov4', 'mov5', 'mov6'] ex=[] routines=['mai1', 'main', 'move', 'seq0', 'seq1', 'seq2', 'seq3', 'seq4', 'seq5', 'seq6', 'seq7', 'sloa', 'slob', 'stop']
- id= 35326  ROM2\19\126.DAT  mov=['mov1', 'mov2', 'mov3', 'mov4', 'mov5', 'mov6'] ex=[] routines=['mai1', 'main', 'move', 'seq0', 'seq1', 'sloa', 'slob', 'stop']

files with BOTH movN and exNN: 1
- id=    23  ROM\0\23.DAT
```

Correction (E16, 2026-09-11): the id column of this run was computed arithmetically ((dir << 7) | file,
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
`p9_zone_scene.py` in the scanner suite, which resolves ids through VTABLE/FTABLE.

### I.3 All zone-object vcall sites in .text; the [zoneObj->vt+N] pattern at 0xB4FF8 / 0xB50E8 / 0xB7439

Source file: `out3/probe_zone_vt.md`

```text
vcall [reg+slot] sites: [('0x4c70d', 'edi', '0x1c'), ('0x5222b', 'edi', '0x24'), ('0x6fad9', 'edi', '0x24'), ('0x6fae0', 'edi', '0x24'), ('0x6fb7d', 'edi', '0x24'), ('0x6fb84', 'edi', '0x24'), ('0x6fcdd', 'edi', '0x24'), ('0x6fce4', 'edi', '0x24'), ('0x70b79', 'edi', '0x24'), ('0x70b80', 'edi', '0x24'), ('0x70c1d', 'edi', '0x24'), ('0x70c24', 'edi', '0x24'), ('0x70d7d', 'edi', '0x24'), ('0x70d84', 'edi', '0x24'), ('0x9dedb', 'edi', '0x18'), ('0xb4ff8', 'ebx', '0x18'), ('0xb50e8', 'ebx', '0x1c'), ('0xb7439', 'ebx', '0x18'), ('0x210a22', 'edi', '0x24'), ('0x2c710c', 'edi', '0x24'), ('0x2c74bf', 'edi', '0x20'), ('0x2c7753', 'edi', '0x24'), ('0x2c7834', 'edi', '0x24'), ('0x2c7882', 'edi', '0x24'), ('0x3084f6', 'edi', '0x24')]
--- context around 0x4c70d (slot +0x1c)
  0004C6EF  8b 38                      mov edi, dword ptr [eax]
  0004C6F1  e8 da 65 2c 00             call 0x10312cd0
  0004C6F6  8b 55 00                   mov edx, dword ptr [ebp]
  0004C6F9  51                         push ecx
  0004C6FA  8b 0d bc cf 47 10          mov ecx, dword ptr [0x1047cfbc]
  0004C700  c1 ea 0d                   shr edx, 0xd
  0004C703  83 e2 3f                   and edx, 0x3f
  0004C706  d9 1c 24                   fstp dword ptr [esp]
  0004C709  8d 04 96                   lea eax, [esi + edx*4]
  0004C70C  50                         push eax
>>0004C70D  ff 57 1c                   call dword ptr [edi + 0x1c]
  0004C710  e9 79 f1 ff ff             jmp 0x1004b88e
  0004C715  8b 4d 00                   mov ecx, dword ptr [ebp]
  0004C718  c1 e9 0d                   shr ecx, 0xd
  0004C71B  83 e1 3f                   and ecx, 0x3f
--- context around 0x5222b (slot +0x24)
  00052209  8b ce                      mov ecx, esi
  0005220B  e8 c0 05 00 00             call 0x100527d0
  00052210  a1 bc cf 47 10             mov eax, dword ptr [0x1047cfbc]
  00052215  8b 0d e8 bf 47 10          mov ecx, dword ptr [0x1047bfe8]
  0005221B  8b 38                      mov edi, dword ptr [eax]
  0005221D  e8 ee 06 00 00             call 0x10052910
  00052222  8b 0d bc cf 47 10          mov ecx, dword ptr [0x1047cfbc]
  00052228  50                         push eax
  00052229  56                         push esi
  0005222A  56                         push esi
>>0005222B  ff 57 24                   call dword ptr [edi + 0x24]
  0005222E  8b 0d bc cf 47 10          mov ecx, dword ptr [0x1047cfbc]
  00052234  56                         push esi
  00052235  8b 11                      mov edx, dword ptr [ecx]
  00052237  ff 52 18                   call dword ptr [edx + 0x18]
--- context around 0x6fad9 (slot +0x24)
  0006FABD  8d 86 50 08 00 00          lea eax, [esi + 0x850]
  0006FAC3  50                         push eax
  0006FAC4  51                         push ecx
  0006FAC5  52                         push edx
  0006FAC6  53                         push ebx
  0006FAC7  8b ce                      mov ecx, esi
  0006FAC9  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  0006FACF  d9 e0                      fchs 
  0006FAD1  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  0006FAD7  8b 3e                      mov edi, dword ptr [esi]
>>0006FAD9  ff 57 24                   call dword ptr [edi + 0x24]
  0006FADC  50                         push eax
  0006FADD  53                         push ebx
  0006FADE  8b ce                      mov ecx, esi
  0006FAE0  ff 57 24                   call dword ptr [edi + 0x24]
--- context around 0x6fae0 (slot +0x24)
  0006FAC6  53                         push ebx
  0006FAC7  8b ce                      mov ecx, esi
  0006FAC9  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  0006FACF  d9 e0                      fchs 
  0006FAD1  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  0006FAD7  8b 3e                      mov edi, dword ptr [esi]
  0006FAD9  ff 57 24                   call dword ptr [edi + 0x24]
  0006FADC  50                         push eax
  0006FADD  53                         push ebx
  0006FADE  8b ce                      mov ecx, esi
>>0006FAE0  ff 57 24                   call dword ptr [edi + 0x24]
  0006FAE3  5f                         pop edi
  0006FAE4  8b c3                      mov eax, ebx
  0006FAE6  5e                         pop esi
  0006FAE7  5b                         pop ebx
--- context around 0x6fb7d (slot +0x24)
  0006FB5B  d9 ff                      fcos 
  0006FB5D  d9 96 e4 08 00 00          fst dword ptr [esi + 0x8e4]
  0006FB63  d9 19                      fstp dword ptr [ecx]
  0006FB65  d9 44 24 2c                fld dword ptr [esp + 0x2c]
  0006FB69  d9 fe                      fsin 
  0006FB6B  8b ce                      mov ecx, esi
  0006FB6D  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  0006FB73  d9 e0                      fchs 
  0006FB75  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  0006FB7B  8b 3e                      mov edi, dword ptr [esi]
>>0006FB7D  ff 57 24                   call dword ptr [edi + 0x24]
  0006FB80  50                         push eax
  0006FB81  53                         push ebx
  0006FB82  8b ce                      mov ecx, esi
  0006FB84  ff 57 24                   call dword ptr [edi + 0x24]
--- context around 0x6fb84 (slot +0x24)
  0006FB69  d9 fe                      fsin 
  0006FB6B  8b ce                      mov ecx, esi
  0006FB6D  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  0006FB73  d9 e0                      fchs 
  0006FB75  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  0006FB7B  8b 3e                      mov edi, dword ptr [esi]
  0006FB7D  ff 57 24                   call dword ptr [edi + 0x24]
  0006FB80  50                         push eax
  0006FB81  53                         push ebx
  0006FB82  8b ce                      mov ecx, esi
>>0006FB84  ff 57 24                   call dword ptr [edi + 0x24]
  0006FB87  5f                         pop edi
  0006FB88  8b c3                      mov eax, ebx
  0006FB8A  5e                         pop esi
  0006FB8B  5b                         pop ebx
--- context around 0x6fcdd (slot +0x24)
  0006FCBB  d9 ff                      fcos 
  0006FCBD  d9 96 e4 08 00 00          fst dword ptr [esi + 0x8e4]
  0006FCC3  d9 19                      fstp dword ptr [ecx]
  0006FCC5  d9 44 24 2c                fld dword ptr [esp + 0x2c]
  0006FCC9  d9 fe                      fsin 
  0006FCCB  8b ce                      mov ecx, esi
  0006FCCD  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  0006FCD3  d9 e0                      fchs 
  0006FCD5  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  0006FCDB  8b 3e                      mov edi, dword ptr [esi]
>>0006FCDD  ff 57 24                   call dword ptr [edi + 0x24]
  0006FCE0  50                         push eax
  0006FCE1  53                         push ebx
  0006FCE2  8b ce                      mov ecx, esi
  0006FCE4  ff 57 24                   call dword ptr [edi + 0x24]
--- context around 0x6fce4 (slot +0x24)
  0006FCC9  d9 fe                      fsin 
  0006FCCB  8b ce                      mov ecx, esi
  0006FCCD  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  0006FCD3  d9 e0                      fchs 
  0006FCD5  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  0006FCDB  8b 3e                      mov edi, dword ptr [esi]
  0006FCDD  ff 57 24                   call dword ptr [edi + 0x24]
  0006FCE0  50                         push eax
  0006FCE1  53                         push ebx
  0006FCE2  8b ce                      mov ecx, esi
>>0006FCE4  ff 57 24                   call dword ptr [edi + 0x24]
  0006FCE7  5f                         pop edi
  0006FCE8  8b c3                      mov eax, ebx
  0006FCEA  5e                         pop esi
  0006FCEB  5b                         pop ebx
--- context around 0x70b79 (slot +0x24)
  00070B5D  8d 86 50 08 00 00          lea eax, [esi + 0x850]
  00070B63  50                         push eax
  00070B64  51                         push ecx
  00070B65  52                         push edx
  00070B66  53                         push ebx
  00070B67  8b ce                      mov ecx, esi
  00070B69  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  00070B6F  d9 e0                      fchs 
  00070B71  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  00070B77  8b 3e                      mov edi, dword ptr [esi]
>>00070B79  ff 57 24                   call dword ptr [edi + 0x24]
  00070B7C  50                         push eax
  00070B7D  53                         push ebx
  00070B7E  8b ce                      mov ecx, esi
  00070B80  ff 57 24                   call dword ptr [edi + 0x24]
--- context around 0x70b80 (slot +0x24)
  00070B66  53                         push ebx
  00070B67  8b ce                      mov ecx, esi
  00070B69  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  00070B6F  d9 e0                      fchs 
  00070B71  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  00070B77  8b 3e                      mov edi, dword ptr [esi]
  00070B79  ff 57 24                   call dword ptr [edi + 0x24]
  00070B7C  50                         push eax
  00070B7D  53                         push ebx
  00070B7E  8b ce                      mov ecx, esi
>>00070B80  ff 57 24                   call dword ptr [edi + 0x24]
  00070B83  5f                         pop edi
  00070B84  8b c3                      mov eax, ebx
  00070B86  5e                         pop esi
  00070B87  5b                         pop ebx
--- context around 0x70c1d (slot +0x24)
  00070BFB  d9 ff                      fcos 
  00070BFD  d9 96 e4 08 00 00          fst dword ptr [esi + 0x8e4]
  00070C03  d9 19                      fstp dword ptr [ecx]
  00070C05  d9 44 24 2c                fld dword ptr [esp + 0x2c]
  00070C09  d9 fe                      fsin 
  00070C0B  8b ce                      mov ecx, esi
  00070C0D  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  00070C13  d9 e0                      fchs 
  00070C15  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  00070C1B  8b 3e                      mov edi, dword ptr [esi]
>>00070C1D  ff 57 24                   call dword ptr [edi + 0x24]
  00070C20  50                         push eax
  00070C21  53                         push ebx
  00070C22  8b ce                      mov ecx, esi
  00070C24  ff 57 24                   call dword ptr [edi + 0x24]
--- context around 0x70c24 (slot +0x24)
  00070C09  d9 fe                      fsin 
  00070C0B  8b ce                      mov ecx, esi
  00070C0D  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  00070C13  d9 e0                      fchs 
  00070C15  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  00070C1B  8b 3e                      mov edi, dword ptr [esi]
  00070C1D  ff 57 24                   call dword ptr [edi + 0x24]
  00070C20  50                         push eax
  00070C21  53                         push ebx
  00070C22  8b ce                      mov ecx, esi
>>00070C24  ff 57 24                   call dword ptr [edi + 0x24]
  00070C27  5f                         pop edi
  00070C28  8b c3                      mov eax, ebx
  00070C2A  5e                         pop esi
  00070C2B  5b                         pop ebx
--- context around 0x70d7d (slot +0x24)
  00070D5B  d9 ff                      fcos 
  00070D5D  d9 96 e4 08 00 00          fst dword ptr [esi + 0x8e4]
  00070D63  d9 19                      fstp dword ptr [ecx]
  00070D65  d9 44 24 2c                fld dword ptr [esp + 0x2c]
  00070D69  d9 fe                      fsin 
  00070D6B  8b ce                      mov ecx, esi
  00070D6D  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  00070D73  d9 e0                      fchs 
  00070D75  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  00070D7B  8b 3e                      mov edi, dword ptr [esi]
>>00070D7D  ff 57 24                   call dword ptr [edi + 0x24]
  00070D80  50                         push eax
  00070D81  53                         push ebx
  00070D82  8b ce                      mov ecx, esi
  00070D84  ff 57 24                   call dword ptr [edi + 0x24]
--- context around 0x70d84 (slot +0x24)
  00070D69  d9 fe                      fsin 
  00070D6B  8b ce                      mov ecx, esi
  00070D6D  d9 96 d4 08 00 00          fst dword ptr [esi + 0x8d4]
  00070D73  d9 e0                      fchs 
  00070D75  d9 9e e0 08 00 00          fstp dword ptr [esi + 0x8e0]
  00070D7B  8b 3e                      mov edi, dword ptr [esi]
  00070D7D  ff 57 24                   call dword ptr [edi + 0x24]
  00070D80  50                         push eax
  00070D81  53                         push ebx
  00070D82  8b ce                      mov ecx, esi
>>00070D84  ff 57 24                   call dword ptr [edi + 0x24]
  00070D87  5f                         pop edi
  00070D88  8b c3                      mov eax, ebx
  00070D8A  5e                         pop esi
  00070D8B  5b                         pop ebx
--- context around 0x9dedb (slot +0x18)
  0009DEBD  83 c4 08                   add esp, 8
  0009DEC0  c3                         ret 
  0009DEC1  8b 80 a0 00 00 00          mov eax, dword ptr [eax + 0xa0]   ; ent.ActorPointer?
  0009DEC7  8b 0d 24 a0 62 10          mov ecx, dword ptr [0x1062a024]
  0009DECD  8b 92 a0 00 00 00          mov edx, dword ptr [edx + 0xa0]   ; ent.ActorPointer?
  0009DED3  50                         push eax
  0009DED4  8b 46 0c                   mov eax, dword ptr [esi + 0xc]
  0009DED7  8b 39                      mov edi, dword ptr [ecx]
  0009DED9  52                         push edx
  0009DEDA  50                         push eax
>>0009DEDB  ff 57 18                   call dword ptr [edi + 0x18]
  0009DEDE  5f                         pop edi
  0009DEDF  5e                         pop esi
  0009DEE0  5d                         pop ebp
  0009DEE1  b0 01                      mov al, 1
--- context around 0xb4ff8 (slot +0x18)
  000B4FDC  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B4FE2  8b 3d 24 a0 62 10          mov edi, dword ptr [0x1062a024]
  000B4FE8  50                         push eax
  000B4FE9  51                         push ecx
  000B4FEA  6a 09                      push 9
  000B4FEC  8b 1f                      mov ebx, dword ptr [edi]
  000B4FEE  8b ce                      mov ecx, esi
  000B4FF0  e8 db aa ff ff             call 0x100afad0
  000B4FF5  50                         push eax
  000B4FF6  8b cf                      mov ecx, edi
>>000B4FF8  ff 53 18                   call dword ptr [ebx + 0x18]
  000B4FFB  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B5003  5f                         pop edi
  000B5004  5e                         pop esi
  000B5005  5b                         pop ebx
--- context around 0xb50e8 (slot +0x1c)
  000B50CC  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  000B50D2  8b 3d 24 a0 62 10          mov edi, dword ptr [0x1062a024]
  000B50D8  50                         push eax
  000B50D9  51                         push ecx
  000B50DA  6a 09                      push 9
  000B50DC  8b 1f                      mov ebx, dword ptr [edi]
  000B50DE  8b ce                      mov ecx, esi
  000B50E0  e8 eb a9 ff ff             call 0x100afad0
  000B50E5  50                         push eax
  000B50E6  8b cf                      mov ecx, edi
>>000B50E8  ff 53 1c                   call dword ptr [ebx + 0x1c]
  000B50EB  66 83 86 56 02 00 00 0d    add word ptr [esi + 0x256], 0xd
  000B50F3  5f                         pop edi
  000B50F4  5e                         pop esi
  000B50F5  5b                         pop ebx
--- context around 0xb7439 (slot +0x18)
  000B7421  57                         push edi
  000B7422  8b 3d 24 a0 62 10          mov edi, dword ptr [0x1062a024]
  000B7428  6a 00                      push 0
  000B742A  6a 00                      push 0
  000B742C  8b 1f                      mov ebx, dword ptr [edi]
  000B742E  51                         push ecx
  000B742F  8b ce                      mov ecx, esi
  000B7431  e8 9a 86 ff ff             call 0x100afad0
  000B7436  50                         push eax
  000B7437  8b cf                      mov ecx, edi
>>000B7439  ff 53 18                   call dword ptr [ebx + 0x18]
  000B743C  b8 06 00 00 00             mov eax, 6
  000B7441  5f                         pop edi
  000B7442  66 01 86 56 02 00 00       add word ptr [esi + 0x256], ax
  000B7449  5e                         pop esi
--- context around 0x210a22 (slot +0x24)
  00210A0A  c2 08 00                   ret 8
  00210A0D  8b 4e 54                   mov ecx, dword ptr [esi + 0x54]
  00210A10  8b 56 50                   mov edx, dword ptr [esi + 0x50]
  00210A13  57                         push edi
  00210A14  52                         push edx
  00210A15  8b 39                      mov edi, dword ptr [ecx]
  00210A17  8b ce                      mov ecx, esi
  00210A19  e8 f2 66 fe ff             call 0x101f7110
  00210A1E  8b 4e 54                   mov ecx, dword ptr [esi + 0x54]
  00210A21  50                         push eax
>>00210A22  ff 57 24                   call dword ptr [edi + 0x24]
  00210A25  84 c0                      test al, al
  00210A27  5f                         pop edi
  00210A28  74 0b                      je 0x10210a35
  00210A2A  e8 71 71 e2 ff             call 0x10037ba0
--- context around 0x2c710c (slot +0x24)
  002C70F1  8b 4e 3c                   mov ecx, dword ptr [esi + 0x3c]
  002C70F4  89 08                      mov dword ptr [eax], ecx
  002C70F6  8b 06                      mov eax, dword ptr [esi]
  002C70F8  8b 7c 24 14                mov edi, dword ptr [esp + 0x14]
  002C70FC  83 f8 04                   cmp eax, 4
  002C70FF  74 05                      je 0x102c7106
  002C7101  83 f8 05                   cmp eax, 5
  002C7104  75 0b                      jne 0x102c7111
  002C7106  ff 76 0c                   push dword ptr [esi + 0xc]
  002C7109  ff 77 28                   push dword ptr [edi + 0x28]
>>002C710C  ff 57 24                   call dword ptr [edi + 0x24]
  002C710F  59                         pop ecx
  002C7110  59                         pop ecx
  002C7111  83 3e 06                   cmp dword ptr [esi], 6
  002C7114  75 0b                      jne 0x102c7121
--- context around 0x2c74bf (slot +0x20)
  002C749A  83 f9 1d                   cmp ecx, 0x1d
  002C749D  0f 87 5e 03 00 00          ja 0x102c7801
  002C74A3  c1 e8 05                   shr eax, 5
  002C74A6  83 e0 1f                   and eax, 0x1f
  002C74A9  83 f8 1d                   cmp eax, 0x1d
  002C74AC  0f 87 4f 03 00 00          ja 0x102c7801
  002C74B2  8d 84 08 02 01 00 00       lea eax, [eax + ecx + 0x102]
  002C74B9  6a 04                      push 4
  002C74BB  50                         push eax
  002C74BC  ff 77 28                   push dword ptr [edi + 0x28]
>>002C74BF  ff 57 20                   call dword ptr [edi + 0x20]
  002C74C2  83 c4 0c                   add esp, 0xc
  002C74C5  89 46 0c                   mov dword ptr [esi + 0xc], eax
  002C74C8  85 c0                      test eax, eax
  002C74CA  0f 84 c2 03 00 00          je 0x102c7892
--- context around 0x2c7753 (slot +0x24)
  002C7731  ff 75 d4                   push dword ptr [ebp - 0x2c]
  002C7734  ff 75 f0                   push dword ptr [ebp - 0x10]
  002C7737  ff 75 ec                   push dword ptr [ebp - 0x14]
  002C773A  e8 3c 16 00 00             call 0x102c8d7b
  002C773F  83 c4 14                   add esp, 0x14
  002C7742  85 c0                      test eax, eax
  002C7744  0f 84 48 01 00 00          je 0x102c7892
  002C774A  ff 76 0c                   push dword ptr [esi + 0xc]
  002C774D  89 46 04                   mov dword ptr [esi + 4], eax
  002C7750  ff 77 28                   push dword ptr [edi + 0x28]
>>002C7753  ff 57 24                   call dword ptr [edi + 0x24]
  002C7756  59                         pop ecx
  002C7757  c7 06 06 00 00 00          mov dword ptr [esi], 6
  002C775D  59                         pop ecx
  002C775E  8b 45 08                   mov eax, dword ptr [ebp + 8]
--- context around 0x2c7834 (slot +0x24)
  002C7814  eb 64                      jmp 0x102c787a
  002C7816  8b 45 08                   mov eax, dword ptr [ebp + 8]
  002C7819  ff 75 10                   push dword ptr [ebp + 0x10]
  002C781C  89 46 20                   mov dword ptr [esi + 0x20], eax
  002C781F  8b 45 0c                   mov eax, dword ptr [ebp + 0xc]
  002C7822  89 46 1c                   mov dword ptr [esi + 0x1c], eax
  002C7825  83 67 04 00                and dword ptr [edi + 4], 0
  002C7829  e9 ce 00 00 00             jmp 0x102c78fc
  002C782E  ff 76 0c                   push dword ptr [esi + 0xc]
  002C7831  ff 77 28                   push dword ptr [edi + 0x28]
>>002C7834  ff 57 24                   call dword ptr [edi + 0x24]
  002C7837  8b 45 08                   mov eax, dword ptr [ebp + 8]
  002C783A  c7 06 09 00 00 00          mov dword ptr [esi], 9
  002C7840  c7 47 18 10 95 3c 10       mov dword ptr [edi + 0x18], 0x103c9510
  002C7847  89 46 20                   mov dword ptr [esi + 0x20], eax
--- context around 0x2c7882 (slot +0x24)
  002C7860  01 47 08                   add dword ptr [edi + 8], eax
  002C7863  8b 45 f8                   mov eax, dword ptr [ebp - 8]
  002C7866  89 46 34                   mov dword ptr [esi + 0x34], eax
  002C7869  e8 e2 1f 00 00             call 0x102c9850
  002C786E  83 c4 14                   add esp, 0x14
  002C7871  e9 9f 00 00 00             jmp 0x102c7915
  002C7876  83 7d f4 fd                cmp dword ptr [ebp - 0xc], -3
  002C787A  75 11                      jne 0x102c788d
  002C787C  ff 76 0c                   push dword ptr [esi + 0xc]
  002C787F  ff 77 28                   push dword ptr [edi + 0x28]
>>002C7882  ff 57 24                   call dword ptr [edi + 0x24]
  002C7885  59                         pop ecx
  002C7886  c7 06 09 00 00 00          mov dword ptr [esi], 9
  002C788C  59                         pop ecx
  002C788D  ff 75 f4                   push dword ptr [ebp - 0xc]
--- context around 0x3084f6 (slot +0x24)
  003084DB  8b 4e 3c                   mov ecx, dword ptr [esi + 0x3c]
  003084DE  89 08                      mov dword ptr [eax], ecx
  003084E0  8b 06                      mov eax, dword ptr [esi]
  003084E2  83 f8 04                   cmp eax, 4
  003084E5  8b 7c 24 14                mov edi, dword ptr [esp + 0x14]
  003084E9  74 05                      je 0x103084f0
  003084EB  83 f8 05                   cmp eax, 5
  003084EE  75 0b                      jne 0x103084fb
  003084F0  ff 76 0c                   push dword ptr [esi + 0xc]
  003084F3  ff 77 28                   push dword ptr [edi + 0x28]
>>003084F6  ff 57 24                   call dword ptr [edi + 0x24]
  003084F9  59                         pop ecx
  003084FA  59                         pop ecx
  003084FB  83 3e 06                   cmp dword ptr [esi], 6
  003084FE  75 0b                      jne 0x1030850b
```

## J. The Tpc B flag chain (E17)

Backs E17: the [vt+0x3D8] vcall target, the flag byte at actor+0x881, its writer and the CIB waist_type identification.

### J.1 Vtable slot +0x3D8: raw read of the vtable rows around rva 0x331318; the slot holds 0x100D04C0

Source file: `out3/probe_vt3d8.md`

```text
0x3312F8: 30 2a 08 10 40 2a 08 10 50 2a 08 10 60 2a 08 10  10082A30 10082A40 10082A50 10082A60  |0*..@*..P*..`*..|
0x331308: e0 fa 0c 10 10 fb 0c 10 20 fc 0c 10 50 ff 0c 10  100CFAE0 100CFB10 100CFC20 100CFF50  |........ ...P...|
0x331318: c0 04 0d 10 10 48 0a 10 20 48 0a 10 60 5b 08 10  100D04C0 100A4810 100A4820 10085B60  |.....H.. H..`[..|
0x331328: a0 5c 08 10 00 5d 08 10 40 47 0a 10 30 47 0a 10  10085CA0 10085D00 100A4740 100A4730  |.\...]..@G..0G..|
0x331338: 80 66 0d 10 70 67 0d 10 00 48 0a 10 30 48 0a 10  100D6680 100D6770 100A4800 100A4830  |.f..pg...H..0H..|
0x331348: 80 49 0a 10 90 49 0a 10 a0 49 0a 10 b0 49 0a 10  100A4980 100A4990 100A49A0 100A49B0  |.I...I...I...I..|
```

### J.2 The accessor @rva 0xD04C0: `lea eax,[ecx+0x878]; ret` (disasm.py --func 0xD04C0)

Source file: `out3/d_d04c0.md`

```text
; func 0xD025E..0xD05B7 (857 bytes), callers: 0
  000D025E  d8 0d 34 9d 32 10          fmul dword ptr [0x10329d34]
  000D0264  d9 c9                      fxch st(1)
  000D0266  d8 0d e4 9c 32 10          fmul dword ptr [0x10329ce4]
  000D026C  8b 17                      mov edx, dword ptr [edi]
  000D026E  8d 44 24 28                lea eax, [esp + 0x28]
  000D0272  de c1                      faddp st(1)
  000D0274  50                         push eax
  000D0275  6a 01                      push 1
  000D0277  8b cf                      mov ecx, edi
  000D0279  d9 5c 24 1c                fstp dword ptr [esp + 0x1c]
  000D027D  ff 92 c4 01 00 00          call dword ptr [edx + 0x1c4]
  000D0283  8d 4c 24 28                lea ecx, [esp + 0x28]
  000D0287  8d 54 24 38                lea edx, [esp + 0x38]
  000D028B  51                         push ecx
  000D028C  52                         push edx
  000D028D  e8 8e 4f f4 ff             call 0x10015220
  000D0292  8b c8                      mov ecx, eax
  000D0294  e8 e7 7e f5 ff             call 0x10028180
  000D0299  d9 44 24 38                fld dword ptr [esp + 0x38]
  000D029D  d8 44 24 14                fadd dword ptr [esp + 0x14]
  000D02A1  8d 44 24 28                lea eax, [esp + 0x28]
  000D02A5  8d 8c 24 84 00 00 00       lea ecx, [esp + 0x84]
  000D02AC  50                         push eax
  000D02AD  d9 5c 24 3c                fstp dword ptr [esp + 0x3c]
  000D02B1  e8 9a 7e f5 ff             call 0x10028150
  000D02B6  d9 44 24 34                fld dword ptr [esp + 0x34]
  000D02BA  d8 1d 2c a2 32 10          fcomp dword ptr [0x1032a22c]
  000D02C0  df e0                      fnstsw ax
  000D02C2  f6 c4 05                   test ah, 5
  000D02C5  7a 08                      jp 0x100d02cf
  000D02C7  c7 44 24 34 6f 12 83 3a    mov dword ptr [esp + 0x34], 0x3a83126f
  000D02CF  d9 05 1c 96 32 10          fld dword ptr [0x1032961c]
  000D02D5  d8 74 24 34                fdiv dword ptr [esp + 0x34]
  000D02D9  51                         push ecx
  000D02DA  8d 4c 24 2c                lea ecx, [esp + 0x2c]
  000D02DE  8d 54 24 2c                lea edx, [esp + 0x2c]
  000D02E2  d9 1c 24                   fstp dword ptr [esp]
  000D02E5  51                         push ecx
  000D02E6  52                         push edx
  000D02E7  e8 04 70 f5 ff             call 0x100272f0
  000D02EC  8b b4 24 d4 00 00 00       mov esi, dword ptr [esp + 0xd4]
  000D02F3  83 c4 0c                   add esp, 0xc
  000D02F6  8d 44 24 38                lea eax, [esp + 0x38]
  000D02FA  d9 06                      fld dword ptr [esi]
  000D02FC  d8 64 24 28                fsub dword ptr [esp + 0x28]
  000D0300  50                         push eax
  000D0301  d9 5c 24 1c                fstp dword ptr [esp + 0x1c]
  000D0305  d9 46 04                   fld dword ptr [esi + 4]
  000D0308  d8 64 24 30                fsub dword ptr [esp + 0x30]
  000D030C  d9 5c 24 20                fstp dword ptr [esp + 0x20]
  000D0310  d9 46 08                   fld dword ptr [esi + 8]
  000D0313  d8 64 24 34                fsub dword ptr [esp + 0x34]
  000D0317  d9 5c 24 24                fstp dword ptr [esp + 0x24]
  000D031B  e8 50 4f f4 ff             call 0x10015270
  000D0320  8b c8                      mov ecx, eax
  000D0322  e8 29 7e f5 ff             call 0x10028150
  000D0327  d9 05 1c 96 32 10          fld dword ptr [0x1032961c]
  000D032D  d8 74 24 44                fdiv dword ptr [esp + 0x44]
  000D0331  51                         push ecx
  000D0332  8d 4c 24 3c                lea ecx, [esp + 0x3c]
  000D0336  8d 54 24 3c                lea edx, [esp + 0x3c]
  000D033A  d9 1c 24                   fstp dword ptr [esp]
  000D033D  51                         push ecx
  000D033E  52                         push edx
  000D033F  e8 ac 6f f5 ff             call 0x100272f0
  000D0344  d9 44 24 44                fld dword ptr [esp + 0x44]
  000D0348  d8 64 24 34                fsub dword ptr [esp + 0x34]
  000D034C  83 c4 0c                   add esp, 0xc
  000D034F  d9 54 24 38                fst dword ptr [esp + 0x38]
  000D0353  d8 4c 24 38                fmul dword ptr [esp + 0x38]
  000D0357  d9 44 24 1c                fld dword ptr [esp + 0x1c]
  000D035B  d8 4c 24 1c                fmul dword ptr [esp + 0x1c]
  000D035F  d9 44 24 18                fld dword ptr [esp + 0x18]
  000D0363  d8 4c 24 18                fmul dword ptr [esp + 0x18]
  000D0367  de c1                      faddp st(1)
  000D0369  de d9                      fcompp 
  000D036B  df e0                      fnstsw ax
  000D036D  f6 c4 05                   test ah, 5
  000D0370  7a 1c                      jp 0x100d038e
  000D0372  d9 45 00                   fld dword ptr [ebp]
  000D0375  d8 5c 24 24                fcomp dword ptr [esp + 0x24]
  000D0379  df e0                      fnstsw ax
  000D037B  25 00 41 00 00             and eax, 0x4100
  000D0380  75 0c                      jne 0x100d038e
  000D0382  8b 44 24 24                mov eax, dword ptr [esp + 0x24]
  000D0386  c6 44 24 13 01             mov byte ptr [esp + 0x13], 1
  000D038B  89 45 00                   mov dword ptr [ebp], eax
  000D038E  8b 17                      mov edx, dword ptr [edi]
  000D0390  8d 44 24 28                lea eax, [esp + 0x28]
  000D0394  50                         push eax
  000D0395  6a 03                      push 3
  000D0397  8b cf                      mov ecx, edi
  000D0399  ff 92 c4 01 00 00          call dword ptr [edx + 0x1c4]
  000D039F  8d 4c 24 28                lea ecx, [esp + 0x28]
  000D03A3  8d 54 24 38                lea edx, [esp + 0x38]
  000D03A7  51                         push ecx
  000D03A8  52                         push edx
  000D03A9  e8 72 4e f4 ff             call 0x10015220
  000D03AE  8b c8                      mov ecx, eax
  000D03B0  e8 cb 7d f5 ff             call 0x10028180
  000D03B5  d9 44 24 38                fld dword ptr [esp + 0x38]
  000D03B9  d8 44 24 14                fadd dword ptr [esp + 0x14]
  000D03BD  8d 44 24 28                lea eax, [esp + 0x28]
  000D03C1  8d 8c 24 84 00 00 00       lea ecx, [esp + 0x84]
  000D03C8  50                         push eax
  000D03C9  d9 5c 24 3c                fstp dword ptr [esp + 0x3c]
  000D03CD  e8 7e 7d f5 ff             call 0x10028150
  000D03D2  d9 44 24 34                fld dword ptr [esp + 0x34]
  000D03D6  d8 1d 2c a2 32 10          fcomp dword ptr [0x1032a22c]
  000D03DC  df e0                      fnstsw ax
  000D03DE  f6 c4 05                   test ah, 5
  000D03E1  7a 08                      jp 0x100d03eb
  000D03E3  c7 44 24 34 6f 12 83 3a    mov dword ptr [esp + 0x34], 0x3a83126f
  000D03EB  d9 05 1c 96 32 10          fld dword ptr [0x1032961c]
  000D03F1  d8 74 24 34                fdiv dword ptr [esp + 0x34]
  000D03F5  51                         push ecx
  000D03F6  8d 4c 24 2c                lea ecx, [esp + 0x2c]
  000D03FA  8d 54 24 2c                lea edx, [esp + 0x2c]
  000D03FE  d9 1c 24                   fstp dword ptr [esp]
  000D0401  51                         push ecx
  000D0402  52                         push edx
  000D0403  e8 e8 6e f5 ff             call 0x100272f0
  000D0408  d9 06                      fld dword ptr [esi]
  000D040A  d8 64 24 34                fsub dword ptr [esp + 0x34]
  000D040E  83 c4 0c                   add esp, 0xc
  000D0411  8d 44 24 38                lea eax, [esp + 0x38]
  000D0415  50                         push eax
  000D0416  d9 5c 24 1c                fstp dword ptr [esp + 0x1c]
  000D041A  d9 46 04                   fld dword ptr [esi + 4]
  000D041D  d8 64 24 30                fsub dword ptr [esp + 0x30]
  000D0421  d9 5c 24 20                fstp dword ptr [esp + 0x20]
  000D0425  d9 46 08                   fld dword ptr [esi + 8]
  000D0428  d8 64 24 34                fsub dword ptr [esp + 0x34]
  000D042C  d9 5c 24 24                fstp dword ptr [esp + 0x24]
  000D0430  e8 3b 4e f4 ff             call 0x10015270
  000D0435  8b c8                      mov ecx, eax
  000D0437  e8 14 7d f5 ff             call 0x10028150
  000D043C  d9 05 1c 96 32 10          fld dword ptr [0x1032961c]
  000D0442  d8 74 24 44                fdiv dword ptr [esp + 0x44]
  000D0446  51                         push ecx
  000D0447  8d 4c 24 3c                lea ecx, [esp + 0x3c]
  000D044B  8d 54 24 3c                lea edx, [esp + 0x3c]
  000D044F  d9 1c 24                   fstp dword ptr [esp]
  000D0452  51                         push ecx
  000D0453  52                         push edx
  000D0454  e8 97 6e f5 ff             call 0x100272f0
  000D0459  d9 44 24 44                fld dword ptr [esp + 0x44]
  000D045D  d8 64 24 34                fsub dword ptr [esp + 0x34]
  000D0461  83 c4 0c                   add esp, 0xc
  000D0464  d9 c0                      fld st(0)
  000D0466  d8 c9                      fmul st(1)
  000D0468  d9 44 24 1c                fld dword ptr [esp + 0x1c]
  000D046C  d8 4c 24 1c                fmul dword ptr [esp + 0x1c]
  000D0470  d9 44 24 18                fld dword ptr [esp + 0x18]
  000D0474  d8 4c 24 18                fmul dword ptr [esp + 0x18]
  000D0478  de c1                      faddp st(1)
  000D047A  de d9                      fcompp 
  000D047C  df e0                      fnstsw ax
  000D047E  f6 c4 05                   test ah, 5
  000D0481  dd d8                      fstp st(0)
  000D0483  7a 1c                      jp 0x100d04a1
  000D0485  d9 45 00                   fld dword ptr [ebp]
  000D0488  d8 5c 24 24                fcomp dword ptr [esp + 0x24]
  000D048C  df e0                      fnstsw ax
  000D048E  25 00 41 00 00             and eax, 0x4100
  000D0493  75 0c                      jne 0x100d04a1
  000D0495  8b 44 24 24                mov eax, dword ptr [esp + 0x24]
  000D0499  c6 44 24 13 01             mov byte ptr [esp + 0x13], 1
  000D049E  89 45 00                   mov dword ptr [ebp], eax
  000D04A1  8d 8c 24 84 00 00 00       lea ecx, [esp + 0x84]
  000D04A8  e8 03 75 f5 ff             call 0x100279b0
  000D04AD  8a 44 24 13                mov al, byte ptr [esp + 0x13]
  000D04B1  5f                         pop edi
  000D04B2  5e                         pop esi
  000D04B3  5d                         pop ebp
  000D04B4  5b                         pop ebx
  000D04B5  81 c4 b4 00 00 00          add esp, 0xb4
  000D04BB  c2 08 00                   ret 8
  000D04BE  90                         nop 
  000D04BF  90                         nop 
  000D04C0  8d 81 78 08 00 00          lea eax, [ecx + 0x878]
  000D04C6  c3                         ret 
  000D04C7  90                         nop 
  000D04C8  90                         nop 
  000D04C9  90                         nop 
  000D04CA  90                         nop 
  000D04CB  90                         nop 
  000D04CC  90                         nop 
  000D04CD  90                         nop 
  000D04CE  90                         nop 
  000D04CF  90                         nop 
  000D04D0  83 ec 10                   sub esp, 0x10
  000D04D3  53                         push ebx
  000D04D4  56                         push esi
  000D04D5  8b f1                      mov esi, ecx
  000D04D7  57                         push edi
  000D04D8  8b 7c 24 20                mov edi, dword ptr [esp + 0x20]
  000D04DC  8b 1e                      mov ebx, dword ptr [esi]
  000D04DE  57                         push edi
  000D04DF  ff 93 b4 00 00 00          call dword ptr [ebx + 0xb4]
  000D04E5  25 ff 00 00 00             and eax, 0xff
  000D04EA  8b ce                      mov ecx, esi
  000D04EC  50                         push eax
  000D04ED  ff 93 c4 01 00 00          call dword ptr [ebx + 0x1c4]
  000D04F3  d9 86 c0 08 00 00          fld dword ptr [esi + 0x8c0]
  000D04F9  8b 44 24 28                mov eax, dword ptr [esp + 0x28]
  000D04FD  8b 4c 24 24                mov ecx, dword ptr [esp + 0x24]
  000D0501  d8 47 04                   fadd dword ptr [edi + 4]
  000D0504  50                         push eax
  000D0505  8d 54 24 10                lea edx, [esp + 0x10]
  000D0509  51                         push ecx
  000D050A  52                         push edx
  000D050B  57                         push edi
  000D050C  8b ce                      mov ecx, esi
  000D050E  d9 5f 04                   fstp dword ptr [edi + 4]
  000D0511  e8 ba 2b fb ff             call 0x100830d0
  000D0516  5f                         pop edi
  000D0517  5e                         pop esi
  000D0518  5b                         pop ebx
  000D0519  83 c4 10                   add esp, 0x10
  000D051C  c2 0c 00                   ret 0xc
  000D051F  90                         nop 
  000D0520  a0 c0 7f 48 10             mov al, byte ptr [0x10487fc0]
  000D0525  81 ec 18 01 00 00          sub esp, 0x118
  000D052B  84 c0                      test al, al
  000D052D  56                         push esi
  000D052E  8b f1                      mov esi, ecx
  000D0530  57                         push edi
  000D0531  8b 7e 70                   mov edi, dword ptr [esi + 0x70]
  000D0534  74 1e                      je 0x100d0554
  000D0536  85 ff                      test edi, edi
  000D0538  74 1a                      je 0x100d0554
  000D053A  b9 40 d6 47 10             mov ecx, 0x1047d640
  000D053F  e8 1c 10 fb ff             call 0x10081560
  000D0544  85 c0                      test eax, eax
  000D0546  74 0c                      je 0x100d0554
  000D0548  8b 48 70                   mov ecx, dword ptr [eax + 0x70]
  000D054B  e8 00 75 fc ff             call 0x10097a50
  000D0550  3b c7                      cmp eax, edi
  000D0552  74 76                      je 0x100d05ca
  000D0554  8b 06                      mov eax, dword ptr [esi]
  000D0556  8b ce                      mov ecx, esi
  000D0558  ff 90 60 02 00 00          call dword ptr [eax + 0x260]
  000D055E  84 c0                      test al, al
  000D0560  75 68                      jne 0x100d05ca
  000D0562  8b ce                      mov ecx, esi
  000D0564  e8 57 40 fb ff             call 0x100845c0
  000D0569  85 c0                      test eax, eax
  000D056B  75 5d                      jne 0x100d05ca
  000D056D  8b 16                      mov edx, dword ptr [esi]
  000D056F  8b ce                      mov ecx, esi
  000D0571  ff 92 4c 03 00 00          call dword ptr [edx + 0x34c]
  000D0577  85 c0                      test eax, eax
  000D0579  75 4f                      jne 0x100d05ca
  000D057B  8b 06                      mov eax, dword ptr [esi]
  000D057D  8b ce                      mov ecx, esi
  000D057F  ff 90 58 03 00 00          call dword ptr [eax + 0x358]
  000D0585  85 c0                      test eax, eax
  000D0587  75 41                      jne 0x100d05ca
  000D0589  85 ff                      test edi, edi
  000D058B  74 0b                      je 0x100d0598
  000D058D  8b cf                      mov ecx, edi
  000D058F  e8 9c 7d fc ff             call 0x10098330
  000D0594  84 c0                      test al, al
  000D0596  75 32                      jne 0x100d05ca
  000D0598  a0 d4 d6 47 10             mov al, byte ptr [0x1047d6d4]
  000D059D  84 c0                      test al, al
  000D059F  74 7a                      je 0x100d061b
  000D05A1  8b 7e 70                   mov edi, dword ptr [esi + 0x70]
  000D05A4  33 c0                      xor eax, eax
  000D05A6  a0 d5 d6 47 10             mov al, byte ptr [0x1047d6d5]
  000D05AB  83 f8 04                   cmp eax, 4
  000D05AE  77 6b                      ja 0x100d061b
  000D05B0  ff 24 85 e0 06 0d 10       jmp dword ptr [eax*4 + 0x100d06e0]
```

### J.3 xref.py --disp 0x881: all twelve disp-0x881 sites in eleven funcs; the two writers are @rva 0xCF419 and 0xD0C5B

Source file: `out3/x_881.md`

```text
memory operands with disp 0x881: 12 sites in 11 funcs
- func 0xCF34B (2): 0xCF40F mov dl, byte ptr [esi + 0x881] | 0xCF419 mov byte ptr [esi + 0x881], cl
- func 0xCD5F8 (1): 0xCD5FD mov al, byte ptr [esi + 0x881]
- func 0xCD7DC (1): 0xCD7E1 mov al, byte ptr [esi + 0x881]
- func 0xD0C58 (1): 0xD0C5B mov byte ptr [esi + 0x881], cl
- func 0xD1D8D (1): 0xD1DA1 mov al, byte ptr [esi + 0x881]
- func 0xD2047 (1): 0xD205B mov al, byte ptr [esi + 0x881]
- func 0xD25CC (1): 0xD2608 mov dl, byte ptr [ebp + 0x881]
- func 0xD292B (1): 0xD2954 cmp byte ptr [esi + 0x881], 1
- func 0xD2AE3 (1): 0xD2B0C mov al, byte ptr [esi + 0x881]
- func 0xD2C93 (1): 0xD2CBC mov al, byte ptr [esi + 0x881]
- func 0xD2D61 (1): 0xD2D8F movsx eax, byte ptr [ecx + 0x881]
```

### J.4 Vtable slots holding the writer @rva 0xCF220: slot +0x290 of four vtables (incl. the skeleton-actor family @0x330F40) plus slots +0x6B0/+0xAD0/+0xEF0 of the larger vtable @0x32E890

Source file: `out3/vt_cf220.md`

```text
hit 0x32d9a0: vtable [0x32d710 .. 0x32db30) len=264, our func at slot +0x290
hit 0x32eb20: vtable [0x32e890 .. 0x32f910) len=1056, our func at slot +0x290
hit 0x32ef40: vtable [0x32e890 .. 0x32f910) len=1056, our func at slot +0x6b0
hit 0x32f360: vtable [0x32e890 .. 0x32f910) len=1056, our func at slot +0xad0
hit 0x32f780: vtable [0x32e890 .. 0x32f910) len=1056, our func at slot +0xef0
hit 0x3311d0: vtable [0x330f40 .. 0x331360) len=264, our func at slot +0x290
hit 0x331678: vtable [0x3313e8 .. 0x331808) len=264, our func at slot +0x290
```

### J.5 Resource-load path pushing types 0x29/0x2A (raw dump from rva 0xCF182)

Source file: `out3/d_cf180.md`

```text
  000CF182  7c f2                      jl 0x100cf176
  000CF184  5f                         pop edi
  000CF185  5e                         pop esi
  000CF186  c2 04 00                   ret 4
  000CF189  90                         nop 
  000CF18A  90                         nop 
  000CF18B  90                         nop 
  000CF18C  90                         nop 
  000CF18D  90                         nop 
  000CF18E  90                         nop 
  000CF18F  90                         nop 
  000CF190  56                         push esi
  000CF191  8b f1                      mov esi, ecx
  000CF193  8b 4e 70                   mov ecx, dword ptr [esi + 0x70]
  000CF196  85 c9                      test ecx, ecx
  000CF198  74 12                      je 0x100cf1ac
  000CF19A  68 ff 00 00 00             push 0xff
  000CF19F  e8 2c 65 fc ff             call 0x100956d0
  000CF1A4  84 c0                      test al, al
  000CF1A6  74 04                      je 0x100cf1ac
  000CF1A8  b0 01                      mov al, 1
  000CF1AA  eb 02                      jmp 0x100cf1ae
  000CF1AC  32 c0                      xor al, al
  000CF1AE  84 c0                      test al, al
  000CF1B0  8b ce                      mov ecx, esi
  000CF1B2  6a 00                      push 0
  000CF1B4  74 0b                      je 0x100cf1c1
  000CF1B6  e8 b5 6e 00 00             call 0x100d6070
  000CF1BB  b0 01                      mov al, 1
  000CF1BD  5e                         pop esi
  000CF1BE  c2 04 00                   ret 4
  000CF1C1  e8 3a 70 00 00             call 0x100d6200
  000CF1C6  b0 01                      mov al, 1
  000CF1C8  5e                         pop esi
  000CF1C9  c2 04 00                   ret 4
  000CF1CC  90                         nop 
  000CF1CD  90                         nop 
  000CF1CE  90                         nop 
  000CF1CF  90                         nop 
  000CF1D0  c7 44 24 04 00 00 00 00    mov dword ptr [esp + 4], 0
  000CF1D8  e9 23 70 00 00             jmp 0x100d6200
  000CF1DD  90                         nop 
  000CF1DE  90                         nop 
  000CF1DF  90                         nop 
  000CF1E0  8b 44 24 08                mov eax, dword ptr [esp + 8]
  000CF1E4  8b 91 1c 08 00 00          mov edx, dword ptr [ecx + 0x81c]
  000CF1EA  3b d0                      cmp edx, eax
  000CF1EC  74 10                      je 0x100cf1fe
  000CF1EE  89 81 1c 08 00 00          mov dword ptr [ecx + 0x81c], eax
  000CF1F4  8b 44 24 0c                mov eax, dword ptr [esp + 0xc]
  000CF1F8  89 81 20 08 00 00          mov dword ptr [ecx + 0x820], eax
  000CF1FE  c2 0c 00                   ret 0xc
  000CF201  90                         nop 
  000CF202  90                         nop 
  000CF203  90                         nop 
  000CF204  90                         nop 
  000CF205  90                         nop 
  000CF206  90                         nop 
  000CF207  90                         nop 
  000CF208  90                         nop 
  000CF209  90                         nop 
  000CF20A  90                         nop 
  000CF20B  90                         nop 
  000CF20C  90                         nop 
  000CF20D  90                         nop 
  000CF20E  90                         nop 
  000CF20F  90                         nop 
  000CF210  81 c1 74 06 00 00          add ecx, 0x674
  000CF216  e9 55 d4 f5 ff             jmp 0x1002c670
  000CF21B  90                         nop 
  000CF21C  90                         nop 
  000CF21D  90                         nop 
  000CF21E  90                         nop 
  000CF21F  90                         nop 
  000CF220  83 ec 20                   sub esp, 0x20
  000CF223  55                         push ebp
  000CF224  8b 6c 24 28                mov ebp, dword ptr [esp + 0x28]
  000CF228  56                         push esi
  000CF229  57                         push edi
  000CF22A  8b f1                      mov esi, ecx
  000CF22C  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  000CF232  55                         push ebp
  000CF233  e8 88 3d fa ff             call 0x10072fc0
  000CF238  6a 00                      push 0
  000CF23A  6a 29                      push 0x29
  000CF23C  8d 4c 24 14                lea ecx, [esp + 0x14]
  000CF240  50                         push eax
  000CF241  51                         push ecx
  000CF242  8b c8                      mov ecx, eax
  000CF244  e8 f7 31 fa ff             call 0x10072440
  000CF249  8b 44 24 0c                mov eax, dword ptr [esp + 0xc]
  000CF24D  85 c0                      test eax, eax
  000CF24F  0f 84 c7 04 00 00          je 0x100cf71c
  000CF255  8d 8e 74 06 00 00          lea ecx, [esi + 0x674]
  000CF25B  e8 50 c4 f5 ff             call 0x1002b6b0
  000CF260  8b f8                      mov edi, eax
  000CF262  85 ff                      test edi, edi
  000CF264  0f 84 e4 04 00 00          je 0x100cf74e
  000CF26A  8b 54 24 0c                mov edx, dword ptr [esp + 0xc]
  000CF26E  8b cf                      mov ecx, edi
  000CF270  52                         push edx
  000CF271  e8 ea ab f5 ff             call 0x10029e60
  000CF276  8b 44 24 0c                mov eax, dword ptr [esp + 0xc]
  000CF27A  8b 08                      mov ecx, dword ptr [eax]
  000CF27C  e8 1f 2c fa ff             call 0x10071ea0
  000CF281  85 ed                      test ebp, ebp
  000CF283  74 05                      je 0x100cf28a
  000CF285  8b 45 00                   mov eax, dword ptr [ebp]
  000CF288  eb 02                      jmp 0x100cf28c
  000CF28A  33 c0                      xor eax, eax
  000CF28C  6a ff                      push -1
  000CF28E  6a 00                      push 0
  000CF290  6a 2a                      push 0x2a
  000CF292  50                         push eax
  000CF293  8d 4c 24 20                lea ecx, [esp + 0x20]
  000CF297  e8 24 50 fa ff             call 0x100742c0
  000CF29C  8b 44 24 24                mov eax, dword ptr [esp + 0x24]
  000CF2A0  85 c0                      test eax, eax
  000CF2A2  74 2d                      je 0x100cf2d1
  000CF2A4  8b 40 14                   mov eax, dword ptr [eax + 0x14]
  000CF2A7  8b cf                      mov ecx, edi
  000CF2A9  50                         push eax
  000CF2AA  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000CF2AE  e8 cd ac f5 ff             call 0x10029f80
  000CF2B3  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000CF2B7  8b 09                      mov ecx, dword ptr [ecx]
  000CF2B9  e8 e2 2b fa ff             call 0x10071ea0
  000CF2BE  6a 00                      push 0
```

### J.6 Same path pushing type 0x45 @rva 0xCF2F2 (raw dump from rva 0xCF2C0)

Source file: `out3/d_cf2c0.md`

```text
  000CF2C0  8d 4c 24 14                lea ecx, [esp + 0x14]
  000CF2C4  e8 07 53 fa ff             call 0x100745d0
  000CF2C9  8b 44 24 24                mov eax, dword ptr [esp + 0x24]
  000CF2CD  85 c0                      test eax, eax
  000CF2CF  75 d3                      jne 0x100cf2a4
  000CF2D1  8b 16                      mov edx, dword ptr [esi]
  000CF2D3  8b ce                      mov ecx, esi
  000CF2D5  ff 92 58 03 00 00          call dword ptr [edx + 0x358]
  000CF2DB  85 c0                      test eax, eax
  000CF2DD  0f 95 44 24 30             setne byte ptr [esp + 0x30]
  000CF2E2  85 ed                      test ebp, ebp
  000CF2E4  74 05                      je 0x100cf2eb
  000CF2E6  8b 45 00                   mov eax, dword ptr [ebp]
  000CF2E9  eb 02                      jmp 0x100cf2ed
  000CF2EB  33 c0                      xor eax, eax
  000CF2ED  53                         push ebx
  000CF2EE  6a ff                      push -1
  000CF2F0  6a 00                      push 0
  000CF2F2  6a 45                      push 0x45
  000CF2F4  50                         push eax
  000CF2F5  8d 4c 24 24                lea ecx, [esp + 0x24]
  000CF2F9  e8 c2 4f fa ff             call 0x100742c0
  000CF2FE  8b 44 24 28                mov eax, dword ptr [esp + 0x28]
  000CF302  bb ff 00 00 00             mov ebx, 0xff
  000CF307  85 c0                      test eax, eax
  000CF309  0f 84 dd 01 00 00          je 0x100cf4ec
  000CF30F  85 c0                      test eax, eax
  000CF311  8b e8                      mov ebp, eax
  000CF313  0f 84 bc 01 00 00          je 0x100cf4d5
  000CF319  8a 4c 24 34                mov cl, byte ptr [esp + 0x34]
  000CF31D  84 c9                      test cl, cl
  000CF31F  74 46                      je 0x100cf367
  000CF321  81 78 20 6d 6f 75 6e       cmp dword ptr [eax + 0x20], 0x6e756f6d   ; fourcc? 'moun'
  000CF328  75 21                      jne 0x100cf34b
  000CF32A  8d be 78 08 00 00          lea edi, [esi + 0x878]
  000CF330  83 c0 30                   add eax, 0x30
  000CF333  50                         push eax
  000CF334  8b cf                      mov ecx, edi
  000CF336  e8 45 2f f5 ff             call 0x10022280
  000CF33B  83 c5 38                   add ebp, 0x38
  000CF33E  8b cf                      mov ecx, edi
  000CF340  55                         push ebp
  000CF341  e8 ca 2f f5 ff             call 0x10022310
  000CF346  e9 8a 01 00 00             jmp 0x100cf4d5
  000CF34B  8a 48 3f                   mov cl, byte ptr [eax + 0x3f]
  000CF34E  80 f9 ff                   cmp cl, 0xff
  000CF351  74 06                      je 0x100cf359
  000CF353  88 8e 9c 08 00 00          mov byte ptr [esi + 0x89c], cl
  000CF359  8a 48 3e                   mov cl, byte ptr [eax + 0x3e]
  000CF35C  80 f9 ff                   cmp cl, 0xff
  000CF35F  74 06                      je 0x100cf367
  000CF361  88 8e 9d 08 00 00          mov byte ptr [esi + 0x89d], cl
  000CF367  8a 48 30                   mov cl, byte ptr [eax + 0x30]
  000CF36A  84 c9                      test cl, cl
  000CF36C  7c 10                      jl 0x100cf37e
  000CF36E  8a 96 78 08 00 00          mov dl, byte ptr [esi + 0x878]
  000CF374  84 d2                      test dl, dl
  000CF376  7d 06                      jge 0x100cf37e
  000CF378  88 8e 78 08 00 00          mov byte ptr [esi + 0x878], cl
  000CF37E  8a 48 31                   mov cl, byte ptr [eax + 0x31]
  000CF381  84 c9                      test cl, cl
  000CF383  7c 10                      jl 0x100cf395
  000CF385  8a 96 79 08 00 00          mov dl, byte ptr [esi + 0x879]
  000CF38B  84 d2                      test dl, dl
  000CF38D  7d 06                      jge 0x100cf395
  000CF38F  88 8e 79 08 00 00          mov byte ptr [esi + 0x879], cl
  000CF395  8a 48 32                   mov cl, byte ptr [eax + 0x32]
  000CF398  84 c9                      test cl, cl
  000CF39A  7c 10                      jl 0x100cf3ac
  000CF39C  8a 96 7a 08 00 00          mov dl, byte ptr [esi + 0x87a]
  000CF3A2  84 d2                      test dl, dl
  000CF3A4  7d 06                      jge 0x100cf3ac
  000CF3A6  88 8e 7a 08 00 00          mov byte ptr [esi + 0x87a], cl
  000CF3AC  8a 48 33                   mov cl, byte ptr [eax + 0x33]
  000CF3AF  84 c9                      test cl, cl
  000CF3B1  7c 10                      jl 0x100cf3c3
  000CF3B3  8a 96 7b 08 00 00          mov dl, byte ptr [esi + 0x87b]
  000CF3B9  84 d2                      test dl, dl
  000CF3BB  7d 06                      jge 0x100cf3c3
  000CF3BD  88 8e 7b 08 00 00          mov byte ptr [esi + 0x87b], cl
  000CF3C3  8a 48 34                   mov cl, byte ptr [eax + 0x34]
  000CF3C6  84 c9                      test cl, cl
  000CF3C8  7c 10                      jl 0x100cf3da
  000CF3CA  8a 96 7c 08 00 00          mov dl, byte ptr [esi + 0x87c]
```

### J.7 The CIB merge loop @rva 0xCF34B: source byte +0x39 -> actor+0x881 with the src < 0x80 / dest >= 0x80 sentinel guards (disasm.py --func 0xCF34B)

Source file: `out3/d_cf34b.md`

```text
; func 0xCF34B..0xCF498 (333 bytes), callers: 0
  000CF34B  8a 48 3f                   mov cl, byte ptr [eax + 0x3f]
  000CF34E  80 f9 ff                   cmp cl, 0xff
  000CF351  74 06                      je 0x100cf359
  000CF353  88 8e 9c 08 00 00          mov byte ptr [esi + 0x89c], cl
  000CF359  8a 48 3e                   mov cl, byte ptr [eax + 0x3e]
  000CF35C  80 f9 ff                   cmp cl, 0xff
  000CF35F  74 06                      je 0x100cf367
  000CF361  88 8e 9d 08 00 00          mov byte ptr [esi + 0x89d], cl
  000CF367  8a 48 30                   mov cl, byte ptr [eax + 0x30]
  000CF36A  84 c9                      test cl, cl
  000CF36C  7c 10                      jl 0x100cf37e
  000CF36E  8a 96 78 08 00 00          mov dl, byte ptr [esi + 0x878]
  000CF374  84 d2                      test dl, dl
  000CF376  7d 06                      jge 0x100cf37e
  000CF378  88 8e 78 08 00 00          mov byte ptr [esi + 0x878], cl
  000CF37E  8a 48 31                   mov cl, byte ptr [eax + 0x31]
  000CF381  84 c9                      test cl, cl
  000CF383  7c 10                      jl 0x100cf395
  000CF385  8a 96 79 08 00 00          mov dl, byte ptr [esi + 0x879]
  000CF38B  84 d2                      test dl, dl
  000CF38D  7d 06                      jge 0x100cf395
  000CF38F  88 8e 79 08 00 00          mov byte ptr [esi + 0x879], cl
  000CF395  8a 48 32                   mov cl, byte ptr [eax + 0x32]
  000CF398  84 c9                      test cl, cl
  000CF39A  7c 10                      jl 0x100cf3ac
  000CF39C  8a 96 7a 08 00 00          mov dl, byte ptr [esi + 0x87a]
  000CF3A2  84 d2                      test dl, dl
  000CF3A4  7d 06                      jge 0x100cf3ac
  000CF3A6  88 8e 7a 08 00 00          mov byte ptr [esi + 0x87a], cl
  000CF3AC  8a 48 33                   mov cl, byte ptr [eax + 0x33]
  000CF3AF  84 c9                      test cl, cl
  000CF3B1  7c 10                      jl 0x100cf3c3
  000CF3B3  8a 96 7b 08 00 00          mov dl, byte ptr [esi + 0x87b]
  000CF3B9  84 d2                      test dl, dl
  000CF3BB  7d 06                      jge 0x100cf3c3
  000CF3BD  88 8e 7b 08 00 00          mov byte ptr [esi + 0x87b], cl
  000CF3C3  8a 48 34                   mov cl, byte ptr [eax + 0x34]
  000CF3C6  84 c9                      test cl, cl
  000CF3C8  7c 10                      jl 0x100cf3da
  000CF3CA  8a 96 7c 08 00 00          mov dl, byte ptr [esi + 0x87c]
  000CF3D0  84 d2                      test dl, dl
  000CF3D2  7d 06                      jge 0x100cf3da
  000CF3D4  88 8e 7c 08 00 00          mov byte ptr [esi + 0x87c], cl
  000CF3DA  8a 48 38                   mov cl, byte ptr [eax + 0x38]
  000CF3DD  84 c9                      test cl, cl
  000CF3DF  7c 10                      jl 0x100cf3f1
  000CF3E1  8a 96 89 08 00 00          mov dl, byte ptr [esi + 0x889]
  000CF3E7  84 d2                      test dl, dl
  000CF3E9  7d 06                      jge 0x100cf3f1
  000CF3EB  88 8e 89 08 00 00          mov byte ptr [esi + 0x889], cl
  000CF3F1  8a 48 35                   mov cl, byte ptr [eax + 0x35]
  000CF3F4  84 c9                      test cl, cl
  000CF3F6  7c 10                      jl 0x100cf408
  000CF3F8  8a 96 7d 08 00 00          mov dl, byte ptr [esi + 0x87d]
  000CF3FE  84 d2                      test dl, dl
  000CF400  7d 06                      jge 0x100cf408
  000CF402  88 8e 7d 08 00 00          mov byte ptr [esi + 0x87d], cl
  000CF408  8a 48 39                   mov cl, byte ptr [eax + 0x39]
  000CF40B  84 c9                      test cl, cl
  000CF40D  7c 10                      jl 0x100cf41f
  000CF40F  8a 96 81 08 00 00          mov dl, byte ptr [esi + 0x881]
  000CF415  84 d2                      test dl, dl
  000CF417  7d 06                      jge 0x100cf41f
  000CF419  88 8e 81 08 00 00          mov byte ptr [esi + 0x881], cl
  000CF41F  38 9e 82 08 00 00          cmp byte ptr [esi + 0x882], bl
  000CF425  75 09                      jne 0x100cf430
  000CF427  8a 48 3a                   mov cl, byte ptr [eax + 0x3a]
  000CF42A  88 8e 82 08 00 00          mov byte ptr [esi + 0x882], cl
  000CF430  38 9e 83 08 00 00          cmp byte ptr [esi + 0x883], bl
  000CF436  75 09                      jne 0x100cf441
  000CF438  8a 50 3b                   mov dl, byte ptr [eax + 0x3b]
  000CF43B  88 96 83 08 00 00          mov byte ptr [esi + 0x883], dl
  000CF441  38 9e 84 08 00 00          cmp byte ptr [esi + 0x884], bl
  000CF447  75 09                      jne 0x100cf452
  000CF449  8a 48 3c                   mov cl, byte ptr [eax + 0x3c]
  000CF44C  88 8e 84 08 00 00          mov byte ptr [esi + 0x884], cl
  000CF452  38 9e 85 08 00 00          cmp byte ptr [esi + 0x885], bl
  000CF458  75 09                      jne 0x100cf463
  000CF45A  8a 50 3d                   mov dl, byte ptr [eax + 0x3d]
  000CF45D  88 96 85 08 00 00          mov byte ptr [esi + 0x885], dl
  000CF463  8a 48 3e                   mov cl, byte ptr [eax + 0x3e]
  000CF466  84 c9                      test cl, cl
  000CF468  7c 10                      jl 0x100cf47a
  000CF46A  8a 96 86 08 00 00          mov dl, byte ptr [esi + 0x886]
  000CF470  84 d2                      test dl, dl
  000CF472  7d 06                      jge 0x100cf47a
  000CF474  88 8e 86 08 00 00          mov byte ptr [esi + 0x886], cl
  000CF47A  8a 48 36                   mov cl, byte ptr [eax + 0x36]
  000CF47D  84 c9                      test cl, cl
  000CF47F  7c 27                      jl 0x100cf4a8
  000CF481  80 f9 79                   cmp cl, 0x79
  000CF484  7c 12                      jl 0x100cf498
  000CF486  8a 96 88 08 00 00          mov dl, byte ptr [esi + 0x888]
  000CF48C  84 d2                      test dl, dl
  000CF48E  7d 18                      jge 0x100cf4a8
  000CF490  88 8e 88 08 00 00          mov byte ptr [esi + 0x888], cl
  000CF496  eb 10                      jmp 0x100cf4a8
```

### J.8 Tail of the CIB merge loop: further guarded byte merges into actor+0x87E.. (raw dump from rva 0xCF498)

Source file: `out3/d_cf4a8.md`

```text
  000CF498  8a 96 7e 08 00 00          mov dl, byte ptr [esi + 0x87e]
  000CF49E  84 d2                      test dl, dl
  000CF4A0  7d 06                      jge 0x100cf4a8
  000CF4A2  88 8e 7e 08 00 00          mov byte ptr [esi + 0x87e], cl
  000CF4A8  8a 40 3f                   mov al, byte ptr [eax + 0x3f]
  000CF4AB  84 c0                      test al, al
  000CF4AD  7c 26                      jl 0x100cf4d5
  000CF4AF  3c 79                      cmp al, 0x79
  000CF4B1  7c 12                      jl 0x100cf4c5
  000CF4B3  8a 8e 88 08 00 00          mov cl, byte ptr [esi + 0x888]
  000CF4B9  84 c9                      test cl, cl
  000CF4BB  7d 18                      jge 0x100cf4d5
  000CF4BD  88 86 88 08 00 00          mov byte ptr [esi + 0x888], al
  000CF4C3  eb 10                      jmp 0x100cf4d5
  000CF4C5  8a 8e 7e 08 00 00          mov cl, byte ptr [esi + 0x87e]
  000CF4CB  84 c9                      test cl, cl
  000CF4CD  7d 06                      jge 0x100cf4d5
  000CF4CF  88 86 7e 08 00 00          mov byte ptr [esi + 0x87e], al
  000CF4D5  6a 00                      push 0
  000CF4D7  8d 4c 24 18                lea ecx, [esp + 0x18]
  000CF4DB  e8 f0 50 fa ff             call 0x100745d0
  000CF4E0  8b 44 24 28                mov eax, dword ptr [esp + 0x28]
  000CF4E4  85 c0                      test eax, eax
  000CF4E6  0f 85 23 fe ff ff          jne 0x100cf30f
  000CF4EC  8b 06                      mov eax, dword ptr [esi]
  000CF4EE  8b ce                      mov ecx, esi
  000CF4F0  ff 90 4c 03 00 00          call dword ptr [eax + 0x34c]
  000CF4F6  85 c0                      test eax, eax
  000CF4F8  0f 85 77 01 00 00          jne 0x100cf675
  000CF4FE  8b 16                      mov edx, dword ptr [esi]
  000CF500  8b ce                      mov ecx, esi
  000CF502  ff 92 58 03 00 00          call dword ptr [edx + 0x358]
  000CF508  85 c0                      test eax, eax
  000CF50A  0f 85 65 01 00 00          jne 0x100cf675
  000CF510  8b 06                      mov eax, dword ptr [esi]
  000CF512  8b ce                      mov ecx, esi
  000CF514  ff 90 60 03 00 00          call dword ptr [eax + 0x360]
  000CF51A  85 c0                      test eax, eax
  000CF51C  74 32                      je 0x100cf550
  000CF51E  8b be 68 07 00 00          mov edi, dword ptr [esi + 0x768]
  000CF524  85 ff                      test edi, edi
  000CF526  74 1e                      je 0x100cf546
  000CF528  8b cf                      mov ecx, edi
  000CF52A  e8 e1 4f fb ff             call 0x10084510
  000CF52F  50                         push eax
  000CF530  8d 8f 78 08 00 00          lea ecx, [edi + 0x878]
  000CF536  e8 f5 2b f5 ff             call 0x10022130
  000CF53B  d9 9e 54 07 00 00          fstp dword ptr [esi + 0x754]
  000CF541  e9 85 01 00 00             jmp 0x100cf6cb
  000CF546  68 74 f9 35 10             push 0x1035f974
  000CF54B  e9 73 01 00 00             jmp 0x100cf6c3
  000CF550  8b 16                      mov edx, dword ptr [esi]
  000CF552  8b ce                      mov ecx, esi
  000CF554  ff 92 94 03 00 00          call dword ptr [edx + 0x394]
  000CF55A  85 c0                      test eax, eax
  000CF55C  74 2e                      je 0x100cf58c
  000CF55E  8b 8e 90 07 00 00          mov ecx, dword ptr [esi + 0x790]
  000CF564  85 c9                      test ecx, ecx
  000CF566  74 1a                      je 0x100cf582
  000CF568  e8 e3 4f fb ff             call 0x10084550
  000CF56D  d9 9e 54 07 00 00          fstp dword ptr [esi + 0x754]
  000CF573  c7 86 5c 07 00 00 00 00 80 3f mov dword ptr [esi + 0x75c], 0x3f800000
  000CF57D  e9 49 01 00 00             jmp 0x100cf6cb
  000CF582  68 38 f9 35 10             push 0x1035f938
  000CF587  e9 37 01 00 00             jmp 0x100cf6c3
  000CF58C  8b 06                      mov eax, dword ptr [esi]
  000CF58E  8b ce                      mov ecx, esi
  000CF590  ff 90 a4 03 00 00          call dword ptr [eax + 0x3a4]
  000CF596  85 c0                      test eax, eax
  000CF598  74 0f                      je 0x100cf5a9
  000CF59A  c7 86 54 07 00 00 00 00 00 00 mov dword ptr [esi + 0x754], 0
  000CF5A4  e9 22 01 00 00             jmp 0x100cf6cb
  000CF5A9  8b 16                      mov edx, dword ptr [esi]
  000CF5AB  8b ce                      mov ecx, esi
  000CF5AD  ff 92 6c 03 00 00          call dword ptr [edx + 0x36c]
  000CF5B3  85 c0                      test eax, eax
  000CF5B5  74 7d                      je 0x100cf634
  000CF5B7  8b be 68 07 00 00          mov edi, dword ptr [esi + 0x768]
  000CF5BD  85 ff                      test edi, edi
  000CF5BF  74 69                      je 0x100cf62a
  000CF5C1  8b cf                      mov ecx, edi
  000CF5C3  8d 9e 78 08 00 00          lea ebx, [esi + 0x878]
  000CF5C9  e8 62 4e fb ff             call 0x10084430
  000CF5CE  50                         push eax
  000CF5CF  8b cb                      mov ecx, ebx
  000CF5D1  e8 ca 2b f5 ff             call 0x100221a0
  000CF5D6  d9 5c 24 34                fstp dword ptr [esp + 0x34]
  000CF5DA  8b cf                      mov ecx, edi
  000CF5DC  e8 4f 4e fb ff             call 0x10084430
  000CF5E1  50                         push eax
  000CF5E2  8b cb                      mov ecx, ebx
  000CF5E4  e8 07 2c f5 ff             call 0x100221f0
  000CF5E9  8b 44 24 34                mov eax, dword ptr [esp + 0x34]
  000CF5ED  8b cf                      mov ecx, edi
  000CF5EF  d9 9e 58 07 00 00          fstp dword ptr [esi + 0x758]
  000CF5F5  89 86 60 07 00 00          mov dword ptr [esi + 0x760], eax
  000CF5FB  8d 9f 78 08 00 00          lea ebx, [edi + 0x878]
  000CF601  e8 0a 4f fb ff             call 0x10084510
  000CF606  50                         push eax
  000CF607  8b cb                      mov ecx, ebx
  000CF609  e8 22 2b f5 ff             call 0x10022130
  000CF60E  d9 5c 24 34                fstp dword ptr [esp + 0x34]
  000CF612  6a 01                      push 1
  000CF614  8b cb                      mov ecx, ebx
  000CF616  e8 15 2b f5 ff             call 0x10022130
  000CF61B  d8 7c 24 34                fdivr dword ptr [esp + 0x34]
  000CF61F  d9 9e 54 07 00 00          fstp dword ptr [esi + 0x754]
  000CF625  e9 a1 00 00 00             jmp 0x100cf6cb
  000CF62A  68 fc f8 35 10             push 0x1035f8fc
  000CF62F  e9 8f 00 00 00             jmp 0x100cf6c3
  000CF634  8b 16                      mov edx, dword ptr [esi]
  000CF636  8b ce                      mov ecx, esi
  000CF638  ff 92 78 03 00 00          call dword ptr [edx + 0x378]
  000CF63E  85 c0                      test eax, eax
  000CF640  74 2a                      je 0x100cf66c
  000CF642  8b 8e 6c 07 00 00          mov ecx, dword ptr [esi + 0x76c]
  000CF648  85 c9                      test ecx, ecx
  000CF64A  74 19                      je 0x100cf665
  000CF64C  e8 df 4e fb ff             call 0x10084530
  000CF651  50                         push eax
  000CF652  8d 8e 78 08 00 00          lea ecx, [esi + 0x878]
  000CF658  e8 d3 2a f5 ff             call 0x10022130
  000CF65D  d9 9e 54 07 00 00          fstp dword ptr [esi + 0x754]
  000CF663  eb 66                      jmp 0x100cf6cb
  000CF665  68 c0 f8 35 10             push 0x1035f8c0
  000CF66A  eb 57                      jmp 0x100cf6c3
  000CF66C  8b ce                      mov ecx, esi
  000CF66E  e8 9d 4e fb ff             call 0x10084510
  000CF673  eb dc                      jmp 0x100cf651
  000CF675  8b be 68 07 00 00          mov edi, dword ptr [esi + 0x768]
  000CF67B  85 ff                      test edi, edi
  000CF67D  74 3f                      je 0x100cf6be
  000CF67F  8a 87 85 08 00 00          mov al, byte ptr [edi + 0x885]
  000CF685  88 44 24 34                mov byte ptr [esp + 0x34], al
  000CF689  8b 4c 24 34                mov ecx, dword ptr [esp + 0x34]
  000CF68D  23 cb                      and ecx, ebx
  000CF68F  51                         push ecx
  000CF690  8d 8e 78 08 00 00          lea ecx, [esi + 0x878]
  000CF696  e8 95 2a f5 ff             call 0x10022130
  000CF69B  d9 5c 24 34                fstp dword ptr [esp + 0x34]
  000CF69F  8b cf                      mov ecx, edi
  000CF6A1  e8 6a 4e fb ff             call 0x10084510
  000CF6A6  50                         push eax
  000CF6A7  8d 8f 78 08 00 00          lea ecx, [edi + 0x878]
  000CF6AD  e8 7e 2a f5 ff             call 0x10022130
  000CF6B2  d8 4c 24 34                fmul dword ptr [esp + 0x34]
  000CF6B6  d9 9e 54 07 00 00          fstp dword ptr [esi + 0x754]
  000CF6BC  eb 0d                      jmp 0x100cf6cb
  000CF6BE  68 80 f8 35 10             push 0x1035f880
  000CF6C3  e8 78 86 f4 ff             call 0x10017d40
  000CF6C8  83 c4 04                   add esp, 4
  000CF6CB  8b 86 14 08 00 00          mov eax, dword ptr [esi + 0x814]
  000CF6D1  5b                         pop ebx
  000CF6D2  85 c0                      test eax, eax
  000CF6D4  75 46                      jne 0x100cf71c
  000CF6D6  8b 16                      mov edx, dword ptr [esi]
  000CF6D8  68 66 76 69 62             push 0x62697666   ; fourcc? 'fvib'
  000CF6DD  8d 44 24 34                lea eax, [esp + 0x34]
  000CF6E1  6a 05                      push 5
  000CF6E3  50                         push eax
  000CF6E4  8b ce                      mov ecx, esi
  000CF6E6  ff 92 ec 01 00 00          call dword ptr [edx + 0x1ec]
  000CF6EC  8b 00                      mov eax, dword ptr [eax]
  000CF6EE  85 c0                      test eax, eax
  000CF6F0  74 2a                      je 0x100cf71c
  000CF6F2  8b 00                      mov eax, dword ptr [eax]
  000CF6F4  85 c0                      test eax, eax
  000CF6F6  74 24                      je 0x100cf71c
  000CF6F8  6a 00                      push 0
  000CF6FA  56                         push esi
  000CF6FB  56                         push esi
  000CF6FC  8b c8                      mov ecx, eax
  000CF6FE  e8 cd 3f f8 ff             call 0x100536d0
  000CF703  8b f8                      mov edi, eax
  000CF705  85 ff                      test edi, edi
  000CF707  74 13                      je 0x100cf71c
  000CF709  8b cf                      mov ecx, edi
  000CF70B  89 77 64                   mov dword ptr [edi + 0x64], esi
  000CF70E  e8 8d 27 fa ff             call 0x10071ea0
  000CF713  8b 7f 14                   mov edi, dword ptr [edi + 0x14]
  000CF716  89 be 14 08 00 00          mov dword ptr [esi + 0x814], edi
  000CF71C  8b 16                      mov edx, dword ptr [esi]
  000CF71E  8d 44 24 30                lea eax, [esp + 0x30]
  000CF722  50                         push eax
  000CF723  8b ce                      mov ecx, esi
  000CF725  ff 92 e0 01 00 00          call dword ptr [edx + 0x1e0]
  000CF72B  8b 00                      mov eax, dword ptr [eax]
  000CF72D  85 c0                      test eax, eax
  000CF72F  89 44 24 0c                mov dword ptr [esp + 0xc], eax
  000CF733  74 19                      je 0x100cf74e
  000CF735  8d 4c 24 0c                lea ecx, [esp + 0xc]
  000CF739  e8 32 19 fa ff             call 0x10071070
  000CF73E  84 c0                      test al, al
  000CF740  74 0c                      je 0x100cf74e
  000CF742  8b 4c 24 0c                mov ecx, dword ptr [esp + 0xc]
  000CF746  51                         push ecx
  000CF747  8b ce                      mov ecx, esi
  000CF749  e8 22 59 fb ff             call 0x10085070
  000CF74E  5f                         pop edi
  000CF74F  5e                         pop esi
  000CF750  5d                         pop ebp
  000CF751  83 c4 20                   add esp, 0x20
  000CF754  c2 04 00                   ret 4
  000CF757  90                         nop 
  000CF758  90                         nop 
  000CF759  90                         nop 
  000CF75A  90                         nop 
  000CF75B  90                         nop 
  000CF75C  90                         nop 
  000CF75D  90                         nop 
  000CF75E  90                         nop 
  000CF75F  90                         nop 
  000CF760  51                         push ecx
  000CF761  53                         push ebx
  000CF762  8b 5c 24 0c                mov ebx, dword ptr [esp + 0xc]
  000CF766  55                         push ebp
  000CF767  56                         push esi
  000CF768  57                         push edi
  000CF769  8b f1                      mov esi, ecx
  000CF76B  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  000CF771  53                         push ebx
  000CF772  33 ed                      xor ebp, ebp
  000CF774  e8 47 38 fa ff             call 0x10072fc0
```

### J.9 The 'moun' FourCC branch @rva 0xCF321: different merge base, no +0x881 site

Source file: `out3/x_moun.md`

```text
instructions with imm 0x6E756F6D: 1
- 0xCF321 in func 0xCF2EB
  000CF319  8a 4c 24 34                mov cl, byte ptr [esp + 0x34]
  000CF31D  84 c9                      test cl, cl
  000CF31F  74 46                      je 0x100cf367
>>000CF321  81 78 20 6d 6f 75 6e       cmp dword ptr [eax + 0x20], 0x6e756f6d   ; fourcc? 'moun'
  000CF328  75 21                      jne 0x100cf34b
  000CF32A  8d be 78 08 00 00          lea edi, [esi + 0x878]
  000CF330  83 c0 30                   add eax, 0x30
```

### J.10 ROM census of CIB byte-9 values over 49317 DATs (18128 with CIB chunks)

Source file: `out3/cib_b9_census.md`

```text
files scanned: 49317
files with >=1 CIB(0x45): 18128
byte-0 (movement) distribution [kuluu cib.rs expects 0/1/2/3/FF = 1102/50/178/304/16494]:
    0 (0x00):    1243
    1 (0x01):      50
    2 (0x02):     195
    3 (0x03):     309
   15 (0x0F):       1
   48 (0x30):       1
  127 (0x7F):       2
  255 (0xFF):   16956
byte-9 (waist_type / Tpc B flag) distribution over all CIBs:
    0 (0x00):     173   e.g. 123/12.DAT
    1 (0x01):     837   e.g. 118/122.DAT
    2 (0x02):    2534   e.g. 118/123.DAT
    3 (0x03):       6   e.g. 351/102.DAT
    5 (0x05):       2   e.g. 353/31.DAT
    6 (0x06):      25   e.g. 351/100.DAT
  100 (0x64):      13   e.g. 321/64.DAT
  255 (0xFF):   15167   e.g. 10/0.DAT
```

## K. The global zone scene file ROM\0\23.DAT (E18)

Backs E18: the full parse of the single global scene file, its routine stage streams and the camera-name census against vendor zone ids. `d_scene23_full.md` is the canonical report regenerated by `scene_dat_parse.py`; the other three are earlier exploration dumps kept for provenance.

### K.1 dat_routines.py dump of ROM\0\23.DAT: 73872 bytes, 346 chunks, chunk-type census and the `loop` routine's stage stream

Source file: `out3/d_scene23.md`

```text
# dat_routines dump of C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\ROM\0\23.DAT (1 files considered)

## C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\ROM\0\23.DAT  (73872 bytes, 346 chunks, 1 routines)

chunk types: 0x00 x1, 0x01 x1, 0x06 x317, 0x07 x24, 0x2F x3

type 0x01 marker           (1): titl
type 0x06 ?                (289): 8c01 8c02 8c03 8c04 8c05 8c06 8c07 8c08 8c09 8c10 8c12 8c13 8c14 9c01 9c02 9c03 9c04 9c05 9c06 9c07 9c08 9c09 9c10 9c11 9c12 9c13 9c14 9c15 9c16 cgn0 cgn1 cgn2 cgn3 cgn4 cgn5 cgn6 cgn7 cgn8 cgn9 cgna cgnb crz0 crz1 crz2 crz3 crz4 crz5 crz6 crz7 crz8 crz9 crza crzb 3c13 3c12 3c11 3c10 3c09 3c08 3c07 3c06 3c05 3c04 3c03 3c02 3c01 2c19 2c18 2c17 2c16 2c15 2c14 2c13 2c12 2c11 2c10 2c09 2c08 2c07 2c06 2c05 2c04 2c03 2c02 2c01 1c14 1c13 1c12 1c11 1c10 1c09 1c08 1c07 1c06 1c05 1c04 1c03 1c02 1c01 cghf cghe cghd cghc cghb cgha cgh9 cgh8 cgh7 cgh6 cgh5 cgh4 cgh3 cgh2 cgh1 cgh0 cqfb cqfa cqf9 cqf8 cqf7 ...
type 0x07 routines         (24): ex3e ex3d ex3c ex3b ex3a ex1c ex1b ex1a mov8 mov7 mov6 mov5 mov3 mov1 main mov2 loop mov4 ex2a ex2b ex2c ex2d ex2e ex2f
type 0x2F ?                (1): s101

### routine `loop`  chunk type 0x07 @0x109A0 len 0x1F0, stream @+0x50 (29 stages, 396/480 body bytes)
    hdr       (2 dw) 00 00 00 00
    grp-begin (2 dw) 00 00 00 00
    ref3B  mov1  at=0 (timing 0x00000000)
    ref3B  mov2  at=0 (timing 0x00000000)
    ref3B  mov3  at=0 (timing 0x00000000)
    ref3B  mov5  at=0 (timing 0x00000000)
    ref3B  mov4  at=0 (timing 0x00000000)
    ref3B  mov6  at=0 (timing 0x00000000)
    ref3B  mov7  at=0 (timing 0x00000000)
    ref3B  mov8  at=0 (timing 0x00000000)
    grp-end   (2 dw) 00 00 00 00
    0xAF      (3 dw) 00 00 00 00 01 00 00 00
    ref3B  ex1a  at=0 (timing 0x00000000)
    ref3B  ex1b  at=0 (timing 0x00000000)
    ref3B  ex1c  at=0 (timing 0x00000000)
    grp-end   (2 dw) 00 00 00 00
    0xAF      (3 dw) 00 00 00 00 02 00 00 00
    ref3B  ex2a  at=0 (timing 0x00000000)
    ref3B  ex2d  at=0 (timing 0x00000000)
    ref3B  ex2b  at=0 (timing 0x00000000)
    ref3B  ex2c  at=0 (timing 0x00000000)
    grp-end   (2 dw) 00 00 00 00
    0xAF      (3 dw) 00 00 00 00 03 00 00 00
    ref3B  ex3a  at=0 (timing 0x00000000)
    ref3B  ex3d  at=0 (timing 0x00000000)
    ref3B  ex3e  at=0 (timing 0x00000000)
    ref3B  ex3c  at=0 (timing 0x00000000)
    grp-end   (2 dw) 00 00 00 00
    end
    hex: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 e0 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 02 00 00 00 00 00 00 3d 02 00 00 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 31 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 32 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 33 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 35 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 34 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 36 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 37 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 38 00 00 00 00 3e 02 00 00 00 00 00 00 af 03 00 00 00 00 00 00 01 00 00 00 3b 04 00 00 00 00 00 00 65 78 31 61 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 31 62 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 31 63 00 00 00 00 3e 02 00 00 00 00 00 00 af 03 00 00 00 00 00 00 02 00 00 00 3b 04 00 00 00 00 00 00 65 78 32 61 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 32 64 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 32 62 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 32 63 00 00 00 00 3e 02 00 00 00 00 00 00 af 03 00 00 00 00 00 00 03 00 00 00 3b 04 00 00 00 00 00 00 65 78 33 61 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 33 64 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 33 65 00 00 00 00 3b 04 00 00 00 00 00 00 65 78 33 63 00 00 00 00 3e 02 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00
```

### K.2 Per-chunk raw view: header bytes, the u32@chunk+0x24 stage pointer and body prefixes for every 0x07 routine chunk

Source file: `out3/d_scene23_chunks.md`

```text
total chunks: 346

=== ex3e type=0x07 off=0xDE80 len=0x250
  hdr: 65 78 33 65 87 12 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x240
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 40 02 00 00 7d 38 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex3d type=0x07 off=0xE0D0 len=0x290
  hdr: 65 78 33 64 87 14 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x280
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 80 02 00 00 64 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex3c type=0x07 off=0xE360 len=0x340
  hdr: 65 78 33 63 07 1a 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x330
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 30 03 00 00 44 2f 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex3b type=0x07 off=0xE6A0 len=0x330
  hdr: 65 78 33 62 87 19 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x320
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 20 03 00 00 4e 25 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex3a type=0x07 off=0xE9D0 len=0x250
  hdr: 65 78 33 61 87 12 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x240
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 40 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex1c type=0x07 off=0xEC20 len=0x270
  hdr: 65 78 31 63 87 13 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x260
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 60 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex1b type=0x07 off=0xEE90 len=0x2F0
  hdr: 65 78 31 62 87 17 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x2e0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 e0 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex1a type=0x07 off=0xF180 len=0x300
  hdr: 65 78 31 61 07 18 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x2f0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 f0 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov8 type=0x07 off=0xF480 len=0x2E0
  hdr: 6d 6f 76 38 07 17 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x2d0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 d0 02 00 00 14 28 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov7 type=0x07 off=0xF760 len=0x2D0
  hdr: 6d 6f 76 37 87 16 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x2c0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 c0 02 00 00 ce 25 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov6 type=0x07 off=0xFA30 len=0x310
  hdr: 6d 6f 76 36 87 18 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x300
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 00 03 00 00 c2 24 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov5 type=0x07 off=0xFD40 len=0x2D0
  hdr: 6d 6f 76 35 87 16 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x2c0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 c0 02 00 00 9a 29 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov3 type=0x07 off=0x10010 len=0x2F0
  hdr: 6d 6f 76 33 87 17 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x2e0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 e0 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov1 type=0x07 off=0x10300 len=0x250
  hdr: 6d 6f 76 31 87 12 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x240
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 40 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== main type=0x07 off=0x10550 len=0x90
  hdr: 6d 61 69 6e 87 04 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x80
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 80 00 00 00 03 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov2 type=0x07 off=0x105E0 len=0x3C0
  hdr: 6d 6f 76 32 07 1e 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x3b0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 b0 03 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== loop type=0x07 off=0x109A0 len=0x1F0
  hdr: 6c 6f 6f 70 87 0f 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x1e0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 e0 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov4 type=0x07 off=0x10B90 len=0x270
  hdr: 6d 6f 76 34 87 13 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x260
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 60 02 00 00 c4 22 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex2a type=0x07 off=0x10E00 len=0x2A0
  hdr: 65 78 32 61 07 15 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x290
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 90 02 00 00 04 29 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex2b type=0x07 off=0x110A0 len=0x270
  hdr: 65 78 32 62 87 13 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x260
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 60 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex2c type=0x07 off=0x11310 len=0x2A0
  hdr: 65 78 32 63 07 15 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x290
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 90 02 00 00 ac 26 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex2d type=0x07 off=0x115B0 len=0x360
  hdr: 65 78 32 64 07 1b 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x350
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 50 03 00 00 a1 2b 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex2e type=0x07 off=0x11910 len=0x2D0
  hdr: 65 78 32 65 87 16 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x2c0
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 c0 02 00 00 56 2c 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== ex2f type=0x07 off=0x11BE0 len=0x260
  hdr: 65 78 32 66 07 13 00 00 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x250
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 40 00 00 00 50 00 00 00 50 02 00 00 74 27 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== 0620 type=0x2F off=0x11E40 len=0xC0
  hdr: 30 36 32 30 2f 06 00 10 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x80426f7d
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 bb b5 84 80 00 00 00 80 9b 94 79 80 7d 6f 42 80 00 00 c6 43 00 00 00 00 00 00 c0 3f 00 00 00 00 c1 b7 68 80 00 00 00 80 92 8a 6d 80 7d 6f 42 80 00 00 fa 43

=== s101 type=0x2F off=0x11F00 len=0xC0
  hdr: 73 31 30 31 2f 06 00 10 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x8078675c
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 c4 c4 bb 80 22 22 22 80 a6 a8 ae 80 5c 67 78 80 00 00 c6 43 00 00 00 00 00 00 c0 3f 00 00 00 00 ba ba af 80 22 22 22 80 9b 9d a4 80 5c 67 78 80 00 e0 54 44

=== 1700 type=0x2F off=0x11FC0 len=0xC0
  hdr: 31 37 30 30 2f 06 00 10 00 00 00 00 00 00 00 00
  u32@chunk+0x28 (stage ptr) = 0x803f516b
  body[0..0x40]: 00 00 00 00 00 00 00 00 00 00 00 00 b7 a7 88 80 00 00 00 80 8f 8b 85 80 6b 51 3f 80 00 00 c6 43 00 00 00 00 00 00 c0 3f 00 00 00 00 c0 a2 69 80 00 00 00 80 8f 82 70 80 6b 51 3f 80 00 00 c6 43

=== 0x06 8c01 off=0x20 len=0x90
  hdr: 38 63 30 31 86 04 00 00 00 00 00 00 00 00 00 00
  body: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 f2 27 9d 41 09 b6 12 c0 93 29 d5 42 00 00 af 43 5d 0c 92 41 42 54 53 c0 5e 48 d7 42 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 ee 27 9d 41 09 b6 12 c0 93 29 d5 42 fa 04 9c 43

=== 0x06 8c02 off=0xB0 len=0x90
  hdr: 38 63 30 32 86 04 00 00 00 00 00 00 00 00 00 00
  body: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 4b f6 4f c2 10 f0 eb c0 af 9a 4d 42 00 00 af 43 b0 7c 59 c2 5d ea 05 c1 9a 4a 54 42 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 4b f6 4f c2 10 f0 eb c0 af 9a 4d 42 00 00 af 43

=== 0x06 8c03 off=0x140 len=0x90
  hdr: 38 63 30 33 86 04 00 00 00 00 00 00 00 00 00 00
  body: 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 a4 3f f9 c2 e9 30 ae bf 3a d3 2f 41 00 00 af 43 cd e6 f1 c2 c1 d7 22 c0 e7 d8 28 41 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 93 3f f9 c2 fa 30 ae bf 29 d3 2f 41 00 00 af 43
```

### K.3 Raw stage-stream byte dumps per routine (the pre-decode exploration)

Source file: `out3/d_scene23_stages.md`

```text
total chunks: 346

=== ex3e off=0xDE80 len=0x250 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 44 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 66 69 6e 65 7d 03 00 00 00 00 00 00 a0 bb 0d 00 04 06 00 00 08 07 08 07 63 72 7a 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 32 00 04 06 00 00 e8 03 e8 03 63 72 7a 32 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00

=== ex3d off=0xE0D0 len=0x290 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 33 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 66 69 6e 65 7d 03 00 00 00 00 00 00 b0 d3 4e 00 04 06 00 00 e8 03 e8 03 63 67 6e 30 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 32 00 7d 03 00 00 00 00 00 00 60 6c 15 00 04 06 00 00 4c 04 4c 04 63 67 6e 31 00 00 00 00

=== ex3c off=0xE360 len=0x340 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 3d 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 80 c6 13 00 04 06 00 00 e8 03 d4 03 31 31 30 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 96 00 04 06 00 00 b0 04 b0 04 31 31 30 32 00 00 00 00 00 00 00 00 00 00 00 00 7d 03 00 00

=== ex3b off=0xE6A0 len=0x330 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 36 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 20 82 21 00 04 06 00 00 58 02 58 02 39 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 7d 03 00 00 00 00 00 00 00 8d 27 00 0f 03 00 00 00 00 00 00 ff ff ff 80 10 02 00 00 00 00 78 00 04 06 00 00

=== ex3a off=0xE9D0 len=0x250 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 32 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 20 82 21 00 04 06 00 00 e8 03 d4 03 38 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 04 06 00 00 bc 02 bc 02 38 63 30 32 00 00 00 00 00 00 00 00 00 00 00 00 04 06 00 00 8a 02 8a 02 38 63 30 33

=== ex1c off=0xEC20 len=0x270 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 82 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7d 03 00 00 00 00 00 00 c0 a9 1d 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 66 69 6e 65 04 06 00 00 20 03 20 03 33 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 04 06 00 00 00 00 20 03 33 63 30 34 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 20 03 96 00 04 06 00 00

=== ex1b off=0xEE90 len=0x2F0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 7b 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 50 3f 16 00 04 06 00 00 20 03 20 03 32 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 04 06 00 00 5e 01 5e 01 32 63 30 32 00 00 00 00 00 00 00 00 00 00 00 00 7d 03 00 00 00 00 00 00 40 dc 1f 00

=== ex1a off=0xF180 len=0x300 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 79 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 20 53 14 00 04 06 00 00 58 02 58 02 31 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 7d 03 00 00 00 00 00 00 00 f9 15 00 04 06 00 00 90 01 90 01 31 63 30 33 00 00 00 00 00 00 00 00 00 00 00 00

=== mov8 off=0xF480 len=0x2E0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 8d 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 01 00 00 00 60 36 1e 00 04 06 00 00 1f 03 20 03 63 67 68 30 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 46 00 7d 03 00 00 00 00 00 00 40 41 24 00 04 06 00 00 58 02 58 02 63 67 68 31 00 00 00 00

=== mov7 off=0xF760 len=0x2D0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 7e 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 66 69 6e 65 7d 03 00 00 00 00 00 00 10 26 15 00 04 06 00 00 58 02 58 02 63 71 66 30 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 1e 00 7d 03 00 00 00 00 00 00 00 5e 1a 00 04 06 00 00 58 02 58 02 63 71 66 31 00 00 00 00

=== mov6 off=0xFA30 len=0x310 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 6f 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 63 6c 6f 64 7d 03 00 00 00 00 00 00 80 f5 20 00 04 06 00 00 20 03 20 03 63 67 61 30 00 00 00 00 00 00 00 00 00 00 00 00 7d 03 00 00 00 00 00 00 00 8d 27 00 04 06 00 00 f4 01 e0 01 63 67 61 38 00 00 00 00 00 00 00 00 00 00 00 00

=== mov5 off=0xFD40 len=0x2D0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 6a 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 00 00 00 8d 27 00 04 06 00 00 84 03 84 03 63 67 75 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 14 00 04 06 00 00 20 03 20 03 63 67 75 32 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00

=== mov3 off=0x10010 len=0x2F0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 68 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 28 00 73 75 6e 79 7d 03 00 00 00 00 14 00 20 15 16 00 04 06 00 00 e8 03 e8 03 36 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 be 00 04 06 00 00 bc 02 bc 02 36 63 30 32 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00

=== mov1 off=0x10300 len=0x250 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 66 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7e 04 00 00 00 00 00 00 73 31 30 31 00 00 00 00 04 06 00 00 bc 02 bc 02 73 31 30 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 c8 00 7d 03 00 00 00 00 00 00 00 8d 27 00 7c 03 00 00 00 00 00 00 73 75 6e 79 04 06 00 00 84 03 84 03 73 31 30 32

=== main off=0x10550 len=0x90 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 73 05 00 00 03 00 00 00 6c 6f 6f 70 00 00 00 00 00 00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 01 00 00 00 00 00 00 00 00 00 00 00 00 00 00

=== mov2 off=0x105E0 len=0x3C0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7d 03 00 00 00 00 00 00 60 6c 15 00 7b 06 00 00 00 00 00 00 67 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 73 75 6e 79 04 06 00 00 e8 03 e8 03 63 31 30 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 32 00 04 06 00 00 f4 01 f4 01 63 31 30 32 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00

=== loop off=0x109A0 len=0x1F0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 3d 02 00 00 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 31 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 32 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 33 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 35 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 34 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 36 00 00 00 00 3b 04 00 00 00 00 00 00 6d 6f 76 37 00 00 00 00

=== mov4 off=0x10B90 len=0x270 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 6d 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 63 6c 6f 64 7d 03 00 00 00 00 14 00 70 c8 21 00 04 06 00 00 20 03 20 03 37 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 64 00 04 06 00 00 f4 01 f4 01 37 63 30 36 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00

=== ex2a off=0x10E00 len=0x2A0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 02 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 20 15 16 00 04 06 00 00 bc 02 bc 02 34 63 30 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 32 00 04 06 00 00 bc 02 bc 02 34 63 30 34 00 00 00 00 00 00 00 00 00 00 00 00 7d 03 00 00

=== ex2b off=0x110A0 len=0x270 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 1d 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 60 9b 22 00 04 06 00 00 20 03 20 03 31 30 30 31 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 6e 00 04 06 00 00 20 03 20 03 31 30 30 32 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00

=== ex2c off=0x11310 len=0x2A0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 7b 06 00 00 00 00 00 00 21 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 14 00 20 15 16 00 04 06 00 00 20 03 20 03 35 63 30 33 00 00 00 00 00 00 00 00 00 00 00 00 04 06 00 00 20 03 20 03 35 63 30 34 00 00 00 00 00 00 00 00 00 00 00 00 04 06 00 00 00 00 20 03 35 63 30 35

=== ex2d off=0x115B0 len=0x360 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 04 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 66 69 6e 65 7d 03 00 00 00 00 00 00 30 e5 17 00 04 06 00 00 58 02 58 02 63 70 61 30 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 3c 00 04 06 00 00 90 01 90 01 63 70 61 31 00 00 00 00 00 00 00 00 00 00 00 00 04 06 00 00

=== ex2e off=0x11910 len=0x2D0 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 18 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 73 75 6e 79 7d 03 00 00 00 00 00 00 e0 fd 4e 00 04 06 00 00 20 03 de 03 63 74 31 36 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 1e 00 04 06 00 00 5c 03 84 03 63 74 31 37 00 00 00 00 00 00 00 00 00 00 00 00 0f 03 00 00

=== ex2f off=0x11BE0 len=0x260 stage@chunk+0x50
  stages: 01 02 00 00 00 00 00 00 0f 03 00 00 00 00 64 00 80 80 80 80 7b 06 00 00 00 00 00 00 19 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00 7c 03 00 00 00 00 00 00 74 68 64 72 7d 03 00 00 00 00 00 00 e0 fd 4e 00 04 06 00 00 f4 01 f4 01 63 74 32 33 00 00 00 00 00 00 00 00 00 00 00 00 10 02 00 00 00 00 32 00 7d 03 00 00 00 00 00 00 20 82 21 00 04 06 00 00 20 03 20 03 63 74 32 31 00 00 00 00
```

### K.4 Canonical report from scene_dat_parse.py: per-routine decoded stage streams, camera-name census with hex-prefix zone-id check and channel names from vendor/server/sql/zone_settings.sql, stage-type histogram, routine -> route reference table, and the 0x04-refs-vs-0x06-definitions check

Source file: `out3/d_scene23_full.md`

```text
# scene_dat_parse report: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\ROM\0\23.DAT

file size: 73872 bytes; total chunks: 346
chunk types: 0x00 x1, 0x01 x1, 0x06 x317, 0x07 x24, 0x2F x3

### ex3e (31 stages, 12 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 44 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 a0 bb 0d 00 ; "...."
    CAMERA name=crz1 delay=1800 dur=1800
    0x10 (2 dw) 00 00 32 00
    CAMERA name=crz2 delay=1000 dur=1000
    0x10 (2 dw) 00 00 28 00
    CAMERA name=crz3 delay=400 dur=600
    0x10 (2 dw) 00 00 1e 00
    CAMERA name=crz4 delay=1220 dur=1400
    0x0F (3 dw) b4 00 78 00 02 06 04 80
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    CAMERA name=crz5 delay=2000 dur=2000
    0x10 (2 dw) 00 00 1e 00
    CAMERA name=crz6 delay=1000 dur=1000
    CAMERA name=crz7 delay=1600 dur=1600
    CAMERA name=crz8 delay=680 dur=800
    0x0F (3 dw) 78 00 78 00 05 08 06 80
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    CAMERA name=crz9 delay=1000 dur=1000
    0x10 (2 dw) 00 00 32 00
    CAMERA name=crz0 delay=600 dur=620
    0x10 (2 dw) 00 00 1e 00
    CAMERA name=crza delay=800 dur=800
    0x10 (2 dw) 00 00 50 00
    CAMERA name=crzb delay=1960 dur=2000
    0x0F (3 dw) 65 00 64 00 00 00 00 80
    end (terminator)
### ex3d (36 stages, 12 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 33 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 b0 d3 4e 00 ; "..N."
    CAMERA name=cgn0 delay=1000 dur=1000
    0x10 (2 dw) 00 00 32 00
    0x7D (3 dw) 00 00 00 00 60 6c 15 00 ; "`l.."
    CAMERA name=cgn1 delay=1100 dur=1100
    0x10 (2 dw) 00 00 32 00
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=cgn3 delay=600 dur=600
    CAMERA name=cgn5 delay=600 dur=600
    0x10 (2 dw) 00 00 32 00
    CAMERA name=cgn4 delay=1000 dur=1000
    0x10 (2 dw) 00 00 14 00
    CAMERA name=cgn6 delay=700 dur=700
    0x7D (3 dw) 00 00 28 00 a0 ad 39 00 ; "..9."
    CAMERA name=cgn7 delay=1100 dur=1200
    0x0F (3 dw) 64 00 78 00 02 01 03 80
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 00 eb 41 00 ; "..A."
    CAMERA name=cgn2 delay=1000 dur=1000
    0x10 (2 dw) 00 00 32 00
    0x7D (3 dw) 00 00 00 00 80 61 0f 00 ; ".a.."
    CAMERA name=cgn9 delay=910 dur=1000
    0x0F (3 dw) 5a 00 78 00 02 02 02 80
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 e0 68 20 00 ; ".h ."
    CAMERA name=cgna delay=800 dur=780
    0x10 (2 dw) 00 00 3c 00
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=cgn8 delay=1800 dur=1800
    CAMERA name=cgnb delay=2000 dur=2000
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex3c (49 stages, 15 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 3d 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 80 c6 13 00 ; "...."
    CAMERA name=1101 delay=1000 dur=980
    0x10 (2 dw) 00 00 96 00
    CAMERA name=1102 delay=1200 dur=1200
    0x7D (3 dw) 00 00 00 00 80 c6 13 00 ; "...."
    0x10 (2 dw) 00 00 6e 00
    CAMERA name=1103 delay=800 dur=800
    0x7D (3 dw) 00 00 00 00 20 b8 18 00 ; " ..."
    CAMERA name=1104 delay=1100 dur=1080
    0x7D (3 dw) 00 00 00 00 c0 a9 1d 00 ; "...."
    0x10 (2 dw) 00 00 fa 00
    CAMERA name=1105 delay=400 dur=500
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    0x7D (3 dw) 00 00 00 00 60 9b 22 00 ; "`."."
    CAMERA name=1106 delay=0 dur=1100
    0x0F (3 dw) 82 00 96 00 80 80 80 80
    0x7D (3 dw) ca 03 00 00 f0 7e 27 00 ; ".~'."
    0x10 (2 dw) 00 00 aa 00
    CAMERA name=1108 delay=1550 dur=1650
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    0x7D (3 dw) 00 00 00 00 20 7b 37 00 ; " {7."
    0x0F (3 dw) 00 00 aa 00 80 80 80 80
    CAMERA name=1109 delay=0 dur=940
    0x3D (2 dw) 00 00 00 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7C (3 dw) 00 00 00 00 64 75 73 74 ; "dust"
    0x7C (3 dw) 01 00 00 00 64 72 79 77 ; "dryw"
    0x3E (2 dw) ab 03 00 00
    0x10 (2 dw) 00 00 6e 00
    CAMERA name=1110 delay=600 dur=600
    0x10 (2 dw) 00 00 87 00
    0x7D (3 dw) 00 00 00 00 a0 ad 39 00 ; "..9."
    CAMERA name=1111 delay=984 dur=1030
    0x0F (3 dw) dd 00 e6 00 00 00 00 80
    0x0F (3 dw) 00 00 aa 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 10 f9 41 00 ; "..A."
    CAMERA name=1112 delay=250 dur=250
    0x10 (2 dw) 00 00 c8 00
    CAMERA name=1113 delay=440 dur=440
    CAMERA name=1114 delay=300 dur=300
    CAMERA name=1115 delay=300 dur=300
    0x10 (2 dw) 00 00 82 00
    CAMERA name=1116 delay=615 dur=600
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex3b (49 stages, 13 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 36 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 20 82 21 00 ; " .!."
    CAMERA name=9c01 delay=600 dur=600
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    0x0F (3 dw) 00 00 00 00 ff ff ff 80
    0x10 (2 dw) 00 00 78 00
    CAMERA name=9c02 delay=2 dur=900
    0x0F (3 dw) 82 03 40 01 80 80 80 80
    0x0F (3 dw) 00 00 28 00 ff ff ff 80
    0x10 (2 dw) 00 00 64 00
    CAMERA name=9c03 delay=2 dur=800
    0x0F (3 dw) 1e 03 40 01 80 80 80 80
    0x0F (3 dw) 00 00 0a 00 ff ff ff 80
    0x10 (2 dw) 00 00 82 00
    CAMERA name=9c04 delay=2 dur=670
    0x0F (3 dw) ba 02 bc 02 80 80 80 80
    0x0F (3 dw) 00 00 01 00 ff ff ff 80
    CAMERA name=9c05 delay=0 dur=1200
    0x10 (2 dw) 02 00 64 00
    0x0F (3 dw) ae 04 90 01 80 80 80 80
    0x0F (3 dw) c8 00 64 00 00 00 00 80
    CAMERA name=9c07 delay=0 dur=500
    0x0F (3 dw) f4 01 41 00 80 80 80 80
    CAMERA name=9c08 delay=0 dur=250
    0x10 (2 dw) fa 00 64 00
    0x0F (3 dw) 00 00 14 00 80 ff 9e 80
    0x10 (2 dw) 00 00 8c 00
    CAMERA name=9c09 delay=1 dur=600
    0x0F (3 dw) 57 02 e6 00 80 80 80 80
    0x10 (2 dw) 00 00 91 00
    CAMERA name=9c11 delay=0 dur=300
    0x0F (3 dw) 65 00 00 00 6c e4 9e 80
    0x0F (3 dw) 63 00 5a 00 80 80 80 80
    0x0F (3 dw) 78 00 3c 00 00 00 00 80
    0x7D (3 dw) 00 00 00 00 e0 88 3c 00 ; "..<."
    0x7C (3 dw) 00 00 00 00 73 6e 6f 77 ; "snow"
    CAMERA name=9c12 delay=15 dur=780
    0x0F (3 dw) fd 02 64 00 80 80 80 80
    0x10 (2 dw) 00 00 96 00
    CAMERA name=9c13 delay=1000 dur=1000
    0x10 (2 dw) 00 00 78 00
    CAMERA name=9c15 delay=900 dur=900
    0x10 (2 dw) 00 00 8c 00
    CAMERA name=9c16 delay=700 dur=800
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex3a (30 stages, 11 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 32 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 20 82 21 00 ; " .!."
    CAMERA name=8c01 delay=1000 dur=980
    CAMERA name=8c02 delay=700 dur=700
    CAMERA name=8c03 delay=650 dur=650
    0x7D (3 dw) 00 00 00 00 c0 83 34 00 ; "..4."
    0x10 (2 dw) 00 00 91 00
    CAMERA name=8c04 delay=800 dur=800
    0x10 (2 dw) 00 00 55 00
    CAMERA name=8c05 delay=0 dur=950
    0x7D (3 dw) ee 02 00 00 40 41 24 00 ; "@A$."
    0x0F (3 dw) c8 00 aa 00 00 00 00 80
    0x0F (3 dw) 00 00 5a 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 80 82 48 00 ; "..H."
    CAMERA name=8c07 delay=800 dur=800
    CAMERA name=8c08 delay=780 dur=780
    0x10 (2 dw) 00 00 69 00
    CAMERA name=8c09 delay=620 dur=620
    CAMERA name=8c12 delay=450 dur=450
    CAMERA name=8c13 delay=850 dur=1050
    0x0F (3 dw) c8 00 87 00 00 00 00 80
    0x0F (3 dw) 00 00 46 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 70 c8 21 00 ; "p.!."
    CAMERA name=8c10 delay=2000 dur=1900
    0x0F (3 dw) 64 00 5a 00 00 00 00 80
    end (terminator)
### ex1c (33 stages, 12 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 82 00 00 00 00 00 00 00
    0x7D (3 dw) 00 00 00 00 c0 a9 1d 00 ; "...."
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    CAMERA name=3c01 delay=800 dur=800
    CAMERA name=3c04 delay=0 dur=800
    0x10 (2 dw) 20 03 96 00
    CAMERA name=3c02 delay=800 dur=800
    CAMERA name=3c03 delay=700 dur=700
    0x10 (2 dw) 00 00 64 00
    CAMERA name=3c10 delay=300 dur=300
    0x7D (3 dw) 00 00 00 00 a0 ad 39 00 ; "..9."
    0x10 (2 dw) 00 00 96 00
    CAMERA name=3c07 delay=800 dur=800
    CAMERA name=3c08 delay=0 dur=500
    0x10 (2 dw) 00 00 b4 00
    0x7D (3 dw) f4 01 00 00 a0 dc 46 00 ; "..F."
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 00 00 00 00 ; "...."
    CAMERA name=3c09 delay=800 dur=900
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    0x7D (3 dw) 00 00 00 00 60 6c 15 00 ; "`l.."
    CAMERA name=3c11 delay=0 dur=900
    0x0F (3 dw) 84 03 6e 00 80 80 80 80
    CAMERA name=3c06 delay=0 dur=800
    0x10 (2 dw) 20 03 87 00
    CAMERA name=3c12 delay=900 dur=900
    0x7D (3 dw) 00 00 00 00 20 e7 25 00 ; " .%."
    0x10 (2 dw) 00 00 af 00
    CAMERA name=3c13 delay=1600 dur=1400
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex1b (40 stages, 14 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 7b 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 50 3f 16 00 ; "P?.."
    CAMERA name=2c01 delay=800 dur=800
    CAMERA name=2c02 delay=350 dur=350
    0x7D (3 dw) 00 00 00 00 40 dc 1f 00 ; "@..."
    CAMERA name=2c03 delay=400 dur=400
    0x0E (5 dw) 00 00 00 00 80 80 80 34 00 00 80 3f
    0x10 (2 dw) 00 00 50 00
    CAMERA name=2c04 delay=30 dur=700
    0x0E (5 dw) 9e 02 28 00 80 80 80 00 00 00 80 3f
    0x10 (2 dw) 00 00 64 00
    CAMERA name=2c16 delay=650 dur=650
    CAMERA name=2c06 delay=0 dur=900
    0x7D (3 dw) 84 03 00 00 00 8d 27 00 ; "..'."
    CAMERA name=2c17 delay=0 dur=500
    0x10 (2 dw) 7e 01 b4 00
    0x0F (3 dw) 76 00 78 00 00 00 00 80
    0x0F (3 dw) 00 00 55 00 80 80 80 80
    CAMERA name=2c07 delay=750 dur=750
    CAMERA name=2c08 delay=700 dur=700
    0x7D (3 dw) 00 00 00 00 c0 07 38 00 ; "..8."
    0x10 (2 dw) 00 00 c8 00
    CAMERA name=2c10 delay=850 dur=850
    CAMERA name=2c12 delay=900 dur=900
    0x10 (2 dw) 00 00 c8 00
    0x7D (3 dw) 00 00 00 00 00 eb 41 00 ; "..A."
    CAMERA name=2c13 delay=600 dur=800
    0x0F (3 dw) c8 00 c8 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 60 8d 4e 00 ; "`.N."
    0x10 (2 dw) 00 00 c8 00
    CAMERA name=2c19 delay=400 dur=500
    0x0F (3 dw) 64 00 4b 00 00 00 00 80
    0x7D (3 dw) 00 00 00 00 e0 03 1c 00 ; "...."
    0x0F (3 dw) 00 00 41 00 80 80 80 80
    CAMERA name=2c15 delay=1000 dur=700
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex1a (44 stages, 14 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 79 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 20 53 14 00 ; " S.."
    CAMERA name=1c01 delay=600 dur=600
    0x7D (3 dw) 00 00 00 00 00 f9 15 00 ; "...."
    CAMERA name=1c03 delay=400 dur=400
    0x7D (3 dw) 00 00 00 00 e0 03 1c 00 ; "...."
    CAMERA name=1c02 delay=400 dur=400
    0x10 (2 dw) 00 00 78 00
    CAMERA name=1c04 delay=600 dur=600
    0x7D (3 dw) 00 00 00 00 40 12 17 00 ; "@..."
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    CAMERA name=1c05 delay=500 dur=500
    0x7D (3 dw) 00 00 00 00 c0 a9 1d 00 ; "...."
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x10 (2 dw) 00 00 e6 00
    CAMERA name=1c06 delay=1100 dur=1100
    0x10 (2 dw) 00 00 c8 00
    CAMERA name=1c07 delay=900 dur=900
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 e0 fb 14 00 ; "...."
    CAMERA name=1c08 delay=0 dur=1000
    0x10 (2 dw) e8 03 c8 00
    CAMERA name=1c09 delay=0 dur=700
    0x10 (2 dw) 00 00 c8 00
    0x7D (3 dw) bc 02 00 00 a0 ad 39 00 ; "..9."
    0x7D (3 dw) 00 00 00 00 00 eb 41 00 ; "..A."
    CAMERA name=1c10 delay=1300 dur=1300
    0x7D (3 dw) 00 00 00 00 a0 41 4b 00 ; ".AK."
    0x10 (2 dw) 00 00 9b 00
    CAMERA name=1c11 delay=400 dur=400
    0x10 (2 dw) 00 00 96 00
    CAMERA name=1c12 delay=300 dur=600
    0x0F (3 dw) 2c 01 2c 01 00 00 00 80
    0x0F (3 dw) 00 00 d2 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 60 6c 15 00 ; "`l.."
    CAMERA name=1c13 delay=600 dur=600
    0x10 (2 dw) 00 00 96 00
    CAMERA name=1c14 delay=0 dur=600
    0x7D (3 dw) bc 02 58 02 60 6c 15 00 ; "`l.."
    0x0F (3 dw) 64 00 50 00 00 00 00 80
    end (terminator)
### mov8 (39 stages, 16 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 8d 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 01 00 00 00 60 36 1e 00 ; "`6.."
    CAMERA name=cgh0 delay=799 dur=800
    0x10 (2 dw) 00 00 46 00
    0x7D (3 dw) 00 00 00 00 40 41 24 00 ; "@A$."
    CAMERA name=cgh1 delay=600 dur=600
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    CAMERA name=cgh2 delay=500 dur=500
    0x10 (2 dw) 00 00 28 00
    CAMERA name=cgh3 delay=1000 dur=1000
    0x10 (2 dw) 00 00 5a 00
    CAMERA name=cgh4 delay=400 dur=400
    0x7C (3 dw) 00 00 28 00 73 75 6e 79 ; "suny"
    CAMERA name=cghc delay=300 dur=300
    CAMERA name=cgh5 delay=600 dur=600
    0x10 (2 dw) 00 00 3c 00
    0x7D (3 dw) 00 00 00 00 40 70 31 00 ; "@p1."
    CAMERA name=cgh6 delay=400 dur=400
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 80 91 39 00 ; "..9."
    CAMERA name=cgh7 delay=300 dur=300
    CAMERA name=cgh8 delay=310 dur=400
    0x0F (3 dw) 5a 00 5a 00 06 04 0a 80
    0x0F (3 dw) 00 00 0a 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 f0 e4 48 00 ; "..H."
    CAMERA name=cgh9 delay=500 dur=500
    0x10 (2 dw) 00 00 14 00
    CAMERA name=cgha delay=500 dur=500
    0x10 (2 dw) 00 00 64 00
    0x7D (3 dw) 00 00 00 00 30 04 17 00 ; "0..."
    CAMERA name=cghb delay=500 dur=500
    CAMERA name=cghf delay=600 dur=600
    CAMERA name=cghd delay=800 dur=800
    CAMERA name=cghe delay=2000 dur=2000
    0x0F (3 dw) 3c 00 3c 00 00 00 00 80
    end (terminator)
### mov7 (42 stages, 12 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 7e 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 10 26 15 00 ; ".&.."
    CAMERA name=cqf0 delay=600 dur=600
    0x10 (2 dw) 00 00 1e 00
    0x7D (3 dw) 00 00 00 00 00 5e 1a 00 ; ".^.."
    CAMERA name=cqf1 delay=600 dur=600
    0x10 (2 dw) 00 00 3c 00
    0x7D (3 dw) 00 00 00 00 20 e7 25 00 ; " .%."
    CAMERA name=cqf2 delay=700 dur=700
    0x10 (2 dw) 00 00 78 00
    0x7D (3 dw) 00 00 00 00 c0 9b 49 00 ; "..I."
    CAMERA name=cqf3 delay=200 dur=300
    0x0F (3 dw) 64 00 64 00 07 07 08 80
    0x0F (3 dw) 00 00 78 00 80 80 80 80
    0x7C (3 dw) 00 00 14 00 61 75 72 61 ; "aura"
    0x7D (3 dw) 00 00 00 00 40 9f 3e 00 ; "@.>."
    CAMERA name=cqf4 delay=400 dur=400
    0x10 (2 dw) 00 00 14 00
    0x7D (3 dw) 00 00 00 00 a0 f1 04 00 ; "...."
    CAMERA name=cqf5 delay=500 dur=500
    0x10 (2 dw) 00 00 50 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 40 e3 09 00 ; "@..."
    CAMERA name=cqf6 delay=700 dur=700
    0x7D (3 dw) 00 00 00 00 00 5e 1a 00 ; ".^.."
    CAMERA name=cqf7 delay=400 dur=400
    0x7D (3 dw) 00 00 00 00 40 41 24 00 ; "@A$."
    CAMERA name=cqf8 delay=500 dur=500
    0x10 (2 dw) 00 00 3c 00
    0x7C (3 dw) 00 00 00 00 61 75 72 61 ; "aura"
    0x7D (3 dw) 00 00 00 00 b0 17 1a 00 ; "...."
    CAMERA name=cqf9 delay=1000 dur=1000
    0x7D (3 dw) 00 00 00 00 00 2f 0d 00 ; "./.."
    CAMERA name=cqfa delay=900 dur=900
    0x10 (2 dw) 00 00 90 01
    0x7D (3 dw) 00 00 00 00 e0 03 1c 00 ; "...."
    CAMERA name=cqfb delay=3000 dur=3000
    0x0F (3 dw) 4e 00 3c 00 00 00 00 80
    end (terminator)
### mov6 (45 stages, 14 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 6f 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    0x7D (3 dw) 00 00 00 00 80 f5 20 00 ; ".. ."
    CAMERA name=cga0 delay=800 dur=800
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=cga8 delay=500 dur=480
    0x10 (2 dw) 00 00 3c 00
    0x7C (3 dw) 00 00 00 00 6d 69 73 74 ; "mist"
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=cga1 delay=800 dur=800
    0x10 (2 dw) 00 00 28 00
    CAMERA name=cga2 delay=500 dur=500
    CAMERA name=cgad delay=100 dur=100
    0x10 (2 dw) 00 00 46 00
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    0x7D (3 dw) 00 00 00 00 f0 5f 28 00 ; "._(."
    CAMERA name=cga3 delay=600 dur=600
    0x10 (2 dw) 00 00 3c 00
    0x7C (3 dw) 00 00 00 00 73 6e 6f 77 ; "snow"
    0x7D (3 dw) 00 00 00 00 80 24 2e 00 ; ".$.."
    CAMERA name=cga4 delay=500 dur=500
    0x10 (2 dw) 00 00 28 00
    CAMERA name=cga5 delay=300 dur=300
    0x7C (3 dw) 00 00 00 00 6d 69 73 74 ; "mist"
    0x7D (3 dw) 00 00 00 00 10 4e 38 00 ; ".N8."
    CAMERA name=cga6 delay=1000 dur=1000
    0x7C (3 dw) 00 00 00 00 73 6e 6f 77 ; "snow"
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=cga7 delay=500 dur=500
    0x7C (3 dw) 00 00 00 00 6d 69 73 74 ; "mist"
    0x7D (3 dw) 00 00 00 00 80 c6 13 00 ; "...."
    CAMERA name=cgaa delay=300 dur=300
    0x10 (2 dw) 00 00 50 00
    CAMERA name=cga9 delay=280 dur=300
    0x0F (3 dw) aa 00 78 00 08 03 0d 80
    0x10 (2 dw) 00 00 3c 00
    0x0F (3 dw) 00 00 50 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    0x7D (3 dw) 00 00 00 00 90 f3 12 00 ; "...."
    CAMERA name=cgab delay=1000 dur=1000
    CAMERA name=cgac delay=2000 dur=2000
    0x0F (3 dw) 3c 00 3c 00 00 00 00 80
    end (terminator)
### mov5 (41 stages, 12 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 6a 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=cgu1 delay=900 dur=900
    0x10 (2 dw) 00 00 14 00
    CAMERA name=cgu2 delay=800 dur=800
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 20 1d 1d 00 ; " ..."
    0x10 (2 dw) 00 00 64 00
    CAMERA name=cgu3 delay=620 dur=800
    0x0F (3 dw) 50 00 dc 00 c6 b2 9e 80
    0x0F (3 dw) 64 00 50 00 04 04 08 80
    0x7D (3 dw) 00 00 00 00 a0 ad 39 00 ; "..9."
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    CAMERA name=cgu9 delay=1000 dur=1000
    0x10 (2 dw) 00 00 28 00
    CAMERA name=cgu4 delay=880 dur=1000
    0x0F (3 dw) 78 00 78 00 1c 14 19 80
    0x0F (3 dw) 00 00 1e 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 40 9f 3e 00 ; "@.>."
    CAMERA name=cgu6 delay=500 dur=500
    0x10 (2 dw) 00 00 3c 00
    CAMERA name=cgu7 delay=500 dur=500
    0x10 (2 dw) 00 00 50 00
    0x7C (3 dw) 00 00 00 00 6d 69 73 74 ; "mist"
    0x7D (3 dw) 00 00 00 00 40 ce 4b 00 ; "@.K."
    CAMERA name=cgu8 delay=1000 dur=1000
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    0x7D (3 dw) 00 00 00 00 20 89 0b 00 ; " ..."
    CAMERA name=cgua delay=350 dur=350
    0x10 (2 dw) 00 00 3c 00
    CAMERA name=cgu0 delay=400 dur=350
    0x10 (2 dw) 00 00 32 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 40 12 17 00 ; "@..."
    CAMERA name=cgu5 delay=1500 dur=1500
    CAMERA name=cguc delay=1800 dur=1800
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### mov3 (42 stages, 14 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 68 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 28 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 20 15 16 00 ; " ..."
    CAMERA name=6c01 delay=1000 dur=1000
    0x10 (2 dw) 00 00 be 00
    CAMERA name=6c02 delay=700 dur=700
    0x10 (2 dw) 00 00 91 00
    CAMERA name=6c06 delay=700 dur=700
    CAMERA name=6c05 delay=400 dur=400
    0x10 (2 dw) 00 00 aa 00
    CAMERA name=6c07 delay=0 dur=900
    0x7D (3 dw) 84 03 00 00 40 dc 1f 00 ; "@..."
    0x10 (2 dw) 00 00 64 00
    CAMERA name=6c08 delay=500 dur=500
    0x7D (3 dw) 00 00 00 00 c0 73 26 00 ; ".s&."
    CAMERA name=6c09 delay=0 dur=900
    0x0F (3 dw) 28 00 02 00 ff ff ff 80
    0x0F (3 dw) 5c 03 50 00 80 80 80 80
    0x10 (2 dw) 00 00 82 00
    CAMERA name=6c13 delay=760 dur=900
    0x0F (3 dw) 8c 00 64 00 00 00 00 80
    0x7D (3 dw) 00 00 00 00 30 ed 1e 00 ; "0..."
    0x0F (3 dw) 00 00 c8 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    CAMERA name=6c12 delay=600 dur=600
    0x10 (2 dw) 00 00 64 00
    CAMERA name=6c14 delay=800 dur=800
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 30 e5 17 00 ; "0..."
    0x10 (2 dw) 00 00 82 00
    CAMERA name=6c03 delay=600 dur=600
    CAMERA name=6c04 delay=200 dur=200
    0x10 (2 dw) 00 00 c8 00
    CAMERA name=6c15 delay=500 dur=800
    0x0E (5 dw) 2c 01 2c 01 80 80 80 41 00 00 80 3f
    CAMERA name=6c16 delay=0 dur=900
    0x0E (5 dw) 00 00 00 00 80 80 80 00 00 00 80 3f
    0x10 (2 dw) 20 03 a5 00
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### mov1 (30 stages, 11 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 66 00 00 00 00 00 00 00
    ref-7E name=s101 (a 0x2F chunk)
    CAMERA name=s101 delay=700 dur=700
    0x10 (2 dw) 00 00 c8 00
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    CAMERA name=s102 delay=900 dur=900
    CAMERA name=s103 delay=600 dur=600
    CAMERA name=s201 delay=0 dur=500
    0x10 (2 dw) f4 01 c8 00
    0x7D (3 dw) 00 00 00 00 d0 62 27 00 ; ".b'."
    0x7C (3 dw) 00 00 c8 00 72 61 69 6e ; "rain"
    CAMERA name=s202 delay=500 dur=500
    0x7D (3 dw) 00 00 00 00 c0 07 38 00 ; "..8."
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    CAMERA name=s203 delay=1000 dur=1000
    0x10 (2 dw) 00 00 2c 01
    CAMERA name=s301 delay=1000 dur=1000
    CAMERA name=s302 delay=700 dur=700
    0x10 (2 dw) 00 00 c8 00
    CAMERA name=s303 delay=950 dur=1000
    0x0F (3 dw) 32 00 32 00 00 00 00 80
    0x0F (3 dw) 00 00 32 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 20 53 14 00 ; " S.."
    CAMERA name=s401 delay=1000 dur=1000
    CAMERA name=s402 delay=1900 dur=2000
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### main (3 stages, 0 camera refs)
    hdr
    0x73 (5 dw) 03 00 00 00 6c 6f 6f 70 00 00 00 00
    end (terminator)
### mov2 (59 stages, 16 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 60 6c 15 00 ; "`l.."
    0x7B (6 dw) 00 00 00 00 67 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    CAMERA name=c101 delay=1000 dur=1000
    0x10 (2 dw) 00 00 32 00
    CAMERA name=c102 delay=500 dur=500
    0x10 (2 dw) 00 00 1e 00
    CAMERA name=c103 delay=300 dur=300
    CAMERA name=c201 delay=0 dur=500
    0x0F (3 dw) 00 00 05 00 ff ff ff 80
    0x10 (2 dw) 00 00 64 00
    0x7D (3 dw) 05 00 00 00 00 8d 27 00 ; "..'."
    0x0F (3 dw) ef 01 1e 00 80 80 80 80
    0x10 (2 dw) 00 00 32 00
    CAMERA name=c211 delay=300 dur=300
    0x0F (3 dw) 00 00 05 00 e4 ff ff 80
    0x7D (3 dw) 00 00 00 00 c0 d8 2a 00 ; "..*."
    CAMERA name=c202 delay=0 dur=400
    0x10 (2 dw) 05 00 32 00
    0x0F (3 dw) 8b 01 1e 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 60 ca 2f 00 ; "`./."
    0x10 (2 dw) 00 00 32 00
    CAMERA name=c212 delay=300 dur=300
    0x0F (3 dw) 00 00 05 00 ff ee da 80
    CAMERA name=c203 delay=0 dur=600
    0x7D (3 dw) 05 00 00 00 00 bc 34 00 ; "..4."
    0x0F (3 dw) 0e 01 1e 00 80 80 80 80
    0x0F (3 dw) 19 00 4b 00 c6 9e 80 80
    0x10 (2 dw) 32 00 32 00
    0x0F (3 dw) fa 00 c8 00 80 80 80 80
    0x10 (2 dw) 00 00 64 00
    CAMERA name=c204 delay=0 dur=600
    0x7D (3 dw) c2 01 00 00 c0 07 38 00 ; "..8."
    0x0F (3 dw) 96 00 96 00 ff e4 e4 80
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    CAMERA name=c301 delay=0 dur=300
    0x10 (2 dw) 2c 01 32 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    CAMERA name=c302 delay=0 dur=500
    0x7D (3 dw) 00 00 00 00 00 00 00 00 ; "...."
    0x10 (2 dw) f4 01 32 00
    CAMERA name=c303 delay=0 dur=500
    0x10 (2 dw) f4 01 1e 00
    0x10 (2 dw) 00 00 32 00
    CAMERA name=c304 delay=0 dur=600
    0x7D (3 dw) 26 02 00 00 20 89 0b 00 ; " ..."
    0x0F (3 dw) 32 00 32 00 00 00 00 80
    0x7D (3 dw) 00 00 00 00 80 24 2e 00 ; ".$.."
    0x7C (3 dw) 00 00 00 00 64 72 79 77 ; "dryw"
    CAMERA name=c401 delay=1 dur=500
    0x0F (3 dw) f3 01 46 00 80 80 80 80
    0x10 (2 dw) 00 00 96 00
    0x7D (3 dw) 00 00 00 00 a0 ad 39 00 ; "..9."
    CAMERA name=c402 delay=1000 dur=1000
    CAMERA name=c403 delay=1900 dur=2000
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### loop (29 stages, 0 camera refs)
    hdr
    0x3D (2 dw) 00 00 00 00
    ref-3B name=mov1 timing=0x00000000
    ref-3B name=mov2 timing=0x00000000
    ref-3B name=mov3 timing=0x00000000
    ref-3B name=mov5 timing=0x00000000
    ref-3B name=mov4 timing=0x00000000
    ref-3B name=mov6 timing=0x00000000
    ref-3B name=mov7 timing=0x00000000
    ref-3B name=mov8 timing=0x00000000
    0x3E (2 dw) 00 00 00 00
    0xAF (3 dw) 00 00 00 00 01 00 00 00
    ref-3B name=ex1a timing=0x00000000
    ref-3B name=ex1b timing=0x00000000
    ref-3B name=ex1c timing=0x00000000
    0x3E (2 dw) 00 00 00 00
    0xAF (3 dw) 00 00 00 00 02 00 00 00
    ref-3B name=ex2a timing=0x00000000
    ref-3B name=ex2d timing=0x00000000
    ref-3B name=ex2b timing=0x00000000
    ref-3B name=ex2c timing=0x00000000
    0x3E (2 dw) 00 00 00 00
    0xAF (3 dw) 00 00 00 00 03 00 00 00
    ref-3B name=ex3a timing=0x00000000
    ref-3B name=ex3d timing=0x00000000
    ref-3B name=ex3e timing=0x00000000
    ref-3B name=ex3c timing=0x00000000
    0x3E (2 dw) 00 00 00 00
    end (terminator)
### mov4 (35 stages, 11 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 6d 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    0x7D (3 dw) 00 00 14 00 70 c8 21 00 ; "p.!."
    CAMERA name=7c01 delay=800 dur=800
    0x10 (2 dw) 00 00 64 00
    CAMERA name=7c06 delay=500 dur=500
    0x10 (2 dw) 00 00 28 00
    CAMERA name=7c12 delay=500 dur=500
    0x10 (2 dw) 00 00 80 00
    0x7D (3 dw) 00 00 00 00 50 3f 16 00 ; "P?.."
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    CAMERA name=7c03 delay=500 dur=500
    0x10 (2 dw) 00 00 32 00
    CAMERA name=7c05 delay=500 dur=500
    0x10 (2 dw) 00 00 91 00
    CAMERA name=7c04 delay=1200 dur=1200
    0x10 (2 dw) 00 00 82 00
    0x7D (3 dw) 00 00 00 00 20 b8 18 00 ; " ..."
    CAMERA name=7c07 delay=300 dur=300
    0x7D (3 dw) 00 00 00 00 60 18 3c 00 ; "`.<."
    CAMERA name=7c08 delay=880 dur=1000
    0x0F (3 dw) 78 00 64 00 00 00 00 80
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x0F (3 dw) 00 00 73 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 00 00 00 00 ; "...."
    CAMERA name=7c09 delay=600 dur=600
    0x10 (2 dw) 00 00 96 00
    CAMERA name=7c11 delay=1300 dur=1300
    0x10 (2 dw) 00 00 0e 01
    CAMERA name=7c14 delay=550 dur=1570
    0x0F (3 dw) e0 01 be 03 30 80 58 80
    0x0F (3 dw) 9e 02 9e 02 00 00 00 80
    end (terminator)
### ex2a (37 stages, 12 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 02 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 20 15 16 00 ; " ..."
    CAMERA name=4c01 delay=700 dur=700
    0x10 (2 dw) 00 00 32 00
    CAMERA name=4c04 delay=700 dur=700
    0x7D (3 dw) 00 00 00 00 60 f8 1f 00 ; "`..."
    0x10 (2 dw) 00 00 7d 00
    CAMERA name=4c11 delay=1200 dur=1200
    0x7D (3 dw) 00 00 00 00 90 8f 2b 00 ; "..+."
    0x7C (3 dw) 00 00 00 00 72 61 69 6e ; "rain"
    CAMERA name=4c06 delay=465 dur=465
    CAMERA name=4c02 delay=895 dur=1000
    0x0F (3 dw) 69 00 5a 00 00 00 00 80
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    CAMERA name=4c10 delay=0 dur=700
    0x0F (3 dw) bc 02 c8 00 80 80 80 80
    0x10 (2 dw) 00 00 55 00
    CAMERA name=4c03 delay=0 dur=585
    0x7D (3 dw) 00 00 00 00 b0 6e 4a 00 ; ".nJ."
    0x7C (3 dw) 49 02 00 00 66 69 6e 65 ; "fine"
    CAMERA name=4c07 delay=700 dur=700
    0x10 (2 dw) 00 00 bc 02
    CAMERA name=4c13 delay=520 dur=650
    0x0F (3 dw) 82 00 82 00 00 00 00 80
    0x0F (3 dw) 00 00 96 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 60 6c 15 00 ; "`l.."
    CAMERA name=4c16 delay=650 dur=650
    0x10 (2 dw) 00 00 82 00
    CAMERA name=4c14 delay=750 dur=750
    0x10 (2 dw) 00 00 aa 00
    CAMERA name=4c15 delay=0 dur=1900
    0x7D (3 dw) fc 08 6c 07 40 12 17 00 ; "@..."
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex2b (34 stages, 12 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 1d 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 60 9b 22 00 ; "`."."
    CAMERA name=1001 delay=800 dur=800
    0x10 (2 dw) 00 00 6e 00
    CAMERA name=1002 delay=800 dur=800
    0x10 (2 dw) 00 00 3c 00
    CAMERA name=1003 delay=1000 dur=1000
    CAMERA name=1004 delay=600 dur=600
    0x10 (2 dw) 00 00 78 00
    CAMERA name=1005 delay=900 dur=900
    0x7D (3 dw) 00 00 00 00 40 41 24 00 ; "@A$."
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    CAMERA name=1006 delay=900 dur=900
    0x10 (2 dw) 00 00 7d 00
    CAMERA name=1007 delay=500 dur=500
    0x7D (3 dw) 00 00 00 00 40 c5 27 00 ; "@.'."
    CAMERA name=1008 delay=0 dur=800
    0x10 (2 dw) 80 02 78 00
    0x0F (3 dw) a0 00 96 00 00 00 00 80
    0x0F (3 dw) 00 00 50 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 60 8d 4e 00 ; "`.N."
    CAMERA name=1009 delay=600 dur=600
    0x10 (2 dw) 00 00 8c 00
    CAMERA name=1010 delay=1100 dur=1100
    0x10 (2 dw) 00 00 8c 00
    CAMERA name=1011 delay=1000 dur=1000
    0x7D (3 dw) 00 00 00 00 c0 4b 03 00 ; ".K.."
    CAMERA name=1012 delay=800 dur=700
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex2c (36 stages, 14 camera refs)
    hdr
    0x7B (6 dw) 00 00 00 00 21 00 00 00 00 00 00 00
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 14 00 20 15 16 00 ; " ..."
    CAMERA name=5c03 delay=800 dur=800
    CAMERA name=5c04 delay=800 dur=800
    CAMERA name=5c05 delay=0 dur=800
    0x10 (2 dw) 20 03 96 00
    CAMERA name=5c06 delay=999 dur=1000
    0x10 (2 dw) 01 00 64 00
    0x0F (3 dw) 00 00 02 00 ff eb cd 80
    0x7C (3 dw) 00 00 28 00 63 6c 6f 64 ; "clod"
    CAMERA name=5c07 delay=25 dur=600
    0x0F (3 dw) 3f 02 87 00 80 80 80 80
    CAMERA name=5c08 delay=1000 dur=1000
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x10 (2 dw) 00 00 78 00
    CAMERA name=5c09 delay=900 dur=930
    0x10 (2 dw) 00 00 96 00
    CAMERA name=5c10 delay=800 dur=800
    0x7C (3 dw) 00 00 00 00 63 6c 6f 64 ; "clod"
    CAMERA name=5c11 delay=300 dur=300
    CAMERA name=5c12 delay=700 dur=700
    0x10 (2 dw) 00 00 64 00
    CAMERA name=5c14 delay=700 dur=700
    CAMERA name=5c15 delay=300 dur=300
    0x10 (2 dw) 00 00 64 00
    0x0F (3 dw) 00 00 05 00 ff ff ff 80
    CAMERA name=5c16 delay=0 dur=300
    0x7C (3 dw) 23 00 00 00 6d 69 73 74 ; "mist"
    0x0F (3 dw) 09 01 64 00 80 80 80 80
    0x10 (2 dw) 00 00 c8 00
    CAMERA name=5c17 delay=800 dur=800
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex2d (49 stages, 16 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 04 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 30 e5 17 00 ; "0..."
    CAMERA name=cpa0 delay=600 dur=600
    0x10 (2 dw) 00 00 3c 00
    CAMERA name=cpa1 delay=400 dur=400
    CAMERA name=cpa2 delay=300 dur=300
    0x7D (3 dw) 00 00 00 00 c0 07 38 00 ; "..8."
    CAMERA name=cpa3 delay=300 dur=300
    0x10 (2 dw) 00 00 28 00
    CAMERA name=cpa5 delay=500 dur=500
    0x10 (2 dw) 00 00 1e 00
    0x7D (3 dw) 00 00 00 00 80 82 48 00 ; "..H."
    CAMERA name=cpa4 delay=500 dur=700
    0x0F (3 dw) c8 00 8c 00 05 02 08 80
    0x0F (3 dw) 00 00 50 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 00 5e 1a 00 ; ".^.."
    CAMERA name=cpa6 delay=700 dur=700
    0x10 (2 dw) 00 00 50 00
    CAMERA name=cpa8 delay=500 dur=500
    0x10 (2 dw) 00 00 1e 00
    CAMERA name=cpa7 delay=680 dur=800
    0x0F (3 dw) 78 00 78 00 00 00 00 80
    0x0F (3 dw) 00 00 50 00 80 80 80 80
    CAMERA name=cpa9 delay=700 dur=700
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 80 f5 20 00 ; ".. ."
    CAMERA name=cpaa delay=500 dur=500
    0x7D (3 dw) 00 00 00 00 80 24 2e 00 ; ".$.."
    CAMERA name=cpab delay=300 dur=300
    0x10 (2 dw) 00 00 3c 00
    0x7D (3 dw) 00 00 84 03 a0 ad 39 00 ; "..9."
    CAMERA name=cpac delay=740 dur=900
    0x0F (3 dw) a0 00 8c 00 06 05 07 80
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    0x7C (3 dw) 00 00 00 00 66 69 6e 65 ; "fine"
    0x7D (3 dw) 00 00 00 00 00 00 00 00 ; "...."
    CAMERA name=cpad delay=500 dur=600
    0x0F (3 dw) 64 00 50 00 07 06 08 80
    0x0F (3 dw) 00 00 a0 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 80 f5 20 00 ; ".. ."
    CAMERA name=cpae delay=1260 dur=1200
    0x10 (2 dw) 00 00 fa 00
    0x7D (3 dw) 00 00 00 00 c0 07 38 00 ; "..8."
    CAMERA name=cpaf delay=2000 dur=2000
    0x0F (3 dw) 6d 00 64 00 00 00 00 80
    end (terminator)
### ex2e (39 stages, 13 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 18 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 e0 fd 4e 00 ; "..N."
    CAMERA name=ct16 delay=800 dur=990
    0x10 (2 dw) 00 00 1e 00
    CAMERA name=ct17 delay=860 dur=900
    0x0F (3 dw) 8c 00 78 00 06 04 08 80
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 70 99 14 00 ; "p..."
    CAMERA name=ct18 delay=1000 dur=960
    0x10 (2 dw) 00 00 00 00
    0x7D (3 dw) 00 00 00 00 40 cd 2e 00 ; "@..."
    CAMERA name=ct10 delay=1160 dur=1320
    0x0E (5 dw) aa 00 01 00 80 80 80 2a 00 00 80 3f
    CAMERA name=ct11 delay=180 dur=180
    CAMERA name=ct19 delay=150 dur=150
    0x10 (2 dw) 00 00 50 00
    0x0E (5 dw) 00 00 01 00 00 00 00 00 00 00 00 00
    0x7D (3 dw) 00 00 0a 00 20 7b 37 00 ; " {7."
    CAMERA name=ct1b delay=790 dur=790
    0x10 (2 dw) 00 00 3c 00
    0x7D (3 dw) 00 00 00 00 c0 aa 3a 00 ; "..:."
    CAMERA name=ct13 delay=1400 dur=1380
    0x7C (3 dw) 00 00 00 00 6d 69 73 74 ; "mist"
    0x7D (3 dw) 00 00 14 00 30 80 13 00 ; "0..."
    CAMERA name=ct1a delay=500 dur=480
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=ct12 delay=1000 dur=1000
    0x10 (2 dw) 00 00 1e 00
    CAMERA name=ct1c delay=600 dur=600
    0x7C (3 dw) 00 00 00 00 74 68 64 72 ; "thdr"
    0x7D (3 dw) 00 00 00 00 e0 59 2f 00 ; ".Y/."
    CAMERA name=ct14 delay=1500 dur=1500
    CAMERA name=ct1d delay=1000 dur=1000
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)
### ex2f (34 stages, 10 camera refs)
    hdr
    0x0F (3 dw) 00 00 64 00 80 80 80 80
    0x7B (6 dw) 00 00 00 00 19 00 00 00 00 00 00 00
    0x7C (3 dw) 00 00 00 00 74 68 64 72 ; "thdr"
    0x7D (3 dw) 00 00 00 00 e0 fd 4e 00 ; "..N."
    CAMERA name=ct23 delay=500 dur=500
    0x10 (2 dw) 00 00 32 00
    0x7D (3 dw) 00 00 00 00 20 82 21 00 ; " .!."
    CAMERA name=ct21 delay=800 dur=800
    0x7C (3 dw) 00 00 00 00 6d 69 73 74 ; "mist"
    0x7D (3 dw) 00 00 00 00 40 41 24 00 ; "@A$."
    CAMERA name=ct20 delay=500 dur=500
    0x10 (2 dw) 00 00 1e 00
    0x7D (3 dw) 00 00 00 00 c0 e8 38 00 ; "..8."
    CAMERA name=ct28 delay=800 dur=800
    0x7C (3 dw) 00 00 00 00 73 75 6e 79 ; "suny"
    0x7D (3 dw) 00 00 00 00 e0 32 29 00 ; ".2)."
    CAMERA name=ct25 delay=1300 dur=1300
    0x10 (2 dw) 00 00 28 00
    0x7D (3 dw) 00 00 00 00 70 83 39 00 ; "p.9."
    CAMERA name=ct26 delay=380 dur=500
    0x0F (3 dw) 78 00 64 00 05 03 08 80
    0x0F (3 dw) 00 00 3c 00 80 80 80 80
    0x7D (3 dw) 00 00 00 00 40 e3 09 00 ; "@..."
    CAMERA name=ct27 delay=400 dur=360
    0x7D (3 dw) 00 00 00 00 00 8d 27 00 ; "..'."
    CAMERA name=ct29 delay=800 dur=800
    0x10 (2 dw) 00 00 32 00
    0x7D (3 dw) 00 00 14 00 e0 9e 17 00 ; "...."
    CAMERA name=ct2a delay=500 dur=500
    0x10 (2 dw) 00 00 3c 00
    CAMERA name=ct2b delay=3900 dur=4000
    0x0F (3 dw) 64 00 64 00 00 00 00 80
    end (terminator)

## census

camera chunks (0x06): 317 total; matching ^[0-9a-f]{2}[0-9]{2}$: 184; other: 133
distinct hex prefixes (as zone ids, with route counts): 0x10=16 x12, 0x11=17 x16, 0x1C=28 x14, 0x2C=44 x19, 0x3C=60 x13, 0x4C=76 x16, 0x5C=92 x16, 0x6C=108 x15, 0x7C=124 x13, 0x8C=140 x13, 0x9C=156 x16, 0xC0=192 x3, 0xC1=193 x3, 0xC2=194 x7, 0xC3=195 x4, 0xC4=196 x3, 0xC9=201 x1
prefixes > 299 (not a valid zone id): none

non-hex camera names: cga0 cga1 cga2 cga3 cga4 cga5 cga6 cga7 cga8 cga9 cgaa cgab cgac cgad cgh0 cgh1 cgh2 cgh3 cgh4 cgh5 cgh6 cgh7 cgh8 cgh9 cgha cghb cghc cghd cghe cghf cgn0 cgn1 cgn2 cgn3 cgn4 cgn5 cgn6 cgn7 cgn8 cgn9 cgna cgnb cgu0 cgu1 cgu2 cgu3 cgu4 cgu5 cgu6 cgu7 cgu8 cgu9 cgua cgub cguc cpa0 cpa1 cpa2 cpa3 cpa4 cpa5 cpa6 cpa7 cpa8 cpa9 cpaa cpab cpac cpad cpae cpaf cqf0 cqf1 cqf2 cqf3 cqf4 cqf5 cqf6 cqf7 cqf8 cqf9 cqfa cqfb crz0 crz1 crz2 crz3 crz4 crz5 crz6 crz7 crz8 crz9 crza crzb ct10 ct11 ct12 ct13 ct14 ct15 ct16 ct17 ct18 ct19 ct1a ct1b ct1c ct1d ct20 ct21 ct22 ct23 ct24 ct25 ct26 ct27 ct28 ct29 ct2a ct2b s101 s102 s103 s201 s202 s203 s301 s302 s303 s313 s401 s402

## hex prefix -> zone id -> channel name

  0x10 =  16  Promyvion-Holla
  0x11 =  17  Spire_of_Holla
  0x1C =  28  Sacrarium
  0x2C =  44  Abdhaljs_Isle-Purgonorgo
  0x3C =  60  The_Ashu_Talif
  0x4C =  76  Silver_Sea_Remnants
  0x5C =  92  Beadeaux_[S]
  0x6C = 108  Konschtat_Highlands
  0x7C = 124  Yhoator_Jungle
  0x8C = 140  Ghelsba_Outpost
  0x9C = 156  Throne_Room_[S]
  0xC0 = 192  Inner_Horutoto_Ruins
  0xC1 = 193  Ordelles_Caves
  0xC2 = 194  Outer_Horutoto_Ruins
  0xC3 = 195  The_Eldieme_Necropolis
  0xC4 = 196  Gusgen_Mines
  0xC9 = 201  Cloister_of_Gales

stage type histogram across all routines: 0x00 x24, 0x01 x24, 0x04 x286, 0x0E x6, 0x0F x141, 0x10 x152, 0x3B x19, 0x3D x2, 0x3E x5, 0x73 x1, 0x7B x22, 0x7C x72, 0x7D x148, 0x7E x1, 0xAF x3

routine -> camera route refs (name, delay u16, dur u16):
  ex3e: crz1(1800,1800), crz2(1000,1000), crz3(400,600), crz4(1220,1400), crz5(2000,2000), crz6(1000,1000), crz7(1600,1600), crz8(680,800), crz9(1000,1000), crz0(600,620), crza(800,800), crzb(1960,2000)
  ex3d: cgn0(1000,1000), cgn1(1100,1100), cgn3(600,600), cgn5(600,600), cgn4(1000,1000), cgn6(700,700), cgn7(1100,1200), cgn2(1000,1000), cgn9(910,1000), cgna(800,780), cgn8(1800,1800), cgnb(2000,2000)
  ex3c: 1101(1000,980), 1102(1200,1200), 1103(800,800), 1104(1100,1080), 1105(400,500), 1106(0,1100), 1108(1550,1650), 1109(0,940), 1110(600,600), 1111(984,1030), 1112(250,250), 1113(440,440), 1114(300,300), 1115(300,300), 1116(615,600)
  ex3b: 9c01(600,600), 9c02(2,900), 9c03(2,800), 9c04(2,670), 9c05(0,1200), 9c07(0,500), 9c08(0,250), 9c09(1,600), 9c11(0,300), 9c12(15,780), 9c13(1000,1000), 9c15(900,900), 9c16(700,800)
  ex3a: 8c01(1000,980), 8c02(700,700), 8c03(650,650), 8c04(800,800), 8c05(0,950), 8c07(800,800), 8c08(780,780), 8c09(620,620), 8c12(450,450), 8c13(850,1050), 8c10(2000,1900)
  ex1c: 3c01(800,800), 3c04(0,800), 3c02(800,800), 3c03(700,700), 3c10(300,300), 3c07(800,800), 3c08(0,500), 3c09(800,900), 3c11(0,900), 3c06(0,800), 3c12(900,900), 3c13(1600,1400)
  ex1b: 2c01(800,800), 2c02(350,350), 2c03(400,400), 2c04(30,700), 2c16(650,650), 2c06(0,900), 2c17(0,500), 2c07(750,750), 2c08(700,700), 2c10(850,850), 2c12(900,900), 2c13(600,800), 2c19(400,500), 2c15(1000,700)
  ex1a: 1c01(600,600), 1c03(400,400), 1c02(400,400), 1c04(600,600), 1c05(500,500), 1c06(1100,1100), 1c07(900,900), 1c08(0,1000), 1c09(0,700), 1c10(1300,1300), 1c11(400,400), 1c12(300,600), 1c13(600,600), 1c14(0,600)
  mov8: cgh0(799,800), cgh1(600,600), cgh2(500,500), cgh3(1000,1000), cgh4(400,400), cghc(300,300), cgh5(600,600), cgh6(400,400), cgh7(300,300), cgh8(310,400), cgh9(500,500), cgha(500,500), cghb(500,500), cghf(600,600), cghd(800,800), cghe(2000,2000)
  mov7: cqf0(600,600), cqf1(600,600), cqf2(700,700), cqf3(200,300), cqf4(400,400), cqf5(500,500), cqf6(700,700), cqf7(400,400), cqf8(500,500), cqf9(1000,1000), cqfa(900,900), cqfb(3000,3000)
  mov6: cga0(800,800), cga8(500,480), cga1(800,800), cga2(500,500), cgad(100,100), cga3(600,600), cga4(500,500), cga5(300,300), cga6(1000,1000), cga7(500,500), cgaa(300,300), cga9(280,300), cgab(1000,1000), cgac(2000,2000)
  mov5: cgu1(900,900), cgu2(800,800), cgu3(620,800), cgu9(1000,1000), cgu4(880,1000), cgu6(500,500), cgu7(500,500), cgu8(1000,1000), cgua(350,350), cgu0(400,350), cgu5(1500,1500), cguc(1800,1800)
  mov3: 6c01(1000,1000), 6c02(700,700), 6c06(700,700), 6c05(400,400), 6c07(0,900), 6c08(500,500), 6c09(0,900), 6c13(760,900), 6c12(600,600), 6c14(800,800), 6c03(600,600), 6c04(200,200), 6c15(500,800), 6c16(0,900)
  mov1: s101(700,700), s102(900,900), s103(600,600), s201(0,500), s202(500,500), s203(1000,1000), s301(1000,1000), s302(700,700), s303(950,1000), s401(1000,1000), s402(1900,2000)
  main: (none)
  mov2: c101(1000,1000), c102(500,500), c103(300,300), c201(0,500), c211(300,300), c202(0,400), c212(300,300), c203(0,600), c204(0,600), c301(0,300), c302(0,500), c303(0,500), c304(0,600), c401(1,500), c402(1000,1000), c403(1900,2000)
  loop: (none)
  mov4: 7c01(800,800), 7c06(500,500), 7c12(500,500), 7c03(500,500), 7c05(500,500), 7c04(1200,1200), 7c07(300,300), 7c08(880,1000), 7c09(600,600), 7c11(1300,1300), 7c14(550,1570)
  ex2a: 4c01(700,700), 4c04(700,700), 4c11(1200,1200), 4c06(465,465), 4c02(895,1000), 4c10(0,700), 4c03(0,585), 4c07(700,700), 4c13(520,650), 4c16(650,650), 4c14(750,750), 4c15(0,1900)
  ex2b: 1001(800,800), 1002(800,800), 1003(1000,1000), 1004(600,600), 1005(900,900), 1006(900,900), 1007(500,500), 1008(0,800), 1009(600,600), 1010(1100,1100), 1011(1000,1000), 1012(800,700)
  ex2c: 5c03(800,800), 5c04(800,800), 5c05(0,800), 5c06(999,1000), 5c07(25,600), 5c08(1000,1000), 5c09(900,930), 5c10(800,800), 5c11(300,300), 5c12(700,700), 5c14(700,700), 5c15(300,300), 5c16(0,300), 5c17(800,800)
  ex2d: cpa0(600,600), cpa1(400,400), cpa2(300,300), cpa3(300,300), cpa5(500,500), cpa4(500,700), cpa6(700,700), cpa8(500,500), cpa7(680,800), cpa9(700,700), cpaa(500,500), cpab(300,300), cpac(740,900), cpad(500,600), cpae(1260,1200), cpaf(2000,2000)
  ex2e: ct16(800,990), ct17(860,900), ct18(1000,960), ct10(1160,1320), ct11(180,180), ct19(150,150), ct1b(790,790), ct13(1400,1380), ct1a(500,480), ct12(1000,1000), ct1c(600,600), ct14(1500,1500), ct1d(1000,1000)
  ex2f: ct23(500,500), ct21(800,800), ct20(500,500), ct28(800,800), ct25(1300,1300), ct26(380,500), ct27(400,360), ct29(800,800), ct2a(500,500), ct2b(3900,4000)

## 0x04 route references vs 0x06 definitions

286 distinct routes referenced by 0x04 stages; 0 not defined in this file: none
  1001: 1 (defined)
  1002: 1 (defined)
  1003: 1 (defined)
  1004: 1 (defined)
  1005: 1 (defined)
  1006: 1 (defined)
  1007: 1 (defined)
  1008: 1 (defined)
  1009: 1 (defined)
  1010: 1 (defined)
  1011: 1 (defined)
  1012: 1 (defined)
  1101: 1 (defined)
  1102: 1 (defined)
  1103: 1 (defined)
  1104: 1 (defined)
  1105: 1 (defined)
  1106: 1 (defined)
  1108: 1 (defined)
  1109: 1 (defined)
  1110: 1 (defined)
  1111: 1 (defined)
  1112: 1 (defined)
  1113: 1 (defined)
  1114: 1 (defined)
  1115: 1 (defined)
  1116: 1 (defined)
  1c01: 1 (defined)
  1c02: 1 (defined)
  1c03: 1 (defined)
  1c04: 1 (defined)
  1c05: 1 (defined)
  1c06: 1 (defined)
  1c07: 1 (defined)
  1c08: 1 (defined)
  1c09: 1 (defined)
  1c10: 1 (defined)
  1c11: 1 (defined)
  1c12: 1 (defined)
  1c13: 1 (defined)
  1c14: 1 (defined)
  2c01: 1 (defined)
  2c02: 1 (defined)
  2c03: 1 (defined)
  2c04: 1 (defined)
  2c06: 1 (defined)
  2c07: 1 (defined)
  2c08: 1 (defined)
  2c10: 1 (defined)
  2c12: 1 (defined)
  2c13: 1 (defined)
  2c15: 1 (defined)
  2c16: 1 (defined)
  2c17: 1 (defined)
  2c19: 1 (defined)
  3c01: 1 (defined)
  3c02: 1 (defined)
  3c03: 1 (defined)
  3c04: 1 (defined)
  3c06: 1 (defined)
  3c07: 1 (defined)
  3c08: 1 (defined)
  3c09: 1 (defined)
  3c10: 1 (defined)
  3c11: 1 (defined)
  3c12: 1 (defined)
  3c13: 1 (defined)
  4c01: 1 (defined)
  4c02: 1 (defined)
  4c03: 1 (defined)
  4c04: 1 (defined)
  4c06: 1 (defined)
  4c07: 1 (defined)
  4c10: 1 (defined)
  4c11: 1 (defined)
  4c13: 1 (defined)
  4c14: 1 (defined)
  4c15: 1 (defined)
  4c16: 1 (defined)
  5c03: 1 (defined)
  5c04: 1 (defined)
  5c05: 1 (defined)
  5c06: 1 (defined)
  5c07: 1 (defined)
  5c08: 1 (defined)
  5c09: 1 (defined)
  5c10: 1 (defined)
  5c11: 1 (defined)
  5c12: 1 (defined)
  5c14: 1 (defined)
  5c15: 1 (defined)
  5c16: 1 (defined)
  5c17: 1 (defined)
  6c01: 1 (defined)
  6c02: 1 (defined)
  6c03: 1 (defined)
  6c04: 1 (defined)
  6c05: 1 (defined)
  6c06: 1 (defined)
  6c07: 1 (defined)
  6c08: 1 (defined)
  6c09: 1 (defined)
  6c12: 1 (defined)
  6c13: 1 (defined)
  6c14: 1 (defined)
  6c15: 1 (defined)
  6c16: 1 (defined)
  7c01: 1 (defined)
  7c03: 1 (defined)
  7c04: 1 (defined)
  7c05: 1 (defined)
  7c06: 1 (defined)
  7c07: 1 (defined)
  7c08: 1 (defined)
  7c09: 1 (defined)
  7c11: 1 (defined)
  7c12: 1 (defined)
  7c14: 1 (defined)
  8c01: 1 (defined)
  8c02: 1 (defined)
  8c03: 1 (defined)
  8c04: 1 (defined)
  8c05: 1 (defined)
  8c07: 1 (defined)
  8c08: 1 (defined)
  8c09: 1 (defined)
  8c10: 1 (defined)
  8c12: 1 (defined)
  8c13: 1 (defined)
  9c01: 1 (defined)
  9c02: 1 (defined)
  9c03: 1 (defined)
  9c04: 1 (defined)
  9c05: 1 (defined)
  9c07: 1 (defined)
  9c08: 1 (defined)
  9c09: 1 (defined)
  9c11: 1 (defined)
  9c12: 1 (defined)
  9c13: 1 (defined)
  9c15: 1 (defined)
  9c16: 1 (defined)
  c101: 1 (defined)
  c102: 1 (defined)
  c103: 1 (defined)
  c201: 1 (defined)
  c202: 1 (defined)
  c203: 1 (defined)
  c204: 1 (defined)
  c211: 1 (defined)
  c212: 1 (defined)
  c301: 1 (defined)
  c302: 1 (defined)
  c303: 1 (defined)
  c304: 1 (defined)
  c401: 1 (defined)
  c402: 1 (defined)
  c403: 1 (defined)
  cga0: 1 (defined)
  cga1: 1 (defined)
  cga2: 1 (defined)
  cga3: 1 (defined)
  cga4: 1 (defined)
  cga5: 1 (defined)
  cga6: 1 (defined)
  cga7: 1 (defined)
  cga8: 1 (defined)
  cga9: 1 (defined)
  cgaa: 1 (defined)
  cgab: 1 (defined)
  cgac: 1 (defined)
  cgad: 1 (defined)
  cgh0: 1 (defined)
  cgh1: 1 (defined)
  cgh2: 1 (defined)
  cgh3: 1 (defined)
  cgh4: 1 (defined)
  cgh5: 1 (defined)
  cgh6: 1 (defined)
  cgh7: 1 (defined)
  cgh8: 1 (defined)
  cgh9: 1 (defined)
  cgha: 1 (defined)
  cghb: 1 (defined)
  cghc: 1 (defined)
  cghd: 1 (defined)
  cghe: 1 (defined)
  cghf: 1 (defined)
  cgn0: 1 (defined)
  cgn1: 1 (defined)
  cgn2: 1 (defined)
  cgn3: 1 (defined)
  cgn4: 1 (defined)
  cgn5: 1 (defined)
  cgn6: 1 (defined)
  cgn7: 1 (defined)
  cgn8: 1 (defined)
  cgn9: 1 (defined)
  cgna: 1 (defined)
  cgnb: 1 (defined)
  cgu0: 1 (defined)
  cgu1: 1 (defined)
  cgu2: 1 (defined)
  cgu3: 1 (defined)
  cgu4: 1 (defined)
  cgu5: 1 (defined)
  cgu6: 1 (defined)
  cgu7: 1 (defined)
  cgu8: 1 (defined)
  cgu9: 1 (defined)
  cgua: 1 (defined)
  cguc: 1 (defined)
  cpa0: 1 (defined)
  cpa1: 1 (defined)
  cpa2: 1 (defined)
  cpa3: 1 (defined)
  cpa4: 1 (defined)
  cpa5: 1 (defined)
  cpa6: 1 (defined)
  cpa7: 1 (defined)
  cpa8: 1 (defined)
  cpa9: 1 (defined)
  cpaa: 1 (defined)
  cpab: 1 (defined)
  cpac: 1 (defined)
  cpad: 1 (defined)
  cpae: 1 (defined)
  cpaf: 1 (defined)
  cqf0: 1 (defined)
  cqf1: 1 (defined)
  cqf2: 1 (defined)
  cqf3: 1 (defined)
  cqf4: 1 (defined)
  cqf5: 1 (defined)
  cqf6: 1 (defined)
  cqf7: 1 (defined)
  cqf8: 1 (defined)
  cqf9: 1 (defined)
  cqfa: 1 (defined)
  cqfb: 1 (defined)
  crz0: 1 (defined)
  crz1: 1 (defined)
  crz2: 1 (defined)
  crz3: 1 (defined)
  crz4: 1 (defined)
  crz5: 1 (defined)
  crz6: 1 (defined)
  crz7: 1 (defined)
  crz8: 1 (defined)
  crz9: 1 (defined)
  crza: 1 (defined)
  crzb: 1 (defined)
  ct10: 1 (defined)
  ct11: 1 (defined)
  ct12: 1 (defined)
  ct13: 1 (defined)
  ct14: 1 (defined)
  ct16: 1 (defined)
  ct17: 1 (defined)
  ct18: 1 (defined)
  ct19: 1 (defined)
  ct1a: 1 (defined)
  ct1b: 1 (defined)
  ct1c: 1 (defined)
  ct1d: 1 (defined)
  ct20: 1 (defined)
  ct21: 1 (defined)
  ct23: 1 (defined)
  ct25: 1 (defined)
  ct26: 1 (defined)
  ct27: 1 (defined)
  ct28: 1 (defined)
  ct29: 1 (defined)
  ct2a: 1 (defined)
  ct2b: 1 (defined)
  s101: 1 (defined)
  s102: 1 (defined)
  s103: 1 (defined)
  s201: 1 (defined)
  s202: 1 (defined)
  s203: 1 (defined)
  s301: 1 (defined)
  s302: 1 (defined)
  s303: 1 (defined)
  s401: 1 (defined)
  s402: 1 (defined)
```

## L. The 192 probe (E19)

Backs E19: the one-probe float search for 192.0f / 280.0f / 350.0f and the dump of the selecting function.

### L.1 Raw u32 byte search over the POL1-decoded .text and all data sections: 192.0f has 0 hits whole-image; 280.0f / 350.0f hit lists with context around rva 0x59455/0x5945F

Source file: `out3/probe_192.md`

```text
# Probe: float immediates 192.0f / 280.0f / 350.0f in FFXiMain.dll (E19)

Method: raw little-endian u32 byte search over the POL1-decoded .text and all on-disk data sections (common.py Image.find_u32). No disassembly assumption.

.text rva 0x1000 size 3307054

192.0f (0x43400000): 0 hit(s) in .text

280.0f (0x438C0000): 3 hit(s) in .text
  rva 0x59455
  rva 0x8429D
  rva 0xA5FE6

350.0f (0x43AF0000): 6 hit(s) in .text
  rva 0x153D4
  rva 0x1E515
  rva 0x1F7C2
  rva 0x29508
  rva 0x29599
  rva 0x5945F

192.0f whole-image hits: 0
1/192 (0x3BAAAAAB) whole-image hits: 0

context around rva 0x59455 (280.0f) / 0x5945F (350.0f):
  0x59445: 5C 00 00 00 00 A0 C0 7F 48 10 84 C0 C7 44 24 18
  0x59455: 00 00 8C 43 75 08 C7 44 24 18 00 00 AF 43 8B 44
  0x59465: 24 18 50 E8 23 BE FB FF 83 C4 04 33 C0 5F 5E 5D
  0x59475: 5B 81 C4 54 02 00 00 C3 8B 41 0C 85 C0 89 44 24
  0x59485: 38 74 5B 8A 11 8B 38 80 FA 73 75 2D 8B 8E 90 00
  0x59495: 00 00 51 6A 01 8B CE E8 3F 93 00 00 50 8B CE E8
```

### L.2 The selecting function @rva 0x5940A to 0x5947D: global byte @rva 0x487FC0 picks 280.0f vs 350.0f, fed to the focal setter @rva 0x15290 (disasm.py --func 0x5940A)

Source file: `out3/d_59455.md`

```text
; func 0x5940A..0x5947D (115 bytes), callers: 0
  0005940A  8d 54 24 5c                lea edx, [esp + 0x5c]
  0005940E  8d 44 24 4c                lea eax, [esp + 0x4c]
  00059412  52                         push edx
  00059413  50                         push eax
  00059414  e8 77 7e fc ff             call 0x10021290
  00059419  83 c4 08                   add esp, 8
  0005941C  8d 4c 24 4c                lea ecx, [esp + 0x4c]
  00059420  51                         push ecx
  00059421  e8 2a be fb ff             call 0x10015250
  00059426  8b c8                      mov ecx, eax
  00059428  e8 43 53 fc ff             call 0x1001e770
  0005942D  8d 54 24 5c                lea edx, [esp + 0x5c]
  00059431  52                         push edx
  00059432  e8 19 be fb ff             call 0x10015250
  00059437  8b c8                      mov ecx, eax
  00059439  e8 52 53 fc ff             call 0x1001e790
  0005943E  e8 0d be fb ff             call 0x10015250
  00059443  c7 40 5c 00 00 00 00       mov dword ptr [eax + 0x5c], 0
  0005944A  a0 c0 7f 48 10             mov al, byte ptr [0x10487fc0]
  0005944F  84 c0                      test al, al
  00059451  c7 44 24 18 00 00 8c 43    mov dword ptr [esp + 0x18], 0x438c0000
  00059459  75 08                      jne 0x10059463
  0005945B  c7 44 24 18 00 00 af 43    mov dword ptr [esp + 0x18], 0x43af0000
  00059463  8b 44 24 18                mov eax, dword ptr [esp + 0x18]
  00059467  50                         push eax
  00059468  e8 23 be fb ff             call 0x10015290
  0005946D  83 c4 04                   add esp, 4
  00059470  33 c0                      xor eax, eax
  00059472  5f                         pop edi
  00059473  5e                         pop esi
  00059474  5d                         pop ebp
  00059475  5b                         pop ebx
  00059476  81 c4 54 02 00 00          add esp, 0x254
  0005947C  c3                         ret 
```

## M. The CHAR_NPC Type sweep (E20)

Backs E20: every disp-0xEE site, the SubKind dispatch and its jump table, and the per-Type setter regions of the s2c 0x0E handler.

### M.1 All 84 memory operands with disp 0xEE across .text (lean capstone scanner), each with a few context lines

Source file: `out3/x_ee.md`

```text
total records: 1175095
memory operands with disp 0xEE: 84 sites
- [R] rva 0x3ED4: movsx eax, word ptr [esp + ebp*4 + 0xee]
      0x3EC9: mov edx, dword ptr [esp + 0x10]
      0x3ECD: lea esi, [esp + 0x88]
      0x3EDC: fst dword ptr [0x1034f740]
      0x3EE2: add ecx, edx
- [R] rva 0x84417: movsx eax, byte ptr [eax + 0xee]
      0x84413: test eax, eax
      0x84415: je 0x8441f
      0x8441E: ret 
      0x8441F: mov eax, dword ptr [0x1047d650]
- [W] rva 0x87519: cmp byte ptr [ecx + 0xee], 3
      0x87512: cmp eax, 0x1000000
      0x87517: jne 0x87581
      0x87520: jne 0x87581
      0x87522: mov eax, dword ptr [ecx + 0xa0]
- [W] rva 0x8A1B3: cmp byte ptr [esi + 0xee], 8
      0x8A1B0: push esi
      0x8A1B1: mov esi, ecx
      0x8A1BA: je 0x8a1da
      0x8A1BC: mov ecx, dword ptr [esi + 0xa0]
- [R] rva 0x8A274: mov al, byte ptr [esi + 0xee]
      0x8A268: mov dword ptr [esi + 0x1b0], edx
      0x8A26E: mov dword ptr [esi + 0x1b4], eax
      0x8A27A: cmp al, 2
      0x8A27C: je 0x8a282
- [W] rva 0x8A3F7: mov byte ptr [esi + 0xee], bl
      0x8A3EB: mov dword ptr [esi + 0x120], edi
      0x8A3F1: lea edi, [esi + 0xfc]
      0x8A3FD: mov byte ptr [esi + 0xef], bl
      0x8A403: mov word ptr [esi + 0x166], bx
- [R] rva 0x8B3B9: mov al, byte ptr [ecx + 0xee]
      0x8B3B0: test dword ptr [ecx + 0x78], 0xff000000
      0x8B3B7: jne 0x8b3ea
      0x8B3BF: cmp al, 3
      0x8B3C1: je 0x8b3ea
- [R] rva 0x8B481: mov al, byte ptr [esi + 0xee]
      0x8B47B: push edi
      0x8B47C: mov edi, 0x200
      0x8B487: cmp al, 6
      0x8B489: je 0x8b48f
- [R] rva 0x8B528: mov al, byte ptr [esi + 0xee]
      0x8B51F: call 0x956b0
      0x8B524: mov byte ptr [esp + 0x11], al
      0x8B52E: cmp al, 4
      0x8B530: jne 0x8b5dc
- [W] rva 0x8B584: cmp byte ptr [esi + 0xee], 4
      0x8B57B: add esp, 0x88
      0x8B581: ret 4
      0x8B58B: jne 0x8c3af
      0x8B591: lea ecx, [esp + 0x14]
- [R] rva 0x8BABC: mov al, byte ptr [esi + 0xee]
      0x8BAB4: test al, al
      0x8BAB6: jne 0x8c3af
      0x8BAC2: cmp al, 3
      0x8BAC4: je 0x8bae9
- [R] rva 0x8BC50: mov al, byte ptr [esi + 0xee]
      0x8BC47: add esp, 0x88
      0x8BC4D: ret 4
      0x8BC56: cmp al, 3
      0x8BC58: je 0x8c3af
- [R] rva 0x8C4A5: mov al, byte ptr [esi + 0xee]
      0x8C4A1: test eax, eax
      0x8C4A3: js 0x8c4d5
      0x8C4AB: cmp al, 3
      0x8C4AD: je 0x8c4d5
- [R] rva 0x8C4E5: mov al, byte ptr [esi + 0xee]
      0x8C4D5: test dword ptr [esi + 0x128], 0x20000000
      0x8C4DF: jne 0x8c66c
      0x8C4EB: cmp al, 3
      0x8C4ED: je 0x8c614
- [R] rva 0x8C62F: mov al, byte ptr [esi + 0xee]
      0x8C628: test eax, 0x40000000
      0x8C62D: je 0x8c66c
      0x8C635: cmp al, 3
      0x8C637: je 0x8c662
- [R] rva 0x8C72F: mov al, byte ptr [esi + 0xee]
      0x8C727: test ecx, ecx
      0x8C729: je 0x8c8a6
      0x8C735: cmp al, bl
      0x8C737: je 0x8c8a6
- [R] rva 0x8C822: mov al, byte ptr [esi + 0xee]
      0x8C81A: test ecx, ecx
      0x8C81C: je 0x8c8a6
      0x8C828: cmp al, 2
      0x8C82A: je 0x8c830
- [W] rva 0x8C85A: cmp byte ptr [esi + 0xee], 2
      0x8C856: test al, al
      0x8C858: je 0x8c8a6
      0x8C861: je 0x8c86a
      0x8C863: mov ecx, esi
- [W] rva 0x8C8D5: cmp byte ptr [esi + 0xee], 5
      0x8C8CD: test eax, eax
      0x8C8CF: je 0x8cc30
      0x8C8DC: jne 0x8cc30
      0x8C8E2: mov al, byte ptr [esi + 0x120]
- [W] rva 0x8C934: cmp byte ptr [esi + 0xee], bl
      0x8C92C: test ecx, ecx
      0x8C92E: je 0x8cc30
      0x8C93A: jne 0x8cc30
      0x8C940: push 1
- [W] rva 0x8C95D: cmp byte ptr [esi + 0xee], bl
      0x8C955: test ecx, ecx
      0x8C957: je 0x8cc30
      0x8C963: jne 0x8cc30
      0x8C969: push 0
- [W] rva 0x8C986: cmp byte ptr [esi + 0xee], bl
      0x8C97E: test ecx, ecx
      0x8C980: je 0x8cc30
      0x8C98C: jne 0x8cc30
      0x8C992: call 0xad280
- [R] rva 0x8C9AD: mov al, byte ptr [esi + 0xee]
      0x8C9A5: test ecx, ecx
      0x8C9A7: je 0x8cc30
      0x8C9B3: cmp al, 2
      0x8C9B5: je 0x8c9bf
- [R] rva 0x8CA2F: mov dl, byte ptr [esi + 0xee]
      0x8CA27: test ecx, ecx
      0x8CA29: je 0x8cc30
      0x8CA35: cmp dl, bl
      0x8CA37: je 0x8cc30
- [R] rva 0x8CAF8: mov al, byte ptr [esi + 0xee]
      0x8CAF0: test ecx, ecx
      0x8CAF2: je 0x8cc30
      0x8CAFE: cmp al, bl
      0x8CB00: je 0x8cc30
- [R] rva 0x8CBAC: mov al, byte ptr [esi + 0xee]
      0x8CBA4: test ecx, ecx
      0x8CBA6: je 0x8cc30
      0x8CBB2: cmp al, bl
      0x8CBB4: je 0x8cc30
- [R] rva 0x8CDD2: mov cl, byte ptr [esi + 0xee]
      0x8CDC5: je 0x8cf7b
      0x8CDCB: test dword ptr [esi + 0x78], 0xff000000
      0x8CDD8: je 0x8cec8
      0x8CDDE: test cl, cl
- [R] rva 0x8D52F: mov al, byte ptr [esi + 0xee]
      0x8D529: fstp dword ptr [esp + 0x10]
      0x8D52D: je 0x8d55f
      0x8D535: test al, al
      0x8D537: je 0x8d549
- [R] rva 0x8D78D: mov al, byte ptr [esi + 0xee]
      0x8D787: mov ecx, dword ptr [esi + 0xc]
      0x8D78A: mov dword ptr [esi + 0x4c], ecx
      0x8D793: cmp al, 2
      0x8D795: je 0x8d79f
- [R] rva 0x8D846: mov al, byte ptr [esi + 0xee]
      0x8D83D: mov dword ptr [esi + 0x10], ecx
      0x8D840: je 0x8d8c9
      0x8D84C: test al, al
      0x8D84E: je 0x8d864
- [R] rva 0x8DA30: mov cl, byte ptr [esi + 0xee]
      0x8DA23: test dword ptr [esi + 0x78], 0xff000000
      0x8DA2A: je 0x8db3f
      0x8DA36: cmp cl, 2
      0x8DA39: je 0x8da40
- [R] rva 0x8DB90: mov al, byte ptr [esi + 0xee]
      0x8DB8C: add esp, 8
      0x8DB8F: ret 
      0x8DB96: cmp al, 3
      0x8DB98: je 0x8e0c3
- [R] rva 0x8E35F: mov al, byte ptr [esi + 0xee]
      0x8E356: or ah, 8
      0x8E359: mov dword ptr [esi + 0x1d0], eax
      0x8E365: cmp al, 3
      0x8E367: jne 0x8e370
- [R] rva 0x8EB5D: mov al, byte ptr [esi + 0xee]
      0x8EB55: test al, al
      0x8EB57: je 0x8ec7e
      0x8EB63: cmp al, 3
      0x8EB65: je 0x8eb82
- [R] rva 0x8EFDE: mov al, byte ptr [esi + 0xee]
      0x8EFD5: cmp eax, 4
      0x8EFD8: jae 0x8f0b2
      0x8EFE4: cmp al, 6
      0x8EFE6: je 0x8f0b2
- [R] rva 0x8F2BB: movsx eax, byte ptr [ecx + 0xee]
      0x8F2B6: test ah, 2
      0x8F2B9: je 0x8f2e8
      0x8F2C2: cmp eax, 8
      0x8F2C5: ja 0x8f2e8
- [R] rva 0x8F814: movsx ecx, byte ptr [esi + 0xee]
      0x8F80B: mov dword ptr [esi + 0x170], ecx
      0x8F811: or ah, 2
      0x8F81B: and edi, 0x5fffffff
      0x8F821: sub ecx, 3
- [R] rva 0x90A09: mov al, byte ptr [esi + 0xee]
      0x90A00: test ah, 2
      0x90A03: je 0x91673
      0x90A0F: cmp al, 3
      0x90A11: je 0x90a78
- [R] rva 0x90B38: mov al, byte ptr [esi + 0xee]
      0x90B2B: mov ebp, dword ptr [eax*4 + 0x1035b4e0]
      0x90B32: mov ecx, dword ptr [esi + 0x120]
      0x90B3E: and ch, 0xe7
      0x90B41: cmp al, 2
- [R] rva 0x929F5: mov al, byte ptr [esi + 0xee]
      0x929EC: test ch, 2
      0x929EF: je 0x92b24
      0x929FB: test al, al
      0x929FD: je 0x92a17
- [R] rva 0x92B40: mov al, byte ptr [ecx + 0xee]
      0x92B37: test ah, 2
      0x92B3A: je 0x92c22
      0x92B46: test al, al
      0x92B48: je 0x92b62
- [R] rva 0x92C42: mov al, byte ptr [edi + 0xee]
      0x92C39: test ah, 2
      0x92C3C: je 0x92f93
      0x92C48: test al, al
      0x92C4A: je 0x92c64
- [R] rva 0x92FBA: mov al, byte ptr [esi + 0xee]
      0x92FB2: test al, al
      0x92FB4: jns 0x933ce
      0x92FC0: test al, al
      0x92FC2: je 0x92fdc
- [W] rva 0x95015: mov byte ptr [esi + 0xee], bl
      0x9500C: cmp word ptr [esi + 0x210], bx
      0x95013: jne 0x9501b
      0x9501B: mov edx, dword ptr [0x104dfdd8]
      0x95021: mov ax, word ptr [0x10485fba]
- [R] rva 0x95863: mov al, byte ptr [esi + 0xee]
      0x95860: push esi
      0x95861: mov esi, ecx
      0x95869: cmp al, 7
      0x9586B: je 0x95909
- [W] rva 0x95F77: mov byte ptr [esi + 0xee], 0
      0x95F6B: mov dword ptr [esi + 0x128], ecx
      0x95F71: mov dword ptr [esi + 0x120], eax
      0x95F7E: pop esi
      0x95F7F: pop ebx
- [W] rva 0x95FA4: mov byte ptr [esi + 0xee], 2
      0x95F9C: or ebx, 0x40000000
      0x95FA2: or al, 0x20
      0x95FAB: mov dword ptr [esi + 0x128], ebx
      0x95FB1: mov dword ptr [esi + 0x120], eax
- [W] rva 0x95FD0: mov byte ptr [esi + 0xee], 0
      0x95FC5: call 0x92910
      0x95FCA: mov ecx, dword ptr [esi + 0x120]
      0x95FD7: and ecx, 0xffffffdf
      0x95FDA: or ecx, 0x10
- [W] rva 0x9606B: cmp byte ptr [esi + 0xee], 4
      0x96061: jne 0x960ee
      0x96067: mov esi, dword ptr [esp + 0x18]
      0x96072: je 0x960ee
      0x96074: call 0x1cc500
- [R] rva 0x96214: mov al, byte ptr [eax + 0xee]
      0x9620F: nop 
      0x96210: mov eax, dword ptr [esp + 4]
      0x9621A: cmp al, 3
      0x9621C: je 0x96229
- [R] rva 0x98220: mov al, byte ptr [ecx + 0xee]
      0x9821E: nop 
      0x9821F: nop 
      0x98226: push ebx
      0x98227: test al, al
- [W] rva 0x99C43: mov byte ptr [eax + 0xee], 0
      0x99C39: cmp word ptr [eax + 0x210], 0
      0x99C41: jne 0x99c4a
      0x99C4A: mov al, byte ptr [esi + 0xa]
      0x99C4D: xor edx, edx
- [W] rva 0x9B03B: mov byte ptr [eax + 0xee], cl
      0x9B02F: mov eax, dword ptr [esi*4 + 0x10480b30]
      0x9B036: mov ecx, 2
      0x9B041: mov eax, dword ptr [esi*4 + 0x10480b30]
      0x9B048: mov di, word ptr [edi]
- [W] rva 0x9B172: mov byte ptr [eax + 0xee], bl
      0x9B169: cmp word ptr [eax + 0x210], bx
      0x9B170: jne 0x9b178
      0x9B178: mov cl, byte ptr [edi + 1]
      0x9B17B: mov eax, dword ptr [esi*4 + 0x10480b30]
- [W] rva 0x9B215: cmp byte ptr [eax + 0xee], bl
      0x9B208: test dword ptr [eax + 0x78], 0xff000000
      0x9B20F: jne 0x9b2aa
      0x9B21B: jne 0x9b2aa
      0x9B221: push 0xa5
- [W] rva 0x9C95F: mov byte ptr [eax + 0xee], 0
      0x9C956: cmp word ptr [eax + 0x210], bp
      0x9C95D: jne 0x9c986
      0x9C966: jmp 0x9c986
      0x9C968: mov edx, dword ptr [eax + 0x120]
- [W] rva 0x9C97F: mov byte ptr [eax + 0xee], 1
      0x9C976: cmp word ptr [eax + 0x210], bp
      0x9C97D: jne 0x9c986
      0x9C986: test byte ptr [esi + 0xa], 0x10
      0x9C98A: je 0x9ce8c
- [W] rva 0x9C9C7: mov byte ptr [eax + 0xee], 2
      0x9C9C2: test cl, 1
      0x9C9C5: jne 0x9c9ce
      0x9C9CE: xor edx, edx
      0x9C9D0: mov dx, word ptr [esi + 8]
- [W] rva 0x9CB82: mov byte ptr [eax + 0xee], 3
      0x9CB77: mov dx, word ptr [esi + 8]
      0x9CB7B: mov eax, dword ptr [edx*4 + 0x10480b30]
      0x9CB89: mov cx, word ptr [esi + 8]
      0x9CB8D: mov eax, dword ptr [ecx*4 + 0x10480b30]
- [W] rva 0x9CC21: mov byte ptr [edx + 0xee], 4
      0x9CC16: mov cx, word ptr [esi + 8]
      0x9CC1A: mov edx, dword ptr [ecx*4 + 0x10480b30]
      0x9CC28: mov ax, word ptr [esi + 8]
      0x9CC2C: mov eax, dword ptr [eax*4 + 0x10480b30]
- [W] rva 0x9CC8E: mov byte ptr [ecx + 0xee], 5
      0x9CC83: mov ax, word ptr [esi + 8]
      0x9CC87: mov ecx, dword ptr [eax*4 + 0x10480b30]
      0x9CC95: mov dx, word ptr [esi + 8]
      0x9CC99: mov eax, dword ptr [edx*4 + 0x10480b30]
- [W] rva 0x9CD57: mov byte ptr [eax + 0xee], 6
      0x9CD4C: mov dx, word ptr [esi + 8]
      0x9CD50: mov eax, dword ptr [edx*4 + 0x10480b30]
      0x9CD5E: mov cx, word ptr [esi + 8]
      0x9CD62: mov ax, word ptr [esi + 0x32]
- [W] rva 0x9CDC1: mov byte ptr [ecx + 0xee], 7
      0x9CDB6: mov ax, word ptr [esi + 8]
      0x9CDBA: mov ecx, dword ptr [eax*4 + 0x10480b30]
      0x9CDC8: mov dx, word ptr [esi + 8]
      0x9CDCC: mov ax, word ptr [esi + 0x32]
- [W] rva 0x9CE6D: mov byte ptr [eax + 0xee], 8
      0x9CE62: mov dx, word ptr [esi + 8]
      0x9CE66: mov eax, dword ptr [edx*4 + 0x10480b30]
      0x9CE74: mov al, byte ptr [esi + 0xa]
      0x9CE77: test al, 0x10
- [R] rva 0x9FF41: mov cl, byte ptr [eax + 0xee]
      0x9FF39: ret 
      0x9FF3A: mov eax, dword ptr [esi*4 + 0x10480b30]
      0x9FF47: test cl, cl
      0x9FF49: je 0x9ff6d
- [R] rva 0xA0052: mov dl, byte ptr [ecx + 0xee]
      0xA004A: cmp edx, 0x1000000
      0xA0050: jne 0xa0089
      0xA0058: cmp dl, 1
      0xA005B: je 0xa0067
- [R] rva 0xA0878: mov dl, byte ptr [ecx + 0xee]
      0xA086C: mov al, byte ptr [ecx + 0x1bc]
      0xA0872: mov edi, dword ptr [ecx + 0x170]
      0xA087E: test al, al
      0xA0880: je 0xa088e
- [W] rva 0xAB24F: mov byte ptr [eax + 0xee], 2
      0xAB249: or edx, 8
      0xAB24C: and ecx, 0xfffffffe
      0xAB256: mov dword ptr [eax + 0x130], edx
      0xAB25C: mov word ptr [eax + 0xf4], 0
- [W] rva 0xAB3E6: mov byte ptr [eax + 0xee], cl
      0xAB3DC: mov cl, byte ptr [esp + 0x18]
      0xAB3E0: mov edx, dword ptr [eax + 0x120]
      0xAB3EC: mov ecx, dword ptr [eax + 0x130]
      0xAB3F2: and edx, 0xfffffffe
- [W] rva 0xAB9FB: mov byte ptr [esi + 0xee], 0
      0xAB9F5: push ebp
      0xAB9F6: call 0xab890
      0xABA02: mov dl, byte ptr [edi + 0x24]
      0xABA05: mov eax, dword ptr [esi + 0x120]
- [R] rva 0xAE4F9: mov al, byte ptr [eax + 0xee]
      0xAE4F4: test cl, 1
      0xAE4F7: jne 0xae53f
      0xAE4FF: cmp al, 3
      0xAE501: je 0xae53f
- [R] rva 0xAE68C: mov cl, byte ptr [eax + 0xee]
      0xAE687: test cl, 1
      0xAE68A: je 0xae701
      0xAE692: cmp cl, 3
      0xAE695: je 0xae701
- [W] rva 0xB14BC: mov byte ptr [eax + 0xee], 7
      0xB14B4: je 0xb1d82
      0xB14BA: xor edx, edx
      0xB14C3: mov dx, word ptr [esi + 2]
      0xB14C7: mov eax, dword ptr [edx*4 + 0x10480b30]
- [R] rva 0xB8F08: movsx eax, byte ptr [eax + 0xee]
      0xB8F04: test ecx, ecx
      0xB8F06: je 0xb8f33
      0xB8F0F: cmp eax, 3
      0xB8F12: je 0xb8f33
- [R] rva 0xBCF07: mov al, byte ptr [ecx + 0xee]
      0xBCEFC: mov dx, word ptr [esi + 2]
      0xBCF00: mov ecx, dword ptr [edx*4 + 0x10480b30]
      0xBCF0D: cmp al, bl
      0xBCF0F: je 0xbcf3f
- [W] rva 0xBCF79: cmp byte ptr [eax + 0xee], 1
      0xBCF6E: mov dx, word ptr [esi + 2]
      0xBCF72: mov eax, dword ptr [edx*4 + 0x10480b30]
      0xBCF80: jne 0xbcf99
      0xBCF82: test byte ptr [eax + 0x120], 4
- [R] rva 0xBD410: mov al, byte ptr [ecx + 0xee]
      0xBD403: mov dword ptr [eax + 0x120], ebp
      0xBD409: mov ecx, dword ptr [edi*4 + 0x10480b30]
      0xBD416: cmp al, bl
      0xBD418: je 0xbd441
- [W] rva 0xBD46F: cmp byte ptr [eax + 0xee], 1
      0xBD466: jne 0xbd48f
      0xBD468: mov eax, dword ptr [edi*4 + 0x10480b30]
      0xBD476: jne 0xbd48f
      0xBD478: test byte ptr [eax + 0x120], 4
- [R] rva 0xBD57A: mov al, byte ptr [edi + 0xee]
      0xBD56D: mov dword ptr [eax + 0x174], edx
      0xBD573: mov edi, dword ptr [edi*4 + 0x10480b30]
      0xBD580: cmp al, bl
      0xBD582: je 0xbd5a0
- [W] rva 0xC3F26: mov byte ptr [eax + 0xee], 3
      0xC3F1D: xor eax, eax
      0xC3F1F: mov dword ptr [esi*4 + 0x10480b30], eax
      0xC3F2D: mov ecx, dword ptr [esi*4 + 0x10480b30]
      0xC3F34: push 0x1035d694
- [R] rva 0xC5799: mov cl, byte ptr [ebx + 0xee]
      0xC5792: cmp eax, 0x706f7073
      0xC5797: jne 0xc57ad
      0xC579F: test cl, cl
      0xC57A1: je 0xc57ad
- [W] rva 0x1D2D0D: mov byte ptr [eax + 0xee], 3
      0x1D2D05: mov eax, dword ptr [esi + 4]
      0x1D2D08: push 0x1037ec7c
      0x1D2D14: mov eax, dword ptr [esi + 4]
      0x1D2D17: mov ecx, dword ptr [eax + 0x12c]
- [W] rva 0x1F845F: mov byte ptr [esi + 0xee], al
      0x1F8457: mov al, 0x80
      0x1F8459: mov byte ptr [esi + 0xed], al
      0x1F8465: mov byte ptr [esi + 0xef], al
      0x1F846B: mov ecx, dword ptr [esp + 0x20]
- [R] rva 0x229AFB: mov cx, word ptr [edx + 0xee]
      0x229AF8: xor ecx, ecx
      0x229AFA: pop esi
      0x229B02: mov dword ptr [eax], ecx
      0x229B04: ret 
```

### M.2 The CHAR_NPC handler region incl. the SubKind dispatch @rva 0x9C917 (`byte [esi+0x30] & 7` -> jumptable @rva 0x9CE98) and the SubKind-1 Type=0/1 path (raw dump from rva 0x9C8E0)

Source file: `out3/d_9c8e0.md`

```text
  0009C8E0  50                         push eax
  0009C8E1  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C8E5  51                         push ecx
  0009C8E6  e8 95 e2 fe ff             call 0x1008ab80
  0009C8EB  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  0009C8EE  33 c0                      xor eax, eax
  0009C8F0  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C8F4  c1 ea 0c                   shr edx, 0xc
  0009C8F7  23 d3                      and edx, ebx
  0009C8F9  52                         push edx
  0009C8FA  50                         push eax
  0009C8FB  e8 b0 e2 fe ff             call 0x1008abb0
  0009C900  83 c4 28                   add esp, 0x28
  0009C903  eb 12                      jmp 0x1009c917
  0009C905  84 db                      test bl, bl
  0009C907  0f 85 7f 05 00 00          jne 0x1009ce8c
  0009C90D  bb 01 00 00 00             mov ebx, 1
  0009C912  bf 08 00 00 00             mov edi, 8
  0009C917  8a 46 30                   mov al, byte ptr [esi + 0x30]
  0009C91A  83 e0 07                   and eax, 7
  0009C91D  83 f8 07                   cmp eax, 7
  0009C920  0f 87 66 05 00 00          ja 0x1009ce8c
  0009C926  ff 24 85 98 ce 09 10       jmp dword ptr [eax*4 + 0x1009ce98]
  0009C92D  33 c9                      xor ecx, ecx
  0009C92F  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C933  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009C93A  8b 90 2c 01 00 00          mov edx, dword ptr [eax + 0x12c]
  0009C940  c1 ea 1e                   shr edx, 0x1e
  0009C943  f6 c2 01                   test dl, 1
  0009C946  74 20                      je 0x1009c968
  0009C948  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009C94E  c1 e9 05                   shr ecx, 5
  0009C951  f6 c1 01                   test cl, 1
  0009C954  75 30                      jne 0x1009c986
  0009C956  66 39 a8 10 02 00 00       cmp word ptr [eax + 0x210], bp
  0009C95D  75 27                      jne 0x1009c986
  0009C95F  c6 80 ee 00 00 00 00       mov byte ptr [eax + 0xee], 0
  0009C966  eb 1e                      jmp 0x1009c986
  0009C968  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009C96E  c1 ea 05                   shr edx, 5
  0009C971  f6 c2 01                   test dl, 1
  0009C974  75 10                      jne 0x1009c986
  0009C976  66 39 a8 10 02 00 00       cmp word ptr [eax + 0x210], bp
  0009C97D  75 07                      jne 0x1009c986
  0009C97F  c6 80 ee 00 00 00 01       mov byte ptr [eax + 0xee], 1
  0009C986  f6 46 0a 10                test byte ptr [esi + 0xa], 0x10
  0009C98A  0f 84 fc 04 00 00          je 0x1009ce8c
  0009C990  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C994  8d 46 32                   lea eax, [esi + 0x32]
  0009C997  53                         push ebx
  0009C998  50                         push eax
  0009C999  51                         push ecx
  0009C99A  e8 51 e6 ff ff             call 0x1009aff0
  0009C99F  83 c4 0c                   add esp, 0xc
  0009C9A2  b0 01                      mov al, 1
  0009C9A4  5f                         pop edi
  0009C9A5  5e                         pop esi
  0009C9A6  5d                         pop ebp
  0009C9A7  5b                         pop ebx
```

### M.3 Adjacent field-packing region of the same handler (raw dump from rva 0x9C843)

Source file: `out3/d_9c840.md`

```text
  0009C843  8b c8                      mov ecx, eax
  0009C845  8b d0                      mov edx, eax
  0009C847  c1 e9 06                   shr ecx, 6
  0009C84A  c1 ea 04                   shr edx, 4
  0009C84D  23 cb                      and ecx, ebx
  0009C84F  83 e2 03                   and edx, 3
  0009C852  51                         push ecx
  0009C853  83 e0 0f                   and eax, 0xf
  0009C856  52                         push edx
  0009C857  50                         push eax
  0009C858  33 c0                      xor eax, eax
  0009C85A  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C85E  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009C865  e8 c6 e4 ff ff             call 0x1009ad30
  0009C86A  8b 56 28                   mov edx, dword ptr [esi + 0x28]
  0009C86D  33 c9                      xor ecx, ecx
  0009C86F  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C873  c1 ea 1f                   shr edx, 0x1f
  0009C876  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009C87D  c1 e2 12                   shl edx, 0x12
  0009C880  8b 88 30 01 00 00          mov ecx, dword ptr [eax + 0x130]
  0009C886  33 d1                      xor edx, ecx
  0009C888  81 e2 00 00 04 00          and edx, 0x40000
  0009C88E  33 ca                      xor ecx, edx
  0009C890  89 88 30 01 00 00          mov dword ptr [eax + 0x130], ecx
  0009C896  8b 46 28                   mov eax, dword ptr [esi + 0x28]
  0009C899  c1 e8 13                   shr eax, 0x13
  0009C89C  33 c9                      xor ecx, ecx
  0009C89E  83 e0 03                   and eax, 3
  0009C8A1  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C8A5  50                         push eax
  0009C8A6  51                         push ecx
  0009C8A7  e8 e4 e1 fe ff             call 0x1008aa90
  0009C8AC  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  0009C8AF  33 c0                      xor eax, eax
  0009C8B1  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C8B5  c1 ea 11                   shr edx, 0x11
  0009C8B8  23 d3                      and edx, ebx
  0009C8BA  52                         push edx
  0009C8BB  50                         push eax
  0009C8BC  e8 1f e2 fe ff             call 0x1008aae0
  0009C8C1  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009C8C4  33 d2                      xor edx, edx
  0009C8C6  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009C8CA  c1 e9 12                   shr ecx, 0x12
  0009C8CD  23 cb                      and ecx, ebx
  0009C8CF  51                         push ecx
  0009C8D0  52                         push edx
  0009C8D1  e8 5a e2 fe ff             call 0x1008ab30
  0009C8D6  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  0009C8D9  c1 e8 0b                   shr eax, 0xb
  0009C8DC  23 c3                      and eax, ebx
  0009C8DE  33 c9                      xor ecx, ecx
  0009C8E0  50                         push eax
  0009C8E1  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C8E5  51                         push ecx
  0009C8E6  e8 95 e2 fe ff             call 0x1008ab80
  0009C8EB  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  0009C8EE  33 c0                      xor eax, eax
  0009C8F0  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C8F4  c1 ea 0c                   shr edx, 0xc
  0009C8F7  23 d3                      and edx, ebx
  0009C8F9  52                         push edx
  0009C8FA  50                         push eax
  0009C8FB  e8 b0 e2 fe ff             call 0x1008abb0
  0009C900  83 c4 28                   add esp, 0x28
  0009C903  eb 12                      jmp 0x1009c917
  0009C905  84 db                      test bl, bl
  0009C907  0f 85 7f 05 00 00          jne 0x1009ce8c
```

### M.4 Another ent+0x12C consumer: bit-14 write @rva 0x9C78B and the bit-30 read gate @rva 0x9C7A1 to 0x9C7AD (raw dump from rva 0x9C785)

Source file: `out3/d_9c780.md`

```text
  0009C785  8b 88 2c 01 00 00          mov ecx, dword ptr [eax + 0x12c]
  0009C78B  80 cd 40                   or ch, 0x40
  0009C78E  89 88 2c 01 00 00          mov dword ptr [eax + 0x12c], ecx
  0009C794  33 c9                      xor ecx, ecx
  0009C796  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C79A  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009C7A1  8b 90 2c 01 00 00          mov edx, dword ptr [eax + 0x12c]
  0009C7A7  c1 ea 1e                   shr edx, 0x1e
  0009C7AA  f6 c2 01                   test dl, 1
  0009C7AD  74 0b                      je 0x1009c7ba
  0009C7AF  8a 4e 24                   mov cl, byte ptr [esi + 0x24]
  0009C7B2  88 88 94 02 00 00          mov byte ptr [eax + 0x294], cl
  0009C7B8  eb 1d                      jmp 0x1009c7d7
  0009C7BA  33 d2                      xor edx, edx
  0009C7BC  c6 80 94 02 00 00 00       mov byte ptr [eax + 0x294], 0
  0009C7C3  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009C7C7  8a 4e 24                   mov cl, byte ptr [esi + 0x24]
  0009C7CA  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009C7D1  88 88 db 01 00 00          mov byte ptr [eax + 0x1db], cl
  0009C7D7  33 d2                      xor edx, edx
  0009C7D9  33 c0                      xor eax, eax
  0009C7DB  8a 56 25                   mov dl, byte ptr [esi + 0x25]
  0009C7DE  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C7E2  89 54 24 5c                mov dword ptr [esp + 0x5c], edx
  0009C7E6  33 d2                      xor edx, edx
  0009C7E8  db 44 24 5c                fild dword ptr [esp + 0x5c]
  0009C7EC  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009C7F3  d8 0d 78 a3 32 10          fmul dword ptr [0x1032a378]
  0009C7F9  d9 99 08 02 00 00          fstp dword ptr [ecx + 0x208]
  0009C7FF  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009C803  66 8b 4e 26                mov cx, word ptr [esi + 0x26]
  0009C807  c1 e9 04                   shr ecx, 4
  0009C80A  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009C811  81 e1 ff 00 00 00          and ecx, 0xff
  0009C817  c1 e1 18                   shl ecx, 0x18
  0009C81A  8b 90 3c 01 00 00          mov edx, dword ptr [eax + 0x13c]
  0009C820  33 ca                      xor ecx, edx
  0009C822  81 e1 00 00 00 0f          and ecx, 0xf000000
  0009C828  33 d1                      xor edx, ecx
  0009C82A  89 90 3c 01 00 00          mov dword ptr [eax + 0x13c], edx
  0009C830  8a 56 26                   mov dl, byte ptr [esi + 0x26]   ; pkt body animationsub?
  0009C833  80 e2 0f                   and dl, 0xf
  0009C836  88 54 24 5c                mov byte ptr [esp + 0x5c], dl
  0009C83A  8b 44 24 5c                mov eax, dword ptr [esp + 0x5c]
  0009C83E  25 ff 00 00 00             and eax, 0xff
  0009C843  8b c8                      mov ecx, eax
  0009C845  8b d0                      mov edx, eax
  0009C847  c1 e9 06                   shr ecx, 6
```

### M.5 Type setters for SubKind 0 to 3: Type=2 @rva 0x9C9C7, Type=3 @rva 0x9CB82, Type=4 @rva 0x9CC21 (raw dump from rva 0x9C940)

Source file: `out3/d_9c940.md`

```text
  0009C940  c1 ea 1e                   shr edx, 0x1e
  0009C943  f6 c2 01                   test dl, 1
  0009C946  74 20                      je 0x1009c968
  0009C948  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009C94E  c1 e9 05                   shr ecx, 5
  0009C951  f6 c1 01                   test cl, 1
  0009C954  75 30                      jne 0x1009c986
  0009C956  66 39 a8 10 02 00 00       cmp word ptr [eax + 0x210], bp
  0009C95D  75 27                      jne 0x1009c986
  0009C95F  c6 80 ee 00 00 00 00       mov byte ptr [eax + 0xee], 0
  0009C966  eb 1e                      jmp 0x1009c986
  0009C968  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009C96E  c1 ea 05                   shr edx, 5
  0009C971  f6 c2 01                   test dl, 1
  0009C974  75 10                      jne 0x1009c986
  0009C976  66 39 a8 10 02 00 00       cmp word ptr [eax + 0x210], bp
  0009C97D  75 07                      jne 0x1009c986
  0009C97F  c6 80 ee 00 00 00 01       mov byte ptr [eax + 0xee], 1
  0009C986  f6 46 0a 10                test byte ptr [esi + 0xa], 0x10
  0009C98A  0f 84 fc 04 00 00          je 0x1009ce8c
  0009C990  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C994  8d 46 32                   lea eax, [esi + 0x32]
  0009C997  53                         push ebx
  0009C998  50                         push eax
  0009C999  51                         push ecx
  0009C99A  e8 51 e6 ff ff             call 0x1009aff0
  0009C99F  83 c4 0c                   add esp, 0xc
  0009C9A2  b0 01                      mov al, 1
  0009C9A4  5f                         pop edi
  0009C9A5  5e                         pop esi
  0009C9A6  5d                         pop ebp
  0009C9A7  5b                         pop ebx
  0009C9A8  83 c4 40                   add esp, 0x40
  0009C9AB  c3                         ret 
  0009C9AC  33 d2                      xor edx, edx
  0009C9AE  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009C9B2  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009C9B9  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009C9BF  c1 e9 05                   shr ecx, 5
  0009C9C2  f6 c1 01                   test cl, 1
  0009C9C5  75 07                      jne 0x1009c9ce
  0009C9C7  c6 80 ee 00 00 00 02       mov byte ptr [eax + 0xee], 2
  0009C9CE  33 d2                      xor edx, edx
  0009C9D0  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009C9D4  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009C9DB  8b 88 2c 01 00 00          mov ecx, dword ptr [eax + 0x12c]
  0009C9E1  c1 e9 06                   shr ecx, 6
  0009C9E4  f6 c1 01                   test cl, 1
  0009C9E7  75 3b                      jne 0x1009ca24
  0009C9E9  66 8b 4e 32                mov cx, word ptr [esi + 0x32]
  0009C9ED  66 81 f9 13 02             cmp cx, 0x213
  0009C9F2  72 19                      jb 0x1009ca0d
  0009C9F4  66 81 f9 28 02             cmp cx, 0x228
  0009C9F9  77 12                      ja 0x1009ca0d
  0009C9FB  80 b8 ef 00 00 00 03       cmp byte ptr [eax + 0xef], 3
  0009CA02  74 20                      je 0x1009ca24
  0009CA04  c6 80 ef 00 00 00 03       mov byte ptr [eax + 0xef], 3
  0009CA0B  eb 11                      jmp 0x1009ca1e
  0009CA0D  8a 88 ef 00 00 00          mov cl, byte ptr [eax + 0xef]
  0009CA13  84 c9                      test cl, cl
  0009CA15  74 0d                      je 0x1009ca24
  0009CA17  c6 80 ef 00 00 00 00       mov byte ptr [eax + 0xef], 0
  0009CA1E  09 98 20 01 00 00          or dword ptr [eax + 0x120], ebx   ; ent.RenderFlags0?
  0009CA24  66 8b 4e 32                mov cx, word ptr [esi + 0x32]
  0009CA28  33 d2                      xor edx, edx
  0009CA2A  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CA2E  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CA35  66 39 88 fc 00 00 00       cmp word ptr [eax + 0xfc], cx
  0009CA3C  74 0e                      je 0x1009ca4c
  0009CA3E  66 09 98 f4 00 00 00       or word ptr [eax + 0xf4], bx
  0009CA45  66 89 88 fc 00 00 00       mov word ptr [eax + 0xfc], cx
  0009CA4C  66 8b 46 32                mov ax, word ptr [esi + 0x32]
  0009CA50  66 3d 32 00                cmp ax, 0x32
  0009CA54  72 18                      jb 0x1009ca6e
  0009CA56  66 3d 3b 00                cmp ax, 0x3b
  0009CA5A  77 12                      ja 0x1009ca6e
  0009CA5C  33 c0                      xor eax, eax
  0009CA5E  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CA62  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CA69  e9 a1 00 00 00             jmp 0x1009cb0f
  0009CA6E  66 3d 74 09                cmp ax, 0x974
  0009CA72  72 0a                      jb 0x1009ca7e
  0009CA74  66 3d 78 09                cmp ax, 0x978
  0009CA78  0f 86 84 00 00 00          jbe 0x1009cb02
  0009CA7E  66 3d 37 07                cmp ax, 0x737
  0009CA82  72 15                      jb 0x1009ca99
  0009CA84  66 3d 46 07                cmp ax, 0x746
  0009CA88  77 0f                      ja 0x1009ca99
  0009CA8A  33 d2                      xor edx, edx
  0009CA8C  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CA90  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CA97  eb 76                      jmp 0x1009cb0f
  0009CA99  66 3d ba 09                cmp ax, 0x9ba
  0009CA9D  72 15                      jb 0x1009cab4
  0009CA9F  66 3d be 09                cmp ax, 0x9be
  0009CAA3  77 0f                      ja 0x1009cab4
  0009CAA5  33 c0                      xor eax, eax
  0009CAA7  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CAAB  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CAB2  eb 5b                      jmp 0x1009cb0f
  0009CAB4  66 3d c0 03                cmp ax, 0x3c0
  0009CAB8  72 06                      jb 0x1009cac0
  0009CABA  66 3d c9 03                cmp ax, 0x3c9
  0009CABE  76 42                      jbe 0x1009cb02
  0009CAC0  66 3d 2e 03                cmp ax, 0x32e
  0009CAC4  72 15                      jb 0x1009cadb
  0009CAC6  66 3d 31 03                cmp ax, 0x331
  0009CACA  77 0f                      ja 0x1009cadb
  0009CACC  33 d2                      xor edx, edx
  0009CACE  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CAD2  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CAD9  eb 34                      jmp 0x1009cb0f
  0009CADB  66 3d 79 09                cmp ax, 0x979
  0009CADF  72 15                      jb 0x1009caf6
  0009CAE1  66 3d 7d 09                cmp ax, 0x97d
  0009CAE5  77 0f                      ja 0x1009caf6
  0009CAE7  33 c0                      xor eax, eax
  0009CAE9  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CAED  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CAF4  eb 19                      jmp 0x1009cb0f
  0009CAF6  66 3d bf 09                cmp ax, 0x9bf
  0009CAFA  72 19                      jb 0x1009cb15
  0009CAFC  66 3d c3 09                cmp ax, 0x9c3
  0009CB00  77 13                      ja 0x1009cb15
  0009CB02  33 c9                      xor ecx, ecx
  0009CB04  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CB08  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009CB0F  09 b8 28 01 00 00          or dword ptr [eax + 0x128], edi
  0009CB15  66 8b 46 32                mov ax, word ptr [esi + 0x32]
  0009CB19  66 3d 18 00                cmp ax, 0x18
  0009CB1D  0f 82 69 03 00 00          jb 0x1009ce8c
  0009CB23  0f 87 63 03 00 00          ja 0x1009ce8c
  0009CB29  33 d2                      xor edx, edx
  0009CB2B  5f                         pop edi
  0009CB2C  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CB30  5e                         pop esi
  0009CB31  5d                         pop ebp
  0009CB32  5b                         pop ebx
  0009CB33  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CB3A  c6 80 f6 00 00 00 01       mov byte ptr [eax + 0xf6], 1
  0009CB41  b0 01                      mov al, 1
  0009CB43  83 c4 40                   add esp, 0x40
  0009CB46  c3                         ret 
  0009CB47  33 c9                      xor ecx, ecx
  0009CB49  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CB4D  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009CB54  8a 88 ef 00 00 00          mov cl, byte ptr [eax + 0xef]
  0009CB5A  84 c9                      test cl, cl
  0009CB5C  74 15                      je 0x1009cb73
  0009CB5E  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009CB64  c6 80 ef 00 00 00 00       mov byte ptr [eax + 0xef], 0
  0009CB6B  0b cb                      or ecx, ebx
  0009CB6D  89 88 20 01 00 00          mov dword ptr [eax + 0x120], ecx   ; ent.RenderFlags0?
  0009CB73  33 d2                      xor edx, edx
  0009CB75  33 c9                      xor ecx, ecx
  0009CB77  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CB7B  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CB82  c6 80 ee 00 00 00 03       mov byte ptr [eax + 0xee], 3
  0009CB89  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CB8D  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009CB94  66 39 a8 fc 00 00 00       cmp word ptr [eax + 0xfc], bp
  0009CB9B  74 0e                      je 0x1009cbab
  0009CB9D  66 09 98 f4 00 00 00       or word ptr [eax + 0xf4], bx
  0009CBA4  66 89 a8 fc 00 00 00       mov word ptr [eax + 0xfc], bp
  0009CBAB  8b 4e 34                   mov ecx, dword ptr [esi + 0x34]
  0009CBAE  33 d2                      xor edx, edx
  0009CBB0  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CBB4  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CBBB  33 d2                      xor edx, edx
  0009CBBD  89 88 f8 00 00 00          mov dword ptr [eax + 0xf8], ecx
  0009CBC3  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CBC7  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CBCE  8b 88 28 01 00 00          mov ecx, dword ptr [eax + 0x128]
  0009CBD4  0b cf                      or ecx, edi
  0009CBD6  5f                         pop edi
  0009CBD7  5e                         pop esi
  0009CBD8  89 88 28 01 00 00          mov dword ptr [eax + 0x128], ecx
  0009CBDE  5d                         pop ebp
  0009CBDF  b0 01                      mov al, 1
  0009CBE1  5b                         pop ebx
  0009CBE2  83 c4 40                   add esp, 0x40
  0009CBE5  c3                         ret 
  0009CBE6  33 c0                      xor eax, eax
  0009CBE8  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CBEC  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CBF3  8a 88 ef 00 00 00          mov cl, byte ptr [eax + 0xef]
  0009CBF9  84 c9                      test cl, cl
  0009CBFB  74 15                      je 0x1009cc12
  0009CBFD  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009CC03  c6 80 ef 00 00 00 00       mov byte ptr [eax + 0xef], 0
  0009CC0A  0b cb                      or ecx, ebx
  0009CC0C  89 88 20 01 00 00          mov dword ptr [eax + 0x120], ecx   ; ent.RenderFlags0?
  0009CC12  33 c9                      xor ecx, ecx
  0009CC14  33 c0                      xor eax, eax
  0009CC16  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CC1A  8b 14 8d 30 0b 48 10       mov edx, dword ptr [ecx*4 + 0x10480b30]
  0009CC21  c6 82 ee 00 00 00 04       mov byte ptr [edx + 0xee], 4
  0009CC28  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CC2C  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CC33  66 39 a8 fc 00 00 00       cmp word ptr [eax + 0xfc], bp
```

### M.6 Type setters for SubKind 4 to 7: Type=5 @rva 0x9CC8E, Type=6 @rva 0x9CD57, Type=7 @rva 0x9CDC1 (model-range check), Type=8 @rva 0x9CE6D; the jumptable bytes at rva 0x9CE98 decode as data here (raw dump from rva 0x9CC28)

Source file: `out3/d_9cc28.md`

```text
  0009CC28  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CC2C  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CC33  66 39 a8 fc 00 00 00       cmp word ptr [eax + 0xfc], bp
  0009CC3A  0f 84 99 00 00 00          je 0x1009ccd9
  0009CC40  66 09 98 f4 00 00 00       or word ptr [eax + 0xf4], bx
  0009CC47  66 89 a8 fc 00 00 00       mov word ptr [eax + 0xfc], bp
  0009CC4E  e9 86 00 00 00             jmp 0x1009ccd9
  0009CC53  33 d2                      xor edx, edx
  0009CC55  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CC59  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CC60  8a 88 ef 00 00 00          mov cl, byte ptr [eax + 0xef]
  0009CC66  84 c9                      test cl, cl
  0009CC68  74 15                      je 0x1009cc7f
  0009CC6A  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009CC70  c6 80 ef 00 00 00 00       mov byte ptr [eax + 0xef], 0
  0009CC77  0b cb                      or ecx, ebx
  0009CC79  89 88 20 01 00 00          mov dword ptr [eax + 0x120], ecx   ; ent.RenderFlags0?
  0009CC7F  33 c0                      xor eax, eax
  0009CC81  33 d2                      xor edx, edx
  0009CC83  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CC87  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009CC8E  c6 81 ee 00 00 00 05       mov byte ptr [ecx + 0xee], 5
  0009CC95  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CC99  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CCA0  66 39 a8 fc 00 00 00       cmp word ptr [eax + 0xfc], bp
  0009CCA7  74 0e                      je 0x1009ccb7
  0009CCA9  66 09 98 f4 00 00 00       or word ptr [eax + 0xf4], bx
  0009CCB0  66 89 a8 fc 00 00 00       mov word ptr [eax + 0xfc], bp
  0009CCB7  33 c0                      xor eax, eax
  0009CCB9  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CCBD  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CCC4  8b 88 f8 00 00 00          mov ecx, dword ptr [eax + 0xf8]
  0009CCCA  3b cd                      cmp ecx, ebp
  0009CCCC  74 0b                      je 0x1009ccd9
  0009CCCE  3b 4e 34                   cmp ecx, dword ptr [esi + 0x34]
  0009CCD1  74 06                      je 0x1009ccd9
  0009CCD3  09 98 20 01 00 00          or dword ptr [eax + 0x120], ebx   ; ent.RenderFlags0?
  0009CCD9  8b 46 34                   mov eax, dword ptr [esi + 0x34]
  0009CCDC  33 c9                      xor ecx, ecx
  0009CCDE  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CCE2  8b 14 8d 30 0b 48 10       mov edx, dword ptr [ecx*4 + 0x10480b30]
  0009CCE9  33 c9                      xor ecx, ecx
  0009CCEB  89 82 f8 00 00 00          mov dword ptr [edx + 0xf8], eax
  0009CCF1  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CCF5  8b 46 38                   mov eax, dword ptr [esi + 0x38]
  0009CCF8  8b 14 8d 30 0b 48 10       mov edx, dword ptr [ecx*4 + 0x10480b30]
  0009CCFF  33 c9                      xor ecx, ecx
  0009CD01  89 82 84 01 00 00          mov dword ptr [edx + 0x184], eax
  0009CD07  66 8b 4e 3c                mov cx, word ptr [esi + 0x3c]
  0009CD0B  8b 56 38                   mov edx, dword ptr [esi + 0x38]
  0009CD0E  03 ca                      add ecx, edx
  0009CD10  33 d2                      xor edx, edx
  0009CD12  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CD16  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CD1D  89 88 80 01 00 00          mov dword ptr [eax + 0x180], ecx
  0009CD23  33 c9                      xor ecx, ecx
  0009CD25  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CD29  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009CD30  8b 88 28 01 00 00          mov ecx, dword ptr [eax + 0x128]
  0009CD36  0b cf                      or ecx, edi
  0009CD38  5f                         pop edi
  0009CD39  5e                         pop esi
  0009CD3A  89 88 28 01 00 00          mov dword ptr [eax + 0x128], ecx
  0009CD40  5d                         pop ebp
  0009CD41  b0 01                      mov al, 1
  0009CD43  5b                         pop ebx
  0009CD44  83 c4 40                   add esp, 0x40
  0009CD47  c3                         ret 
  0009CD48  33 d2                      xor edx, edx
  0009CD4A  33 c9                      xor ecx, ecx
  0009CD4C  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CD50  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CD57  c6 80 ee 00 00 00 06       mov byte ptr [eax + 0xee], 6
  0009CD5E  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CD62  66 8b 46 32                mov ax, word ptr [esi + 0x32]
  0009CD66  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  0009CD6D  80 cc 90                   or ah, 0x90
  0009CD70  66 39 81 0e 01 00 00       cmp word ptr [ecx + 0x10e], ax
  0009CD77  74 0e                      je 0x1009cd87
  0009CD79  80 89 f5 00 00 00 02       or byte ptr [ecx + 0xf5], 2
  0009CD80  66 89 81 0e 01 00 00       mov word ptr [ecx + 0x10e], ax
  0009CD87  33 d2                      xor edx, edx
  0009CD89  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CD8D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CD94  66 39 a8 f4 00 00 00       cmp word ptr [eax + 0xf4], bp
  0009CD9B  0f 84 eb 00 00 00          je 0x1009ce8c
  0009CDA1  5f                         pop edi
  0009CDA2  66 89 a8 fc 00 00 00       mov word ptr [eax + 0xfc], bp
  0009CDA9  5e                         pop esi
  0009CDAA  5d                         pop ebp
  0009CDAB  b0 01                      mov al, 1
  0009CDAD  5b                         pop ebx
  0009CDAE  83 c4 40                   add esp, 0x40
  0009CDB1  c3                         ret 
  0009CDB2  33 c0                      xor eax, eax
  0009CDB4  33 d2                      xor edx, edx
  0009CDB6  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CDBA  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009CDC1  c6 81 ee 00 00 00 07       mov byte ptr [ecx + 0xee], 7
  0009CDC8  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CDCC  66 8b 46 32                mov ax, word ptr [esi + 0x32]
  0009CDD0  8b 0c 95 30 0b 48 10       mov ecx, dword ptr [edx*4 + 0x10480b30]
  0009CDD7  80 cc 90                   or ah, 0x90
  0009CDDA  66 39 81 0e 01 00 00       cmp word ptr [ecx + 0x10e], ax
  0009CDE1  74 0e                      je 0x1009cdf1
  0009CDE3  80 89 f5 00 00 00 02       or byte ptr [ecx + 0xf5], 2
  0009CDEA  66 89 81 0e 01 00 00       mov word ptr [ecx + 0x10e], ax
  0009CDF1  33 c0                      xor eax, eax
  0009CDF3  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CDF7  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009CDFE  66 39 a8 f4 00 00 00       cmp word ptr [eax + 0xf4], bp
  0009CE05  74 07                      je 0x1009ce0e
  0009CE07  66 89 a8 fc 00 00 00       mov word ptr [eax + 0xfc], bp
  0009CE0E  66 8b 46 32                mov ax, word ptr [esi + 0x32]
  0009CE12  66 3d b8 07                cmp ax, 0x7b8
  0009CE16  72 1a                      jb 0x1009ce32
  0009CE18  66 3d cb 07                cmp ax, 0x7cb
  0009CE1C  77 14                      ja 0x1009ce32
  0009CE1E  33 c9                      xor ecx, ecx
  0009CE20  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009CE24  8b 14 8d 30 0b 48 10       mov edx, dword ptr [ecx*4 + 0x10480b30]
  0009CE2B  c6 82 f6 00 00 00 02       mov byte ptr [edx + 0xf6], 2
  0009CE32  66 8b 46 32                mov ax, word ptr [esi + 0x32]
  0009CE36  66 3d d3 07                cmp ax, 0x7d3
  0009CE3A  72 50                      jb 0x1009ce8c
  0009CE3C  66 3d da 07                cmp ax, 0x7da
  0009CE40  77 4a                      ja 0x1009ce8c
  0009CE42  33 c0                      xor eax, eax
  0009CE44  5f                         pop edi
  0009CE45  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009CE49  5e                         pop esi
  0009CE4A  5d                         pop ebp
  0009CE4B  5b                         pop ebx
  0009CE4C  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009CE53  b0 01                      mov al, 1
  0009CE55  c6 81 f6 00 00 00 02       mov byte ptr [ecx + 0xf6], 2
  0009CE5C  83 c4 40                   add esp, 0x40
  0009CE5F  c3                         ret 
  0009CE60  33 d2                      xor edx, edx
  0009CE62  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CE66  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009CE6D  c6 80 ee 00 00 00 08       mov byte ptr [eax + 0xee], 8
  0009CE74  8a 46 0a                   mov al, byte ptr [esi + 0xa]
  0009CE77  a8 10                      test al, 0x10
  0009CE79  74 11                      je 0x1009ce8c
  0009CE7B  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009CE7F  8d 4e 32                   lea ecx, [esi + 0x32]
  0009CE82  51                         push ecx
  0009CE83  52                         push edx
  0009CE84  e8 77 e5 ff ff             call 0x1009b400
  0009CE89  83 c4 08                   add esp, 8
  0009CE8C  5f                         pop edi
  0009CE8D  5e                         pop esi
  0009CE8E  5d                         pop ebp
  0009CE8F  b0 01                      mov al, 1
  0009CE91  5b                         pop ebx
  0009CE92  83 c4 40                   add esp, 0x40
  0009CE95  c3                         ret 
  0009CE96  8b ff                      mov edi, edi
  0009CE98  ac                         lodsb al, byte ptr [esi]
  0009CE99  c9                         leave 
  0009CE9A  09 10                      or dword ptr [eax], edx
  0009CE9C  2d c9 09 10 47             sub eax, 0x471009c9
  0009CEA1  cb                         retf 
  0009CEA2  09 10                      or dword ptr [eax], edx
  0009CEA4  e6 cb                      out 0xcb, al
  0009CEA6  09 10                      or dword ptr [eax], edx
```

### M.7 All write/test sites of ent+0x12C (the flag word whose bit 30 splits Type 0 vs 1)

Source file: `out3/x_12c_w.md`

```text
- rva 0x448D6: mov dword ptr [esi + 0x12c], eax
- rva 0x4C400: mov dword ptr [esp + 0x12c], edx
- rva 0x529F8: mov dword ptr [ecx + 0x12c], eax
- rva 0x8476E: mov dword ptr [eax + 0x12c], ecx
- rva 0x8477A: mov dword ptr [eax + 0x12c], ecx
- rva 0x87DAD: mov dword ptr [ecx + 0x12c], edx
- rva 0x87DC0: and dword ptr [ecx + 0x12c], 0xfff7ffff
- rva 0x88168: mov dword ptr [esi + 0x12c], eax
- rva 0x8A518: mov dword ptr [esi + 0x12c], eax
- rva 0x8CDBF: mov dword ptr [esi + 0x12c], edx
- rva 0x8CE47: mov dword ptr [esi + 0x12c], eax
- rva 0x8CE8E: test byte ptr [esi + 0x12c], 8
- rva 0x8CEA1: test byte ptr [esi + 0x12c], 4
- rva 0x8CF39: mov dword ptr [esi + 0x12c], edx
- rva 0x8DE8D: mov dword ptr [esi + 0x12c], edi
- rva 0x8E75E: test byte ptr [esi + 0x12c], 0x10
- rva 0x8E7D0: mov dword ptr [esi + 0x12c], edx
- rva 0x8E846: mov dword ptr [esi + 0x12c], eax
- rva 0x8E871: mov dword ptr [esi + 0x12c], eax
- rva 0x8E8D3: mov dword ptr [esi + 0x12c], eax
- rva 0x8E9DB: mov dword ptr [esi + 0x12c], edx
- rva 0x8EA17: mov dword ptr [esi + 0x12c], eax
- rva 0x94EF8: mov dword ptr [esi + 0x12c], eax
- rva 0x94F21: mov dword ptr [esi + 0x12c], edx
- rva 0x94F6F: mov dword ptr [esi + 0x12c], eax
- rva 0x94F97: mov dword ptr [esi + 0x12c], eax
- rva 0x94FC0: mov dword ptr [esi + 0x12c], edx
- rva 0x952D6: mov dword ptr [esi + 0x12c], eax
- rva 0x958FC: test byte ptr [esi + 0x12c], 0x20
- rva 0x959CD: mov dword ptr [esi + 0x12c], eax
- rva 0x959FB: mov dword ptr [esi + 0x12c], eax
- rva 0x95A81: and dword ptr [esi + 0x12c], ebx
- rva 0x95AE4: mov dword ptr [esi + 0x12c], ecx
- rva 0x95B7B: mov dword ptr [esi + 0x12c], eax
- rva 0x95BD6: mov dword ptr [esi + 0x12c], eax
- rva 0x95C3F: mov dword ptr [esi + 0x12c], eax
- rva 0x95C97: and dword ptr [esi + 0x12c], ebx
- rva 0x95CE6: mov dword ptr [esi + 0x12c], eax
- rva 0x95DB5: test byte ptr [esi + 0x12c], 1
- rva 0x95DD4: mov dword ptr [esi + 0x12c], eax
- rva 0x97642: test dword ptr [ecx + 0x12c], 0x40000
- rva 0x99E18: mov dword ptr [eax + 0x12c], ecx
- rva 0x9A634: mov dword ptr [eax + 0x12c], edx
- rva 0x9A6E6: mov dword ptr [eax + 0x12c], edx
- rva 0x9A712: mov dword ptr [eax + 0x12c], edx
- rva 0x9A73E: mov dword ptr [eax + 0x12c], edx
- rva 0x9A79F: mov dword ptr [eax + 0x12c], edx
- rva 0x9A7D1: mov dword ptr [eax + 0x12c], edx
- rva 0x9A803: mov dword ptr [eax + 0x12c], edx
- rva 0x9A835: mov dword ptr [eax + 0x12c], edx
- rva 0x9A864: mov dword ptr [eax + 0x12c], ecx
- rva 0x9A897: mov dword ptr [ecx + 0x12c], edx
- rva 0x9A8BF: mov dword ptr [eax + 0x12c], edx
- rva 0x9ACDE: mov dword ptr [ecx + 0x12c], edx
- rva 0x9AD19: mov dword ptr [ecx + 0x12c], ebx
- rva 0x9B85B: mov dword ptr [eax + 0x12c], ecx
- rva 0x9B9E0: mov dword ptr [eax + 0x12c], ecx
- rva 0x9C288: mov dword ptr [eax + 0x12c], ebx
- rva 0x9C37E: mov dword ptr [eax + 0x12c], edx
- rva 0x9C3AC: mov dword ptr [eax + 0x12c], ebx
- rva 0x9C3DB: mov dword ptr [eax + 0x12c], edx
- rva 0x9C466: mov dword ptr [eax + 0x12c], edx
- rva 0x9C498: mov dword ptr [eax + 0x12c], edx
- rva 0x9C4CA: mov dword ptr [eax + 0x12c], edx
- rva 0x9C4FC: mov dword ptr [eax + 0x12c], edx
- rva 0x9C52B: mov dword ptr [eax + 0x12c], ecx
- rva 0x9C55E: mov dword ptr [ecx + 0x12c], edx
- rva 0x9C586: mov dword ptr [eax + 0x12c], edx
- rva 0x9C78E: mov dword ptr [eax + 0x12c], ecx
- rva 0x9D5DD: mov dword ptr [esi + 0x12c], edx
- rva 0x9D61E: mov dword ptr [esi + 0x12c], ecx
- rva 0x9D67D: mov dword ptr [esi + 0x12c], ecx
- rva 0x9D69E: mov dword ptr [esi + 0x12c], ecx
- rva 0x9FB3B: mov dword ptr [ecx + 0x12c], eax
- rva 0x9FB50: mov dword ptr [ecx + 0x12c], edx
- rva 0xA8BBC: mov dword ptr [esi + 0x12c], eax
- rva 0xAADA1: mov dword ptr [esi + 0x12c], edx
- rva 0xAE5A1: mov dword ptr [eax + 0x12c], edx
- rva 0xAE602: mov dword ptr [eax + 0x12c], ecx
- rva 0xAE65E: mov dword ptr [eax + 0x12c], ecx
- rva 0xB88C0: mov dword ptr [eax + 0x12c], ecx
- rva 0xB897B: mov dword ptr [eax + 0x12c], edx
- rva 0xB8A68: mov dword ptr [eax + 0x12c], edx
- rva 0xB8FAC: mov dword ptr [eax + 0x12c], ecx
- rva 0xB9121: or dword ptr [eax + 0x12c], 1
- rva 0xB9C11: mov dword ptr [eax + 0x12c], ecx
- rva 0xB9D21: mov dword ptr [eax + 0x12c], ecx
- rva 0xBA91A: mov dword ptr [eax + 0x12c], edx
- rva 0xBA96A: mov dword ptr [eax + 0x12c], edx
- rva 0xBA9BB: mov dword ptr [edx + 0x12c], eax
- rva 0xBCEDE: mov dword ptr [eax + 0x12c], ecx
- rva 0xBD378: and dword ptr [eax + 0x12c], 0xfffeffff
- rva 0xBD674: mov dword ptr [eax + 0x12c], ecx
- rva 0xBD6A1: mov dword ptr [eax + 0x12c], edx
- rva 0xE7A95: mov dword ptr [ecx + 0x12c], esi
- rva 0xE7AD1: mov dword ptr [ecx + 0x12c], esi
- rva 0xE7B1A: mov dword ptr [ecx + 0x12c], eax
- rva 0x116ED4: mov dword ptr [esi + 0x12c], edx
- rva 0x13BF89: mov byte ptr [ecx + 0x12c], al
- rva 0x15B862: mov dword ptr [edx + 0x12c], eax
- rva 0x18709D: mov dword ptr [esi + 0x12c], edx
- rva 0x19F825: mov dword ptr [esp + 0x12c], ebx
- rva 0x19FBD4: mov dword ptr [esp + 0x12c], ebx
- rva 0x1A0FBE: mov dword ptr [esp + 0x12c], ebx
- rva 0x1BEC0A: mov dword ptr [esp + 0x12c], edx
- rva 0x1BED2A: mov dword ptr [esp + 0x12c], edx
- rva 0x1BEDBA: mov dword ptr [esp + 0x12c], edx
- rva 0x1BEF3A: mov dword ptr [esp + 0x12c], edx
- rva 0x1BF03A: mov dword ptr [esp + 0x12c], edx
- rva 0x1BF137: mov dword ptr [esp + 0x12c], edx
- rva 0x1BF2EA: mov dword ptr [esp + 0x12c], edx
- rva 0x1BF4CA: mov dword ptr [esp + 0x12c], edx
- rva 0x1BF5BA: mov dword ptr [esp + 0x12c], edx
- rva 0x1BF6A7: mov dword ptr [esp + 0x12c], edx
- rva 0x1BF9EC: mov dword ptr [esp + 0x12c], edx
- rva 0x1BFA6C: mov dword ptr [esp + 0x12c], ebp
- rva 0x1BFB16: mov dword ptr [esp + 0x12c], edx
- rva 0x1BFB9D: mov dword ptr [esp + 0x12c], ebp
- rva 0x1BFC4C: mov dword ptr [esp + 0x12c], edx
- rva 0x1BFCCC: mov dword ptr [esp + 0x12c], ebp
- rva 0x1BFD7C: mov dword ptr [esp + 0x12c], edx
- rva 0x1BFDFC: mov dword ptr [esp + 0x12c], ebp
- rva 0x1BFEA9: mov dword ptr [esp + 0x12c], edx
- rva 0x1BFEEF: mov dword ptr [esp + 0x12c], ecx
- rva 0x1BFF13: mov dword ptr [esp + 0x12c], ebp
- rva 0x1BFFB3: mov dword ptr [esp + 0x12c], edx
- rva 0x1C0018: mov dword ptr [esp + 0x12c], ebx
- rva 0x1C01CA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C02CA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C03C7: mov dword ptr [esp + 0x12c], edx
- rva 0x1C05AA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C07CF: mov dword ptr [esp + 0x12c], ebx
- rva 0x1C0A9B: mov dword ptr [esp + 0x12c], ebp
- rva 0x1C0C5D: mov dword ptr [esp + 0x12c], esi
- rva 0x1C0DD3: mov dword ptr [esp + 0x12c], ebx
- rva 0x1C0DE3: mov dword ptr [esp + 0x12c], eax
- rva 0x1C10FA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C11B7: mov dword ptr [esp + 0x12c], edx
- rva 0x1C125A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C133A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C140A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1594: mov dword ptr [esp + 0x12c], edx
- rva 0x1C165A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1717: mov dword ptr [esp + 0x12c], edx
- rva 0x1C188A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C194A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1A07: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1ABA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1B8A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1C4A: mov dword ptr [esp + 0x12c], ebx
- rva 0x1C1CFA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1DB7: mov dword ptr [esp + 0x12c], edx
- rva 0x1C1F2A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C20AE: mov dword ptr [esp + 0x12c], ebx
- rva 0x1C222A: mov dword ptr [esp + 0x12c], edx
- rva 0x1C23EA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C24BA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C2587: mov dword ptr [esp + 0x12c], edx
- rva 0x1C28AA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C2967: mov dword ptr [esp + 0x12c], edx
- rva 0x1C2AF3: mov dword ptr [esp + 0x12c], edx
- rva 0x1C343E: mov dword ptr [esp + 0x12c], ebp
- rva 0x1C34D3: mov dword ptr [esp + 0x12c], ecx
- rva 0x1C3589: mov dword ptr [esp + 0x12c], ecx
- rva 0x1C3706: mov dword ptr [esp + 0x12c], edx
- rva 0x1C376E: mov dword ptr [esp + 0x12c], edx
- rva 0x1C3989: mov dword ptr [esp + 0x12c], ebx
- rva 0x1C41C7: mov dword ptr [esp + 0x12c], ebx
- rva 0x1C42CA: mov dword ptr [esp + 0x12c], edx
- rva 0x1C4403: mov dword ptr [esp + 0x12c], ebp
- rva 0x1CD6B0: mov dword ptr [eax + 0x12c], ecx
- rva 0x1D2D23: mov dword ptr [eax + 0x12c], ecx
- rva 0x212CAC: mov byte ptr [esi + 0x12c], 1
- rva 0x212CDF: mov byte ptr [esi + 0x12c], 1
- rva 0x2133FD: mov byte ptr [ebp + 0x12c], 1
- rva 0x213E55: mov byte ptr [esp + 0x12c], bl
- rva 0x213EA3: mov byte ptr [esp + 0x12c], bl
- rva 0x215853: mov byte ptr [esp + 0x12c], bl
- rva 0x2159B7: mov byte ptr [esp + 0x12c], bl
- rva 0x23C81D: mov dword ptr [esp + 0x12c], eax
- rva 0x23C958: mov dword ptr [esp + 0x12c], edi
- rva 0x23D826: mov dword ptr [ebp + ecx*4 + 0x12c], 0
- rva 0x241619: mov dword ptr [esp + 0x12c], eax
- rva 0x25FEAF: mov dword ptr [esi + 0x12c], eax
- rva 0x25FFF1: mov dword ptr [ecx + 0x12c], eax
- rva 0x2B857A: mov dword ptr [ecx + 0x12c], eax
- rva 0x2BD044: mov byte ptr [esi + 0x12c], 8
- rva 0x2C3536: mov byte ptr [esi + 0x12c], al
- rva 0x2D1863: mov dword ptr [ebx + edx*4 + 0x12c], edi
- rva 0x2D1C10: mov dword ptr [ebx + esi*4 + 0x12c], ecx
- rva 0x2EFC25: sub ecx, dword ptr [ebx + 0x12c]
- rva 0x2F1944: mov dword ptr [esi + 0x12c], eax
total write sites: 192
```
