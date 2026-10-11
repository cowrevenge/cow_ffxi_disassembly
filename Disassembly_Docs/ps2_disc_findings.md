# PS2 disc findings (side work, 2026-10-11)

Tier: `[web]`/hypothesis for anything about the Windows client. Different
platform, different compiler (Metrowerks MIPS C 2.4.1), different build.
Nothing here is ground truth for FFXiMain.dll retail-2026-09.

## Sources examined

| Disc | Boot ELF | Installer | PATCH.VER |
|---|---|---|---|
| Seekers of Adoulin (JP) | `SLPM_552.98` (2005) | `INSTALL.ELF` (2012) | `20121130_0` |
| Vana'diel Collection (US) | `SLUS_217.04` (2005) | `INSTALL.ELF` | n/a |

`SLPSBOOT.ELF` in `POL\` is byte-identical to `SLPM_552.98`.

## Symbols

None. Both boot ELFs are stripped (`.mdebug.eabi64` is 0 bytes). Both
`INSTALL.ELF`s have `.symtab`/`.strtab` headers with size 0. No DWARF, no
function names.

## Boot chain (high level)

1. `SYSTEM.CNF` `BOOT2` launches the booter (`SLPM_552.98` / `SLUS_217.04`).
2. Booter loads the PlayOnline viewer `POL\POL.PEX` (Square's packed
   executable format), or the HDD copy once installed.
3. PlayOnline runs `INSTALL.ELF` to install FFXI to the PS2 HDD:
   `DANCER.ENC` and `FFXI_POL.ENC` are copied to
   `/image/ffxi/prog/ps2/dancer.enc` and `ffxi_pol.pex.enc`, plus the ROM DATs.
4. At launch the game core is loaded as `Dancer.bin`.

`DANCER.ENC` is the PS2 game core (name matches the `C:\dev\dancer\` engine
in the DLL). It is encrypted and bound to Sony DNAS and per-console/HDD
identifiers. Not recoverable from disc contents; out of scope, parked.

## Leaked source file names

48 names recovered from error/assert strings in the two `INSTALL.ELF`s and
boot ELFs. Full list: `ps2_source_names.txt`.

They group by prefix, which looks like Square's per-team/module naming:

- `gc*` (C): game client systems: `gcbazaar gcchat gcconf gcequip gcfeat gcgm gcgroup gcitem gcmagic gcmain gcmyroom gcshop gcswitch gctracking gczone`
- `gp*` (C): `gpequip gpgame`
- `nt*`: network: `ntIP ntgame ntsys nttime ntudp`
- `Fs*` (C++): text input / IME: `FsCandidateMenu FsPreParser FsTextInputBase FsWordCompletion fsmain`
- `Xi*` (C++): `XiFileImpl XiTextModule xicontrolactor`
- `km*` (C++): items: `kmItem kmItemBase`
- `gn*` (C++): `gnNewMem gnString GNMmLink.h`
- single: `JkJobChange KzObject TkInputCtrl commandcalc fdtFFXiService polinterface auth_ps2 enacv enque libat3dec libscf psfiles.h q.c`

## Cross-check against the retail DLL

Checked every name and stem against `FFXiMain.unpacked.dll` strings and
`tables_classnames.csv` (from `artifacts/ffximain_tables_v0.zip`).

- No PS2 file name appears as a path in the DLL. The DLL's 95 leaked paths
  are all `C:\dev\dancer\modules\sq*` and `D:\build0001\FFXi_Win\Main\`.
- Real matches by name:
  - `xicontrolactor.cpp` ↔ class `CXiControlActor` (descriptor string @ VA `0x1035bcec`)
  - `gcmyroom.c` ↔ string `gcMyroomDancerGet() failed` (DLL offset `0x388d04`)
  - `psfiles.h` ↔ string `psfiles date[%d:%d:%d]` (DLL offset `0x357ff4`)
- False positives, ignore: `ntIP` (hit `ClientIP`), `nttime` (hit `cnttime`), `q.c`.

## Use for the readable-source loop

- `CXiControlActor` code can be filed under a source file named
  `XiControlActor.cpp`. Hypothesis tier, needs DLL evidence for structure.
- Functions around `gcMyroomDancerGet` are candidates for a `gcmyroom.c`
  unit; the `gc*` prefix suggests a C "game client" layer the DLL path table
  does not show.
- The prefix groups are naming leads only. Do not create TUs from them
  without DLL evidence.
