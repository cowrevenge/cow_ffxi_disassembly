# Mob pass evidence 1: module map, POL1 stub, vtable anchors (§A, §B)

Raw scanner output backing F24-F27 in [mob_animation.md](mob_animation.md). Conventions in
[README.md](README.md).

## §A. Module map, build ids, POL1 entry stub (F24, F25)

Full output of `p0_modmap.py` against the install dir:

## Phase 0 module map for `C:\PhoenixXI\SquareEnix\FINAL FANTASY XI`

Files: `FFXi.dll` (91 KB), `FFXiMain.dll` (2833 KB), `FFXiResource.dll` (44 KB), `FFXiVersions.dll` (56 KB), `ImeUiDll2.dll` (68 KB), `imeuidll.dll` (80 KB), `polboot.exe` (69 KB), `xinputdll.dll` (6 KB)

### FFXi.dll

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\FFXi.dll  size 93251 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0x2C000  EntryPoint rva 0x28FD0
TimeDateStamp 0x6A7297E3  Characteristics 0x210E  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x00010998  raw 0x00000400  rawsize 0x00000000  flags 0xE0000080
  .rdata   rva 0x00012000  vsize 0x00002000  raw 0x00000400  rawsize 0x00002000  flags 0x40000040
  .data    rva 0x00014000  vsize 0x00006250  raw 0x00002400  rawsize 0x00005000  flags 0xC0000040
  .rsrc    rva 0x0001B000  vsize 0x00002C00  raw 0x00007400  rawsize 0x00002C00  flags 0x40000040
  POL1     rva 0x0001E000  vsize 0x0000B200  raw 0x0000A000  rawsize 0x0000B200  flags 0xE0000040
  .reloc   rva 0x0002A000  vsize 0x00001A00  raw 0x00015200  rawsize 0x00001A00  flags 0x42000040
```

imports: 114 from 5 DLLs: KERNEL32.dll(91), ADVAPI32.dll(10), ole32.dll(7), OLEAUT32.dll(5), USER32.dll(1)
interesting imports: KERNEL32.dll!LoadLibraryExA, KERNEL32.dll!GetProcAddress, KERNEL32.dll!LoadLibraryA
exports: 4 -> DllCanUnloadNow@0x33A0, DllGetClassObject@0x33B0, DllRegisterServer@0x3490, DllUnregisterServer@0x3810
ASCII strings >=4: 1097 (11 per KB); per section: .rdata=314, POL1=305, .data=220, .reloc=185, .rsrc=73
path/module strings:
  0x124F0  SOFTWARE\PlayOnline\InstallFolder
  0x12514  SOFTWARE\PlayOnlineUS\InstallFolder
  0x12538  SOFTWARE\PlayOnlineEU\InstallFolder
  0x13238  user32.dll
  0x13928  KERNEL32.dll
  0x13942  USER32.dll
  0x139FA  ADVAPI32.dll
  0x13A8C  ole32.dll
  0x13A96  OLEAUT32.dll
  0x13E90  FFXi.DLL
  0x14204  oleaut32.dll
  0x14280  C:\Program Files\PlayOnline\SQUARE\FINAL FANTASY XI
  0x142B4  C:\image\ffxi
  0x142E4  FFXi.dll
  0x143A0  FFXiApp
  0x143A8  FFXiClass
  0x14574  Ein Fehler ist aufgetreten.(Fehlercode: FFXI-9001)
  0x145A8  Ein Fehler ist aufgetreten.(Fehlercode: FFXI-9000)
  0x147ED  ck zu PlayOnline.
  0x14850  ltig. (Fehlercode: FFXI-9001)
  0x14A3C  An error has occurred.(Error code: FFXI-9001)
  0x14A6C  An error has occurred.(Error code: FFXI-9000)
  0x14C18  Returning to PlayOnline.
  0x14C50  The installation path is not valid. (Error code: FFXI-9001)
  0x14DF4  Une erreur s'est produite.(Code erreur : FFXI-9001)
  0x14E28  Une erreur s'est produite.(Code erreur : FFXI-9000)
  0x1504D   PlayOnline.
  0x15096  pertoire d'installation n'est pas valide. (Code erreur : FFXI-9001)
  0x152B8  FFFXI-9001)
  0x152F0  FFFXI-9000)
  0x15430  PlayOnline
  0x1549A  FFFXI-9001)
  0x1B1FA  FFXi.FFXiEntry.1 = s 'FFXiEntry Class'
  0x1B261  FFXi.FFXiEntry = s 'FFXiEntry Class'
  0x1B2C3  CurVer = s 'FFXi.FFXiEntry.1'
  0x1B2FD  ForceRemove {989D790D-6236-11D4-80E9-00105A81E890} = s 'FFXiEntry Class'
  0x1B34F  ProgID = s 'FFXi.FFXiEntry.1'
  0x1B371  VersionIndependentProgID = s 'FFXi.FFXiEntry'
  0x1B422  FFXi.FxFileManager.1 = s 'FxFileManager Class'
  0x1B491  FFXi.FxFileManager = s 'FxFileManager Class'
  0x1B4FB  CurVer = s 'FFXi.FxFileManager.1'
  0x1B58F  ProgID = s 'FFXi.FxFileManager.1'
  0x1B5B5  VersionIndependentProgID = s 'FFXi.FxFileManager'
  0x1D2BC  FFXILibW
  0x1D2D0  _IFFXiEntryEventsWWWd
  0x1D58B  oFFXiEntryWWW
  0x1D5A1  8*gIFFXiEntryWW
  0x1D5E3  cpFFXiMessage
  0x1D636  FFXi 1.0 
  0x1D64E  _IFFXiEntryEvents InterfaceWWW
  0x1D68A  FFXiEntry ClassWWW
  0x1D69E  IFFXiEntry InterfaceWW

### FFXiMain.dll

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\FFXiMain.dll  size 2901584 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0xBE2000  EntryPoint rva 0xBB1A60
TimeDateStamp 0x6A7297F5  Characteristics 0x210E  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x0032762E  raw 0x00000400  rawsize 0x00000000  flags 0xE0000080
  .rdata   rva 0x00329000  vsize 0x00026000  raw 0x00000400  rawsize 0x00026000  flags 0x40000040
  .data    rva 0x0034F000  vsize 0x00677B89  raw 0x00026400  rawsize 0x00085000  flags 0xC0000040
  .data1   rva 0x009C7000  vsize 0x00001000  raw 0x000AB400  rawsize 0x00001000  flags 0xC0000040
  .rsrc    rva 0x009C8000  vsize 0x00003200  raw 0x000AC400  rawsize 0x00003200  flags 0x40000040
  POL1     rva 0x009CC000  vsize 0x001E5C00  raw 0x000AF600  rawsize 0x001E5C00  flags 0xE0000040
  .reloc   rva 0x00BB2000  vsize 0x0002F400  raw 0x00295200  rawsize 0x0002F400  flags 0x42000040
```

imports: 294 from 12 DLLs: KERNEL32.dll(148), USER32.dll(55), WS2_32.dll(32), IMM32.dll(15), ADVAPI32.dll(11), GDI32.dll(10), ole32.dll(9), WINMM.dll(6), OLEAUT32.dll(5), DSOUND.dll(1), d3d8.dll(1), DINPUT8.dll(1)
interesting imports: WS2_32.dll!recv, WS2_32.dll!send, WS2_32.dll!select, d3d8.dll!Direct3DCreate8, KERNEL32.dll!LoadLibraryA, KERNEL32.dll!GetProcAddress, KERNEL32.dll!LoadLibraryExA, KERNEL32.dll!CreateFileA, KERNEL32.dll!CreateProcessA, KERNEL32.dll!ReadFile, KERNEL32.dll!CreateFileW
exports: 4 -> DllCanUnloadNow@0xF780, DllGetClassObject@0xF790, DllRegisterServer@0xF870, DllUnregisterServer@0xFBF0
ASCII strings >=4: 33701 (11 per KB); per section: POL1=18680, .data=7494, .reloc=6244, .rdata=1213, .rsrc=63, .data1=7
path/module strings:
  0x329E03  _SOFTWARE\PlayOnline\DebugPatch
  0x329E24  SOFTWARE\PlayOnlineUS\DebugPatch
  0x329E48  SOFTWARE\PlayOnlineEU\DebugPatch
  0x32A000  SOFTWARE\PlayOnline\SQUARE\
  0x32A01C  SOFTWARE\PlayOnlineUS\SquareEnix\
  0x32A040  SOFTWARE\PlayOnlineEU\SquareEnix\
  0x337BD0  SOFTWARE\PlayOnline\InstallFolder
  0x337BF4  SOFTWARE\PlayOnlineUS\InstallFolder
  0x337C18  SOFTWARE\PlayOnlineEU\InstallFolder
  0x340914  OleAut32.dll
  0x3460F8  d3d8d.dll
  0x346114  d3d8.dll
  0x34B2D8  user32.dll
  0x34D1BC  DSOUND.dll
  0x34D320  IMM32.dll
  0x34D38C  WINMM.dll
  0x34D41C  WS2_32.dll
  0x34D43A  d3d8.dll
  0x34D45A  DINPUT8.dll
  0x34DAC6  KERNEL32.dll
  0x34DEA6  USER32.dll
  0x34DF56  GDI32.dll
  0x34E01A  ADVAPI32.dll
  0x34E0D2  ole32.dll
  0x34E0DC  OLEAUT32.dll
  0x34E540  FFXiMain.DLL
  0x34F2C8  \11.DAT
  0x34F788  D:\build0001\FFXi_Win\Main\Debug.cpp
  0x34F830  c:\image\ffxi_ex%d\sound\win\se\se%3.3u\se%6.6u.spw
  0x34F864  c:\image\ffxi_ex\sound\win\se\se%3.3u\se%6.6u.spw
  0x34F898  c:\image\ffxi\sound\win\se\se%3.3u\se%6.6u.spw
  0x34F8EC  C:\image\ffxi\Bench
  0x34FB65  K.$\xinputdll.dll
  0x350140  oleaut32.dll
  0x35017C  .\FFXiMain.dll
  0x35018C  .\FFXi.dll
  0x350238  b2.dat
  0x350240  wr_8.dat
  0x35024C  wr_7.dat
  0x350258  wr_6.dat
  0x350264  wr_5.dat
  0x350270  wr_4.dat
  0x35027C  wr_3.dat
  0x350288  wr_2.dat
  0x350294  wr.dat
  0x35029C  ca.dat
  0x3502A4  sk.dat
  0x3502AC  sb.dat
  0x3502B4  mb.dat
  0x3502BC  ti.dat
  0x3502C4  cl.dat
  0x3502CC  bs.dat
  0x3502D4  is.dat
  0x3502DC  is_2.dat
  0x350310  c:\image\ffxi\mov
  0x350350  FFXiClass
  0x3505AC  winfiles11.dat
  0x3505BC  winfiles10.dat
  0x3505CC  winfiles9.dat
  0x3505DC  winfiles8.dat

