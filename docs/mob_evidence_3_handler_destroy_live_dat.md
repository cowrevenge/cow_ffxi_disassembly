# Mob pass evidence 3: name resolvers, 0x0E handler, destroy path, live sessions, DAT dumps (§D to §H)

Dumps and logs backing F29-F34 and F46-F55 in [mob_animation.md](mob_animation.md). Conventions in
[README.md](README.md).

## §D. init -> ini0 resolvers and the state -> fourcc switch machine (F29)

Decode in F29: resolver 0xCE241 (body 0xCE260), siblings 0xCE59D / 0xCE790, caller @0x5CC16, and
the five 0xCE790 callers ~0xD6B6B-0xD6C84 that build fourccs from state words.

### D.1 resolver func 0xCE241 (`out2/d_ce241.md`)

````text

; func 0xCE241..0xCE2CA (137 bytes), callers: 0
  000CE241  e8 6a 97 f5 ff             call 0x100279b0
  000CE246  b8 01 00 00 00             mov eax, 1
  000CE24B  83 c4 58                   add esp, 0x58
  000CE24E  c2 04 00                   ret 4
  000CE251  90                         nop 
  000CE252  90                         nop 
  000CE253  90                         nop 
  000CE254  90                         nop 
  000CE255  90                         nop 
  000CE256  90                         nop 
  000CE257  90                         nop 
  000CE258  90                         nop 
  000CE259  90                         nop 
  000CE25A  90                         nop 
  000CE25B  90                         nop 
  000CE25C  90                         nop 
  000CE25D  90                         nop 
  000CE25E  90                         nop 
  000CE25F  90                         nop 
  000CE260  83 ec 24                   sub esp, 0x24
  000CE263  53                         push ebx
  000CE264  55                         push ebp
  000CE265  56                         push esi
  000CE266  57                         push edi
  000CE267  8b 7c 24 3c                mov edi, dword ptr [esp + 0x3c]
  000CE26B  8b d9                      mov ebx, ecx
  000CE26D  81 ff 69 6e 69 74          cmp edi, 0x74696e69   ; 'init'
  000CE273  75 1f                      jne 0x100ce294
  000CE275  8b 03                      mov eax, dword ptr [ebx]
  000CE277  8d 4c 24 14                lea ecx, [esp + 0x14]
  000CE27B  51                         push ecx
  000CE27C  8b cb                      mov ecx, ebx
  000CE27E  ff 90 dc 01 00 00          call dword ptr [eax + 0x1dc]
  000CE284  8b 00                      mov eax, dword ptr [eax]
  000CE286  85 c0                      test eax, eax
  000CE288  74 0a                      je 0x100ce294
  000CE28A  83 38 00                   cmp dword ptr [eax], 0
  000CE28D  74 05                      je 0x100ce294
  000CE28F  bf 69 6e 69 30             mov edi, 0x30696e69   ; fourcc? 'ini0'
  000CE294  8b 13                      mov edx, dword ptr [ebx]
  000CE296  8d 44 24 14                lea eax, [esp + 0x14]
  000CE29A  50                         push eax
  000CE29B  8b cb                      mov ecx, ebx
  000CE29D  ff 92 00 04 00 00          call dword ptr [edx + 0x400]
  000CE2A3  8b 00                      mov eax, dword ptr [eax]
  000CE2A5  8b 6c 24 40                mov ebp, dword ptr [esp + 0x40]
  000CE2A9  85 c0                      test eax, eax
  000CE2AB  89 44 24 10                mov dword ptr [esp + 0x10], eax
  000CE2AF  74 76                      je 0x100ce327
  000CE2B1  8d 4c 24 10                lea ecx, [esp + 0x10]
  000CE2B5  e8 b6 2d fa ff             call 0x10071070
  000CE2BA  3c 01                      cmp al, 1
  000CE2BC  75 69                      jne 0x100ce327
  000CE2BE  8b 44 24 10                mov eax, dword ptr [esp + 0x10]
  000CE2C2  85 c0                      test eax, eax
  000CE2C4  74 04                      je 0x100ce2ca
  000CE2C6  8b 00                      mov eax, dword ptr [eax]
  000CE2C8  eb 02                      jmp 0x100ce2cc

````

### D.2 state→fourcc switch machine calling sibling 0xCE790 (`out2/d_d6b40.md`, rva ~0xD6B43-0xD6CBC)

````text

  000D6B43  81 ce 00 00 77 77          or esi, 0x77770000
  000D6B49  eb 0a                      jmp 0x100d6b55
  000D6B4B  8b 74 24 28                mov esi, dword ptr [esp + 0x28]
  000D6B4F  81 ce 00 00 77 6e          or esi, 0x6e770000
  000D6B55  8b 54 24 2c                mov edx, dword ptr [esp + 0x2c]
  000D6B59  8d 44 24 28                lea eax, [esp + 0x28]
  000D6B5D  52                         push edx
  000D6B5E  6a 00                      push 0
  000D6B60  6a ff                      push -1
  000D6B62  56                         push esi
  000D6B63  6a 07                      push 7
  000D6B65  50                         push eax
  000D6B66  e9 90 01 00 00             jmp 0x100d6cfb
  000D6B6B  81 ce 00 00 69 00          or esi, 0x690000
  000D6B71  89 6c 24 18                mov dword ptr [esp + 0x18], ebp
  000D6B75  e8 56 63 0b 00             call 0x1018ced0
  000D6B7A  66 83 78 04 01             cmp word ptr [eax + 4], 1
  000D6B7F  75 38                      jne 0x100d6bb9
  000D6B81  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  000D6B85  e8 46 63 0b 00             call 0x1018ced0
  000D6B8A  66 83 78 06 01             cmp word ptr [eax + 6], 1
  000D6B8F  75 28                      jne 0x100d6bb9
  000D6B91  8b c6                      mov eax, esi
  000D6B93  57                         push edi
  000D6B94  0c 62                      or al, 0x62
  000D6B96  8b cb                      mov ecx, ebx
  000D6B98  50                         push eax
  000D6B99  6a 07                      push 7
  000D6B9B  89 44 24 2c                mov dword ptr [esp + 0x2c], eax
  000D6B9F  e8 ec 7b ff ff             call 0x100ce790
  000D6BA4  85 c0                      test eax, eax
  000D6BA6  89 44 24 28                mov dword ptr [esp + 0x28], eax
  000D6BAA  0f 84 d4 00 00 00          je 0x100d6c84
  000D6BB0  8b 74 24 20                mov esi, dword ptr [esp + 0x20]
  000D6BB4  e9 e5 00 00 00             jmp 0x100d6c9e
  000D6BB9  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  000D6BBD  e8 0e 63 0b 00             call 0x1018ced0
  000D6BC2  66 83 78 04 01             cmp word ptr [eax + 4], 1
  000D6BC7  75 38                      jne 0x100d6c01
  000D6BC9  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  000D6BCD  e8 fe 62 0b 00             call 0x1018ced0
  000D6BD2  66 83 78 06 02             cmp word ptr [eax + 6], 2
  000D6BD7  75 28                      jne 0x100d6c01
  000D6BD9  8b c6                      mov eax, esi
  000D6BDB  57                         push edi
  000D6BDC  0c 63                      or al, 0x63
  000D6BDE  8b cb                      mov ecx, ebx
  000D6BE0  50                         push eax
  000D6BE1  6a 07                      push 7
  000D6BE3  89 44 24 2c                mov dword ptr [esp + 0x2c], eax
  000D6BE7  e8 a4 7b ff ff             call 0x100ce790
  000D6BEC  85 c0                      test eax, eax
  000D6BEE  89 44 24 28                mov dword ptr [esp + 0x28], eax
  000D6BF2  0f 84 8c 00 00 00          je 0x100d6c84
  000D6BF8  8b 74 24 20                mov esi, dword ptr [esp + 0x20]
  000D6BFC  e9 9d 00 00 00             jmp 0x100d6c9e
  000D6C01  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  000D6C05  e8 c6 62 0b 00             call 0x1018ced0
  000D6C0A  66 83 78 04 01             cmp word ptr [eax + 4], 1
  000D6C0F  75 31                      jne 0x100d6c42
  000D6C11  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  000D6C15  e8 b6 62 0b 00             call 0x1018ced0
  000D6C1A  66 83 78 06 03             cmp word ptr [eax + 6], 3
  000D6C1F  75 21                      jne 0x100d6c42
  000D6C21  8b c6                      mov eax, esi
  000D6C23  57                         push edi
  000D6C24  0c 64                      or al, 0x64
  000D6C26  8b cb                      mov ecx, ebx
  000D6C28  50                         push eax
  000D6C29  6a 07                      push 7
  000D6C2B  89 44 24 2c                mov dword ptr [esp + 0x2c], eax
  000D6C2F  e8 5c 7b ff ff             call 0x100ce790
  000D6C34  85 c0                      test eax, eax
  000D6C36  89 44 24 28                mov dword ptr [esp + 0x28], eax
  000D6C3A  74 48                      je 0x100d6c84
  000D6C3C  8b 74 24 20                mov esi, dword ptr [esp + 0x20]
  000D6C40  eb 5c                      jmp 0x100d6c9e
  000D6C42  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  000D6C46  e8 85 62 0b 00             call 0x1018ced0
  000D6C4B  66 83 78 04 01             cmp word ptr [eax + 4], 1
  000D6C50  75 32                      jne 0x100d6c84
  000D6C52  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  000D6C56  e8 75 62 0b 00             call 0x1018ced0
  000D6C5B  66 83 78 06 04             cmp word ptr [eax + 6], 4
  000D6C60  75 22                      jne 0x100d6c84
  000D6C62  6a ff                      push -1
  000D6C64  68 6c 73 30 35             push 0x3530736c   ; fourcc? 'ls05'
  000D6C69  6a 07                      push 7
  000D6C6B  8b cb                      mov ecx, ebx
  000D6C6D  e8 1e 7b ff ff             call 0x100ce790
  000D6C72  85 c0                      test eax, eax
  000D6C74  89 44 24 28                mov dword ptr [esp + 0x28], eax
  000D6C78  74 0a                      je 0x100d6c84
  000D6C7A  be 6c 73 30 35             mov esi, 0x3530736c   ; fourcc? 'ls05'
  000D6C7F  83 cf ff                   or edi, 0xffffffff
  000D6C82  eb 1a                      jmp 0x100d6c9e
  000D6C84  83 ce 61                   or esi, 0x61
  000D6C87  57                         push edi
  000D6C88  8b ce                      mov ecx, esi
  000D6C8A  23 cf                      and ecx, edi
  000D6C8C  51                         push ecx
  000D6C8D  6a 07                      push 7
  000D6C8F  8b cb                      mov ecx, ebx
  000D6C91  e8 fa 7a ff ff             call 0x100ce790
  000D6C96  85 c0                      test eax, eax
  000D6C98  89 44 24 28                mov dword ptr [esp + 0x28], eax
  000D6C9C  74 66                      je 0x100d6d04
  000D6C9E  8b 44 24 28                mov eax, dword ptr [esp + 0x28]
  000D6CA2  83 f8 01                   cmp eax, 1
  000D6CA5  7e 21                      jle 0x100d6cc8
  000D6CA7  8b 93 c4 07 00 00          mov edx, dword ptr [ebx + 0x7c4]
  000D6CAD  33 d6                      xor edx, esi
  000D6CAF  f7 c2 00 00 00 ff          test edx, 0xff000000
  000D6CB5  75 05                      jne 0x100d6cbc
  000D6CB7  48                         dec eax
  000D6CB8  89 44 24 28                mov dword ptr [esp + 0x28], eax
  000D6CBC  e8 1f dd 23 00             call 0x103149e0

