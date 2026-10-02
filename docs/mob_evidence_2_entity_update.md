# Mob pass evidence 2: the per-entity update routine (§C)

Disassembly dumps backing F28, F34 and F35 in [mob_animation.md](mob_animation.md). Conventions in
[README.md](README.md).

## §C. The per-entity update routine: PopEffect, position sync, create dispatch, flush wrapper

The "PopEffect handler" is not a standalone function; it sits mid-way in the update routine that
C.5 later bounded at rva 0x8F750-0x926C7. C.1-C.3 are consecutive fragments of that routine
(`d_906c0.md` event-driven position sync; `d_90840.md` fragment start @0x90881 and slot +0x3F0
predicate; `d_908ec.md` entity->actor position copies then the PopEffect pop1 branch). C.4 supplies
the pop0 block that `disasm.py --func 0x908EC` stopped short of. Decode: F28 (PopEffect), F35
(boundaries, create dispatch, flush wrapper, angle wrap, +0x12C writers), F34 (xrefs).

### C.1 fragment @ rva 0x906C0-0x9087C (`out2/d_906c0.md`)

````text

  000906C1  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  000906C7  df e0                      fnstsw ax
  000906C9  f6 c4 05                   test ah, 5
  000906CC  7a 0a                      jp 0x100906d8
  000906CE  d9 07                      fld dword ptr [edi]
  000906D0  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  000906D6  d9 1f                      fstp dword ptr [edi]
  000906D8  d9 45 48                   fld dword ptr [ebp + 0x48]
  000906DB  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  000906E1  df e0                      fnstsw ax
  000906E3  25 00 41 00 00             and eax, 0x4100
  000906E8  75 0c                      jne 0x100906f6
  000906EA  d9 45 48                   fld dword ptr [ebp + 0x48]
  000906ED  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  000906F3  d9 5d 48                   fstp dword ptr [ebp + 0x48]
  000906F6  d9 45 48                   fld dword ptr [ebp + 0x48]
  000906F9  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  000906FF  df e0                      fnstsw ax
  00090701  f6 c4 05                   test ah, 5
  00090704  7a 0c                      jp 0x10090712
  00090706  d9 45 48                   fld dword ptr [ebp + 0x48]
  00090709  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  0009070F  d9 5d 48                   fstp dword ptr [ebp + 0x48]
  00090712  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090715  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  0009071B  df e0                      fnstsw ax
  0009071D  25 00 41 00 00             and eax, 0x4100
  00090722  75 0c                      jne 0x10090730
  00090724  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090727  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  0009072D  d9 5d 4c                   fstp dword ptr [ebp + 0x4c]
  00090730  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090733  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  00090739  df e0                      fnstsw ax
  0009073B  f6 c4 05                   test ah, 5
  0009073E  7a 0c                      jp 0x1009074c
  00090740  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090743  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  00090749  d9 5d 4c                   fstp dword ptr [ebp + 0x4c]
  0009074C  8b 86 d4 00 00 00          mov eax, dword ptr [esi + 0xd4]
  00090752  8b 90 5c 02 00 00          mov edx, dword ptr [eax + 0x25c]
  00090758  8b 88 60 02 00 00          mov ecx, dword ptr [eax + 0x260]
  0009075E  3b d1                      cmp edx, ecx
  00090760  0f 84 94 02 00 00          je 0x100909fa
  00090766  33 c9                      xor ecx, ecx
  00090768  66 8b 48 02                mov cx, word ptr [eax + 2]
  0009076C  8b 0c 8d 30 0b 48 10       mov ecx, dword ptr [ecx*4 + 0x10480b30]
  00090773  85 c9                      test ecx, ecx
  00090775  0f 84 7f 02 00 00          je 0x100909fa
  0009077B  8b 89 a0 00 00 00          mov ecx, dword ptr [ecx + 0xa0]   ; ent.ActorPointer?
  00090781  85 c9                      test ecx, ecx
  00090783  0f 84 71 02 00 00          je 0x100909fa
  00090789  8b 90 60 02 00 00          mov edx, dword ptr [eax + 0x260]
  0009078F  83 c1 34                   add ecx, 0x34
  00090792  81 c2 40 01 00 00          add edx, 0x140
  00090798  52                         push edx
  00090799  51                         push ecx
  0009079A  e8 01 67 f9 ff             call 0x10026ea0
  0009079F  8b 86 d4 00 00 00          mov eax, dword ptr [esi + 0xd4]
  000907A5  33 c9                      xor ecx, ecx
  000907A7  66 8b 48 02                mov cx, word ptr [eax + 2]
  000907AB  8b 80 60 02 00 00          mov eax, dword ptr [eax + 0x260]
  000907B1  05 50 01 00 00             add eax, 0x150
  000907B6  8b 14 8d 30 0b 48 10       mov edx, dword ptr [ecx*4 + 0x10480b30]
  000907BD  50                         push eax
  000907BE  8b aa a0 00 00 00          mov ebp, dword ptr [edx + 0xa0]   ; ent.ActorPointer?
  000907C4  8d 7d 44                   lea edi, [ebp + 0x44]
  000907C7  57                         push edi
  000907C8  e8 d3 66 f9 ff             call 0x10026ea0
  000907CD  d9 07                      fld dword ptr [edi]
  000907CF  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  000907D5  83 c4 10                   add esp, 0x10
  000907D8  df e0                      fnstsw ax
  000907DA  25 00 41 00 00             and eax, 0x4100
  000907DF  75 0a                      jne 0x100907eb
  000907E1  d9 07                      fld dword ptr [edi]
  000907E3  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  000907E9  d9 1f                      fstp dword ptr [edi]
  000907EB  d9 07                      fld dword ptr [edi]
  000907ED  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  000907F3  df e0                      fnstsw ax
  000907F5  f6 c4 05                   test ah, 5
  000907F8  7a 0a                      jp 0x10090804
  000907FA  d9 07                      fld dword ptr [edi]
  000907FC  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  00090802  d9 1f                      fstp dword ptr [edi]
  00090804  d9 45 48                   fld dword ptr [ebp + 0x48]
  00090807  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  0009080D  df e0                      fnstsw ax
  0009080F  25 00 41 00 00             and eax, 0x4100
  00090814  75 0c                      jne 0x10090822
  00090816  d9 45 48                   fld dword ptr [ebp + 0x48]
  00090819  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  0009081F  d9 5d 48                   fstp dword ptr [ebp + 0x48]
  00090822  d9 45 48                   fld dword ptr [ebp + 0x48]
  00090825  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  0009082B  df e0                      fnstsw ax
  0009082D  f6 c4 05                   test ah, 5
  00090830  7a 0c                      jp 0x1009083e
  00090832  d9 45 48                   fld dword ptr [ebp + 0x48]
  00090835  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  0009083B  d9 5d 48                   fstp dword ptr [ebp + 0x48]
  0009083E  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090841  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  00090847  df e0                      fnstsw ax
  00090849  25 00 41 00 00             and eax, 0x4100
  0009084E  75 0c                      jne 0x1009085c
  00090850  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090853  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  00090859  d9 5d 4c                   fstp dword ptr [ebp + 0x4c]
  0009085C  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  0009085F  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  00090865  df e0                      fnstsw ax
  00090867  f6 c4 05                   test ah, 5
  0009086A  0f 8a 8a 01 00 00          jp 0x100909fa
  00090870  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090873  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  00090879  d9 5d 4c                   fstp dword ptr [ebp + 0x4c]
  0009087C  e9 79 01 00 00             jmp 0x100909fa