### FFXiResource.dll

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\FFXiResource.dll  size 45056 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0xC000  EntryPoint rva 0x10E9
TimeDateStamp 0x6A7295FA  Characteristics 0x210E  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x00004000  raw 0x00001000  rawsize 0x00004000  flags 0x60000020
  .rdata   rva 0x00005000  vsize 0x00001000  raw 0x00005000  rawsize 0x00001000  flags 0x40000040
  .data    rva 0x00006000  vsize 0x00003120  raw 0x00006000  rawsize 0x00003000  flags 0xC0000040
  .rsrc    rva 0x0000A000  vsize 0x00001000  raw 0x00009000  rawsize 0x00001000  flags 0x40000040
  .reloc   rva 0x0000B000  vsize 0x00001000  raw 0x0000A000  rawsize 0x00001000  flags 0x42000040
```

imports: 50 from 1 DLLs: KERNEL32.dll(50)
interesting imports: KERNEL32.dll!GetProcAddress, KERNEL32.dll!LoadLibraryA
exports: 0
ASCII strings >=4: 241 (5 per KB); per section: .rdata=113, .text=81, .reloc=46, .rsrc=1
path/module strings:
  0x5468  user32.dll
  0x5A76  KERNEL32.dll

### FFXiVersions.dll

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\FFXiVersions.dll  size 57344 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0xF000  EntryPoint rva 0x2EDA
TimeDateStamp 0x3D872923  Characteristics 0x210E  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x00007000  raw 0x00001000  rawsize 0x00007000  flags 0x60000020
  .rdata   rva 0x00008000  vsize 0x00001000  raw 0x00008000  rawsize 0x00001000  flags 0x40000040
  .data    rva 0x00009000  vsize 0x000032E0  raw 0x00009000  rawsize 0x00003000  flags 0xC0000040
  .rsrc    rva 0x0000D000  vsize 0x00001000  raw 0x0000C000  rawsize 0x00001000  flags 0x40000040
  .reloc   rva 0x0000E000  vsize 0x00001000  raw 0x0000D000  rawsize 0x00001000  flags 0x42000040
```

imports: 69 from 4 DLLs: KERNEL32.dll(61), OLEAUT32.dll(6), USER32.dll(1), ole32.dll(1)
interesting imports: KERNEL32.dll!GetProcAddress, KERNEL32.dll!LoadLibraryA
exports: 4 -> DllCanUnloadNow@0x1220, DllGetClassObject@0x1230, DllRegisterServer@0x1310, DllUnregisterServer@0x1390
ASCII strings >=4: 380 (6 per KB); per section: .text=146, .rdata=135, .reloc=68, .rsrc=28, .data=3
path/module strings:
  0x8698  user32.dll
  0x8C2C  KERNEL32.dll
  0x8C46  USER32.dll
  0x8C66  ole32.dll
  0x8C70  OLEAUT32.dll
  0x8F80  FFXiVersions.DLL
  0x90E8  oleaut32.dll
  0xD592  FFXiVersions.FFXiVersion.1 = s 'FFXiVersion Class'
  0xD605  FFXiVersions.FFXiVersion = s 'FFXiVersion Class'
  0xD673  CurVer = s 'FFXiVersions.FFXiVersion.1'
  0xD6B7  ForceRemove {E636B693-A5A7-4161-9F02-D769178DE989} = s 'FFXiVersion Class'
  0xD70B  ProgID = s 'FFXiVersions.FFXiVersion.1'
  0xD737  VersionIndependentProgID = s 'FFXiVersions.FFXiVersion'
  0xDDB0  FFXIVERSIONSLibW
  0xDDCB  -FFXiVersionWd
  0xDDE4  IFFXiVersion
  0xDE1A  FFXiVersions 1.0 
  0xDE3A  FFXiVersion ClassW
  0xDE4E  IFFXiVersion Interface
  0xDE6D   FFXiVersionWWW

### ImeUiDll2.dll

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\ImeUiDll2.dll  size 69632 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0x12000  EntryPoint rva 0x2A7E
TimeDateStamp 0x4F44BDB1  Characteristics 0x2102  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x00009000  raw 0x00001000  rawsize 0x00009000  flags 0x60000020
  .rdata   rva 0x0000A000  vsize 0x00003000  raw 0x0000A000  rawsize 0x00003000  flags 0x40000040
  .data    rva 0x0000D000  vsize 0x00001A00  raw 0x0000D000  rawsize 0x00001000  flags 0xC0000040
  .rsrc    rva 0x0000F000  vsize 0x00001000  raw 0x0000E000  rawsize 0x00001000  flags 0x40000040
  .reloc   rva 0x00010000  vsize 0x00002000  raw 0x0000F000  rawsize 0x00002000  flags 0x42000040
```

imports: 64 from 2 DLLs: KERNEL32.dll(61), USER32.dll(3)
interesting imports: KERNEL32.dll!GetProcAddress, KERNEL32.dll!LoadLibraryA
exports: 1 -> KeyInput@0x11E0
ASCII strings >=4: 493 (7 per KB); per section: .rdata=223, .text=171, .reloc=84, .data=13, .rsrc=2
path/module strings:
  0xA220  KERNEL32.DLL
  0xA27C  mscoree.dll
  0xAB48  `local vftable constructor closure'
  0xAB6C  `local vftable'
  0xAD58  `vftable'
  0xB030  kernel32.dll
  0xB9DC  USER32.DLL
  0xBAB8  m:\FFXI\FFXi_WinTool\ImeUiDll2\release\ImeUiDll2.pdb
  0xC5F2  KERNEL32.dll
  0xC62C  USER32.dll
  0xCAB2  ImeUiDll2.dll

### imeuidll.dll

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\imeuidll.dll  size 81920 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0x16000  EntryPoint rva 0x3B8B
TimeDateStamp 0x45BDE926  Characteristics 0x2102  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x0000A000  raw 0x00001000  rawsize 0x0000A000  flags 0x60000020
  .rdata   rva 0x0000B000  vsize 0x00004000  raw 0x0000B000  rawsize 0x00004000  flags 0x40000040
  .data    rva 0x0000F000  vsize 0x00003EBC  raw 0x0000F000  rawsize 0x00002000  flags 0xC0000040
  .rsrc    rva 0x00013000  vsize 0x00001000  raw 0x00011000  rawsize 0x00001000  flags 0x40000040
  .reloc   rva 0x00014000  vsize 0x00002000  raw 0x00012000  rawsize 0x00002000  flags 0x42000040
```

imports: 107 from 6 DLLs: KERNEL32.dll(74), IMM32.dll(16), USER32.dll(9), VERSION.dll(3), ole32.dll(3), OLEAUT32.dll(2)
interesting imports: KERNEL32.dll!GetProcAddress, KERNEL32.dll!LoadLibraryA, KERNEL32.dll!CreateFileA
exports: 7 -> ??0CImeUiDll@@QAE@XZ@0x10B0, ??4CImeUiDll@@QAEAAV0@ABV0@@Z@0x1000, ?ImeUi_Initialize_@@YA_NPAUHWND__@@_N@Z@0x1060, ?ImeUi_SetState_@@YAXK@Z@0x10A0, ?ImeUi_Uninitialize_@@YAXXZ@0x1090, ?fnImeUiDll@@YAHXZ@0x1020, ?nImeUiDll@@3HA@0x11CE8
ASCII strings >=4: 635 (7 per KB); per section: .rdata=311, .text=187, .reloc=120, .data=15, .rsrc=2
path/module strings:
  0xBD4C  mscoree.dll
  0xC324  KERNEL32.DLL
  0xC44C  kernel32.dll
  0xC4C0  USER32.DLL
  0xC7B0  `local vftable constructor closure'
  0xC7D4  `local vftable'
  0xC9C0  `vftable'
  0xD660  imm32.dll
  0xD7E0  m:\ffxi\ffxi_winsample\microsoft\imeuidll\release\ImeUiDll.pdb
  0xE17E  VERSION.dll
  0xE2EA  IMM32.dll
  0xE3C0  KERNEL32.dll
  0xE46A  USER32.dll
  0xE4AE  ole32.dll
  0xE4B8  OLEAUT32.dll
  0xE99E  ImeUiDll.dll

### polboot.exe

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\polboot.exe  size 70696 bytes
machine: 0x14C (i386)
ImageBase 0x00400000  SizeOfImage 0xF000  EntryPoint rva 0x187F
TimeDateStamp 0x4B91EBA2  Characteristics 0x010F  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x00006000  raw 0x00001000  rawsize 0x00006000  flags 0x60000020
  .rdata   rva 0x00007000  vsize 0x00001000  raw 0x00007000  rawsize 0x00001000  flags 0x40000040
  .data    rva 0x00008000  vsize 0x00003FC0  raw 0x00008000  rawsize 0x00003000  flags 0xC0000040
  .rsrc    rva 0x0000C000  vsize 0x00003000  raw 0x0000B000  rawsize 0x00003000  flags 0x40000040
```

imports: 47 from 2 DLLs: KERNEL32.dll(44), ADVAPI32.dll(3)
interesting imports: KERNEL32.dll!CreateProcessA, KERNEL32.dll!GetProcAddress, KERNEL32.dll!LoadLibraryA
exports: 0
ASCII strings >=4: 264 (3 per KB); per section: .text=101, .rdata=93, .rsrc=40, .data=30
path/module strings:
  0x74D4  user32.dll
  0x7616  KERNEL32.dll
  0x7656  ADVAPI32.dll
  0x8158  SOFTWARE\PlayOnlineEU
  0x8170  SOFTWARE\PlayOnlineUS
  0x8188  SOFTWARE\PlayOnline

### xinputdll.dll

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\xinputdll.dll  size 6656 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0x6000  EntryPoint rva 0x1385
TimeDateStamp 0x56050A17  Characteristics 0x2102  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x00000A00  raw 0x00000400  rawsize 0x00000A00  flags 0x60000020
  .rdata   rva 0x00002000  vsize 0x00000600  raw 0x00000E00  rawsize 0x00000600  flags 0x40000040
  .data    rva 0x00003000  vsize 0x00000364  raw 0x00001400  rawsize 0x00000200  flags 0xC0000040
  .rsrc    rva 0x00004000  vsize 0x00000200  raw 0x00001600  rawsize 0x00000200  flags 0x40000040
  .reloc   rva 0x00005000  vsize 0x00000200  raw 0x00001800  rawsize 0x00000200  flags 0x42000040
```