````

### D.3 caller context: `call rva 0xCE260` @ rva 0x5CC16 in func 0x5CBFF (`out2/d_5cbf0.md`)

````text

  0005CBF0  8d 94 24 c0 00 00 00       lea edx, [esp + 0xc0]
  0005CBF7  51                         push ecx
  0005CBF8  52                         push edx
  0005CBF9  8d 4c 24 2c                lea ecx, [esp + 0x2c]
  0005CBFD  eb 2b                      jmp 0x1005cc2a
  0005CBFF  8b c7                      mov eax, edi
  0005CC01  68 ff ff ff 00             push 0xffffff
  0005CC06  25 ff ff ff 00             and eax, 0xffffff
  0005CC0B  8d 8c 24 cc 00 00 00       lea ecx, [esp + 0xcc]
  0005CC12  50                         push eax
  0005CC13  51                         push ecx
  0005CC14  8b cb                      mov ecx, ebx
  0005CC16  e8 45 16 07 00             call 0x100ce260
  0005CC1B  8b 10                      mov edx, dword ptr [eax]
  0005CC1D  8d 84 24 d0 00 00 00       lea eax, [esp + 0xd0]
  0005CC24  52                         push edx
  0005CC25  50                         push eax
  0005CC26  8d 4c 24 28                lea ecx, [esp + 0x28]
  0005CC2A  e8 51 5c ff ff             call 0x10052880
  0005CC2F  55                         push ebp
  0005CC30  8d 4c 24 24                lea ecx, [esp + 0x24]
  0005CC34  89 6c 24 18                mov dword ptr [esp + 0x18], ebp
  0005CC38  e8 83 17 ff ff             call 0x1004e3c0
  0005CC3D  84 c0                      test al, al
  0005CC3F  74 14                      je 0x1005cc55
  0005CC41  8b 4c 24 20                mov ecx, dword ptr [esp + 0x20]
  0005CC45  51                         push ecx
  0005CC46  8b 0d 68 d1 47 10          mov ecx, dword ptr [0x1047d168]
  0005CC4C  e8 6f 63 01 00             call 0x10072fc0
  0005CC51  89 44 24 14                mov dword ptr [esp + 0x14], eax
  0005CC55  8b ce                      mov ecx, esi
  0005CC57  e8 44 19 00 00             call 0x1005e5a0
  0005CC5C  d9 5c 24 18                fstp dword ptr [esp + 0x18]
  0005CC60  8d 4c 24 20                lea ecx, [esp + 0x20]
  0005CC64  e8 d7 14 00 00             call 0x1005e140
  0005CC69  85 c0                      test eax, eax
  0005CC6B  74 2e                      je 0x1005cc9b
  0005CC6D  d9 44 24 18                fld dword ptr [esp + 0x18]
  0005CC71  d8 1d 18 9a 32 10          fcomp dword ptr [0x10329a18]
  0005CC77  df e0                      fnstsw ax
  0005CC79  25 00 41 00 00             and eax, 0x4100
  0005CC7E  75 1b                      jne 0x1005cc9b
  0005CC80  8b 4c 24 14                mov ecx, dword ptr [esp + 0x14]
  0005CC84  e8 e7 19 00 00             call 0x1005e670
  0005CC89  d9 05 90 99 32 10          fld dword ptr [0x10329990]
  0005CC8F  d8 74 24 18                fdiv dword ptr [esp + 0x18]
  0005CC93  de c9                      fmulp st(1)
  0005CC95  d9 5c 24 10                fstp dword ptr [esp + 0x10]
  0005CC99  eb 08                      jmp 0x1005cca3
  0005CC9B  c7 44 24 10 00 00 80 3f    mov dword ptr [esp + 0x10], 0x3f800000
  0005CCA3  6a 00                      push 0
  0005CCA5  8d 4c 24 24                lea ecx, [esp + 0x24]
  0005CCA9  c7 44 24 20 00 00 00 00    mov dword ptr [esp + 0x20], 0
  0005CCB1  c7 44 24 1c 00 00 00 00    mov dword ptr [esp + 0x1c], 0
  0005CCB9  e8 02 17 ff ff             call 0x1004e3c0
  0005CCBE  84 c0                      test al, al
  0005CCC0  74 5a                      je 0x1005cd1c
  0005CCC2  8b 96 88 00 00 00          mov edx, dword ptr [esi + 0x88]
  0005CCC8  8b 42 1c                   mov eax, dword ptr [edx + 0x1c]
  0005CCCB  c1 e8 1c                   shr eax, 0x1c
  0005CCCE  48                         dec eax
  0005CCCF  74 25                      je 0x1005ccf6

````

---

## §E. The s2c 0x0E CHAR_NPC handler: field-packing core @rva 0x9BCF7 (F30, F31, F43)

`p2_handler.py --dump` ranked heuristic functions by signals S1-S10 (see its docstring; sweep =
1,175,095 insns / 34,634 funcs). Top candidate: func rva **0x9BCF7** (score 50), the field-packing
core of the 0x0E handler. esi = packet buffer pointer (**header-inclusive** offsets); entity looked
up via global table VA 0x10480B30 (rva 0x480B30, .data), stride 4 (`mov eax,[edx*4+0x10480B30]`,
edx = u16 target index at pkt+8).

### E.1 top-15 candidate table (from `out2/p2.lf.md`)

````text

## Phase 2 handler search

sweep: 1175095 insns, 34634 funcs

ActionTimer2=1800 store funcs: 0xA4110
CXiSkeletonActor vtable-installing funcs (ctor candidates): 0xC525E, 0xC59C0, 0xC5B71

````
| # | func range | score | size | signals | callers |
|---|---|---|---|---|---|
| 1 | 0x9BCF7..0x9BE88 | 50 | 401 B | S1 status byte, S2 animsub byte, S10 spawn flag 0x04 | 0 (virtual/pointer-table reach) |
| 2 | 0xFAE5B..0xFB650 | 49 | 2037 B | S1, S2, S3 anim byte, word-granular unpacker into a big local struct; not entity-table based | 0 |
| 3 | 0x99E24..0x9A1DB | 49 | 951 B | S1, S2, S10, position/pose update path, same entity table | 0 |
| 4 | 0xE5B8D..0xE5D16 | 38 | 393 B | S1, S2 | 0 |
| 5 | 0x2623E0..0x2625E3 | 37 | 515 B | S1, S2 | 0 |
| 6 | 0x1B1558..0x1B15E4 | 37 | 140 B | S1, S2 | 0 |
| 7 | 0xFF3DC..0xFF743 | 37 | 871 B | S1, S2 | 0 |
| 8 | 0x9D2C2..0x9D4C9 | 37 | 519 B | S1, S2 | 0 |
| 9 | 0x39B53..0x39BDC | 37 | 137 B | S1, S2 | 0 |
| 10 | 0x2F1E0C..0x2F1E5D | 35 | 81 B | S1, S3, S4 cmp-3-after-status | 1: 0x2F8245 in 0x2F820D |
| 11 | 0x2C8099..0x2C822B | 34 | 402 B | S1, S3, S10 | 1: 0x2C4ABE in 0x2C4A81 |
| 12 | 0x2EFDDA..0x2EFE6A | 33 | 144 B | S1, S3, S4 | 1: 0x2DC637 in 0x2DC57D |
| 13 | 0x2C2C48..0x2C2D0B | 33 | 195 B | S1, S3, S4 | 2: 0x253BB3 in 0x253B5A; 0x254198 in 0x25413A |
| 14 | 0xADF91..0xAE083 | 33 | 242 B | S1, S4, S10 | 0 |
| 15 | 0x13CCD9..0x13CDA1 | 26 | 200 B | S1, S4 | 0 |

### E.2 top candidate signal excerpts (verbatim from `out2/p2.lf.md`)

````text

#### func 0x9BCF7..0x9BE88 (score 50, 401 bytes) signals: S1 status byte, S10 spawn flag 0x04, S2 animsub byte
callers (0): 
```
-- S1 status byte @ 0x9BD30
  0009BD23  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BD27  33 c9                      xor ecx, ecx
  0009BD29  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
>>0009BD30  8a 4e 20                   mov cl, byte ptr [esi + 0x20]   ; pkt(hdr) status?
  0009BD33  c1 e1 0d                   shl ecx, 0xd
  0009BD36  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BD3C  33 ca                      xor ecx, edx
-- S1 status byte @ 0x9BDC9
  0009BDC1  33 d2                      xor edx, edx
  0009BDC3  33 c9                      xor ecx, ecx
  0009BDC5  66 8b 56 08                mov dx, word ptr [esi + 8]
>>0009BDC9  8a 4e 20                   mov cl, byte ptr [esi + 0x20]   ; pkt(hdr) status?
  0009BDCC  c1 e1 0d                   shl ecx, 0xd
  0009BDCF  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BDD6  8b 98 20 01 00 00          mov ebx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
-- S1 status byte @ 0x9BE55
  0009BE47  81 e1 00 00 04 00          and ecx, 0x40000
  0009BE4D  33 d1                      xor edx, ecx
  0009BE4F  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
>>0009BE55  8a 46 20                   mov al, byte ptr [esi + 0x20]   ; pkt(hdr) status?
  0009BE58  a8 01                      test al, 1
  0009BE5A  75 2c                      jne 0x1009be88
  0009BE5C  f7 46 28 00 00 00 04       test dword ptr [esi + 0x28], 0x4000000
-- S10 spawn flag 0x04 @ 0x9BDAF
  0009BDA1  81 e1 00 00 04 00          and ecx, 0x40000
  0009BDA7  33 d1                      xor edx, ecx
  0009BDA9  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
>>0009BDAF  f6 46 0a 04                test byte ptr [esi + 0xa], 4
  0009BDB3  0f 84 4c 0b 00 00          je 0x1009c905
  0009BDB9  84 db                      test bl, bl
  0009BDBB  0f 85 cb 10 00 00          jne 0x1009ce8c
-- S2 animsub byte @ 0x9BE6D
  0009BE65  33 d2                      xor edx, edx
  0009BE67  33 c9                      xor ecx, ecx
  0009BE69  66 8b 56 08                mov dx, word ptr [esi + 8]
>>0009BE6D  8a 4e 2a                   mov cl, byte ptr [esi + 0x2a]   ; pkt(hdr) animationsub?
  0009BE70  c1 e1 0d                   shl ecx, 0xd
  0009BE73  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BE7A  33 88 24 01 00 00          xor ecx, dword ptr [eax + 0x124]
```