````

### C.2 fragment @ rva 0x90841-0x9090E, incl. routine start 0x90881 (`out2/d_90840.md`)

````text

  00090841  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  00090847  df e0                      fnstsw ax
  00090849  25 00 41 00 00             and eax, 0x4100
  0009084E  75 0c                      jne 0x1009085c
  00090850  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090853  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  00090859  d9 5d 4c                   fstp dword ptr [ebp + 0x4c]
  0009085C  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  0009085F  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  00090865  df e0                      fnstsw ax
  00090867  f6 c4 05                   test ah, 5
  0009086A  0f 8a 8a 01 00 00          jp 0x100909fa
  00090870  d9 45 4c                   fld dword ptr [ebp + 0x4c]
  00090873  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  00090879  d9 5d 4c                   fstp dword ptr [ebp + 0x4c]
  0009087C  e9 79 01 00 00             jmp 0x100909fa
  00090881  85 c9                      test ecx, ecx
  00090883  0f 85 71 01 00 00          jne 0x100909fa
  00090889  a9 00 00 10 00             test eax, 0x100000
  0009088E  0f 85 8f 00 00 00          jne 0x10090923
  00090894  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0009089A  8b 11                      mov edx, dword ptr [ecx]
  0009089C  ff 92 f0 03 00 00          call dword ptr [edx + 0x3f0]
  000908A2  3c 01                      cmp al, 1
  000908A4  75 7d                      jne 0x10090923
  000908A6  8b 46 08                   mov eax, dword ptr [esi + 8]
  000908A9  8b 56 08                   mov edx, dword ptr [esi + 8]
  000908AC  8b 4e 0c                   mov ecx, dword ptr [esi + 0xc]
  000908AF  89 44 24 14                mov dword ptr [esp + 0x14], eax
  000908B3  8b 46 04                   mov eax, dword ptr [esi + 4]
  000908B6  3b fe                      cmp edi, esi
  000908B8  89 54 24 1c                mov dword ptr [esp + 0x1c], edx
  000908BC  75 2e                      jne 0x100908ec
  000908BE  89 4c 24 18                mov dword ptr [esp + 0x18], ecx
  000908C2  8d 4c 24 14                lea ecx, [esp + 0x14]
  000908C6  8b 54 24 18                mov edx, dword ptr [esp + 0x18]
  000908CA  89 44 24 20                mov dword ptr [esp + 0x20], eax
  000908CE  8b 44 24 1c                mov eax, dword ptr [esp + 0x1c]
  000908D2  51                         push ecx
  000908D3  8b 4c 24 24                mov ecx, dword ptr [esp + 0x24]
  000908D7  68 00 00 48 42             push 0x42480000
  000908DC  52                         push edx
  000908DD  50                         push eax
  000908DE  51                         push ecx
  000908DF  8b 0d 44 f4 5f 10          mov ecx, dword ptr [0x105ff444]
  000908E5  e8 b6 09 0f 00             call 0x101812a0
  000908EA  eb 27                      jmp 0x10090913
  000908EC  89 4c 24 20                mov dword ptr [esp + 0x20], ecx
  000908F0  8b 54 24 20                mov edx, dword ptr [esp + 0x20]
  000908F4  8d 4c 24 14                lea ecx, [esp + 0x14]
  000908F8  89 44 24 18                mov dword ptr [esp + 0x18], eax
  000908FC  8b 44 24 1c                mov eax, dword ptr [esp + 0x1c]
  00090900  51                         push ecx
  00090901  8b 4c 24 1c                mov ecx, dword ptr [esp + 0x1c]
  00090905  52                         push edx
  00090906  50                         push eax
  00090907  51                         push ecx
  00090908  8b 0d 44 f4 5f 10          mov ecx, dword ptr [0x105ff444]
  0009090E  e8 fd 09 0f 00             call 0x10181310