imports: 33 from 3 DLLs: MSVCR80.dll(17), KERNEL32.dll(13), XINPUT1_3.dll(3)
exports: 3 -> XInputEnable_@0x1040, XInputGetState_@0x1010, XInputSetState_@0x1030
ASCII strings >=4: 65 (9 per KB); per section: .rdata=40, .text=9, .reloc=9, .rsrc=7
path/module strings:
  0x2138  m:\FFXI\FFXi_WinTool\XinputDll\Release\XinputDll.pdb
  0x23C4  MSVCR80.dll
  0x23EA  XINPUT1_3.dll
  0x251A  KERNEL32.dll
  0x2576  XinputDll.dll

### patch.sin

```
54 54 54 54 54 54 54 54 54 54 54 59 61 53 44 34 55 30 6b 41 6b 65 67 62 41 37 78 54 4a 57 78 5a 66 53 66 66 6f 38 40 38 6f 66 74 76 4e 78 42 6d 6b 44 38 6c 4c 37 54 54
```
printable: b'TTTTTTTTTTTYaSD4U0kAkegbA7xTJWxZfSffo8@8oftvNxBmkD8lL7TT'

### FTABLE.DAT

```
00 00 01 00 02 00 03 00 04 00 05 00 06 00 07 00 08 00 09 00 0a 00 0b 00 0c 00 0d 00 0e 00 0f 00 10 00 11 00 12 00 13 00 14 00 15 00 16 00 17 00 18 00 19 00 1a 00 1b 00 bc 4f 92 30 88 30 93 30 94 30 95 30 96 30 97 30 98 30 99 30 9a 30 9b 30 9c 30 9e 30 9f 30 a0 30 a1 30 66 3b bd 4f a3 30 a4 30 a5 30 a6 30 a7 30 a8 30 a9 30 aa 30 ab 30 ac 30 ad 30 ae 30 b0 30 b1 30 b2 30 b3 30 67 3b b4 30 b5 30 b6 3
```
printable: b'.........................................................O.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0f;.O.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0.0g;.0.0.0h;.0i;.0.0.0j;k;l;m;n;o;p;q;r;s;t;.;.;.;.;.I.T.R0W{l;.<.Y...v.w...'

````

### A.1 POL1 entry stub + unpacker (re-verified 2026-09-08, `probe_entrystub.py`)

Stub @ rva 0xBB1A60-0xBB1AFB; unpacker @ rva 0xBB1AFB-0xBB1B47. Note the base materialization
`mov esi,0x10000000 / mov edi,0 / add esi,edi` (the "base-reloc trick", DllCharacteristics has no
dynamic-base bit), the unpack call args (src = base+POL1_rva 0x9CC000, dst = base+.text_rva 0x1000,
size ptr → 0x32762E), then the stub's own .reloc walk starting at base+0xBB2000, and finally
`jmp rva 0x31676F` (real DllMain). Unpacker: tag byte = 8 ops MSB-first (`shl bl,1; jae` tests the
original bit7); bit=1 → literal copy; bit=0 → back-ref b1,b2 with off=(b2|b1<<8)&0xFFF, off==0
terminates, len=(b1>>4)+3.

````text

=== entry stub @ rva 0xBB1A60 .. 0xBB1AFB ===
10bb1a60: cmp byte ptr [esp + 8], 1
10bb1a65: jne 0x10bb1af6
10bb1a6b: jmp 0x10bb1a71
10bb1a6d: inc ebp
10bb1a6e: pop eax
10bb1a6f: inc ebp
10bb1a70: inc ebp
10bb1a71: pushal 
10bb1a72: mov ebp, esp
10bb1a74: sub esp, 8
10bb1a77: mov esi, 0x10000000
10bb1a7c: mov edi, 0
10bb1a81: add esi, edi
10bb1a83: push 0
10bb1a85: mov eax, 0x32762e
10bb1a8a: mov dword ptr [ebp - 4], eax
10bb1a8d: lea eax, [ebp - 4]
10bb1a90: push eax
10bb1a91: lea eax, [esi + 0x1000]
10bb1a97: push eax
10bb1a98: push 0x1e5a60
10bb1a9d: lea eax, [esi + 0x9cc000]
10bb1aa3: push eax
10bb1aa4: call 0x10bb1afb
10bb1aa9: add esp, 0x14
10bb1aac: mov edx, edi
10bb1aae: or edx, edx
10bb1ab0: je 0x10bb1af2
10bb1ab2: lea edi, [esi + 0xbb2000]
10bb1ab8: mov eax, dword ptr [edi + 4]
10bb1abb: or eax, eax
10bb1abd: je 0x10bb1af2
10bb1abf: mov eax, 0x32862e
10bb1ac4: sub eax, dword ptr [edi]
10bb1ac6: jbe 0x10bb1af2
10bb1ac8: mov ebx, 8
10bb1acd: mov ax, word ptr [edi + ebx]
10bb1ad1: or ax, ax
10bb1ad4: je 0x10bb1ae0
10bb1ad6: and eax, 0xfff
10bb1adb: add eax, dword ptr [edi]
10bb1add: add dword ptr [esi + eax], edx
10bb1ae0: add ebx, 2
10bb1ae3: cmp ebx, dword ptr [edi + 4]
10bb1ae6: jne 0x10bb1acd
10bb1ae8: mov eax, dword ptr [edi + 4]
10bb1aeb: add edi, eax
10bb1aed: jmp 0x10bb1ab8
10bb1af2: add esp, 8
10bb1af5: popal 
10bb1af6: jmp 0x1031676f

=== unpacker @ rva 0xBB1AFB (first 40 insns) ===
10bb1afb: pushal 
10bb1afc: mov ebp, esp
10bb1afe: mov esi, dword ptr [ebp + 0x24]
10bb1b01: mov edi, dword ptr [ebp + 0x2c]
10bb1b04: mov ecx, 8
10bb1b09: mov bl, byte ptr [esi]
10bb1b0b: inc esi
10bb1b0c: shl bl, 1
10bb1b0e: jae 0x10bb1b1b
10bb1b10: mov al, byte ptr [esi]
10bb1b12: mov byte ptr [edi], al
10bb1b14: inc esi
10bb1b15: inc edi
10bb1b16: jmp 0x10bb1b42
10bb1b1b: xor eax, eax
10bb1b1d: mov al, byte ptr [esi]
10bb1b1f: inc esi
10bb1b20: mov edx, eax
10bb1b22: mov al, byte ptr [esi]
10bb1b24: mov ah, dl
10bb1b26: and eax, 0xfff
10bb1b2b: je 0x10bb1b46
10bb1b2d: inc esi
10bb1b2e: neg eax
10bb1b30: shr edx, 4
10bb1b33: add edx, 3
10bb1b39: mov bh, byte ptr [edi + eax]
10bb1b3c: mov byte ptr [edi], bh
10bb1b3e: inc edi
10bb1b3f: dec edx
10bb1b40: jne 0x10bb1b39
10bb1b42: loop 0x10bb1b0c
10bb1b44: jmp 0x10bb1b04
10bb1b46: popal 
10bb1b47: ret 
10bb1b48: add byte ptr [eax], al
10bb1b4a: add byte ptr [eax], al
10bb1b4c: add byte ptr [eax], al
10bb1b4e: add byte ptr [eax], al
10bb1b50: add byte ptr [eax], al

````

---

## §B. Vtable slot lists, ctor sites, fourcc literals (F26, F27)

Full output of `p1_anchors.py` on the decoded image: known-RVA table with section placement, raw VA
reference hits, complete vtable slot lists, class-name strings, constructor-site disassembly for all
nine anchor tables, and every fourcc literal used as an instruction operand. Decode in F26/F27.

````text

## Phase 1 anchors

```
file: C:\PhoenixXI\SquareEnix\FINAL FANTASY XI\FFXiMain.dll  size 2901584 bytes
machine: 0x14C (i386)
ImageBase 0x10000000  SizeOfImage 0xBE2000  EntryPoint rva 0xBB1A60
TimeDateStamp 0x6A7297F5  Characteristics 0x210E  DllCharacteristics 0x0000
sections:
  .text    rva 0x00001000  vsize 0x0032762E  raw 0x00000400  rawsize 0x00000000  flags 0xE0000080
  .rdata   rva 0x00329000  vsize 0x00026000  raw 0x00000400  rawsize 0x00026000  flags 0x40000040
  .data    rva 0x0034F000  vsize 0x00677B89  raw 0x00026400  rawsize 0x00085000  flags 0xC0000040
  .data1   rva 0x009C7000  vsize 0x00001000  raw 0x000AB400  rawsize 0x00001000  flags 0xC0000040
  .rsrc    rva 0x009C8000  vsize 0x00003200  raw 0x000AC400  rawsize 0x00003200  flags 0x40000040
  POL1     rva 0x009CC000  vsize 0x001E5C00  raw 0x000AF600  rawsize 0x001E5C00  flags 0xE0000040
  .reloc   rva 0x00BB2000  vsize 0x0002F400  raw 0x00295200  rawsize 0x0002F400  flags 0x42000040
```

### 1. Known RVAs