````

### E.3 full disassembly of func rva 0x9BCF7..0x9BE88 (the field-packing core; verbatim from `out2/p2.lf.md`)

Decode notes (F30): [esi+0xA] = update mask byte, bit 2 → block A @0x9BD0B, bit 4 → block B
@0x9BDB9. [esi+0x1E] → ent+0xEC; [esi+0x2C] u32 → ent+0x188. **The "status" is a full u32 at
pkt+0x20** (body+0x1C), unpacked with the XOR-diff toggle idiom into: B0 bits 0/1/2 → RenderFlags0
(+0x120) bits **0x2000 / 0x4000 / 0x40000** (status&7 packed at <<13, bit2→bit18); B0 bits 5-7 →
`call rva 0x97A30(ent, val)` @0x9BECF; B1(pkt+0x21): bit0 → RFlags0 0x400000, bits 1-2 → RFlags0
bits 30-31 (cleared-then-set via `and 0x3FFFFFFF`); B2(pkt+0x22) bit0 → +0x124 bit 0x400000;
B3(pkt+0x23): bit0 → +0x124 0x1000000, low 3 bits → +0x128 bits 0x3800. Also: [ent+0x124] bits
17/18/19 cleared; [ent+0x140] &= ~0x8; (pkt+0x20)>>21 & 0xF → +0x128 bit 0x10. **animationsub
(pkt+0x2A) is stored TWICE in RenderFlags1(+0x124): bits 1-3** (`shl 1; xor; and 0xE` @0x9BE88-
0x9BEAD, shown in E.5) **and bits 13-15** (`shl 13; xor; and 0x6000` @0x9BE6D, visible at the end of
E.3). Where the old sub is kept: packed in +0x124, not a named field.

````text

#### 0x9BCF7
```
  0009BCF7  33 ed                      xor ebp, ebp
  0009BCF9  f6 46 0a 02                test byte ptr [esi + 0xa], 2
  0009BCFD  0f 84 ac 00 00 00          je 0x1009bdaf
  0009BD03  84 db                      test bl, bl
  0009BD05  0f 85 a4 00 00 00          jne 0x1009bdaf
  0009BD0B  8b 4e 2c                   mov ecx, dword ptr [esi + 0x2c]
  0009BD0E  33 d2                      xor edx, edx
  0009BD10  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BD14  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BD1B  33 d2                      xor edx, edx
  0009BD1D  89 88 88 01 00 00          mov dword ptr [eax + 0x188], ecx
  0009BD23  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BD27  33 c9                      xor ecx, ecx
  0009BD29  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BD30  8a 4e 20                   mov cl, byte ptr [esi + 0x20]   ; pkt(hdr) status?
  0009BD33  c1 e1 0d                   shl ecx, 0xd
  0009BD36  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BD3C  33 ca                      xor ecx, edx
  0009BD3E  81 e1 00 20 00 00          and ecx, 0x2000
  0009BD44  33 d1                      xor edx, ecx
  0009BD46  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
  0009BD4C  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009BD4F  33 d2                      xor edx, edx
  0009BD51  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BD55  d1 e9                      shr ecx, 1
  0009BD57  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BD5E  81 e1 ff 00 00 00          and ecx, 0xff
  0009BD64  c1 e1 0e                   shl ecx, 0xe
  0009BD67  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BD6D  33 ca                      xor ecx, edx
  0009BD6F  81 e1 00 40 00 00          and ecx, 0x4000
  0009BD75  33 d1                      xor edx, ecx
  0009BD77  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
  0009BD7D  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009BD80  33 d2                      xor edx, edx
  0009BD82  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BD86  c1 e9 02                   shr ecx, 2
  0009BD89  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BD90  81 e1 ff 00 00 00          and ecx, 0xff
  0009BD96  c1 e1 12                   shl ecx, 0x12
  0009BD99  8b 90 20 01 00 00          mov edx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BD9F  33 ca                      xor ecx, edx
  0009BDA1  81 e1 00 00 04 00          and ecx, 0x40000
  0009BDA7  33 d1                      xor edx, ecx
  0009BDA9  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
  0009BDAF  f6 46 0a 04                test byte ptr [esi + 0xa], 4
  0009BDB3  0f 84 4c 0b 00 00          je 0x1009c905
  0009BDB9  84 db                      test bl, bl
  0009BDBB  0f 85 cb 10 00 00          jne 0x1009ce8c
  0009BDC1  33 d2                      xor edx, edx
  0009BDC3  33 c9                      xor ecx, ecx
  0009BDC5  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BDC9  8a 4e 20                   mov cl, byte ptr [esi + 0x20]   ; pkt(hdr) status?
  0009BDCC  c1 e1 0d                   shl ecx, 0xd
  0009BDCF  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BDD6  8b 98 20 01 00 00          mov ebx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BDDC  33 cb                      xor ecx, ebx
  0009BDDE  8b d3                      mov edx, ebx
  0009BDE0  81 e1 00 20 00 00          and ecx, 0x2000
  0009BDE6  33 d1                      xor edx, ecx
  0009BDE8  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
  0009BDEE  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009BDF1  33 d2                      xor edx, edx
  0009BDF3  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BDF7  d1 e9                      shr ecx, 1
  0009BDF9  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BE00  81 e1 ff 00 00 00          and ecx, 0xff
  0009BE06  c1 e1 0e                   shl ecx, 0xe
  0009BE09  8b 98 20 01 00 00          mov ebx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BE0F  33 cb                      xor ecx, ebx
  0009BE11  8b d3                      mov edx, ebx
  0009BE13  81 e1 00 40 00 00          and ecx, 0x4000
  0009BE19  33 d1                      xor edx, ecx
  0009BE1B  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
  0009BE21  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009BE24  33 d2                      xor edx, edx
  0009BE26  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BE2A  c1 e9 02                   shr ecx, 2
  0009BE2D  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BE34  81 e1 ff 00 00 00          and ecx, 0xff
  0009BE3A  c1 e1 12                   shl ecx, 0x12
  0009BE3D  8b 98 20 01 00 00          mov ebx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BE43  33 cb                      xor ecx, ebx
  0009BE45  8b d3                      mov edx, ebx
  0009BE47  81 e1 00 00 04 00          and ecx, 0x40000
  0009BE4D  33 d1                      xor edx, ecx
  0009BE4F  89 90 20 01 00 00          mov dword ptr [eax + 0x120], edx   ; ent.RenderFlags0?
  0009BE55  8a 46 20                   mov al, byte ptr [esi + 0x20]   ; pkt(hdr) status?
  0009BE58  a8 01                      test al, 1
  0009BE5A  75 2c                      jne 0x1009be88
  0009BE5C  f7 46 28 00 00 00 04       test dword ptr [esi + 0x28], 0x4000000
  0009BE63  75 23                      jne 0x1009be88
  0009BE65  33 d2                      xor edx, edx
  0009BE67  33 c9                      xor ecx, ecx
  0009BE69  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BE6D  8a 4e 2a                   mov cl, byte ptr [esi + 0x2a]   ; pkt(hdr) animationsub?
  0009BE70  c1 e1 0d                   shl ecx, 0xd
  0009BE73  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BE7A  33 88 24 01 00 00          xor ecx, dword ptr [eax + 0x124]
  0009BE80  81 e1 00 60 00 00          and ecx, 0x6000
  0009BE86  eb 1d                      jmp 0x1009bea5
```

````

### E.4 animationsub double-packing + status-u32 unpacking region @ rva 0x9BE88-0x9C0EA (`out2/d_9be88.md`, full dump)

The first block (0x9BE88-0x9BEAD) is the sub→+0x124 bits 1-3 store; 0x9BEB3-0x9BECF is B0
bits 5-7 → `call rva 0x97A30`; the rest unpacks the status u32 (pkt+0x20) into +0x124/+0x128 bits.