````

### C.3 fragment @ rva 0x908EC-0x90A5B, PopEffect pop1 branch (`out2/d_908ec.md`)

````text

; func 0x908EC..0x90A5B (367 bytes), callers: 0
  000908EC  89 4c 24 20                mov dword ptr [esp + 0x20], ecx
  000908F0  8b 54 24 20                mov edx, dword ptr [esp + 0x20]
  000908F4  8d 4c 24 14                lea ecx, [esp + 0x14]
  000908F8  89 44 24 18                mov dword ptr [esp + 0x18], eax
  000908FC  8b 44 24 1c                mov eax, dword ptr [esp + 0x1c]
  00090900  51                         push ecx
  00090901  8b 4c 24 1c                mov ecx, dword ptr [esp + 0x1c]
  00090905  52                         push edx
  00090906  50                         push eax
  00090907  51                         push ecx
  00090908  8b 0d 44 f4 5f 10          mov ecx, dword ptr [0x105ff444]
  0009090E  e8 fd 09 0f 00             call 0x10181310
  00090913  3c 01                      cmp al, 1
  00090915  75 0c                      jne 0x10090923
  00090917  8b 54 24 14                mov edx, dword ptr [esp + 0x14]
  0009091B  8b c2                      mov eax, edx
  0009091D  89 56 08                   mov dword ptr [esi + 8], edx
  00090920  89 46 28                   mov dword ptr [esi + 0x28], eax
  00090923  8b 96 a0 00 00 00          mov edx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  00090929  8d 4e 04                   lea ecx, [esi + 4]
  0009092C  83 c2 34                   add edx, 0x34
  0009092F  51                         push ecx
  00090930  52                         push edx
  00090931  e8 6a 65 f9 ff             call 0x10026ea0
  00090936  8b be a0 00 00 00          mov edi, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0009093C  8d 46 14                   lea eax, [esi + 0x14]
  0009093F  50                         push eax
  00090940  8d 6f 44                   lea ebp, [edi + 0x44]
  00090943  55                         push ebp
  00090944  e8 57 65 f9 ff             call 0x10026ea0
  00090949  d9 45 00                   fld dword ptr [ebp]
  0009094C  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  00090952  83 c4 10                   add esp, 0x10
  00090955  df e0                      fnstsw ax
  00090957  25 00 41 00 00             and eax, 0x4100
  0009095C  75 0c                      jne 0x1009096a
  0009095E  d9 45 00                   fld dword ptr [ebp]
  00090961  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  00090967  d9 5d 00                   fstp dword ptr [ebp]
  0009096A  d9 45 00                   fld dword ptr [ebp]
  0009096D  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  00090973  df e0                      fnstsw ax
  00090975  f6 c4 05                   test ah, 5
  00090978  7a 0c                      jp 0x10090986
  0009097A  d9 45 00                   fld dword ptr [ebp]
  0009097D  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  00090983  d9 5d 00                   fstp dword ptr [ebp]
  00090986  d9 47 48                   fld dword ptr [edi + 0x48]
  00090989  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  0009098F  df e0                      fnstsw ax
  00090991  25 00 41 00 00             and eax, 0x4100
  00090996  75 0c                      jne 0x100909a4
  00090998  d9 47 48                   fld dword ptr [edi + 0x48]
  0009099B  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  000909A1  d9 5f 48                   fstp dword ptr [edi + 0x48]
  000909A4  d9 47 48                   fld dword ptr [edi + 0x48]
  000909A7  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  000909AD  df e0                      fnstsw ax
  000909AF  f6 c4 05                   test ah, 5
  000909B2  7a 0c                      jp 0x100909c0
  000909B4  d9 47 48                   fld dword ptr [edi + 0x48]
  000909B7  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  000909BD  d9 5f 48                   fstp dword ptr [edi + 0x48]
  000909C0  d9 47 4c                   fld dword ptr [edi + 0x4c]
  000909C3  d8 1d 30 9d 32 10          fcomp dword ptr [0x10329d30]
  000909C9  df e0                      fnstsw ax
  000909CB  25 00 41 00 00             and eax, 0x4100
  000909D0  75 0c                      jne 0x100909de
  000909D2  d9 47 4c                   fld dword ptr [edi + 0x4c]
  000909D5  d8 25 2c 9d 32 10          fsub dword ptr [0x10329d2c]
  000909DB  d9 5f 4c                   fstp dword ptr [edi + 0x4c]
  000909DE  d9 47 4c                   fld dword ptr [edi + 0x4c]
  000909E1  d8 1d 28 9d 32 10          fcomp dword ptr [0x10329d28]
  000909E7  df e0                      fnstsw ax
  000909E9  f6 c4 05                   test ah, 5
  000909EC  7a 0c                      jp 0x100909fa
  000909EE  d9 47 4c                   fld dword ptr [edi + 0x4c]
  000909F1  d8 05 2c 9d 32 10          fadd dword ptr [0x10329d2c]
  000909F7  d9 5f 4c                   fstp dword ptr [edi + 0x4c]
  000909FA  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  00090A00  f6 c4 02                   test ah, 2
  00090A03  0f 84 6a 0c 00 00          je 0x10091673
  00090A09  8a 86 ee 00 00 00          mov al, byte ptr [esi + 0xee]
  00090A0F  3c 03                      cmp al, 3
  00090A11  74 65                      je 0x10090a78
  00090A13  3c 04                      cmp al, 4
  00090A15  74 61                      je 0x10090a78
  00090A17  3c 05                      cmp al, 5
  00090A19  74 5d                      je 0x10090a78
  00090A1B  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  00090A21  e8 ba 08 04 00             call 0x100d12e0
  00090A26  84 c0                      test al, al
  00090A28  74 4e                      je 0x10090a78
  00090A2A  8b ce                      mov ecx, esi
  00090A2C  e8 3f e5 ff ff             call 0x1008ef70
  00090A31  8a 86 44 01 00 00          mov al, byte ptr [esi + 0x144]
  00090A37  84 c0                      test al, al
  00090A39  74 3d                      je 0x10090a78
  00090A3B  3c 03                      cmp al, 3
  00090A3D  74 1c                      je 0x10090a5b
  00090A3F  3c 06                      cmp al, 6
  00090A41  75 2e                      jne 0x10090a71
  00090A43  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  00090A49  6a 00                      push 0
  00090A4B  51                         push ecx
  00090A4C  68 70 6f 70 31             push 0x31706f70   ; 'pop1'
  00090A51  8b 11                      mov edx, dword ptr [ecx]
  00090A53  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  00090A59  eb 16                      jmp 0x10090a71