| RVA | on-disk VA | section | what | first bytes / slots |
|---|---|---|---|---|
| 0x75010 | 0x10075010 | .text | actor +4 / motion object +4 (function or 2nd vtable) | 56 8b 74 24 08 8b ce 8b 06 ff 50 20 84 c0 75 08 |
| 0x32A210 | 0x1032A210 | .rdata | first-node +0x04 | 7 .text slots: 0x1ABF0 0x1370 0x2C940 0x2C930 0x1380 0x1390 0x1AC20 |
| 0x32A5EC | 0x1032A5EC | .rdata | constant at node +0x6C / motion obj +0x60 | 43 .text slots: 0x28F90 0x1370 0x2C940 0x2C930 0x1380 0x1390 0x28FD0 0x1370 0x2C940 0x2C930 0x1380 0x1390 ... |
| 0x32B654 | 0x1032B654 | .rdata | motion object vtable (clip fourcc +0x30, model id +0x44) | 29 .text slots: 0x74740 0x54200 0x2C940 0x2C930 0x1380 0x1390 0x53360 0x11920 0x42650 0x54230 0x11940 0x54460 ... |
| 0x32B680 | 0x1032B680 | .rdata | generic scheduler node vtable (pool, stride 0x140) | 18 .text slots: 0x54460 0x54470 0x3C730 0x3C740 0x54390 0x543A0 0x53840 0x542F0 0x54370 0x2C940 0x2C930 0x47FD0 ... |
| 0x32BB38 | 0x1032BB38 | .rdata | motion-task scheduler node vtable (clip fourcc +0x3C, frames +0x40) | 64 .text slots: 0x3B540 0x63050 0x3C730 0x3C740 0x60850 0x60870 0x3B5A0 0x74740 0x1370 0x2C940 0x2C930 0x1380 ... |
| 0x32CF5C | 0x1032CF5C | .rdata | constant at node +0x14/+0x20 | 1 .text slots: 0x814D0 |
| 0x32D69C | 0x1032D69C | .rdata | constant at node +0x8C | 6 .text slots: 0x2C890 0x1370 0x2C940 0x2C930 0x1380 0x1390 |
| 0x330F40 | 0x10330F40 | .rdata | CXiSkeletonActor vtable (actor +0) | 64 .text slots: 0xC51A0 0x1370 0x2C940 0x2C930 0x1380 0x1390 0xC5550 0x11920 0xC63E0 0x11930 0x11940 0xA4850 ... |

Vtable slot lists (virtual method RVAs, in order):

- 0x32A210 first-node +0x04:
    slot  0 (+0x00) -> 0x1ABF0
    slot  1 (+0x04) -> 0x1370
    slot  2 (+0x08) -> 0x2C940
    slot  3 (+0x0C) -> 0x2C930
    slot  4 (+0x10) -> 0x1380
    slot  5 (+0x14) -> 0x1390
    slot  6 (+0x18) -> 0x1AC20
- 0x32A5EC constant at node +0x6C / motion obj +0x60:
    slot  0 (+0x00) -> 0x28F90
    slot  1 (+0x04) -> 0x1370
    slot  2 (+0x08) -> 0x2C940
    slot  3 (+0x0C) -> 0x2C930
    slot  4 (+0x10) -> 0x1380
    slot  5 (+0x14) -> 0x1390
    slot  6 (+0x18) -> 0x28FD0
    slot  7 (+0x1C) -> 0x1370
    slot  8 (+0x20) -> 0x2C940
    slot  9 (+0x24) -> 0x2C930
    slot 10 (+0x28) -> 0x1380
    slot 11 (+0x2C) -> 0x1390
    slot 12 (+0x30) -> 0x28FB0
    slot 13 (+0x34) -> 0x1370
    slot 14 (+0x38) -> 0x2C940
    slot 15 (+0x3C) -> 0x2C930
    slot 16 (+0x40) -> 0x1380
    slot 17 (+0x44) -> 0x1390
    slot 18 (+0x48) -> 0x28F70
    slot 19 (+0x4C) -> 0x1370
    slot 20 (+0x50) -> 0x2C940
    slot 21 (+0x54) -> 0x2C930
    slot 22 (+0x58) -> 0x1380
    slot 23 (+0x5C) -> 0x1390
    slot 24 (+0x60) -> 0x28F50
    slot 25 (+0x64) -> 0x1370
    slot 26 (+0x68) -> 0x2C940
    slot 27 (+0x6C) -> 0x2C930
    slot 28 (+0x70) -> 0x1380
    slot 29 (+0x74) -> 0x1390
    slot 30 (+0x78) -> 0x28F10
    slot 31 (+0x7C) -> 0x1370
    slot 32 (+0x80) -> 0x2C940
    slot 33 (+0x84) -> 0x2C930
    slot 34 (+0x88) -> 0x1380
    slot 35 (+0x8C) -> 0x1390
    slot 36 (+0x90) -> 0x28F30
    slot 37 (+0x94) -> 0x1370
    slot 38 (+0x98) -> 0x2C940
    slot 39 (+0x9C) -> 0x2C930
    slot 40 (+0xA0) -> 0x1380
    slot 41 (+0xA4) -> 0x1390
    slot 42 (+0xA8) -> 0x29250
- 0x32B654 motion object vtable (clip fourcc +0x30, model id +0x44):
    slot  0 (+0x00) -> 0x74740
    slot  1 (+0x04) -> 0x54200
    slot  2 (+0x08) -> 0x2C940
    slot  3 (+0x0C) -> 0x2C930
    slot  4 (+0x10) -> 0x1380
    slot  5 (+0x14) -> 0x1390
    slot  6 (+0x18) -> 0x53360
    slot  7 (+0x1C) -> 0x11920
    slot  8 (+0x20) -> 0x42650
    slot  9 (+0x24) -> 0x54230
    slot 10 (+0x28) -> 0x11940
    slot 11 (+0x2C) -> 0x54460
    slot 12 (+0x30) -> 0x54470
    slot 13 (+0x34) -> 0x3C730
    slot 14 (+0x38) -> 0x3C740
    slot 15 (+0x3C) -> 0x54390
    slot 16 (+0x40) -> 0x543A0
    slot 17 (+0x44) -> 0x53840
    slot 18 (+0x48) -> 0x542F0
    slot 19 (+0x4C) -> 0x54370
    slot 20 (+0x50) -> 0x2C940
    slot 21 (+0x54) -> 0x2C930
    slot 22 (+0x58) -> 0x47FD0
    slot 23 (+0x5C) -> 0x47FE0
    slot 24 (+0x60) -> 0x53850
    slot 25 (+0x64) -> 0x47C40
    slot 26 (+0x68) -> 0x47CF0
    slot 27 (+0x6C) -> 0x480E0
    slot 28 (+0x70) -> 0x53E10
- 0x32B680 generic scheduler node vtable (pool, stride 0x140):
    slot  0 (+0x00) -> 0x54460
    slot  1 (+0x04) -> 0x54470
    slot  2 (+0x08) -> 0x3C730
    slot  3 (+0x0C) -> 0x3C740
    slot  4 (+0x10) -> 0x54390
    slot  5 (+0x14) -> 0x543A0
    slot  6 (+0x18) -> 0x53840
    slot  7 (+0x1C) -> 0x542F0
    slot  8 (+0x20) -> 0x54370
    slot  9 (+0x24) -> 0x2C940
    slot 10 (+0x28) -> 0x2C930
    slot 11 (+0x2C) -> 0x47FD0
    slot 12 (+0x30) -> 0x47FE0
    slot 13 (+0x34) -> 0x53850
    slot 14 (+0x38) -> 0x47C40
    slot 15 (+0x3C) -> 0x47CF0
    slot 16 (+0x40) -> 0x480E0
    slot 17 (+0x44) -> 0x53E10
- 0x32BB38 motion-task scheduler node vtable (clip fourcc +0x3C, frames +0x40):
    slot  0 (+0x00) -> 0x3B540
    slot  1 (+0x04) -> 0x63050
    slot  2 (+0x08) -> 0x3C730
    slot  3 (+0x0C) -> 0x3C740
    slot  4 (+0x10) -> 0x60850
    slot  5 (+0x14) -> 0x60870
    slot  6 (+0x18) -> 0x3B5A0
    slot  7 (+0x1C) -> 0x74740
    slot  8 (+0x20) -> 0x1370
    slot  9 (+0x24) -> 0x2C940
    slot 10 (+0x28) -> 0x2C930
    slot 11 (+0x2C) -> 0x1380
    slot 12 (+0x30) -> 0x1390
    slot 13 (+0x34) -> 0x608C0
    slot 14 (+0x38) -> 0x11920
    slot 15 (+0x3C) -> 0x60890
    slot 16 (+0x40) -> 0x11930
    slot 17 (+0x44) -> 0x11940
    slot 18 (+0x48) -> 0x74740
    slot 19 (+0x4C) -> 0x1370
    slot 20 (+0x50) -> 0x2C940
    slot 21 (+0x54) -> 0x2C930
    slot 22 (+0x58) -> 0x1380
    slot 23 (+0x5C) -> 0x1390
    slot 24 (+0x60) -> 0x60A60
    slot 25 (+0x64) -> 0x11920
    slot 26 (+0x68) -> 0x60A00
    slot 27 (+0x6C) -> 0x11930
    slot 28 (+0x70) -> 0x11940
    slot 29 (+0x74) -> 0x3B540
    slot 30 (+0x78) -> 0x63150
    slot 31 (+0x7C) -> 0x3C730
    slot 32 (+0x80) -> 0x3C740
    slot 33 (+0x84) -> 0x60AD0
    slot 34 (+0x88) -> 0x60B00
    slot 35 (+0x8C) -> 0x3B5A0
    slot 36 (+0x90) -> 0x74740
    slot 37 (+0x94) -> 0x1370
    slot 38 (+0x98) -> 0x2C940
    slot 39 (+0x9C) -> 0x2C930
    slot 40 (+0xA0) -> 0x1380
    slot 41 (+0xA4) -> 0x1390
    slot 42 (+0xA8) -> 0x60BC0
    slot 43 (+0xAC) -> 0x11920
    slot 44 (+0xB0) -> 0x60B90
    slot 45 (+0xB4) -> 0x11930
    slot 46 (+0xB8) -> 0x11940
    slot 47 (+0xBC) -> 0x3B540
    slot 48 (+0xC0) -> 0x62F80
    slot 49 (+0xC4) -> 0x3C730
    slot 50 (+0xC8) -> 0x3C740
    slot 51 (+0xCC) -> 0x60C30
    slot 52 (+0xD0) -> 0x60C50
    slot 53 (+0xD4) -> 0x3B5A0
    slot 54 (+0xD8) -> 0x74740
    slot 55 (+0xDC) -> 0x1370
    slot 56 (+0xE0) -> 0x2C940
    slot 57 (+0xE4) -> 0x2C930
    slot 58 (+0xE8) -> 0x1380
    slot 59 (+0xEC) -> 0x1390
    slot 60 (+0xF0) -> 0x60E70
    slot 61 (+0xF4) -> 0x11920
    slot 62 (+0xF8) -> 0x60E40
    slot 63 (+0xFC) -> 0x11930
- 0x32CF5C constant at node +0x14/+0x20:
    slot  0 (+0x00) -> 0x814D0