````text

  0009BE88  33 d2                      xor edx, edx
  0009BE8A  33 c9                      xor ecx, ecx
  0009BE8C  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BE90  8a 4e 2a                   mov cl, byte ptr [esi + 0x2a]   ; pkt(hdr) animationsub?
  0009BE93  03 c9                      add ecx, ecx
  0009BE95  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BE9C  33 88 24 01 00 00          xor ecx, dword ptr [eax + 0x124]
  0009BEA2  83 e1 0e                   and ecx, 0xe
  0009BEA5  8b 90 24 01 00 00          mov edx, dword ptr [eax + 0x124]
  0009BEAB  33 d1                      xor edx, ecx
  0009BEAD  89 90 24 01 00 00          mov dword ptr [eax + 0x124], edx
  0009BEB3  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  0009BEB6  33 c0                      xor eax, eax
  0009BEB8  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009BEBC  c1 ea 05                   shr edx, 5
  0009BEBF  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009BEC6  83 e2 07                   and edx, 7
  0009BEC9  52                         push edx
  0009BECA  e8 61 bb ff ff             call 0x10097a30
  0009BECF  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  0009BED2  33 c9                      xor ecx, ecx
  0009BED4  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009BED8  c1 ea 08                   shr edx, 8
  0009BEDB  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009BEE2  81 e2 ff 00 00 00          and edx, 0xff
  0009BEE8  c1 e2 16                   shl edx, 0x16
  0009BEEB  8b 88 20 01 00 00          mov ecx, dword ptr [eax + 0x120]   ; ent.RenderFlags0?
  0009BEF1  33 d1                      xor edx, ecx
  0009BEF3  8b f9                      mov edi, ecx
  0009BEF5  81 e2 00 00 40 00          and edx, 0x400000
  0009BEFB  33 c9                      xor ecx, ecx
  0009BEFD  33 fa                      xor edi, edx
  0009BEFF  89 b8 20 01 00 00          mov dword ptr [eax + 0x120], edi   ; ent.RenderFlags0?
  0009BF05  8b 46 20                   mov eax, dword ptr [esi + 0x20]
  0009BF08  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009BF0C  c1 e8 09                   shr eax, 9
  0009BF0F  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  0009BF16  24 03                      and al, 3
  0009BF18  88 44 24 5c                mov byte ptr [esp + 0x5c], al
  0009BF1C  8b 44 24 5c                mov eax, dword ptr [esp + 0x5c]
  0009BF20  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  0009BF26  25 ff 00 00 00             and eax, 0xff
  0009BF2B  c1 e0 1e                   shl eax, 0x1e
  0009BF2E  33 d0                      xor edx, eax
  0009BF30  81 e2 ff ff ff 3f          and edx, 0x3fffffff
  0009BF36  33 d0                      xor edx, eax
  0009BF38  33 c0                      xor eax, eax
  0009BF3A  89 91 20 01 00 00          mov dword ptr [ecx + 0x120], edx   ; ent.RenderFlags0?
  0009BF40  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009BF44  33 c9                      xor ecx, ecx
  0009BF46  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009BF4D  8b b8 24 01 00 00          mov edi, dword ptr [eax + 0x124]
  0009BF53  81 e7 ff ff ef ff          and edi, 0xffefffff
  0009BF59  89 b8 24 01 00 00          mov dword ptr [eax + 0x124], edi
  0009BF5F  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009BF63  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009BF6A  8b 90 24 01 00 00          mov edx, dword ptr [eax + 0x124]
  0009BF70  81 e2 ff ff df ff          and edx, 0xffdfffff
  0009BF76  89 90 24 01 00 00          mov dword ptr [eax + 0x124], edx
  0009BF7C  33 d2                      xor edx, edx
  0009BF7E  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BF82  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BF89  8b 88 24 01 00 00          mov ecx, dword ptr [eax + 0x124]
  0009BF8F  81 e1 ff ff 7f ff          and ecx, 0xff7fffff
  0009BF95  89 88 24 01 00 00          mov dword ptr [eax + 0x124], ecx
  0009BF9B  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009BF9E  33 c0                      xor eax, eax
  0009BFA0  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009BFA4  c1 e9 0d                   shr ecx, 0xd
  0009BFA7  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009BFAE  81 e1 ff 00 00 00          and ecx, 0xff
  0009BFB4  c1 e1 18                   shl ecx, 0x18
  0009BFB7  8b 98 24 01 00 00          mov ebx, dword ptr [eax + 0x124]
  0009BFBD  33 cb                      xor ecx, ebx
  0009BFBF  8b d3                      mov edx, ebx
  0009BFC1  81 e1 00 00 00 01          and ecx, 0x1000000
  0009BFC7  33 d1                      xor edx, ecx
  0009BFC9  89 90 24 01 00 00          mov dword ptr [eax + 0x124], edx
  0009BFCF  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009BFD2  33 d2                      xor edx, edx
  0009BFD4  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009BFD8  c1 e9 0e                   shr ecx, 0xe
  0009BFDB  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009BFE2  81 e1 ff 00 00 00          and ecx, 0xff
  0009BFE8  c1 e1 16                   shl ecx, 0x16
  0009BFEB  8b 98 24 01 00 00          mov ebx, dword ptr [eax + 0x124]
  0009BFF1  33 cb                      xor ecx, ebx
  0009BFF3  8b d3                      mov edx, ebx
  0009BFF5  81 e1 00 00 40 00          and ecx, 0x400000
  0009BFFB  33 d1                      xor edx, ecx
  0009BFFD  89 90 24 01 00 00          mov dword ptr [eax + 0x124], edx
  0009C003  8b 4e 20                   mov ecx, dword ptr [esi + 0x20]
  0009C006  33 d2                      xor edx, edx
  0009C008  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009C00C  c1 e9 0f                   shr ecx, 0xf
  0009C00F  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009C016  0f be d1                   movsx edx, cl
  0009C019  8b 88 24 01 00 00          mov ecx, dword ptr [eax + 0x124]
  0009C01F  c1 e2 19                   shl edx, 0x19
  0009C022  33 d1                      xor edx, ecx
  0009C024  8b f9                      mov edi, ecx
  0009C026  81 e2 00 00 00 02          and edx, 0x2000000
  0009C02C  33 fa                      xor edi, edx
  0009C02E  33 d2                      xor edx, edx
  0009C030  89 b8 24 01 00 00          mov dword ptr [eax + 0x124], edi
  0009C036  33 c0                      xor eax, eax
  0009C038  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C03C  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009C043  8b 88 24 01 00 00          mov ecx, dword ptr [eax + 0x124]
  0009C049  81 e1 ff ff ff fb          and ecx, 0xfbffffff
  0009C04F  89 88 24 01 00 00          mov dword ptr [eax + 0x124], ecx
  0009C055  33 c9                      xor ecx, ecx
  0009C057  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C05B  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009C062  33 c9                      xor ecx, ecx
  0009C064  8b 98 24 01 00 00          mov ebx, dword ptr [eax + 0x124]
  0009C06A  81 e3 ff ff ff f7          and ebx, 0xf7ffffff
  0009C070  89 98 24 01 00 00          mov dword ptr [eax + 0x124], ebx
  0009C076  66 8b 56 08                mov dx, word ptr [esi + 8]
  0009C07A  8b 04 95 30 0b 48 10       mov eax, dword ptr [edx*4 + 0x10480b30]
  0009C081  8b b8 24 01 00 00          mov edi, dword ptr [eax + 0x124]
  0009C087  81 e7 ff ff ff ef          and edi, 0xefffffff
  0009C08D  89 b8 24 01 00 00          mov dword ptr [eax + 0x124], edi
  0009C093  33 c0                      xor eax, eax
  0009C095  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C099  bf f7 ff ff ff             mov edi, 0xfffffff7
  0009C09E  8b 04 85 30 0b 48 10       mov eax, dword ptr [eax*4 + 0x10480b30]
  0009C0A5  8b 90 40 01 00 00          mov edx, dword ptr [eax + 0x140]
  0009C0AB  23 d7                      and edx, edi
  0009C0AD  89 90 40 01 00 00          mov dword ptr [eax + 0x140], edx
  0009C0B3  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C0B7  8b 56 20                   mov edx, dword ptr [esi + 0x20]
  0009C0BA  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009C0C1  c1 ea 13                   shr edx, 0x13
  0009C0C4  0f be ca                   movsx ecx, dl
  0009C0C7  8b 90 28 01 00 00          mov edx, dword ptr [eax + 0x128]
  0009C0CD  c1 e1 04                   shl ecx, 4
  0009C0D0  33 ca                      xor ecx, edx
  0009C0D2  83 e1 10                   and ecx, 0x10
  0009C0D5  33 d1                      xor edx, ecx
  0009C0D7  89 90 28 01 00 00          mov dword ptr [eax + 0x128], edx
  0009C0DD  8a 46 28                   mov al, byte ptr [esi + 0x28]
  0009C0E0  a8 01                      test al, 1
  0009C0E2  74 18                      je 0x1009c0fc
  0009C0E4  33 d2                      xor edx, edx
  0009C0E6  66 8b 56 08                mov dx, word ptr [esi + 8]

````

### E.5 ent+0xEC store, StatusServer gate @ rva 0x9C14B-0x9C183, B3→+0x128 packing (excerpt from `out2/d_9c0e6.md`)

**StatusServer(+0x16C) ← animation byte (pkt+0x1F)** @ rva 0x9C17D: skip if RFlags0 bit 1 set
(`shr edx,1; test dl,1`); else if ((pkt+0x28)&1) and anim ∈ {0x21,0x2F} or `call rva 0x957A0(anim)`
true → skip. So yes, 0x0E writes StatusServer (§8 answered).

````text

  0009C128  8a 56 1e                   mov dl, byte ptr [esi + 0x1e]
  0009C12B  33 c0                      xor eax, eax
  0009C12D  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C131  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009C138  33 c0                      xor eax, eax
  0009C13A  88 91 ec 00 00 00          mov byte ptr [ecx + 0xec], dl
  0009C140  66 8b 46 08                mov ax, word ptr [esi + 8]
  0009C144  8b 0c 85 30 0b 48 10       mov ecx, dword ptr [eax*4 + 0x10480b30]
  0009C14B  8b 91 20 01 00 00          mov edx, dword ptr [ecx + 0x120]   ; ent.RenderFlags0?
  0009C151  d1 ea                      shr edx, 1
  0009C153  f6 c2 01                   test dl, 1
  0009C156  75 2b                      jne 0x1009c183
  0009C158  f6 46 28 01                test byte ptr [esi + 0x28], 1
  0009C15C  74 1a                      je 0x1009c178
  0009C15E  8a 46 1f                   mov al, byte ptr [esi + 0x1f]   ; pkt(hdr) animation?
  0009C161  3c 21                      cmp al, 0x21
  0009C163  74 1e                      je 0x1009c183
  0009C165  3c 2f                      cmp al, 0x2f
  0009C167  74 1a                      je 0x1009c183
  0009C169  25 ff 00 00 00             and eax, 0xff
  0009C16E  50                         push eax
  0009C16F  e8 2c 96 ff ff             call 0x100957a0
  0009C174  84 c0                      test al, al
  0009C176  75 0b                      jne 0x1009c183
  0009C178  33 c0                      xor eax, eax
  0009C17A  8a 46 1f                   mov al, byte ptr [esi + 0x1f]   ; pkt(hdr) animation?
  0009C17D  89 81 6c 01 00 00          mov dword ptr [ecx + 0x16c], eax
  0009C183  33 c9                      xor ecx, ecx
  0009C185  33 d2                      xor edx, edx
  0009C187  66 8b 4e 08                mov cx, word ptr [esi + 8]
  0009C18B  8a 56 23                   mov dl, byte ptr [esi + 0x23]
  0009C18E  c1 e2 0b                   shl edx, 0xb
  0009C191  8b 04 8d 30 0b 48 10       mov eax, dword ptr [ecx*4 + 0x10480b30]
  0009C198  8b 88 28 01 00 00          mov ecx, dword ptr [eax + 0x128]
  0009C19E  33 d1                      xor edx, ecx
  0009C1A0  81 e2 00 38 00 00          and edx, 0x3800
  0009C1A6  33 ca                      xor ecx, edx
  0009C1A8  33 d2                      xor edx, edx
  0009C1AA  89 88 28 01 00 00          mov dword ptr [eax + 0x128], ecx
  0009C1B0  33 c0                      xor eax, eax

````

### E.6 ActorPointer=0 store sites + the single "has actor" test site (verbatim from `out2/p2.lf.md`)

Nine `[reg+0xA0]=0` stores were found; eight are stack-local zeroing (false positives). The one real
entity-field clear is in func 0x928A3 @ rva 0x92966 (§F). And there is exactly **one** site in the
whole image that tests RenderFlags0 bit 0x200:

````text

### All ActorPointer=0 store sites

- func 0x928A3: 0x92966
- func 0xA5101: 0xA51D5
- func 0xD55BA: 0xD5824
- func 0x16885B: 0x168A8B
- func 0x1714D0: 0x171AAC
- func 0x173B38: 0x173F37
- func 0x174A35: 0x1754A2
- func 0x1D306E: 0x1D30DC
- func 0x1D30E7: 0x1D30EB