````

### C.4 the missing pop0 block @ rva 0x90A5B-0x90A78 (from `out2/p1.md` §3, 'pop0' literal context)

````text

  in func 0x90A5B:
  00090A59  eb 16                      jmp 0x10090a71
  00090A5B  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  00090A61  6a 00                      push 0
  00090A63  51                         push ecx
>>00090A64  68 70 6f 70 30             push 0x30706f70   ; 'pop0'
  00090A69  8b 01                      mov eax, dword ptr [ecx]
  00090A6B  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  00090A71  c6 86 44 01 00 00 00       mov byte ptr [esi + 0x144], 0

````

### C.5 true function boundaries @ rva 0x8F750-0x926C7 (`out2/d_8f6e0.md`, `out2/d_92680.md`)

The "fragment start" at 0x90881 (C.2) is mid-function. A byte-pattern scan of the decoded .text for
the prologue/epilogue pair found the true start: rva **0x8F750**, end ~**rva 0x926C7** (~12.1 KB).
Thiscall, `ecx` = XiAtelBuff*.

Prologue (`out2/d_8f6e0.md`):

````text

  0008F750  83 ec 34                   sub esp, 0x34
  0008F753  53                         push ebx
  0008F754  55                         push ebp
  0008F755  56                         push esi
  0008F756  57                         push edi
  0008F757  68 ff 00 00 00             push 0xff
  0008F75C  8b f1                      mov esi, ecx

````

Matching epilogues at **0x926AA** and **0x926C0** (`out2/d_92680.md`):

````text

  000926AA  5f                         pop edi
  000926AB  5e                         pop esi
  000926AC  5d                         pop ebp
  000926AD  5b                         pop ebx
  000926AE  83 c4 34                   add esp, 0x34
  000926B1  c3                         ret 
  ...
  000926C0  5f                         pop edi
  000926C1  5e                         pop esi
  000926C2  5d                         pop ebp
  000926C3  5b                         pop ebx
  000926C4  83 c4 34                   add esp, 0x34
  000926C7  c3                         ret 

````

Why the earlier linear sweep desynced: the bytes at **0x8F72C-0x8F74B are a jump table**, eight
dwords of on-disk VAs (image base 0x10000000) pointing into the small predicate func that ends
`ret 0x10` @0x8F729:

````text
; raw bytes at 0x8F72C..0x8F74B read as LE dwords (out2/d_8f6e0.md)
  0x1008F60B  0x1008F652  0x1008F720  0x1008F63A
  0x1008F687  0x1008F70C  0x1008F6E7  0x1008F6B7
````

