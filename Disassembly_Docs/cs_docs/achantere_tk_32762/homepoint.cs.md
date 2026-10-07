# Achantere, T.K. (Northern San d'Oria, zone 231) — event 32762, Home Point branch

Event DAT `ROM/21/40.DAT`, block for actor `0x010E704F`, tag `0x7FFA` (32762) at offset `0x0002`.
Strings are zone 231's string DAT (`ROM/25/40.DAT`); message operands are `ImidData` references
dereferenced to that file's indices.

The player reaches this branch by picking **"I'd like to set my home point here."** — option 1 of the
overseer's sub-menu 11840 ("What do you want?"), which is offered from the overseer's top menu 11753
("What is your business?"). The menu choice lands in `Work_Zone[0]` (0-based) via
`QUERYWAIT`; the bytecode writes the server's end-para `Work_Zone[1] = 4` (Home Point) just before the
cast. The server (`vendor/server/scripts/globals/conquest.lua`, `overseerOnEventFinish` option 4) then
charges the home-point fee and calls `setHomePoint`.

Offsets are bytes into the 13 645-byte `EventData`. "player" = `0x7FFFFFF0`, "guard/event entity" =
`0x7FFFFFF8`.

## Menu select

| off | op | operands | what it does | actor |
|---|---|---|---|---|
| `0x0975` | `0x24` QUERY | msg=`Imid[0x78]`=11840 | Open the "What do you want?" menu (Signet / Home point / Nothing) | player |
| `0x097c` | `0x25` QUERYWAIT | — | Hold until the player picks; choice → `WZ[0]` | player |
| `0x097d` | `0x02` IF | `WZ[0] == 0` | Signet picked → fall to `0x0985`; Home point / Nothing → jump `0x09e6` | — |
| `0x09e6` | `0x02` IF | `WZ[0] == 1` | Home point picked (option 1) → fall to `0x09ee`; Nothing → jump `0x09f9` (end) | — |

## Home point — set the end-para and jump to the cast

| off | op | operands | what it does | actor |
|---|---|---|---|---|
| `0x09ee` | `0x03` GET_STORE | `WZ[1] = Imid[0x02]`=4 | set the end-para to 4 (Home Point) | — |
| `0x09f3` | `0x1A` JUMP | `0x0b4e` | into the home-point cast epilogue | — |

### Fee-confirmation variant

Some entry routes reach the home point through a fee check instead of the direct `0x09ee`. The fee is
computed from the player's rank into `W[0x0E]` (100/200/400/800/1600/2400/3200/4000/4800/5600 for
ranks 0–9), copied to `WZ[9]`, and confirmed through menu 11841:

| off | op | operands | what it does | actor |
|---|---|---|---|---|
| `0x09fc` | `0x02` IF | `W[2] == 7` | gate into the fee table | — |
| `0x0a07`–`0x0ab7` | `0x02` IF ×10 + `0x03` GET_STORE | `W[7] == rank` → `W[0x0E] = fee` | fee by rank (100 … 5600) | — |
| `0x0abc` | `0x03` GET_STORE | `WZ[9] = W[0x0E]` | publish the fee | — |
| `0x0ac1` | `0x24` QUERY | msg=`Imid[0x88]`=11841 | "Pay {fee} gil and set my home point here." / "Nothing." | player |
| `0x0ac8` | `0x25` QUERYWAIT | — | hold until the player picks; choice → `WZ[0]` | player |
| `0x0ac9` | `0x02` IF | `WZ[0] == 0` | pay (option 0) → fall; Nothing → jump `0x0aed` (end) | — |
| `0x0ad1` | `0x03` GET_STORE | `WZ[1] = Imid[0x02]`=4 | set the end-para to 4 (Home Point) | — |
| `0x0ad6` | `0x43` SENDTAG | case 0 | tell the server the event updated (`EndPara = WZ[1]`) | — |
| `0x0ad8` | `0x43` SENDTAG | case 1 | poll until the server acknowledges | — |
| `0x0ae7` | `0x1A` JUMP | `0x0b4e` | into the home-point cast epilogue | — |

## Home-point cast epilogue

| off | op | operands | what it does | actor |
|---|---|---|---|---|
| `0x0b4e` | `0x42` CANCEL_DISARM | — | clear the cancel flag | — |
| **`0x0b4f`** | **`0x73` MAGICSCHEDULOR** | **key=`Imid[0x8D]`=504, ent1=guard, ent2=player** | **★ PLAYS THE HOME-POINT CAST: schedules the `main` routine of key 504 on the guard with the player as partner — the vfx on the player as the home point is set** | **guard → player** |
| `0x0b5a` | `0x1D` MESSAGE | 11844 | "I will set your home point here." | guard |
| `0x0b5d` | `0x23` MESWAIT | — | hold for dismiss | player |
| `0x0b5e` | `0x1C` WAIT | `Imid[0x8F]`=150 | hold 150/60 s while the cast plays | — |
| `0x0b61` | `0x1B` RETURN | — | end the request; VM sends c2s `0x005B` EVENT_END with `EndPara = WZ[1] = 4` | — |

## The player-visual line

- **`0x0b4f` `0x73` MAGICSCHEDULOR, key `504`** (ent1 = guard `0x7FFFFFF8`, ent2 = player
  `0x7FFFFFF0`). This is the home-point cast. Per `research/XiEvents/OpCodes/0x0073.md` it calls
  `FUNC_XiActor_Unknown(guard, 504, player, 'main')` — i.e. it plays the `main`-tagged routine whose
  key is `504` on the guard, with the player as the target/partner. The key `504` is a work-offset
  value (`Imid[0x8D]`), not a DAT id. This is the line that produces the visual on the player, and it
  is the line that does **not** play in kuluu (see `report.md`).