### All RenderFlags0 (+0x120) mask sites with 0x200 / 0xC16000 / 0x800000

- func 0x87D41: 0x87D65 test dword ptr [ecx + 0x120], 0x200

Record in ?9: the handler RVA, the status==3 branch (S4/S5/S6), the actor-create branch (S8), the ini dispatch (S9), the spawn-flag gate (S10), and where the previous sub value is compared (look for a cmp between the S2 load and a byte on the entity or actor).

````

---

## §F. Actor destroy path (func rva 0x928A3) and create-path xrefs (F32-F34)

Full dump of func rva **0x928A3** (`disasm.py --func 0x928A3`; the heuristic range spans several
adjacent functions, three distinct entries are visible: @0x928A3, @0x92910, @0x929E0).

Decode (F32/F33):

- **Entry @ rva 0x928A3** (`cmp eax,2` → `push 9; call rva 0xD44C0(actor)`): a second-pointer
  teardown, clears `[esi+0xA4]` via its own vcall slot 6 (+0x18) @0x928BF-0x928C3, zeroes
  `[actor+0x768]`, and writes `0x20202020` (four spaces, the "no fourcc" marker, cf. F4's event-VM
  op) to `[actor+0x7D8]`. Also clears RFlags0 bit **0x100** (`and ah,0xFB` @0x928F6).
- **Entry @ rva 0x92910, the destroy block**: calls four small helpers (rva 0x92880/0x92810/
  0x92770/0x92720/0x926D0), then gates on **RFlags0 bit 0x200 "has actor" only** (`test ah,2` @
  0x9293A), NOT directly on status bits. If `[esi+0x128]&4` is also set it first calls `rva
  0xD44C0(actor, 3)` (@0x92950); then vcall slot 6 (+0x18 → rva **0xC5550**, the CXiSkeletonActor
  dtor/release) with arg 1 @0x9295F-0x92963; stores `[esi+0xA0]=0` @**0x92966**; clears RFlags0 bit
  **0x200** (`and ah,0xFD`) and +0x128 bit 2 (`and edx,0xFFFFFFFB`) @0x9297C-0x9297F; if
  `[esi+0x1BC]` ∈ {1,2} sets it to 3. This matches F11's observed destroy exactly (ActorPointer=0,
  Flags0 0x00402200→0x00C16000).
- **Entry @ rva 0x929E0**: another "has actor" consumer, `test ch,2` on RFlags0, Type(+0xEE) ∈
  {0,1,2,6,7,8} check, then a position-copy via the same global-object call (rva 0x1812A0) used in
  §C when RFlags0 bit 0x100000 is clear.

How this entry is reached (flush wrapper 0x95DB0 on RF3 bit 0) is F35/F36.

### F.1 full dump (`out2/d_928a3.md`)

````text

; func 0x928A3..0x92A7A (471 bytes), callers: 0
  000928A3  83 f8 02                   cmp eax, 2
  000928A6  75 0d                      jne 0x100928b5
  000928A8  6a 09                      push 9
  000928AA  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  000928B0  e8 0b 1c 04 00             call 0x100d44c0
  000928B5  8b 8e a4 00 00 00          mov ecx, dword ptr [esi + 0xa4]
  000928BB  85 c9                      test ecx, ecx
  000928BD  74 11                      je 0x100928d0
  000928BF  8b 01                      mov eax, dword ptr [ecx]
  000928C1  6a 01                      push 1
  000928C3  ff 50 18                   call dword ptr [eax + 0x18]
  000928C6  c7 86 a4 00 00 00 00 00 00 00 mov dword ptr [esi + 0xa4], 0
  000928D0  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  000928D6  c7 81 68 07 00 00 00 00 00 00 mov dword ptr [ecx + 0x768], 0
  000928E0  c7 86 a4 00 00 00 00 00 00 00 mov dword ptr [esi + 0xa4], 0
  000928EA  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  000928F0  8b 96 a0 00 00 00          mov edx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  000928F6  80 e4 fb                   and ah, 0xfb
  000928F9  89 86 20 01 00 00          mov dword ptr [esi + 0x120], eax   ; ent.RenderFlags0?
  000928FF  c7 82 d8 07 00 00 20 20 20 20 mov dword ptr [edx + 0x7d8], 0x20202020   ; fourcc? '    '
  00092909  5e                         pop esi
  0009290A  c3                         ret 
  0009290B  90                         nop 
  0009290C  90                         nop 
  0009290D  90                         nop 
  0009290E  90                         nop 
  0009290F  90                         nop 
  00092910  56                         push esi
  00092911  8b f1                      mov esi, ecx
  00092913  e8 68 ff ff ff             call 0x10092880
  00092918  8b ce                      mov ecx, esi
  0009291A  e8 f1 fe ff ff             call 0x10092810
  0009291F  8b ce                      mov ecx, esi
  00092921  e8 4a fe ff ff             call 0x10092770
  00092926  8b ce                      mov ecx, esi
  00092928  e8 f3 fd ff ff             call 0x10092720
  0009292D  8b ce                      mov ecx, esi
  0009292F  e8 9c fd ff ff             call 0x100926d0
  00092934  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  0009293A  f6 c4 02                   test ah, 2
  0009293D  74 64                      je 0x100929a3
  0009293F  f6 86 28 01 00 00 04       test byte ptr [esi + 0x128], 4
  00092946  74 0d                      je 0x10092955
  00092948  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0009294E  6a 03                      push 3
  00092950  e8 6b 1b 04 00             call 0x100d44c0
  00092955  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0009295B  85 c9                      test ecx, ecx
  0009295D  74 11                      je 0x10092970
  0009295F  8b 01                      mov eax, dword ptr [ecx]
  00092961  6a 01                      push 1
  00092963  ff 50 18                   call dword ptr [eax + 0x18]
  00092966  c7 86 a0 00 00 00 00 00 00 00 mov dword ptr [esi + 0xa0], 0   ; ent.ActorPointer?
  00092970  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  00092976  8b 96 28 01 00 00          mov edx, dword ptr [esi + 0x128]
  0009297C  80 e4 fd                   and ah, 0xfd
  0009297F  83 e2 fb                   and edx, 0xfffffffb
  00092982  89 86 20 01 00 00          mov dword ptr [esi + 0x120], eax   ; ent.RenderFlags0?
  00092988  8a 86 bc 01 00 00          mov al, byte ptr [esi + 0x1bc]
  0009298E  3c 01                      cmp al, 1
  00092990  89 96 28 01 00 00          mov dword ptr [esi + 0x128], edx
  00092996  74 04                      je 0x1009299c
  00092998  3c 02                      cmp al, 2
  0009299A  75 07                      jne 0x100929a3
  0009299C  c6 86 bc 01 00 00 03       mov byte ptr [esi + 0x1bc], 3
  000929A3  8b ce                      mov ecx, esi
  000929A5  5e                         pop esi
  000929A6  e9 35 c8 ff ff             jmp 0x1008f1e0
  000929AB  90                         nop 
  000929AC  90                         nop 
  000929AD  90                         nop 
  000929AE  90                         nop 
  000929AF  90                         nop 
  000929B0  8b 41 24                   mov eax, dword ptr [ecx + 0x24]
  000929B3  89 41 04                   mov dword ptr [ecx + 4], eax
  000929B6  8b 51 28                   mov edx, dword ptr [ecx + 0x28]
  000929B9  89 51 08                   mov dword ptr [ecx + 8], edx
  000929BC  8b 41 2c                   mov eax, dword ptr [ecx + 0x2c]
  000929BF  89 41 0c                   mov dword ptr [ecx + 0xc], eax
  000929C2  8b 51 34                   mov edx, dword ptr [ecx + 0x34]
  000929C5  89 51 14                   mov dword ptr [ecx + 0x14], edx
  000929C8  8b 41 38                   mov eax, dword ptr [ecx + 0x38]
  000929CB  89 41 18                   mov dword ptr [ecx + 0x18], eax
  000929CE  8b 51 3c                   mov edx, dword ptr [ecx + 0x3c]
  000929D1  89 51 1c                   mov dword ptr [ecx + 0x1c], edx
  000929D4  e9 57 02 00 00             jmp 0x10092c30
  000929D9  90                         nop 
  000929DA  90                         nop 
  000929DB  90                         nop 
  000929DC  90                         nop 
  000929DD  90                         nop 
  000929DE  90                         nop 
  000929DF  90                         nop 
  000929E0  83 ec 10                   sub esp, 0x10
  000929E3  56                         push esi
  000929E4  8b f1                      mov esi, ecx
  000929E6  8b 8e 20 01 00 00          mov ecx, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  000929EC  f6 c5 02                   test ch, 2
  000929EF  0f 84 2f 01 00 00          je 0x10092b24
  000929F5  8a 86 ee 00 00 00          mov al, byte ptr [esi + 0xee]
  000929FB  84 c0                      test al, al
  000929FD  74 18                      je 0x10092a17
  000929FF  3c 01                      cmp al, 1
  00092A01  74 14                      je 0x10092a17
  00092A03  3c 02                      cmp al, 2
  00092A05  74 10                      je 0x10092a17
  00092A07  3c 06                      cmp al, 6
  00092A09  74 0c                      je 0x10092a17
  00092A0B  3c 07                      cmp al, 7
  00092A0D  74 08                      je 0x10092a17
  00092A0F  3c 08                      cmp al, 8
  00092A11  0f 85 0d 01 00 00          jne 0x10092b24
  00092A17  f7 c1 00 00 10 00          test ecx, 0x100000
  00092A1D  c7 44 24 04 00 00 00 00    mov dword ptr [esp + 4], 0
  00092A25  0f 85 8e 00 00 00          jne 0x10092ab9
  00092A2B  e8 d0 9a 13 00             call 0x101cc500
  00092A30  3b c6                      cmp eax, esi
  00092A32  75 46                      jne 0x10092a7a
  00092A34  8b 46 0c                   mov eax, dword ptr [esi + 0xc]
  00092A37  8b 4e 08                   mov ecx, dword ptr [esi + 8]
  00092A3A  8b 56 04                   mov edx, dword ptr [esi + 4]
  00092A3D  89 44 24 08                mov dword ptr [esp + 8], eax
  00092A41  8d 44 24 04                lea eax, [esp + 4]
  00092A45  89 4c 24 0c                mov dword ptr [esp + 0xc], ecx
  00092A49  8b 4c 24 08                mov ecx, dword ptr [esp + 8]
  00092A4D  89 54 24 10                mov dword ptr [esp + 0x10], edx
  00092A51  8b 54 24 0c                mov edx, dword ptr [esp + 0xc]
  00092A55  50                         push eax
  00092A56  8b 44 24 14                mov eax, dword ptr [esp + 0x14]
  00092A5A  68 00 00 48 42             push 0x42480000
  00092A5F  51                         push ecx
  00092A60  8b 0d 44 f4 5f 10          mov ecx, dword ptr [0x105ff444]
  00092A66  52                         push edx
  00092A67  50                         push eax
  00092A68  e8 33 e8 0e 00             call 0x101812a0
  00092A6D  3c 01                      cmp al, 1
  00092A6F  75 48                      jne 0x10092ab9
  00092A71  8b 4c 24 04                mov ecx, dword ptr [esp + 4]
  00092A75  89 4e 08                   mov dword ptr [esi + 8], ecx
  00092A78  eb 3f                      jmp 0x10092ab9