Disassembled as code they look like garbage (`or esi,esi` / `or byte [eax],dl` ...), which is why
the heuristic function boundary landed at 0x8F72C and C.1/C.2's "no prologue found" result came out.
Note: `xref.py --to 0x8F750` labels the containing func as "func 0x8F72C" for the same reason.

### C.6 create dispatch @ rva 0x8F7FF-0x8F9D4 (`out2/d_8f7e0.md`, `out2/d_8f900.md`)

Top of the routine, right after a few predicate calls (rva 0x95690/0x956B0/0x957A0):

````text
; out2/d_8f7e0.md, gate + status sync + Type switch
  0008F7F0  8b 86 20 01 00 00          mov eax, dword ptr [esi + 0x120]   ; ent.RenderFlags0?
  0008F7F6  f6 c4 02                   test ah, 2                         ; bit 0x200 "has actor"
  0008F7F9  0f 85 34 0e 00 00          jne 0x10090633                     ; has actor -> update path, no create
; --- create path: Status <- StatusServer, pre-set bit 0x200 ---
  0008F7FF  8b 8e 6c 01 00 00          mov ecx, dword ptr [esi + 0x16c]   ; ent.StatusServer?
  0008F805  8b be 28 01 00 00          mov edi, dword ptr [esi + 0x128]
  0008F80B  89 8e 70 01 00 00          mov dword ptr [esi + 0x170], ecx   ; ent.Status? <- StatusServer
  0008F811  80 cc 02                   or ah, 2                         ; pre-set "has actor"
  0008F814  0f be 8e ee 00 00 00       movsx ecx, byte ptr [esi + 0xee]  ; ent.Type?
  0008F821  83 e9 03                   sub ecx, 3
  0008F824  89 86 20 01 00 00          mov dword ptr [esi + 0x120], eax   ; ent.RenderFlags0?
  0008F830  0f 84 d5 0a 00 00          je 0x1009030b                    ; Type==3 -> alloc(0x894)+init rva 0xAC8F0
  0008F836  49                         dec ecx
  0008F837  0f 84 45 08 00 00          je 0x10090082                    ; Type==4 -> alloc(0x600)+init rva 0xC39A0
  0008F83D  49                         dec ecx
  0008F83E  0f 84 99 05 00 00          je 0x1008fddd                    ; Type==5 -> alloc(0x794)+init rva 0xC4200
; else (normal NPC/mob, incl. worm Type=2): stage initial pos/rot on the stack,
; from entity [esi+4..0x20] @0x8F8E1, or, when the low RFlags0 byte is negative AND
; global byte [rva 0x480835]!=0 @0x8F84C-0x8F853, from event data
; ([esi+0xD4]+0x260 +0x140..+0x15C) @0x8F859-0x8F8DF.
````

Then the alloc/ctor block (`out2/d_8f900.md`):

````text
; out2/d_8f900.md, alloc + base ctor + 'spop' fourcc literal @0x8F958
  0008F91B  e8 b0 84 ff ff             call 0x10087dd0                  ; predicate -> al (index path if ==1)
  0008F920  6a 00                      push 0                           ; alloc arg3
  0008F922  6a 04                      push 4                           ; alloc arg2
  0008F924  cmp al, 1
  0008F926  68 0c 0a 00 00             push 0xa0c                       ; alloc size (default)
  0008F92B  je 0x1008f999              ; al==1 -> index ctor path @0x8F999
; --- 'spop' name path: bit 23 of [esi+0x12C] set @0x8F92D-0x8F93A ---
  0008F93C  e8 9f 96 f9 ff             call 0x10028fe0                  ; allocator
  0008F941  8b f8                      mov edi, eax                     ; actor = alloc result
  0008F943  83 c4 0c                   add esp, 0xc
  0008F946  8b cf                      mov ecx, edi
  0008F948  e8 b3 4f fe ff             call 0x10074900                  ; base ctor (CYyObject)
  0008F956  je 0x1008f9d0              ; alloc failed -> [esi+0xA0]=0
>>0008F958  68 73 70 6f 70             push 0x706f7073   ; fourcc? 'spop'
  0008F95D  8d 4c 24 38                lea ecx, [esp + 0x38]            ; pos/rot ptr
  0008F961  56                         push esi                         ; entity
  0008F962  51                         push ecx
  0008F963  8b cf                      mov ecx, edi                     ; this = new actor
  0008F965  e8 86 5d 03 00             call 0x100c56f0                  ; 'spop' ctor entry of func 0xC525E
; --- name=0 path @0x8F96C: same alloc/ctor, push 0 instead of 'spop', call 0xC56F0 @0x8F992 ---
; --- index path @0x8F999 (al==1): same alloc/ctor, then
  0008F9B9  mov al, byte ptr [esi + 0xef]   ; index = byte[ent+0xEF]
  0008F9C3  dec eax
  0008F9C4  push eax / push esi / push posptr
  0008F9C9  e8 c2 5e 03 00             call 0x100c5890                  ; index ctor entry of func 0xC525E
; --- all paths converge: [esi+0xA0] = actor (or 0 on alloc failure) @0x8F9D4, then pos/rot copy +
; angle-wrap (C.7) starting @0x8F9E0.
````

Decode notes:

- **Type(+0xEE)-driven create** (cf. F6): Types 3/4/5 (doors etc.) get different actor classes , 
  alloc sizes **0x894 / 0x600 / 0x794**, init calls rva **0xAC8F0 / 0xC39A0 / 0xC4200**; none of
  those install the CXiSkeletonActor vtable. Normal NPCs/mobs (Type ≤ 2; worm is Type=2, F7) get
  the **0xA0C-byte** actor via func 0xC525E entries (C.9).
- Alloc idiom: `push size; push 4; push 0; call rva 0x28FE0`, then base ctor **rva 0x74900**
  (85 refs incl. all six create paths in this routine @0x8F948/0x8F978/0x8F9A5/0x8FE04/0x90097/
  0x90320).
- **'spop' is a new fourcc literal** (@0x8F958) not in F27's list. It is the routine name passed to
  the ctor and stored at actor+0x8C4 (cf. F4's event-VM op, which also mirrors a fourcc into the
  actor); it will resolve later against DAT tables like 'init' does (F27/F29). The 'spop' path is
  taken when **bit 23 of [ent+0x12C]** is set (`shr eax,0x17; and al,1` @0x8F933-0x8F936); the
  index path (rva 0x87DD0(entity)==1) passes **index = byte[ent+0xEF]−1** to entry 0xC5890.
- The create block also sets global byte [rva 0x47D17C]=1 after each successful alloc
  (@0x8F94F/0x8F97F/0x8F9AC).

### C.7 angle-wrap correction to F28's "float clamps" (constants at rva 0x329D28/0x329D2C/0x329D30)

The float ops in C.1/C.6 against the three .rdata constants are **wrap-to-[−π,π]**, not clamps.
The constants (verified by reading .rdata directly; file offset 0x1128):

````text
  rva 0x329D28 = -3.1415   bytes C0 49 0E 56   (-pi, slightly truncated)
  rva 0x329D2C = +6.283    bytes 40 C9 0E 56   (+2*pi)
  rva 0x329D30 = +3.1415   bytes 40 49 0E 56   (+pi)
````

The idiom (visible in `out2/d_906c0.md` C.1 and repeated at @0x8F9F0+ after create):
`if v > +pi: v -= 2*pi; if v < -pi: v += 2*pi`, applied to actor+0x44/+0x48/+0x4C (the rotation
floats) and other rotation fields. F28's "float clamps against constants" wording is superseded:
nothing is clamped, angles are wrapped into [−π, π].

### C.8 callers of rva 0x8F750 + flush wrapper rva 0x95DB0 + counter budget + +0x12C bit-0 writers (`out2/x_8f750.md`, `out2/d_95D9F.md`, `out2/d_95A43.md`, `out2/x_disp_12c.md`, `out2/x_2c3511.md`)

**Callers of rva 0x8F750: 6 sites**, a per-frame entity flush loop (`out2/x_8f750.md`):

````text
references to 0x8F750 (func 0x8F72C): 6
- 0x95050 in func 0x94FE8      mov ecx, esi / call 0x1008f750
- 0x95A74 in func 0x95A43      ... call 0x1008f750 / inc dword ptr [0x10487e8c]
- 0x95B06 in func 0x95A81      ... call 0x1008f750 / inc dword ptr [0x10487e8c]
- 0x95BC7 in func 0x95B9A      ... call 0x1008f750 / inc dword ptr [0x10487e8c]
- 0x95D4C in func 0x95CC7      cmp dl,1 / jne skip / call 0x1008f750 / inc dword ptr [0x10487e8c]
- 0x95DC7 in func 0x95D9F      (inside the flush wrapper below)
````

Four of the six sites `inc` a **global counter VA 0x10487E8C (rva 0x487E8C)** after the call.
The budget check (`out2/d_95A43.md`, func 0x95A43):

````text
  00095A48  8b 15 8c 7e 48 10          mov edx, dword ptr [0x10487e8c]   ; counter (rva 0x487E8C)
  00095A4E  a1 48 af 35 10             mov eax, dword ptr [0x1035af48]   ; limit  (rva 0x35AF48)
  ...
  00095A53  3b d0                      cmp edx, eax
  00095A55  7d 2a                      jge 0x10095a81                    ; counter >= limit -> skip flush
  00095A57  56                         push esi
  00095A58  e8 53 03 00 00             call 0x10095db0                   ; flush wrapper
````

i.e. entity updates are **rate-limited per frame** (relevant when predicting timing of create/
destroy after packets).

**Flush wrapper = rva 0x95DB0** (`out2/d_95D9F.md`), this answers F32's open question on the
destroy side:

````text
; out2/d_95D9F.md
  00095DB0  56                         push esi
  00095DB1  8b 74 24 08                mov esi, dword ptr [esp + 8]     ; entity
  00095DB5  f6 86 2c 01 00 00 01       test byte ptr [esi + 0x12c], 1   ; "update pending" bit 0
  00095DBC  74 1c                      je 0x10095dda                    ; not set -> do nothing
  00095DBE  8b ce                      mov ecx, esi
  00095DC0  e8 4b cb ff ff             call 0x10092910                  ; destroy entry (gated on RFlags0 0x200 inside)
  00095DC5  8b ce                      mov ecx, esi
  00095DC7  e8 84 99 ff ff             call 0x1008f750                  ; update/create routine (C.5)
  00095DCC  8b 86 2c 01 00 00          mov eax, dword ptr [esi + 0x12c]
  00095DD2  24 fe                      and al, 0xfe                     ; clear bit 0
  00095DD4  89 86 2c 01 00 00          mov dword ptr [esi + 0x12c], eax
  00095DDA  5e                         pop esi
  00095DDB  c3                         ret 