- 0x32D69C constant at node +0x8C:
    slot  0 (+0x00) -> 0x2C890
    slot  1 (+0x04) -> 0x1370
    slot  2 (+0x08) -> 0x2C940
    slot  3 (+0x0C) -> 0x2C930
    slot  4 (+0x10) -> 0x1380
    slot  5 (+0x14) -> 0x1390
- 0x330F40 CXiSkeletonActor vtable (actor +0):
    slot  0 (+0x00) -> 0xC51A0
    slot  1 (+0x04) -> 0x1370
    slot  2 (+0x08) -> 0x2C940
    slot  3 (+0x0C) -> 0x2C930
    slot  4 (+0x10) -> 0x1380
    slot  5 (+0x14) -> 0x1390
    slot  6 (+0x18) -> 0xC5550
    slot  7 (+0x1C) -> 0x11920
    slot  8 (+0x20) -> 0xC63E0
    slot  9 (+0x24) -> 0x11930
    slot 10 (+0x28) -> 0x11940
    slot 11 (+0x2C) -> 0xA4850
    slot 12 (+0x30) -> 0xA4840
    slot 13 (+0x34) -> 0xA4870
    slot 14 (+0x38) -> 0xA4880
    slot 15 (+0x3C) -> 0xA4890
    slot 16 (+0x40) -> 0xA48A0
    slot 17 (+0x44) -> 0xA4860
    slot 18 (+0x48) -> 0xD6380
    slot 19 (+0x4C) -> 0xA48B0
    slot 20 (+0x50) -> 0xA48D0
    slot 21 (+0x54) -> 0xA48F0
    slot 22 (+0x58) -> 0xA4900
    slot 23 (+0x5C) -> 0xA4920
    slot 24 (+0x60) -> 0xA4930
    slot 25 (+0x64) -> 0xA4940
    slot 26 (+0x68) -> 0xA4950
    slot 27 (+0x6C) -> 0xA49E0
    slot 28 (+0x70) -> 0xA49F0
    slot 29 (+0x74) -> 0xA4A00
    slot 30 (+0x78) -> 0xA4A10
    slot 31 (+0x7C) -> 0xA4960
    slot 32 (+0x80) -> 0xA4970
    slot 33 (+0x84) -> 0xD6FA0
    slot 34 (+0x88) -> 0xD6FB0
    slot 35 (+0x8C) -> 0xD6FC0
    slot 36 (+0x90) -> 0xD6FD0
    slot 37 (+0x94) -> 0xD6FE0
    slot 38 (+0x98) -> 0xD08F0
    slot 39 (+0x9C) -> 0xD09C0
    slot 40 (+0xA0) -> 0xD0A90
    slot 41 (+0xA4) -> 0xA4AA0
    slot 42 (+0xA8) -> 0xA4AB0
    slot 43 (+0xAC) -> 0xA4AC0
    slot 44 (+0xB0) -> 0xA4AD0
    slot 45 (+0xB4) -> 0xA4AE0
    slot 46 (+0xB8) -> 0xA4AF0
    slot 47 (+0xBC) -> 0xA4B00
    slot 48 (+0xC0) -> 0xA4B10
    slot 49 (+0xC4) -> 0xA4B20
    slot 50 (+0xC8) -> 0xA4B30
    slot 51 (+0xCC) -> 0x82F30
    slot 52 (+0xD0) -> 0x82F70
    slot 53 (+0xD4) -> 0x84750
    slot 54 (+0xD8) -> 0x84790
    slot 55 (+0xDC) -> 0x847D0
    slot 56 (+0xE0) -> 0x847F0
    slot 57 (+0xE4) -> 0x84810
    slot 58 (+0xE8) -> 0x84830
    slot 59 (+0xEC) -> 0x84850
    slot 60 (+0xF0) -> 0x84870
    slot 61 (+0xF4) -> 0x84890
    slot 62 (+0xF8) -> 0x848B0
    slot 63 (+0xFC) -> 0x848D0

### 1b. Raw references to vtable VAs anywhere in the file (data + code)

- 0x32A210 (first-node +0x04): 2 raw hits: 0x1AC04[.text], 0x1AC42[.text]
- 0x32A5EC (constant at node +0x6C / motion obj +0x60): 1 raw hits: 0x29122[.text]
- 0x32B654 (motion object vtable (clip fourcc +0x30, model id +0x44)): 3 raw hits: 0x532F0[.text], 0x53420[.text], 0x541D4[.text]
- 0x32B680 (generic scheduler node vtable (pool, stride 0x140)): 2 raw hits: 0x53705[.text], 0x54312[.text]
- 0x32BB38 (motion-task scheduler node vtable (clip fourcc +0x3C, frames +0x40)): 2 raw hits: 0x60822[.text], 0x608D1[.text]
- 0x32CF5C (constant at node +0x14/+0x20): 2 raw hits: 0x814C1[.text], 0x814F2[.text]
- 0x32D69C (constant at node +0x8C): 4 raw hits: 0xA092B0[POL1], 0x8A137[.text], 0x8A15A[.text], 0x8A7C5[.text]
- 0x330F40 (CXiSkeletonActor vtable (actor +0)): 7 raw hits: 0xA3D4DB[POL1], 0xC533B[.text], 0xC55FB[.text], 0xC577D[.text], 0xC591B[.text], 0xC5A52[.text], 0xC5C16[.text]

### 4. Class-name / resource strings