````

### F.2 create path: first xref attempt (0 refs; superseded by F.3)

`xref.py --to 0xC525E` (the ctor func that installs the actor vtable at all four 0xC525E sites and
does `mov [ebx+0xA0], esi` @0xC5783):

````text

references to 0xC525E (func 0xC525E): 0

````
```

Same result for the ActionTimer2=1800 setter (func 0xA4110, p1.md §5), which also had 0 direct
callers:

````text

references to 0xA4110 (func 0xA4110): 0

````
```

Conclusion: these hot functions are reached via **virtual calls / pointer tables**, not direct `call`
instructions, direct-call xrefs undercount. Next cheapest alternatives (not yet run): `xref.py --imm`
on the vtable VA variants, `--disp 0xA0`, or walk callers of the funcs containing the six
vtable-install sites (they are all inside 0xC525E/0xC59C0/0xC5B71 themselves, find *their* callers).

### F.3 xref re-run: the targets were mid-function addresses (F34)

The "next cheapest alternatives" above were run in the follow-up session; they also explain why every
F.2 probe returned 0: each `--to` target is an address that is **never a direct call/jmp target** , 
either a mid-function entry into a larger func, or a function start merged with a preceding registrar
func. Corrected re-runs (verbatim scanner output in §C.8-§C.11 of mob_evidence_2_entity_update.md and `out2/x_*.md`):

| Probe | Result |
|---|---|
| `--to 0x8F750`, true start of the entity-update routine (§C.5) | **6** refs: per-frame flush loop @0x95050/0x95A74/0x95B06/0x95BC7/0x95D4C/0x95DC7 (§C.8) |
| `--to 0xC56F0`, mid-function entry into ctor func 0xC525E | **3** refs: @0x8F965 + @0x8F992 (entity-update routine create dispatch, §C.6/§C.9) and @0xD71F4 in func 0xD710D (§C.9) |
| `--to 0xC5890`, second mid-function entry into 0xC525E | **2** refs: @0x8F9C9 (entity-update routine) + @0xD7229 in func 0xD710D (§C.9) |
| `--to 0xA4150`, true start of the ActionTimer2=1800 setter (0xA4110 is a merged-in registrar func, §C.10) | **5** callers: @0x83317/0xA8F3C/0xA8F67/0xA9361/0xA938C (§C.10) |
| `--to 0x92910`, destroy entry inside func 0x928A3 | **23** call sites (flush-loop family, zone-wide sweeps, entity-table sweeps; §C.11) |
| still 0: `--to 0x908EC`, `--to 0xC525E`, `--to 0xA4110` | as expected, none of these is a direct-call target (mid-function / merged-registrar addresses) |

Also run, per F33's suggested alternatives: `--imm 0x10330F40` = **6** refs, exactly the six known
vtable-install sites (no other immediate uses); `--disp 0xA0 --size 4` = **1036** sites / **532** funcs
(too noisy; top consumer func 0x92A7A with 26 sites sits right after the destroy func).

## §G. Live session, wormwatch_20260908_231759.log: routine records + combat crawls (F46-F49)

Log: local untracked wormwatch log `wormwatch_20260908_231759.log` (3526 lines, v0.4,
FFXiMain.dll base this session 0x03DF0000). Three Carrion Worms locked at f328: idx 100 (entity
0x29120B10), 101 (0x2911F680), 102 (0x29120820). One wormwatch frame = ~34.5 ms.

### G.1 Routine records at dispatch (F46)

Dig, worm 101, f6473 (sub=1 packet at f6472). First node SCH=0x2911A174 (vtable rva 0x32BB38);
crawl of its +0x118 and +0x114 pointers, verbatim:

```
[f6473] CRWL idx=101 SCH=0x2911A174 +118 -> 0x261280A0 fourccs[+010=init +038=sp1?]
 +000=00000201 +004=00000000 +008=0000045F +00C=00000000 +010=74696E69 +014=291B953C +018=0000031F +01C=00700000
 +020=00000000 +024=00000307 +028=00700000 +02C=00000000 +030=00000A05 +034=00640010 +038=3F317073 +03C=00000000
 +040=3F800000 +044=3F800000 +048=00000028 +04C=00010028 +050=00000000 +054=00000000 +058=0000080A +05C=00000000
 +060=35323037 +064=291B9634 +068=00000000 +06C=00000000 +070=00000000 +074=00000000 +078=00000402 +07C=00360000
[f6473] CRWL idx=101 SCH=0x2911A174 +114 -> 0x261280F8 fourccs[+028=kak0 +038=mok0 +048=mok1 +058=dis0]
 +000=0000080A +004=00000000 +008=35323037 +00C=291B9634 +010=00000000 +014=00000000 +018=00000000 +01C=00000000
 +020=00000402 +024=00360000 +028=306B616B +02C=291B94BC +030=00000402 +034=0037002C +038=306B6F6D +03C=291B94B4
 +040=00000402 +044=00120008 +048=316B6F6D +04C=291B94C4 +050=00000402 +054=0019002C +058=30736964 +05C=291B94B8
 +060=00000429 +064=00000000 +068=00808080 +06C=00000000 +070=00000200 +074=00000000 +078=00000100 +07C=00000000
```

0x261280F8 = 0x261280A0 + 0x58, so the second dump continues the first. Parsed as a stage stream
(low byte = type, high byte = length in dwords):

| off | header | type | payload |
|---|---|---|---|
| +000 | 0x0201 | 0x01 record header | (1 dw) |
| +008 | 0x045F | 0x5F sibling xref | +010 = 'init' (the *other* routine), +014 ptr |
| +018 | 0x031F | 0x1F ? | 0x00700000, 0 |
| +024 | 0x0307 | 0x07 ? | 0x00700000, 0 |
| +030 | 0x0A05 | 0x05 motion | +034 = 0x00640010, **+038 = 'sp1?'**, +040/+044 = 1.0f, +048 = 0x28, +04C = 0x00010028 |
| +058 | 0x080A | 0x0A sound | +05C = 0, **+060 = '7025'**, +064 ptr |
| +078 | 0x0402 | 0x02 VFX | +07C = 0x00360000, **+080 = 'kak0'**, +084 ptr (generator) |
| +088 | 0x0402 | 0x02 VFX | 0x0037002C, **'mok0'**, ptr |
| +098 | 0x0402 | 0x02 VFX | 0x00120008, **'mok1'**, ptr |
| +0A8 | 0x0402 | 0x02 VFX | 0x0019002C, **'dis0'**, ptr |
| +0B8 | 0x0429 | 0x29 ? | 0, 0x00808080, 0 |

= the DAT's `ini1` (dig) routine exactly (companion doc §8: Motion sp1? + kak0/mok0/mok1/dis0 + 7025).

Pop, worm 100, f4382 (new actor at f4380). First node SCH=0x2911BF34; the +0x114 pointer lands
mid-record:

```
[f4382] CRWL idx=100 SCH=0x2911BF34 +114 -> 0x261282F0 fourccs[+028=mok1 +038=sp0? +060=kak1]
 +000=0000080A +004=00000005 +008=34323037 +00C=291B9630 +010=00000000 +014=00000000 +018=00000000 +01C=00000000
 +020=00000402 +024=006C0001 +028=316B6F6D +02C=291B94C4 +030=00000A05 +034=00960002 +038=3F307073 +03C=00000000
 +040=3F800000 +044=3F800000 +048=00000000 +04C=00010028 +050=00000000 +054=00000000 +058=00000402 +05C=00080000
 +060=316B616B +064=291B94C0 +068=00000429 +06C=00080007 +070=80808080 +074=00000000 +078=00000402 +07C=005A0002
```

| off | header | type | payload |
|---|---|---|---|
| +000 | 0x080A | 0x0A sound | +004 = 5, **+008 = '7024'** |
| +020 | 0x0402 | 0x02 VFX | 0x006C0001, **'mok1'** |
| +030 | 0x0A05 | 0x05 motion | 0x00960002, **'sp0?'**, 1.0f, 1.0f, 0, 0x00010028 |
| +058 | 0x0402 | 0x02 VFX | 0x00080000, **'kak1'** |
| +068 | 0x0429 | 0x29 ? | 0x00080007, 0x80808080, 0 |
| +078 | 0x0402 | 0x02 VFX | 0x005A0002, (name beyond dump) |

= the DAT's `init` (pop) routine (Motion sp0? + dis0/mok1/kak1/kak0/mok0 + 7024). F22's record
(`+010='ini1' +028=0x402 +030='dis0' +038=0x307 +050=0x80A +054=5 +058='7024' +070=0x402 +078='mok1'`)
is this same routine seen from its header: +010 was the 0x5F xref to `ini1`, and 7024 with +4 = 5
is the pop sound stage. F22's name attribution is withdrawn in F46.

Timing words (second dword of VFX stages), high u16 read as a frame: dig kak0 @54, mok0 @55,
mok1 @18, dis0 @25 (clip sp10 = 112 frames, F20); pop kak1 @8, mok1 @108, next @90 (sp00 = 186).
Motion stage +4: dig 0x00640010, pop 0x00960002 (meaning open). The generator pointers
(0x291B94B4..C4) were not crawled this session.

### G.2 Combat crawls (F49), worm 102, f5196-f6240

Routine starts (actor +0x68 0 -> node) and the fourccs found by the same-frame crawl:

```
f5196  +070=run2 | +008=skaz +018=dada | +010=at2? +054=skaz +064=dada | +004=main   (first player hit; lock 15 frames)
f5207  node 0x290F6854 (vtable rva 0x32B844) -> +058 -> 0x261276A0: +010=0000080A +018='dam4' +030=0000080A +038='dam3' ... +058='dam2'
f5220  +030=atk4 +050=atk3 +070=atk2                                                (lock 14 frames)
f5253  +038=FjCA +05C=IIIK | (+1) run2 / run1
f5381  +004=main | (+1) +03C=run2 +0EC=eye3 +108=Zovr +10C=iace                       (lock 29 frames)
f5494  +004=main +018=ev01                                                            (lock 30)
f5597  +004=main +064=main                                                            (lock 31)
f5729  +004=main +04C=main                                                            (lock 30)
f5841  +004=main +01C=main +064=main | +054=sb00                                      (lock 29)
f5897  +01C=hit1 | +00C=hit1
f5948  (lock 33)   f6102 (lock 31)   f6211 (lock 24; ActionTimer1 reached 2 at f6218)
f6232  death packet anim=3; lock f6235-f6240 (22 frames incl. the overlapping one)
```