````

So: whenever **+0x12C bit 0** ("update pending") is set, the wrapper first runs the destroy block
(rva 0x92910, which itself only tears down when RFlags0 bit 0x200 "has actor" is set), then runs
the update/create routine, then clears the bit. Wrapper call sites: @0x95A58 (func 0x95A43),
@0x95AEA (func 0x95A81, preceded by `or ecx,0x20000000; mov [esi+0x12C],ecx` @0x95ADE-0x95AE4,
a dword write to the same field), @0x95BAB (func 0x95B9A); each preceded by the counter budget
check above.

**+0x12C byte-level writers** (`out2/x_disp_12c.md`, `--disp 0x12C --size 1`: 21 sites / 19 funcs;
entity-context ones):

````text
- func 0x2BD011: 0x2BD044 mov byte ptr [esi + 0x12c], 8        ; "=8" write
- func 0x95D9F:   0x95DB5  test byte ptr [esi + 0x12c], 1      ; flush wrapper (reader)
- func 0x13BF05:  0x13BF89 mov byte ptr [ecx + 0x12c], al      ; bulk-zero path
- func 0x212CA6:  0x212CAC mov byte ptr [esi + 0x12c], 1       ; direct bit-0 write (context unverified)
- func 0x212CD2:  0x212CDF mov byte ptr [esi + 0x12c], 1       ; direct bit-0 write (context unverified)
- func 0x2C3511:  0x2C3536 mov byte ptr [esi + 0x12c], al      ; setter API (range-checked)
````

The setter rva **0x2C3511** is called from exactly two entity-registration paths (`out2/x_2c3511.md`):
@0x253B83 (func 0x253B5A) and @0x254168 (func 0x25413A); both pass a local value, not yet traced to
its source. Dword-level (`--disp 0x12C --size 4`): 500 sites / 254 funcs, too noisy; the relevant
one is func **0x9C0FC**'s RMW of F30's bits 0x400/0x2000/0x40000 (the u32 at pkt+0x24). **Exact
bit-0 trigger: still open.**

### C.9 create-path closure: entries 0xC56F0 / 0xC5890 into func 0xC525E (`out2/d_c56e0.md`, `out2/d_c5880.md`, `out2/x_c56f0.md`, `out2/x_c5890.md`)

The "failed" xrefs of F.2 targeted the func start 0xC525E (still 0 refs). The create path actually
calls **mid-function entries**:

````text
; out2/x_c56f0.md, references to 0xC56F0: 3
- 0x8F965 in func 0x8F8E1   (create dispatch, 'spop' path, C.6)
- 0x8F992 in func 0x8F96C   (create dispatch, name=0 path, C.6)
- 0xD71F4 in func 0xD710D:
    000D71F4  e8 f7 e4 fe ff             call 0x100c56f0
    000D71FB  c7 06 e8 13 33 10          mov dword ptr [esi], 0x103313e8   ; DIFFERENT vtable (rva 0x3313E8)
    000D7201  e8 ea 01 00 00             call 0x100d73f0
; out2/x_c5890.md, references to 0xC5890: 2
- 0x8F9C9 in func 0x8F999   (create dispatch, index path, C.6)
- 0xD7229 in func 0xD710D:
    000D7229  e8 62 e6 fe ff             call 0x100c5890
    000D7230  c7 06 e8 13 33 10          mov dword ptr [esi], 0x103313e8   ; same derived vtable
````

The third caller, **func 0xD710D**, calls both ctor entries and then overwrites `[esi]` with vtable
rva **0x3313E8**, the base-ctor + derived-vtable pattern (CXiSkeletonActor as a base class of
something else).

Entry 0xC56F0 ('spop' ctor), `out2/d_c56e0.md`:

````text
; out2/d_c56e0.md @0xC577B-0xC57C0 (field init omitted)
  000C577B  c7 06 40 0f 33 10          mov dword ptr [esi], 0x10330f40   ; VA of CXiSkeletonActor vtable (rva 0x330F40)
  000C5781  8b ce                      mov ecx, esi
  000C5783  89 b3 a0 00 00 00          mov dword ptr [ebx + 0xa0], esi   ; ent.ActorPointer? = actor (ebx = entity)
  000C5789  e8 e2 05 00 00             call 0x100c5d70
  000C578E  8b 44 24 1c                mov eax, dword ptr [esp + 0x1c]   ; fourcc arg ('spop' or 0)
  000C5792  3d 73 70 6f 70             cmp eax, 0x706f7073   ; 'spop'
  000C5797  75 14                      jne 0x100c57ad
  000C5799  8a 8b ee 00 00 00          mov cl, byte ptr [ebx + 0xee]     ; entity Type
  000C579F  84 c9                      test cl, cl                ; Type != 0?
  000C57A1  74 0a                      je 0x100c57ad
  000C57A3  c7 86 60 06 00 00 80 80 80 00 mov dword ptr [esi + 0x660], 0x808080
  ...
  000C57B9  89 86 c4 08 00 00          mov dword ptr [esi + 0x8c4], eax   ; store the fourcc at actor+0x8C4
