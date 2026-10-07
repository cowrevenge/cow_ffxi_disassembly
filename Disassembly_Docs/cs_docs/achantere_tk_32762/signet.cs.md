# Achantere, T.K. (Northern San d'Oria, zone 231) — event 32762, Signet branch

Event DAT `ROM/21/40.DAT`, block for actor `0x010E704F`, tag `0x7FFA` (32762) at offset `0x0002`.
The tag entry is a one-byte `JUMP 0x0006` into the shared program. Strings are zone 231's string DAT
(`ROM/25/40.DAT`); message operands below are `ImidData` references dereferenced to that file's indices.

The player reaches this branch by picking **"Would you cast Signet on me?"** — option 0 of the
overseer's sub-menu 11840 ("What do you want?"), which is offered from the overseer's top menu 11753
("What is your business?"). The menu choice lands in `Work_Zone[0]` (0-based) via `QUERYWAIT`; the
bytecode then writes the server's end-para `Work_Zone[1] = 1` (Signet) just before `RETURN`.

Offsets are bytes into the 13 645-byte `EventData`. "player" = `0x7FFFFFF0`, "guard/event entity" =
`0x7FFFFFF8`.

## Menu select

| off | op | operands | what it does | actor |
|---|---|---|---|---|
| `0x0975` | `0x24` QUERY | msg=`Imid[0x78]`=11840 | Open the "What do you want?" menu (Signet / Home point / Nothing) | player |
| `0x097c` | `0x25` QUERYWAIT | — | Hold until the player picks; choice → `WZ[0]` | player |
| `0x097d` | `0x02` IF | `WZ[0] == 0` | Signet picked (option 0) → fall through; anything else jumps to `0x09e6` (home-point/nothing) | — |

## Eligibility / region beat (work-slot gated)

The guard checks the player's standing before bestowing the Signet. These branch on local work slots
the entry code derives from the server params, so the exact line taken varies per player; the path
below is the one that reaches the cast.

| off | op | operands | what it does | actor |
|---|---|---|---|---|
| `0x0985` | `0x02` IF | `W[1] == W[5]` | not equal → jump `0x09e0` (straight to the epilogue); equal → fall to the region beat | — |
| `0x098d` | `0x02` IF | `W[0x1D] == 1` | region-state selector (beastman / dominant / major / minor / minimal) | — |
| `0x0995` | `0x1D` MESSAGE | 11886 | "…this area is currently overrun with beastmen!…" | guard |
| `0x0998` | `0x23` MESWAIT | — | hold for dismiss | player |
| `0x09a4`–`0x09d1` | `0x02` IF ×4 | `W[0x1C] == 3/2/1/0` | pick one of 11882/11883/11884/11885 (the other region states) | guard |
| `0x09e0` | `0x1A` JUMP | `0x0aef` | into the shared epilogue (farewell + Signet cast) | — |

## Epilogue — the Signet is cast

| off | op | operands | what it does | actor |
|---|---|---|---|---|
| `0x0aef` | `0x42` CANCEL_DISARM | — | clear the cancel flag | — |
| `0x0af0` | `0x02` IF | `W[2] == 0` | no alliance beat → fall to `0x0af8` (skip to `0x0b28`) | — |
| `0x0af8` | `0x01` GOTO | `0x0b28` | skip the farewell lines | — |
| `0x0afb` | `0x02` IF | `W[2] == 4` | allied-nation selector (San d'Oria / Bastok / Windurst) | — |
| `0x0b03` | `0x1D` MESSAGE | 11742 | "Since we are allied with San d'Oria…" | guard |
| `0x0b06` | `0x23` MESWAIT | — | hold for dismiss | player |
| `0x0b0a` | `0x02` IF | `W[2] == 2` | else Bastok (11743 @ `0x0b12`) / Windurst (11744 @ `0x0b21`) | — |
| `0x0b28` | `0x06` SET0 | `WZ[2]` | clear the end-para side flag | — |
| `0x0b2b` | `0x02` IF | `W[1] == 1` | true → jump `0x0b36` (skip the SET1); else fall to `0x0b33` | — |
| `0x0b33` | `0x05` SET1 | `WZ[2]` | set the end-para side flag | — |
| `0x0b36` | `0x1D` MESSAGE | 11739 | "Good luck, [citizen/comrade]. I will bestow upon you your nation's Signet." | guard |
| `0x0b39` | `0x23` MESWAIT | — | hold for dismiss | player |
| **`0x0b3a`** | **`0x73` MAGICSCHEDULOR** | **key=`Imid[0x46]`=497, ent1=guard, ent2=player** | **★ PLAYS THE SIGNET CAST: schedules the `main` routine of key 497 on the guard with the player as partner — the spell animation/vfx on the player** | **guard → player** |
| `0x0b45` | `0x1C` WAIT | `Imid[0x47]`=260 | hold 260/60 s while the cast plays | — |
| `0x0b48` | `0x03` GET_STORE | `WZ[1] = Imid[0x0A]`=1 | set the end-para to 1 (Signet) | — |
| `0x0b4d` | `0x1B` RETURN | — | end the request; VM sends c2s `0x005B` EVENT_END with `EndPara = WZ[1] = 1` | — |

## The player-visual line

- **`0x0b3a` `0x73` MAGICSCHEDULOR, key `497`** (ent1 = guard `0x7FFFFFF8`, ent2 = player
  `0x7FFFFFF0`). This is the Signet spell cast. Per `research/XiEvents/OpCodes/0x0073.md` it calls
  `FUNC_XiActor_Unknown(guard, 497, player, 'main')` — i.e. it plays the `main`-tagged routine whose
  key is `497` on the guard, with the player as the target/partner. The key `497` is a work-offset
  value (`Imid[0x46]`), not a DAT id; the routine it names lives in the guard's motion resources.
  This is the line that produces the visual on the player, and it is the line that does **not** play
  in kuluu (see `report.md`).