The `dam2`/`dam3`/`dam4` record is entirely 0x080A (sound) stages, i.e. damage-reaction sound sets;
`atk2-4`, `at2?`, `hit1` are routine/clip-name families that the burrow sessions never touched.
Attribution of each lock to "player hit" vs "worm swing" needs the 0x28 action packets, which
wormwatch does not log yet (v0.5 item).

### G.3 Entity flag timeline (F47/F48/F49), condensed

```
f328   SNAP idx=100: RF0=0x00C06000[status=3 actor=0] RF1=0x0200055A[subA=5] RF4=0x00000080 ActionTimer2=17096 ActorPointer=0
f1636  PKT 102 mask=0x04 status=1 sub=1        f1637 ENT RF1 ...800->...012[subA=1] RF2 A0020001->A0020011 RF4 +0x80 AT1 0->1
f1693  ENT 102 AT1 1->0 (56 frames)            f1732 PKT status=3   f1733 ENT RF0 00402200->00C16000 RF1 ...012->...112 actor->0
f2102  PKT 102 mask=0x05 status=1 sub=1        f2103 ENT RF0 ->00402200 RF1 ...112->...180[subA=0] RF2 ->00020001 actor=new
f2105  ENT 102 RF1 ...180->...800 RF2 ->A0020001 AT1 0->1   f2172 PKT sub=0 -> RF4 -0x80 only   f2199 AT1 1->0 (94 frames)
f2462  PKT 100 mask=0x05 status=1 sub=1        f2463 ENT RF0 00C06000->00402200 RF1 ...55A[subA=5]->...180[subA=0] actor=new
f2465  ENT 100 AT1 0->1 AT2 17096->1798         f2534 PKT sub=0 (no-op)   f2559 AT1 1->0 (94)
f5203  PKT 102 mask=0x06 anim=1 -> StatusServer 0->1, HP 100->24, RF3 |0x10000000; f5211 Status 0->1
f6232  PKT 102 mask=0x06 anim=3 -> StatusServer 1->3, HP 0, RF3 |0x10000000; f6240 Status 1->3, RF3 bit cleared
f6762  PKT 102 status=2 mask=0x30 size=72 -> UpdateMask 0x0F->0x00, RF0 00402200->00406000, RF1 ...800->...1800->...1000, actor->0
```

---

### G.4 Fourth session (wormwatch_20260909_000019.log, v0.5): action packets vs actor locks (F50-F53)

Log: 13095 lines, FFXiMain.dll base 0x042E0000, Forest Hares idx 94/95/96/97/99/190 locked (94 and 97
fought). 98 `ACTN` lines. The 32 bits at bit 86 of every category-1 packet are 0x306B7461 ('atk0'),
of every category-7 packet 0x65746163 ('cate'); category 11 carries the mob skill id there (259).

Representative rows (packet frame -> actor lock start/end, crawled fourccs in the same frames):

```
melee (hare 97 as actor, react 8 hit):   f2413 -> AT1 f2414..f2440 (26)  crawl f2415 +050=at00
melee (hare 94, react 8):                f2513 -> AT1 f2514..f2538 (24)  crawl f2514 +05C=at10
melee (hare 94, react 8):                f2630 -> AT1 f2631..f2656 (25)  crawl f2632 +050=at20
melee (hare 97, react 9 miss):           f1015 -> AT1 f1016..f1041 (25)  crawl f1017 +010=at1? +054=aloc +064=skaz
melee (hare 97, react 8, param 4):       f4539 -> AT1 f4540..f4564 (24)  crawl f4540 +03C=at20
player hits hare 94 (2 results):         f1986 -> hare AT1 f1987..f2002 (15)  = damage reaction
player hits hare 94 (miss + hit):        f6155 -> hare AT1 f6156..f6171 (15)  crawl f6156 +0BC=btl1 +13C=btl0 +030=at21
ws-start hare 94 (cat 7, param 259):     f6162 -> no lock, no new node; crawl f6167 +018=swy3 +038=swy2 +058=swy1
mobskill hare 94 (cat 11, anim 3):       f6177 -> AT1 0->2 f6178, 2->3 f6180, 3->2 f6194, 2->0 f6218 (40)
                                                  crawl f6178 +050=wz60, f6180 motion node +03C=sp10
mobskill hare 97 (cat 11, anim 3):       f6184 -> AT1 1->3 f6185, 3->2 f6189, 2->0 f6225 (41)  crawl f6189 +010=stnm
mobskill hare 97 (first, f2887):         f2887 -> AT1 1->2 f2888, 2->1 f2889, 1->2 f2891, 2->0 f2931 (44)
engage hare 94:  PKT f1994 mask 0x06 anim=1 -> StatusServer 0->1 f1995, Status 0->1 f2002, lock f2011..f2025 (14) no packet
death hare 94:   player WS f6252 -> AT1 0->1 f6253; StatusServer 1->3 f6260 (HP 0); Status 1->3 + AT1 1->0 f6306 (53)
death hare 97:   player melee f6677 -> AT1 0->2 f6678; StatusServer 1->3 f6678; 2->1 f6689; Status 1->3 + AT1 1->0 f6706 (28)
view-range:      hare 94 f992 UpdateMask 0x0F->0x00 RF0->0x00406000 actor 0; f1085 back: UpdateMask 0x0F, RF0 0x00402200,
                 new actor, RF2 A0020001 -> 00020001 -> A0020001 (f1087) = init replay
```

Melee lock lengths over all 80 mob melee rounds: 24, 25 or 26 frames, independent of hit/miss and
of which at?? clip was chosen. Result-field vocabulary seen: react {8, 9, 24}, anim {0, 1, 3, 16},
eff {0, 32, 34, 64, 65, 66, 96, 97}, msg {1, 15, 43, 67, 185}.

## §H. On-disk mob DAT dump (F54): `dat_routines.py` on 5.DAT ('drak'), 11.DAT ('grif'), 32.DAT (PC-type)

Raw bytes of the `vdam`, `atk0`, `dead`, `init`, `cate`, `sway` chunks of 5.DAT were read by hand first
(chunk header at +0, pointers at +0x20/+0x24/+0x28, stream from +0x50, type-0 end header); the tool
output below is the parse of every routine in 5.DAT. 11.DAT differs only by five routines
(`cnf0 cni0 cnt0 paly shld` present, `pary` absent) and 32.DAT is a five-section PC-type file
(`skel mdl_ skl_ sep_ wep_`) with the same 36 routine names, a `swor` skeleton and an `ma10` clip.

#### dat_routines dump of /mnt/user-data/uploads/5.DAT (1 files considered)

#### /mnt/user-data/uploads/5.DAT  (164944 bytes, 78 chunks, 35 routines)

chunk types: 0x00 x1, 0x01 x1, 0x07 x36, 0x20 x1, 0x29 x1, 0x2A x1, 0x2B x17, 0x3D x19, 0x45 x1

type 0x01 marker           (1): drak
type 0x07 routines         (36): vdam vatk shso shit shnj shsm shbk shwh chit sway vded vswy corp caso atf0 ati2 ati1 ati0 shot cait canj casm cawh cabk cast dead pop0 init cate ntob ldam atk0 sdam damg gurd pary
type 0x20 skeleton         (1): bat 
type 0x29 skeleton-adjacent (1): bat 
type 0x2A meshes           (1): hh_1
type 0x2B motion clips     (17): at00 run0 idl0 gud0 dfm1 dfi0 ded0 dbm1 dbi0 cor0 btl0 at20 at10 wlk0 ma00 ma20 atm0
type 0x3D sound samples    (19): sdam skaz shit idl1 idl2 atk1 atk2 atk3 atk4 dam1 dam2 dam3 dam4 swy1 swy2 swy3 ded1 ded2 ded3
type 0x45 info             (1): info

##### routine `vdam`  chunk type 0x07 @0x20 len 0x120, stream @+0x50 (11 stages, 184/272 body bytes)
    hdr       (2 dw) 00 00 00 00
    grp-begin (2 dw) 01 00 00 00
    sound dam4  (dat-sound) flag=0x0
    sound dam3  (dat-sound) flag=0x0
    sound dam2  (dat-sound) flag=0x0
    grp-sep   (2 dw) 00 00 00 00
    grp-sep   (2 dw) 00 00 00 00
    grp-sep   (2 dw) 00 00 00 00
    sound dam1  (dat-sound) flag=0x1
    grp-end   (2 dw) 00 00 00 00
    end

##### routine `vatk`  chunk type 0x07 @0x140 len 0x120, stream @+0x50 (11 stages, 184/272 body bytes)
    hdr       (2 dw) 00 00 00 00
    grp-begin (2 dw) 01 00 00 00
    grp-sep   (2 dw) 00 00 00 00
    grp-sep   (2 dw) 00 00 00 00
    grp-sep   (2 dw) 00 00 00 00
    sound atk4  (dat-sound) flag=0x0
    sound atk3  (dat-sound) flag=0x0
    sound atk2  (dat-sound) flag=0x0
    sound atk1  (dat-sound) flag=0x1
    grp-end   (2 dw) 00 00 00 00
    end

##### routine `shso`  chunk type 0x07 @0x260 len 0xB0, stream @+0x50 (6 stages, 80/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   eis6  at=0 (timing 0x00000000)
    call   stso  at=0 (timing 0x00000000)
    call   shot  at=1 (timing 0x00000001)
    ref3B  waso  at=0 (timing 0x00000000)
    end

##### routine `shit`  chunk type 0x07 @0x310 len 0x90, stream @+0x50 (4 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   shot  at=1 (timing 0x00000001)
    ref3B  wash  at=0 (timing 0x00000000)
    end

##### routine `shnj`  chunk type 0x07 @0x3A0 len 0xB0, stream @+0x50 (6 stages, 80/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   ner3  at=0 (timing 0x00000000)
    call   stnj  at=0 (timing 0x00000000)
    call   shot  at=1 (timing 0x00000001)
    ref3B  wash  at=0 (timing 0x00000000)
    end

##### routine `shsm`  chunk type 0x07 @0x450 len 0xB0, stream @+0x50 (6 stages, 80/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   eis2  at=0 (timing 0x00000000)
    call   stsm  at=0 (timing 0x00000000)
    call   shot  at=1 (timing 0x00000001)
    ref3B  wash  at=0 (timing 0x00000000)
    end