- `CXiSkeletonActor`: 2 hits: 0x35F620[.data] `CXiSkeletonActorRes`; 0x35F634[.data] `CXiSkeletonActor`
- `CYyObject`: 1 hits: 0x3515BC[.data] `CYyObject`
- `CXi`: 18 hits: 0x350FCC[.data] `CXiOpening`; 0x351020[.data] `CXiTimerLow`; 0x35102C[.data] `CXiTimerHigh`; 0x35103C[.data] `CXiTimer`; 0x3581FC[.data] `CXiActorNameDraw`; 0x358210[.data] `CXiActorDraw`; 0x358220[.data] `CXiActor`; 0x358320[.data] `CXiAtelActor`
- `CYy`: 47 hits: 0x351048[.data] `CYyBlendQue`; 0x3510B8[.data] `CYyMotionQue`; 0x3510CC[.data] `CYyMotionQueList`; 0x351184[.data] `CYyMoveBlendQue`; 0x351194[.data] `CYyQue`; 0x3511A0[.data] `CYyResfList`; 0x3511AC[.data] `CYyAfterImage`; 0x351288[.data] `CYyCamMng2`
- `CXiActor`: 3 hits: 0x3581FC[.data] `CXiActorNameDraw`; 0x358210[.data] `CXiActorDraw`; 0x358220[.data] `CXiActor`
- `Schedul`: 2 hits: 0x35388F[.data] `SchedularTask`; 0x35461C[.data] `Scheduler`
- `Motion`: 23 hits: 0x3510BB[.data] `MotionQue`; 0x3510CF[.data] `MotionQueList`; 0x3B45AC[.data] `Motion\src\sqmoUtil.c`; 0x3B79D0[.data] `Motion\src\sqmoChannel.c`; 0x3B7B00[.data] `Motion\src\sqmoBuild.c`; 0x3BA654[.data] `Motion\src\sqmoMotion.c`; 0x3BA663[.data] `Motion.c`; 0x3BB27C[.data] `Motion\src\sqmoPlaybackChannel.c`
- `Generator`: 1 hits: 0x35370B[.data] `GeneratorClone`
- `ROM/`: 1 hits: 0x37CD11[.data] `ROM/%d/%d.DAT`
- `ROM\`: 1 hits: 0x37CD23[.data] `ROM\%d\%d.DAT`
- `FTABLE.DAT`: 1 hits: 0x37CCB5[.data] `FTABLE.DAT`
- `.DAT`: 12 hits: 0x34F2CB[.data] `.DAT`; 0x37CC53[.data] `.DAT`; 0x37CC67[.data] `.DAT`; 0x37CCA3[.data] `.DAT`; 0x37CCBB[.data] `.DAT`; 0x37CCC8[.data] `.DAT`; 0x37CD08[.data] `.DAT`; 0x37CD1A[.data] `.DAT`
- `VTABLE.DAT`: 1 hits: 0x37CC9D[.data] `VTABLE.DAT`

Strings mentioning ini/init/pop/sched/motion (ASCII, any section):

  0x3510B7[.data] '?CYyMotionQue'
  0x3510CC[.data] 'CYyMotionQueList'
  0x35388C[.data] 'CMoSchedularTask'
  0x35461C[.data] 'Scheduler'
  0x358130[.data] 'motion'
  0x38F6EC[.data] 'blink_animation_speed'
  0x38F704[.data] 'blink_animation_time'
  0x38F71C[.data] 'blink_animation_darkness'
  0x3B338C[.data] 'motionBlurSize=<%lf>'
  0x3B416C[.data] 'Animation: %d translations, %d rotations, %d scales'
  0x3B44DC[.data] 'skeleton has no motion information, aborting'
  0x3B4594[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoUtil.c'
  0x3B79B8[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoChannel.c'
  0x3B7AE8[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoBuild.c'
  0x3BA61C[.data] 'unrecognized motion type %d.'
  0x3BA63C[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoMotion.c'
  0x3BB264[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoPlaybackChannel.c'
  0x3BB568[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoFrameChannel.c'
  0x3BB684[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoMixerMotion.c'
  0x3BB6F0[.data] 'num input motions = %d'
  0x3BB734[.data] 'sqmoMixerMotion <%x>'
  0x3BB74C[.data] 'empty motion (entrySize = %d)'
  0x3BB784[.data] 'no input motions'
  0x3BB798[.data] 'number of input motions (%d) does not match entrySize (%d).'
  0x3BB7D8[.data] 'attempt to mix motions with incompatible data'
  0x3BB824[.data] '%d motion is non-channel motion.'
  0x3BB848[.data] 'mixer has no input motions'
  0x3BB864[.data] 'sqmoMixerMotionEntrySize -- mixer has no input motions'
  0x3BB8A0[.data] 'sqmoMixerMotionSetEntrySize --'
  0x3BB8BF[.data] 'an input motion with an entrySize of %d'
  0x3BB908[.data] 'sqmoMixerMotionAddInputMotion --'
  0x3BB929[.data] "input motion's entrySize (%d) does not match that"
  0x3BB974[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoKeyChannel.c'
  0x3BBAC4[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoChannelMotion.c'
  0x3BBB18[.data] 'sqmoChannelMotion <%x>'
  0x3BBB80[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoIO.c'
  0x3BD8E4[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoStreamChannel.c'
  0x3BDBE4[.data] 'C:\\dev\\dancer\\modules\\sqMotion\\src\\sqmoMayaChannel.c'
  0xA18BF1[POL1] 'init'
  0xA1C708[POL1] 'ini'
  0xA43A60[POL1] 'init'

### 3b. Fourcc bytes in non-code sections (tables?)

- 'init' 0x74696E69: 0x34658A[.rdata], 0x34A657[.rdata], 0x34A690[.rdata], 0x34A6C8[.rdata], 0x34E08C[.rdata], 0x3506F1[.data], 0x353FAC[.data], 0x35AF60[.data], 0x35AF70[.data], 0x3623C1[.data], 0x3902DB[.data], 0x3BDD23[.data], 0x3BDD36[.data], 0x3C7DF5[.data], 0xA18BF1[POL1], 0xA41FF5[POL1]
    0x34657A: 6f 72 29 20 63 6f 6e 73 74 61 6e 74 20 64 65 66 69 6e 69 74 69 6f 6e 20 69 6e 20 73 68 61 64 65 72 20 62 6f 64 79 00 00 00 00 64 65 66 00 25 73  |or) constant definition in shader body....def.%s|
    0x34A647: 32 38 0d 0a 2d 20 75 6e 61 62 6c 65 20 74 6f 20 69 6e 69 74 69 61 6c 69 7a 65 20 68 65 61 70 0d 0a 00 00 00 00 52 36 30 32 37 0d 0a 2d 20 6e 6f  |28..- unable to initialize heap......R6027..- no|
    0x34A680: 73 70 61 63 65 20 66 6f 72 20 6c 6f 77 69 6f 20 69 6e 69 74 69 61 6c 69 7a 61 74 69 6f 6e 0d 0a 00 00 00 00 52 36 30 32 36 0d 0a 2d 20 6e 6f 74  |space for lowio initialization......R6026..- not|
    0x34A6B8: 73 70 61 63 65 20 66 6f 72 20 73 74 64 69 6f 20 69 6e 69 74 69 61 6c 69 7a 61 74 69 6f 6e 0d 0a 00 00 00 00 52 36 30 32 35 0d 0a 2d 20 70 75 72  |space for stdio initialization......R6025..- pur|
- 'ini1' 0x31696E69: 0x35AF64[.data], 0x35AF74[.data]
    0x35AF54: 00 00 00 00 00 00 00 00 00 00 80 3f 69 6e 69 74 69 6e 69 31 69 6e 69 32 69 6e 69 33 69 6e 69 74 69 6e 69 31 69 6e 69 32 69 6e 69 33 28 4e 5f 49  |...........?initini1ini2ini3initini1ini2ini3(N_I|
    0x35AF64: 69 6e 69 31 69 6e 69 32 69 6e 69 33 69 6e 69 74 69 6e 69 31 69 6e 69 32 69 6e 69 33 28 4e 5f 49 44 4c 45 29 00 00 00 00 00 00 00 00 28 42 5f 49  |ini1ini2ini3initini1ini2ini3(N_IDLE)........(B_I|

sweep: 1175095 instructions, 34634 heuristic functions

### 2. Constructor sites (imm32 == vtable VA)

- 0x32A210 first-node +0x04: 2 instruction(s) use its VA
  in func 0x1AB5C:
  0001ABFD  90                         nop 
  0001ABFE  90                         nop 
  0001ABFF  90                         nop 
  0001AC00  8b c1                      mov eax, ecx
>>0001AC02  c7 00 10 a2 32 10          mov dword ptr [eax], 0x1032a210   ; VA of first-node +0x04 (rva 0x32A210)
  0001AC08  c7 40 04 00 00 00 00       mov dword ptr [eax + 4], 0
  0001AC0F  c7 40 08 00 00 80 3f       mov dword ptr [eax + 8], 0x3f800000
  0001AC16  c3                         ret 
  in func 0x1AB5C:
  0001AC3A  5e                         pop esi
  0001AC3B  c2 04 00                   ret 4
  0001AC3E  90                         nop 
  0001AC3F  90                         nop 
>>0001AC40  c7 01 10 a2 32 10          mov dword ptr [ecx], 0x1032a210   ; VA of first-node +0x04 (rva 0x32A210)
  0001AC46  e9 05 05 00 00             jmp 0x1001b150
  0001AC4B  90                         nop 
  0001AC4C  90                         nop 

- 0x32A5EC constant at node +0x6C / motion obj +0x60: 1 instruction(s) use its VA
  in func 0x29102:
  00029114  e8 27 f8 ff ff             call 0x10028940
  00029119  83 c4 10                   add esp, 0x10
  0002911C  85 c0                      test eax, eax
  0002911E  74 0a                      je 0x1002912a
>>00029120  c7 00 ec a5 32 10          mov dword ptr [eax], 0x1032a5ec   ; VA of constant at node +0x6C / motion obj +0x60 (rva 0x32A5EC)
  00029126  83 c0 20                   add eax, 0x20
  00029129  c3                         ret 
  0002912A  68 d2 07 00 00             push 0x7d2

- 0x32B654 motion object vtable (clip fourcc +0x30, model id +0x44): 2 instruction(s) use its VA
  in func 0x53299:
  000532DE  c6 05 7c d1 47 10 01       mov byte ptr [0x1047d17c], 1
  000532E5  74 12                      je 0x100532f9
  000532E7  8b cf                      mov ecx, edi
  000532E9  e8 62 14 02 00             call 0x10074750
>>000532EE  c7 07 54 b6 32 10          mov dword ptr [edi], 0x1032b654   ; VA of motion object vtable (clip fourcc +0x30, model id +0x44) (rva 0x32B654)
  000532F4  88 5f 3c                   mov byte ptr [edi + 0x3c], bl
  000532F7  eb 02                      jmp 0x100532fb
  000532F9  33 ff                      xor edi, edi
  in func 0x533C8:
  0005340E  c6 05 7c d1 47 10 01       mov byte ptr [0x1047d17c], 1
  00053415  74 12                      je 0x10053429
  00053417  8b cf                      mov ecx, edi
  00053419  e8 32 13 02 00             call 0x10074750
>>0005341E  c7 07 54 b6 32 10          mov dword ptr [edi], 0x1032b654   ; VA of motion object vtable (clip fourcc +0x30, model id +0x44) (rva 0x32B654)
  00053424  88 5f 3c                   mov byte ptr [edi + 0x3c], bl
  00053427  eb 02                      jmp 0x1005342b
  00053429  33 ff                      xor edi, edi

- 0x32B680 generic scheduler node vtable (pool, stride 0x140): 2 instruction(s) use its VA
  in func 0x53429:
  000536F3  74 22                      je 0x10053717
  000536F5  8b ce                      mov ecx, esi
  000536F7  e8 94 48 ff ff             call 0x10047f90
  000536FC  c7 06 9c b6 32 10          mov dword ptr [esi], 0x1032b69c
>>00053702  c7 46 30 80 b6 32 10       mov dword ptr [esi + 0x30], 0x1032b680   ; VA of generic scheduler node vtable (pool, stride 0x140) (rva 0x32B680)
  00053709  89 9e f0 00 00 00          mov dword ptr [esi + 0xf0], ebx
  0005370F  89 9e f8 00 00 00          mov dword ptr [esi + 0xf8], ebx
  00053715  eb 02                      jmp 0x10053719
  in func 0x542CB:
  00054304  51                         push ecx
  00054305  8d 7e 30                   lea edi, [esi + 0x30]
  00054308  8b c4                      mov eax, esp
  0005430A  c7 06 9c b6 32 10          mov dword ptr [esi], 0x1032b69c
>>00054310  c7 07 80 b6 32 10          mov dword ptr [edi], 0x1032b680   ; VA of generic scheduler node vtable (pool, stride 0x140) (rva 0x32B680)
  00054316  c7 00 00 00 00 00          mov dword ptr [eax], 0
  0005431C  e8 cf f5 ff ff             call 0x100538f0
  00054321  8b cf                      mov ecx, edi

- 0x32BB38 motion-task scheduler node vtable (clip fourcc +0x3C, frames +0x40): 2 instruction(s) use its VA
  in func 0x607F0:
  00060814  53                         push ebx
  00060815  8b cf                      mov ecx, edi
  00060817  d9 5e 74                   fstp dword ptr [esi + 0x74]
  0006081A  c7 06 54 bb 32 10          mov dword ptr [esi], 0x1032bb54
>>00060820  c7 07 38 bb 32 10          mov dword ptr [edi], 0x1032bb38   ; VA of motion-task scheduler node vtable (clip fourcc +0x3C, frames +0x40) (rva 0x32BB38)
  00060826  e8 95 af fd ff             call 0x1003b7c0
  0006082B  53                         push ebx
  0006082C  8b cf                      mov ecx, edi
  in func 0x608B8:
  000608C3  57                         push edi
  000608C4  8d 7e 34                   lea edi, [esi + 0x34]
  000608C7  c7 06 54 bb 32 10          mov dword ptr [esi], 0x1032bb54
  000608CD  8b cf                      mov ecx, edi
>>000608CF  c7 07 38 bb 32 10          mov dword ptr [edi], 0x1032bb38   ; VA of motion-task scheduler node vtable (clip fourcc +0x3C, frames +0x40) (rva 0x32BB38)
  000608D5  e8 06 ae fd ff             call 0x1003b6e0
  000608DA  85 c0                      test eax, eax
  000608DC  74 11                      je 0x100608ef

- 0x32CF5C constant at node +0x14/+0x20: 2 instruction(s) use its VA
  in func 0x81446:
  000814B0  8b c1                      mov eax, ecx
  000814B2  c6 40 0b 04                mov byte ptr [eax + 0xb], 4
  000814B6  8b 48 08                   mov ecx, dword ptr [eax + 8]
  000814B9  81 e1 00 00 00 ff          and ecx, 0xff000000
>>000814BF  c7 00 5c cf 32 10          mov dword ptr [eax], 0x1032cf5c   ; VA of constant at node +0x14/+0x20 (rva 0x32CF5C)
  000814C5  c7 40 04 00 00 00 00       mov dword ptr [eax + 4], 0
  000814CC  89 48 08                   mov dword ptr [eax + 8], ecx
  000814CF  c3                         ret 
  in func 0x814D0:
  000814EA  5e                         pop esi
  000814EB  c2 04 00                   ret 4
  000814EE  90                         nop 
  000814EF  90                         nop 
>>000814F0  c7 01 5c cf 32 10          mov dword ptr [ecx], 0x1032cf5c   ; VA of constant at node +0x14/+0x20 (rva 0x32CF5C)
  000814F6  c3                         ret 
  000814F7  90                         nop 
  000814F8  90                         nop 

- 0x32D69C constant at node +0x8C: 3 instruction(s) use its VA
  in func 0x89FD0:
  0008A12F  90                         nop 
  0008A130  56                         push esi
  0008A131  8b f1                      mov esi, ecx
  0008A133  6a 00                      push 0
>>0008A135  c7 06 9c d6 32 10          mov dword ptr [esi], 0x1032d69c   ; VA of constant at node +0x8C (rva 0x32D69C)
  0008A13B  e8 20 02 00 00             call 0x1008a360
  0008A140  8b c6                      mov eax, esi
  0008A142  5e                         pop esi
  in func 0x89FD0:
  0008A150  8b 44 24 04                mov eax, dword ptr [esp + 4]
  0008A154  56                         push esi
  0008A155  8b f1                      mov esi, ecx
  0008A157  50                         push eax
>>0008A158  c7 06 9c d6 32 10          mov dword ptr [esi], 0x1032d69c   ; VA of constant at node +0x8C (rva 0x32D69C)
  0008A15E  e8 fd 01 00 00             call 0x1008a360
  0008A163  8b c6                      mov eax, esi
  0008A165  5e                         pop esi
  in func 0x8A7B2:
  0008A7BE  90                         nop 
  0008A7BF  90                         nop 
  0008A7C0  56                         push esi
  0008A7C1  8b f1                      mov esi, ecx
>>0008A7C3  c7 06 9c d6 32 10          mov dword ptr [esi], 0x1032d69c   ; VA of constant at node +0x8C (rva 0x32D69C)
  0008A7C9  e8 72 46 00 00             call 0x1008ee40
  0008A7CE  8b ce                      mov ecx, esi
  0008A7D0  5e                         pop esi

- 0x330F40 CXiSkeletonActor vtable (actor +0): 6 instruction(s) use its VA
  in func 0xC525E:
  000C5327  e8 44 6f fa ff             call 0x1006c270
  000C532C  8d 8e 98 09 00 00          lea ecx, [esi + 0x998]
  000C5332  e8 69 26 f6 ff             call 0x100279a0
  000C5337  8b ce                      mov ecx, esi
>>000C5339  c7 06 40 0f 33 10          mov dword ptr [esi], 0x10330f40   ; VA of CXiSkeletonActor vtable (actor +0) (rva 0x330F40)
  000C533F  e8 2c 0a 00 00             call 0x100c5d70
  000C5344  8b 44 24 14                mov eax, dword ptr [esp + 0x14]
  000C5348  89 86 c4 08 00 00          mov dword ptr [esi + 0x8c4], eax
  in func 0xC525E:
  000C55E7  e8 84 6c fa ff             call 0x1006c270
  000C55EC  8d 8e 98 09 00 00          lea ecx, [esi + 0x998]
  000C55F2  e8 a9 23 f6 ff             call 0x100279a0
  000C55F7  8b ce                      mov ecx, esi
>>000C55F9  c7 06 40 0f 33 10          mov dword ptr [esi], 0x10330f40   ; VA of CXiSkeletonActor vtable (actor +0) (rva 0x330F40)
  000C55FF  e8 6c 07 00 00             call 0x100c5d70
  000C5604  8b 6c 24 14                mov ebp, dword ptr [esp + 0x14]
  000C5608  8b 44 24 18                mov eax, dword ptr [esp + 0x18]
  in func 0xC525E:
  000C5767  e8 04 6b fa ff             call 0x1006c270
  000C576C  8d 8e 98 09 00 00          lea ecx, [esi + 0x998]
  000C5772  e8 29 22 f6 ff             call 0x100279a0
  000C5777  8b 5c 24 18                mov ebx, dword ptr [esp + 0x18]
>>000C577B  c7 06 40 0f 33 10          mov dword ptr [esi], 0x10330f40   ; VA of CXiSkeletonActor vtable (actor +0) (rva 0x330F40)
  000C5781  8b ce                      mov ecx, esi
  000C5783  89 b3 a0 00 00 00          mov dword ptr [ebx + 0xa0], esi   ; ent.ActorPointer?
  000C5789  e8 e2 05 00 00             call 0x100c5d70
  in func 0xC525E:
  000C5907  e8 64 69 fa ff             call 0x1006c270
  000C590C  8d 8e 98 09 00 00          lea ecx, [esi + 0x998]
  000C5912  e8 89 20 f6 ff             call 0x100279a0
  000C5917  8b ce                      mov ecx, esi
>>000C5919  c7 06 40 0f 33 10          mov dword ptr [esi], 0x10330f40   ; VA of CXiSkeletonActor vtable (actor +0) (rva 0x330F40)
  000C591F  e8 4c 04 00 00             call 0x100c5d70
  000C5924  8b 6c 24 14                mov ebp, dword ptr [esp + 0x14]
  000C5928  8b 44 24 20                mov eax, dword ptr [esp + 0x20]
  in func 0xC59C0:
  000C5A40  e8 5b 1f f6 ff             call 0x100279a0
  000C5A45  8b 96 88 00 00 00          mov edx, dword ptr [esi + 0x88]
  000C5A4B  8b ce                      mov ecx, esi
  000C5A4D  83 ca 08                   or edx, 8
>>000C5A50  c7 06 40 0f 33 10          mov dword ptr [esi], 0x10330f40   ; VA of CXiSkeletonActor vtable (actor +0) (rva 0x330F40)
  000C5A56  89 96 88 00 00 00          mov dword ptr [esi + 0x88], edx
  000C5A5C  e8 0f 03 00 00             call 0x100c5d70
  000C5A61  8b 44 24 14                mov eax, dword ptr [esp + 0x14]
  in func 0xC5B71:
  000C5C0F  90                         nop 
  000C5C10  56                         push esi
  000C5C11  8b f1                      mov esi, ecx
  000C5C13  57                         push edi
>>000C5C14  c7 06 40 0f 33 10          mov dword ptr [esi], 0x10330f40   ; VA of CXiSkeletonActor vtable (actor +0) (rva 0x330F40)
  000C5C1A  8b 86 64 07 00 00          mov eax, dword ptr [esi + 0x764]
  000C5C20  85 c0                      test eax, eax
  000C5C22  74 29                      je 0x100c5c4d

### 3. Fourcc literals used as instruction operands

- 'ini' 0x00696E69: 0 site(s)
- 'init' 0x74696E69: 10 site(s)
  in func 0x85F03:
  00085F14  e8 87 bf fe ff             call 0x10071ea0
  00085F19  8b 06                      mov eax, dword ptr [esi]
  00085F1B  6a 00                      push 0
  00085F1D  56                         push esi
>>00085F1E  68 69 6e 69 74             push 0x74696e69   ; 'init'
  00085F23  8b ce                      mov ecx, esi
  00085F25  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  00085F2B  8b ce                      mov ecx, esi
  00085F2D  e8 de e4 ff ff             call 0x10084410
  in func 0x85F03:
  00085F44  ff 92 90 02 00 00          call dword ptr [edx + 0x290]
  00085F4A  8b 06                      mov eax, dword ptr [esi]
  00085F4C  6a 00                      push 0
  00085F4E  56                         push esi
>>00085F4F  68 69 6e 69 74             push 0x74696e69   ; 'init'
  00085F54  8b ce                      mov ecx, esi
  00085F56  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  00085F5C  6a ff                      push -1
  00085F5E  8b ce                      mov ecx, esi
  in func 0x8C561:
  0008C55C  e9 b3 00 00 00             jmp 0x1008c614
  0008C561  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C567  6a 00                      push 0
  0008C569  51                         push ecx
>>0008C56A  68 69 6e 69 74             push 0x74696e69   ; 'init'
  0008C56F  8b 01                      mov eax, dword ptr [ecx]
  0008C571  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  0008C577  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C57D  6a 00                      push 0
  in func 0x8C5A8:
  0008C5CD  ff 92 a8 00 00 00          call dword ptr [edx + 0xa8]
  0008C5D3  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C5D9  6a 00                      push 0
  0008C5DB  51                         push ecx
>>0008C5DC  68 69 6e 69 74             push 0x74696e69   ; 'init'
  0008C5E1  8b 11                      mov edx, dword ptr [ecx]
  0008C5E3  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  0008C5E9  8b 86 a0 00 00 00          mov eax, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C5EF  8b cf                      mov ecx, edi
  in func 0xAB4A0:
  000AB49B  e9 40 07 00 00             jmp 0x100abbe0
  000AB4A0  8b 16                      mov edx, dword ptr [esi]
  000AB4A2  6a 00                      push 0
  000AB4A4  56                         push esi
>>000AB4A5  68 69 6e 69 74             push 0x74696e69   ; 'init'
  000AB4AA  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  000AB4B0  c6 86 b8 0c 00 00 01       mov byte ptr [esi + 0xcb8], 1
  000AB4B7  8b ce                      mov ecx, esi
  000AB4B9  5e                         pop esi
  in func 0xC4A3D:
  000C4A78  75 12                      jne 0x100c4a8c
  000C4A7A  8b 16                      mov edx, dword ptr [esi]
  000C4A7C  6a 00                      push 0
  000C4A7E  56                         push esi
>>000C4A7F  68 69 6e 69 74             push 0x74696e69   ; 'init'
  000C4A84  8b ce                      mov ecx, esi
  000C4A86  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  000C4A8C  c6 86 7a 07 00 00 01       mov byte ptr [esi + 0x77a], 1
  000C4A93  8b 86 e4 00 00 00          mov eax, dword ptr [esi + 0xe4]
  in func 0xCE241:
  000CE265  56                         push esi
  000CE266  57                         push edi
  000CE267  8b 7c 24 3c                mov edi, dword ptr [esp + 0x3c]
  000CE26B  8b d9                      mov ebx, ecx
>>000CE26D  81 ff 69 6e 69 74          cmp edi, 0x74696e69   ; 'init'
  000CE273  75 1f                      jne 0x100ce294
  000CE275  8b 03                      mov eax, dword ptr [ebx]
  000CE277  8d 4c 24 14                lea ecx, [esp + 0x14]
  000CE27B  51                         push ecx
  in func 0xCE59D:
  000CE59D  8b 76 08                   mov esi, dword ptr [esi + 8]
  000CE5A0  85 f6                      test esi, esi
  000CE5A2  0f 85 12 ff ff ff          jne 0x100ce4ba
  000CE5A8  8b 7c 24 40                mov edi, dword ptr [esp + 0x40]
>>000CE5AC  81 ff 69 6e 69 74          cmp edi, 0x74696e69   ; 'init'
  000CE5B2  75 1f                      jne 0x100ce5d3
  000CE5B4  8b 03                      mov eax, dword ptr [ebx]
  000CE5B6  8d 4c 24 3c                lea ecx, [esp + 0x3c]
  000CE5BA  51                         push ecx
  in func 0xCE790:
  000CE795  56                         push esi
  000CE796  57                         push edi
  000CE797  8b 7c 24 40                mov edi, dword ptr [esp + 0x40]
  000CE79B  8b d9                      mov ebx, ecx
>>000CE79D  81 ff 69 6e 69 74          cmp edi, 0x74696e69   ; 'init'
  000CE7A3  c7 44 24 14 00 00 00 00    mov dword ptr [esp + 0x14], 0
  000CE7AB  75 1f                      jne 0x100ce7cc
  000CE7AD  8b 03                      mov eax, dword ptr [ebx]
  000CE7AF  8d 4c 24 18                lea ecx, [esp + 0x18]
  in func 0xD1046:
  000D1043  c2 08 00                   ret 8
  000D1046  85 db                      test ebx, ebx
  000D1048  74 19                      je 0x100d1063
  000D104A  8b 16                      mov edx, dword ptr [esi]
>>000D104C  b8 69 6e 69 74             mov eax, 0x74696e69   ; 'init'
  000D1051  6a 00                      push 0
  000D1053  56                         push esi
  000D1054  50                         push eax
  000D1055  8b ce                      mov ecx, esi
- 'ini1' 0x31696E69: 0 site(s)
- 'pop0' 0x30706F70: 1 site(s)
  in func 0x90A5B:
  00090A59  eb 16                      jmp 0x10090a71
  00090A5B  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  00090A61  6a 00                      push 0
  00090A63  51                         push ecx
>>00090A64  68 70 6f 70 30             push 0x30706f70   ; 'pop0'
  00090A69  8b 01                      mov eax, dword ptr [ecx]
  00090A6B  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  00090A71  c6 86 44 01 00 00 00       mov byte ptr [esi + 0x144], 0
  00090A78  8b 86 2c 01 00 00          mov eax, dword ptr [esi + 0x12c]
- 'pop1' 0x31706F70: 1 site(s)
  in func 0x908EC:
  00090A41  75 2e                      jne 0x10090a71
  00090A43  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  00090A49  6a 00                      push 0
  00090A4B  51                         push ecx
>>00090A4C  68 70 6f 70 31             push 0x31706f70   ; 'pop1'
  00090A51  8b 11                      mov edx, dword ptr [ecx]
  00090A53  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  00090A59  eb 16                      jmp 0x10090a71
  00090A5B  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
- 'sp00' 0x30307073: 0 site(s)
- 'sp10' 0x30317073: 0 site(s)
- 24-bit 'ini' (0x00696E69 masked) or byte writes of 'i','n','i':
  in func 0x85F03:
  00085F14  e8 87 bf fe ff             call 0x10071ea0
  00085F19  8b 06                      mov eax, dword ptr [esi]
  00085F1B  6a 00                      push 0
  00085F1D  56                         push esi
>>00085F1E  68 69 6e 69 74             push 0x74696e69   ; 'init'
  00085F23  8b ce                      mov ecx, esi
  00085F25  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  00085F2B  8b ce                      mov ecx, esi
  00085F2D  e8 de e4 ff ff             call 0x10084410
  in func 0x85F03:
  00085F44  ff 92 90 02 00 00          call dword ptr [edx + 0x290]
  00085F4A  8b 06                      mov eax, dword ptr [esi]
  00085F4C  6a 00                      push 0
  00085F4E  56                         push esi
>>00085F4F  68 69 6e 69 74             push 0x74696e69   ; 'init'
  00085F54  8b ce                      mov ecx, esi
  00085F56  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  00085F5C  6a ff                      push -1
  00085F5E  8b ce                      mov ecx, esi
  in func 0x8C561:
  0008C55C  e9 b3 00 00 00             jmp 0x1008c614
  0008C561  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C567  6a 00                      push 0
  0008C569  51                         push ecx
>>0008C56A  68 69 6e 69 74             push 0x74696e69   ; 'init'
  0008C56F  8b 01                      mov eax, dword ptr [ecx]
  0008C571  ff 90 98 02 00 00          call dword ptr [eax + 0x298]
  0008C577  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C57D  6a 00                      push 0
  in func 0x8C5A8:
  0008C5CD  ff 92 a8 00 00 00          call dword ptr [edx + 0xa8]
  0008C5D3  8b 8e a0 00 00 00          mov ecx, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C5D9  6a 00                      push 0
  0008C5DB  51                         push ecx
>>0008C5DC  68 69 6e 69 74             push 0x74696e69   ; 'init'
  0008C5E1  8b 11                      mov edx, dword ptr [ecx]
  0008C5E3  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  0008C5E9  8b 86 a0 00 00 00          mov eax, dword ptr [esi + 0xa0]   ; ent.ActorPointer?
  0008C5EF  8b cf                      mov ecx, edi
  in func 0xAB4A0:
  000AB49B  e9 40 07 00 00             jmp 0x100abbe0
  000AB4A0  8b 16                      mov edx, dword ptr [esi]
  000AB4A2  6a 00                      push 0
  000AB4A4  56                         push esi
>>000AB4A5  68 69 6e 69 74             push 0x74696e69   ; 'init'
  000AB4AA  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  000AB4B0  c6 86 b8 0c 00 00 01       mov byte ptr [esi + 0xcb8], 1
  000AB4B7  8b ce                      mov ecx, esi
  000AB4B9  5e                         pop esi
  in func 0xC4A3D:
  000C4A78  75 12                      jne 0x100c4a8c
  000C4A7A  8b 16                      mov edx, dword ptr [esi]
  000C4A7C  6a 00                      push 0
  000C4A7E  56                         push esi
>>000C4A7F  68 69 6e 69 74             push 0x74696e69   ; 'init'
  000C4A84  8b ce                      mov ecx, esi
  000C4A86  ff 92 98 02 00 00          call dword ptr [edx + 0x298]
  000C4A8C  c6 86 7a 07 00 00 01       mov byte ptr [esi + 0x77a], 1
  000C4A93  8b 86 e4 00 00 00          mov eax, dword ptr [esi + 0xe4]
  in func 0xCE241:
  000CE265  56                         push esi
  000CE266  57                         push edi
  000CE267  8b 7c 24 3c                mov edi, dword ptr [esp + 0x3c]
  000CE26B  8b d9                      mov ebx, ecx
>>000CE26D  81 ff 69 6e 69 74          cmp edi, 0x74696e69   ; 'init'
  000CE273  75 1f                      jne 0x100ce294
  000CE275  8b 03                      mov eax, dword ptr [ebx]
  000CE277  8d 4c 24 14                lea ecx, [esp + 0x14]
  000CE27B  51                         push ecx
  in func 0xCE241:
  000CE286  85 c0                      test eax, eax
  000CE288  74 0a                      je 0x100ce294
  000CE28A  83 38 00                   cmp dword ptr [eax], 0
  000CE28D  74 05                      je 0x100ce294
>>000CE28F  bf 69 6e 69 30             mov edi, 0x30696e69   ; fourcc? 'ini0'
  000CE294  8b 13                      mov edx, dword ptr [ebx]
  000CE296  8d 44 24 14                lea eax, [esp + 0x14]
  000CE29A  50                         push eax
  000CE29B  8b cb                      mov ecx, ebx
  in func 0xCE59D:
  000CE59D  8b 76 08                   mov esi, dword ptr [esi + 8]
  000CE5A0  85 f6                      test esi, esi
  000CE5A2  0f 85 12 ff ff ff          jne 0x100ce4ba
  000CE5A8  8b 7c 24 40                mov edi, dword ptr [esp + 0x40]
>>000CE5AC  81 ff 69 6e 69 74          cmp edi, 0x74696e69   ; 'init'
  000CE5B2  75 1f                      jne 0x100ce5d3
  000CE5B4  8b 03                      mov eax, dword ptr [ebx]
  000CE5B6  8d 4c 24 3c                lea ecx, [esp + 0x3c]
  000CE5BA  51                         push ecx
  in func 0xCE59D:
  000CE5C5  85 c0                      test eax, eax
  000CE5C7  74 0a                      je 0x100ce5d3
  000CE5C9  83 38 00                   cmp dword ptr [eax], 0
  000CE5CC  74 05                      je 0x100ce5d3
>>000CE5CE  bf 69 6e 69 30             mov edi, 0x30696e69   ; fourcc? 'ini0'
  000CE5D3  8b 13                      mov edx, dword ptr [ebx]
  000CE5D5  8d 44 24 3c                lea eax, [esp + 0x3c]
  000CE5D9  50                         push eax
  000CE5DA  8b cb                      mov ecx, ebx

### 5. ActionTimer2 = 1800 stores and +0x11C/+0x11E accesses

- `mov [reg+0x11E], 0x708`: 2 site(s)
  func 0xA4110 (2 store(s)); callers: 
  000A4149  90                         nop 
  000A414A  90                         nop 
  000A414B  90                         nop 
  000A414C  90                         nop 
  000A414D  90                         nop 
  000A414E  90                         nop 
  000A414F  90                         nop 
  000A4150  66 ff 81 1c 01 00 00       inc word ptr [ecx + 0x11c]   ; ent.ActionTimer1?
>>000A4157  66 c7 81 1e 01 00 00 08 07 mov word ptr [ecx + 0x11e], 0x708   ; ent.ActionTimer2?
  000A4160  c3                         ret 
  000A4161  90                         nop 
  000A4162  90                         nop 
  000A4163  90                         nop 
  000A4164  90                         nop 
  000A4165  90                         nop 

- any access to [reg+0x11C] (ActionTimer1, byte/word): 23 site(s) in 15 funcs: 0x1AD1D3, 0x1ADA5D, 0x1B9883, 0x1B9ADE, 0x1B9C54, 0x2C364F, 0x2C45BC, 0x2C4635, 0x2EF464, 0x2F1FEC, 0x8332C, 0x8A2C1, 0x8E9A9, 0x95850, 0xA4110

Next: feed the function RVAs above to p2_handler.py / xref.py.

````