````

Entry 0xC5890 (index ctor), `out2/d_c5880.md`: same shape; vtable install @**0xC5919**, call rva
0xC5D70 @0xC591F, posptr arg at [esp+0x14] @0xC5924 (dump ends at 0xC592C, the +0x8C4 store is just
past it).

### C.10 ActionTimer2=1800 setter: true start rva 0xA4150 (`out2/d_a4110.md`, `out2/x_a4150.md`)

"Func 0xA4110" is actually two funcs:

````text
; out2/d_a4110.md, 0xA4110-0xA4143: global-table registrar (NOT the timer setter)
  000A4110  8d 04 89                   lea eax, [ecx + ecx*4]     ; index * 5
  000A4119  c1 e0 06                   shl eax, 6                 ; -> index * 320 (stride 0x140)
  000A4121  8d b8 b8 5a 48 10          lea edi, [eax + 0x10485ab8]   ; table at rva 0x485AB8
  000A4127  f3 a5                      rep movsd ...              ; copy 6 dwords
  000A412D  8d b8 f4 5a 48 10          lea edi, [eax + 0x10485af4]
  000A4133  b9 40 00 00 00             mov ecx, 0x40              ; copy 64 dwords
  000A4138  f3 a5                      rep movsd ...
  000A413B  c6 80 f4 5b 48 10 01       mov byte ptr [eax + 0x10485bf4], 1
; out2/d_a4110.md, the real timer setter starts at rva 0xA4150:
  000A4150  66 ff 81 1c 01 00 00       inc word ptr [ecx + 0x11c]   ; ent.ActionTimer1?
  000A4157  66 c7 81 1e 01 00 00 08 07 mov word ptr [ecx + 0x11e], 0x708   ; ent.ActionTimer2? = 1800
  000A4160  c3                         ret 
````

**5 direct callers** (`out2/x_a4150.md`, re-run this session):

````text
references to 0xA4150 (func 0xA4110): 5
- 0x83317 in func 0x832AE   mov ecx,[ecx+0x70] / test / je skip / jmp 0x100a4150   ; tail-jmp, entity via actor back-ptr +0x70 (F15)
- 0xA8F3C in func 0xA8EAB   cmp eax,ebp / je skip / mov ecx,eax / call
- 0xA8F67 in func 0xA8F53   same shape
- 0xA9361 in func 0xA9286   same shape
- 0xA938C in func 0xA9378   same shape
````

This corrects the "reached virtually, 0 direct callers" reading of the timer setter (F.2): it has
five direct callers; `--to 0xA4110` was just aimed at the registrar half.

### C.11 destroy entry rva 0x92910: 23 call sites (`out2/x_92910.md`)

````text
references to 0x92910 (func 0x928A3): 23
- 0x8A7D1 in func 0x8A7B2      ; tail jmp after call rva 0x8EE40
- 0x95993, 0x95A37 in func 0x95909   ; zone-wide entity sweep (cmp reg, 0x900 = up to 2304 entities)
- 0x95B93 in func 0x95A81      ; flush-loop family
- 0x95CA1 in func 0x95C9F      ; after `and [esi+0x12C], ebx`
- 0x95D5B in func 0x95D59      ; else-branch of the update call @0x95D4C
- 0x95DC0, 0x95E16, 0x95E81 in func 0x95D9F   ; flush wrapper (C.8) + two more gates
- 0x95F52 in func 0x95F22      ; cmp word [esi+0x166], 0
- 0x95F89 in func 0x95F82      ; cmp cl, 1
- 0x95FC5 in func 0x95FBB      ; test cl,cl; then `mov byte [esi+0xEE], 0` (Type cleared!)
- 0x96909 in func 0x9686D      ; another zone-wide sweep (cmp esi, 0x900)
- 0x99A84 in func 0x999DA      ; after call rva 0x8EE40
- 0x99B7C in func 0x99B3B      ; entity-table indexed by word [esi+8]
- 0x99DE8 in func 0x99CCA      ; same shape
- 0x9B605 in func 0x9B5C2      ; same shape
- 0x9B9AD in func 0x9B993      ; same shape
- 0x9F0C5 in func 0x9F07D      ; right after `mov byte [edx+0x144], al` (PopEffect write!)
- 0xB5B37 in func 0xB5B2B      ; entity-table sweep up to VA 0x10482F30
- 0xB5C0A in func 0xB5BFE      ; same sweep, second pass
- 0xB9C6D, 0xB9CA6 in func 0xB9BB0   ; entity-table indexed by word [esi+2]
````

Destroy is a **general primitive** (zone-out/delete/despawn/etc.), not status=3-only; the block
itself still gates on RFlags0 bit 0x200 (§F). Notable: func 0x95FBB clears Type(+0xEE) right after
calling destroy, and func 0x9F07D calls it immediately after writing PopEffect(+0x144).