##### routine `shbk`  chunk type 0x07 @0x500 len 0xB0, stream @+0x50 (6 stages, 80/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   stbk  at=0 (timing 0x00000000)
    call   eis3  at=0 (timing 0x00000000)
    call   shot  at=1 (timing 0x00000001)
    ref3B  wash  at=0 (timing 0x00000000)
    end

##### routine `shwh`  chunk type 0x07 @0x5B0 len 0xB0, stream @+0x50 (6 stages, 80/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   stwh  at=0 (timing 0x00000000)
    call   eis4  at=0 (timing 0x00000000)
    call   shot  at=1 (timing 0x00000001)
    ref3B  wash  at=0 (timing 0x00000000)
    end

##### routine `chit`  chunk type 0x07 @0x660 len 0xA0, stream @+0x50 (4 stages, 64/144 body bytes)
    hdr       (2 dw) 00 00 00 00
    sound shit  (dat-sound) flag=0x0
    call   hit2  at=0 (timing 0x00000000)
    end

##### routine `sway`  chunk type 0x07 @0x700 len 0x80, stream @+0x50 (3 stages, 32/112 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   vswy  at=0 (timing 0x00000000)
    end

##### routine `vded`  chunk type 0x07 @0x780 len 0xE0, stream @+0x50 (7 stages, 128/208 body bytes)
    hdr       (2 dw) 00 00 00 00
    grp-begin (2 dw) 01 00 00 00
    sound ded3  (dat-sound) flag=0x0
    sound ded2  (dat-sound) flag=0x0
    sound ded1  (dat-sound) flag=0x1
    grp-end   (2 dw) 00 00 00 00
    end

##### routine `vswy`  chunk type 0x07 @0x860 len 0xE0, stream @+0x50 (7 stages, 128/208 body bytes)
    hdr       (2 dw) 00 00 00 00
    grp-begin (2 dw) 01 00 00 00
    sound swy3  (dat-sound) flag=0x0
    sound swy2  (dat-sound) flag=0x0
    sound swy1  (dat-sound) flag=0x1
    grp-end   (2 dw) 00 00 00 00
    end

##### routine `corp`  chunk type 0x07 @0x940 len 0xA0, stream @+0x50 (3 stages, 56/144 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion cor?  frames=2 lo=2 (0x00020002)
    end

##### routine `caso`  chunk type 0x07 @0x9E0 len 0x90, stream @+0x50 (4 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   ner5  at=0 (timing 0x00000000)
    call   cast  at=0 (timing 0x00000000)
    end

##### routine `atf0`  chunk type 0x07 @0xA70 len 0xE0, stream @+0x50 (7 stages, 124/208 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion atm?  frames=32 lo=0 (0x00200000)
    unk59     (2 dw) 00 00 16 00
    unk20     (3 dw) 00 00 10 00 00 00 00 00
    sound skaz  (dat-sound) flag=0xC
    call   dada  at=20 (timing 0x00000014)
    end

##### routine `ati2`  chunk type 0x07 @0xB50 len 0x100, stream @+0x50 (9 stages, 148/240 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion at2?  frames=72 lo=0 (0x00480000)
    unk2F     (2 dw) 00 00 38 00
    unk59     (2 dw) 00 00 38 00
    call   aloc  at=0 (timing 0x00000000)
    unk20     (3 dw) 18 00 28 00 00 00 00 00
    sound skaz  (dat-sound) flag=0xC
    call   dada  at=36 (timing 0x00000024)
    end

##### routine `ati1`  chunk type 0x07 @0xC50 len 0x100, stream @+0x50 (9 stages, 148/240 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion at1?  frames=60 lo=0 (0x003C0000)
    unk59     (2 dw) 00 00 34 00
    unk2F     (2 dw) 00 00 34 00
    call   aloc  at=0 (timing 0x00000000)
    unk20     (3 dw) 14 00 20 00 00 00 00 00
    sound skaz  (dat-sound) flag=0x8
    call   dada  at=32 (timing 0x00000020)
    end

##### routine `ati0`  chunk type 0x07 @0xD50 len 0x100, stream @+0x50 (9 stages, 148/240 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion at0?  frames=75 lo=0 (0x004B0000)
    call   aloc  at=0 (timing 0x00000000)
    unk2F     (2 dw) 00 00 38 00
    unk59     (2 dw) 00 00 38 00
    unk20     (3 dw) 18 00 26 00 00 00 00 00
    sound skaz  (dat-sound) flag=0xA
    call   dada  at=41 (timing 0x00000029)
    end

##### routine `shot`  chunk type 0x07 @0xE50 len 0xB0, stream @+0x50 (4 stages, 72/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   mloc  at=60 (timing 0x0000003C)
    motion ma2?  frames=36 lo=120 (0x00240078)
    end

##### routine `cait`  chunk type 0x07 @0xF00 len 0x80, stream @+0x50 (3 stages, 32/112 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   cast  at=0 (timing 0x00000000)
    end

##### routine `canj`  chunk type 0x07 @0xF80 len 0x90, stream @+0x50 (4 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   sei5  at=0 (timing 0x00000000)
    call   cast  at=0 (timing 0x00000000)
    end

##### routine `casm`  chunk type 0x07 @0x1010 len 0x90, stream @+0x50 (4 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   ner4  at=0 (timing 0x00000000)
    call   cast  at=0 (timing 0x00000000)
    end

##### routine `cawh`  chunk type 0x07 @0x10A0 len 0x90, stream @+0x50 (4 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   ner2  at=0 (timing 0x00000000)
    call   cast  at=0 (timing 0x00000000)
    end

##### routine `cabk`  chunk type 0x07 @0x1130 len 0x90, stream @+0x50 (4 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   ner1  at=0 (timing 0x00000000)
    call   cast  at=0 (timing 0x00000000)
    end

##### routine `cast`  chunk type 0x07 @0x11C0 len 0xA0, stream @+0x50 (3 stages, 56/144 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion ma0?  frames=48 lo=48 (0x00300030)
    end

##### routine `dead`  chunk type 0x07 @0x1260 len 0xF0, stream @+0x50 (6 stages, 132/224 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion ded?  frames=60 lo=0 (0x003C0000)
    call   vded  at=38 (timing 0x00000026)
    unk78     (5 dw) 16 00 00 00 00 00 00 00 00 00 00 00 00 00 00 00
    motion cor0  frames=2 lo=2 (0x00020002)
    end

##### routine `pop0`  chunk type 0x07 @0x1350 len 0xB0, stream @+0x50 (6 stages, 76/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    unk29     (4 dw) 02 00 00 00 00 00 00 00 00 00 00 00
    unk28     (3 dw) 02 00 00 00 00 00 00 00
    unk29     (4 dw) 56 00 56 00 80 80 80 80 00 00 00 00
    call   init  at=0 (timing 0x00000000)
    end

##### routine `cate`  chunk type 0x07 @0x1470 len 0x90, stream @+0x50 (4 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   nerm  at=0 (timing 0x00000000)
    call   cast  at=0 (timing 0x00000000)
    end

##### routine `ntob`  chunk type 0x07 @0x1500 len 0x90, stream @+0x50 (3 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    sound idl1  (dat-sound) flag=0x0
    end

##### routine `ldam`  chunk type 0x07 @0x1590 len 0xD0, stream @+0x50 (6 stages, 100/192 body bytes)
    hdr       (2 dw) 00 00 00 00
    ref09  lhit  at=0 (timing 0x00000000)
    call57 sdam  at=0 (timing 0x00000000)
    unk21     (9 dw) 02 00 00 00 00 00 80 3f 00 00 80 3f 02 00 00 00
    call57 vdam  at=0 (timing 0x00000000)
    end

##### routine `atk0`  chunk type 0x07 @0x1660 len 0xA0, stream @+0x50 (6 stages, 64/144 body bytes)
    hdr       (2 dw) 00 00 00 00
    call   hwat  at=0 (timing 0x00000000)
    call57 vatk  at=0 (timing 0x00000000)
    unk24     (2 dw) 01 00 00 00
    unk32     (2 dw) 00 00 00 00
    end

##### routine `sdam`  chunk type 0x07 @0x1700 len 0x90, stream @+0x50 (3 stages, 48/128 body bytes)
    hdr       (2 dw) 00 00 00 00
    sound sdam  (dat-sound) flag=0x0
    end

##### routine `damg`  chunk type 0x07 @0x1790 len 0xD0, stream @+0x50 (6 stages, 100/192 body bytes)
    hdr       (2 dw) 00 00 00 00
    ref09  chit  at=0 (timing 0x00000000)
    call57 sdam  at=0 (timing 0x00000000)
    unk21     (9 dw) 02 00 00 00 00 00 80 3f 00 00 80 3f 02 00 00 00
    call57 vdam  at=0 (timing 0x00000000)
    end

##### routine `gurd`  chunk type 0x07 @0x1860 len 0xB0, stream @+0x50 (4 stages, 72/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    call57 vatk  at=0 (timing 0x00000000)
    motion gud?  frames=2 lo=2 (0x00020002)
    end

##### routine `pary`  chunk type 0x07 @0x1910 len 0xB0, stream @+0x50 (4 stages, 72/160 body bytes)
    hdr       (2 dw) 00 00 00 00
    motion gud?  frames=2 lo=0 (0x00020000)
    call   vswy  at=2 (timing 0x00000002)
    end

11.DAT header section for comparison:

```
# dat_routines dump of /mnt/user-data/uploads/11.DAT (1 files considered)

## /mnt/user-data/uploads/11.DAT  (164480 bytes, 82 chunks, 39 routines)

chunk types: 0x00 x1, 0x01 x1, 0x07 x40, 0x20 x1, 0x29 x1, 0x2A x1, 0x2B x17, 0x3D x19, 0x45 x1

type 0x01 marker           (1): grif
type 0x07 routines         (40): corp caso atf0 ati2 ati1 ati0 shot cait canj casm cawh cabk cast shld dead pop0 init sway vswy vded chit shwh shbk shsm shnj shit shso vatk vdam cnt0 cni0 cnf0 gurd paly cate ntob ldam atk0 sdam damg
type 0x20 skeleton         (1): bat 
type 0x29 skeleton-adjacent (1): bat 
type 0x2A meshes           (1): hh_1
type 0x2B motion clips     (17): at00 run0 idl0 gud0 dfm1 dfi0 ded0 dbm1 dbi0 cor0 btl0 at20 at10 wlk0 ma00 ma20 atm0
type 0x3D sound samples    (19): sdam skaz shit idl1 idl2 atk1 atk2 atk3 atk4 dam1 dam2 dam3 dam4 swy1 swy2 swy3 ded1 ded2 ded3
type 0x45 info             (1): info
```

---
