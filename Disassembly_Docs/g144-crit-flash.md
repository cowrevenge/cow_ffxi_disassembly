# g144 — the muted hit3 flash in the hi14 crit chain

Vault note (folded in 2026-10-08 from a session scratch file; DAT values re-read that day). All values pulled from the DAT via
`cargo run -p kuluu-render --example zz-g14-defs` and `--example zz-hi14-stages`.

## DAT location

- **ROM\0\0.DAT** — the global effect dir, generator chunk at file offset **0x059160**.
- mesh = **hit3**, a static mesh (single quad) from that same global dir.

## Order in the hi14 scheduler (8 entries)

| idx | frame | id   | delay | dur  | what it is                                                        |
|-----|-------|------|-------|------|-------------------------------------------------------------------|
| 0   | 0     | —    | —     | —    | StartRoutineMarker                                                |
| 1   | 0     | g14s | 0     | 0    | SOUND sep=5008 (crit SE), far=30 near=0, life=60                  |
| 2   | 0     | g140 | 0     | 0    | eis1 SpriteSheet — sparkle, grows to 0.65× (k140/k141)            |
| 3   | 0     | g143 | 0     | 0    | hit1 SpriteSheet — central streak, grows to 0.65×                 |
| 4   | 0     | g141 | 0     | 0    | eis2 StaticMesh — the big flash, grows to **3.66×** (k142)        |
| 5   | 10    | **g144** | **10** | **0** | **hit3 StaticMesh ← this one**                                  |
| 6   | 10    | g142 | 30    | 15   | DISTORTION (0x22) — haze_x=0.02, life=45                          |
| 7   | 40    | —    | —     | —    | end marker                                                        |

g144 is the only stage that starts on routine frame 10 with its own delay (10 frames ≈ 0.17 s
after routine start); dur=0 means no explicit duration window — it lives exactly `life` frames.

## Details (verbatim from the def)

```
g144 mesh=hit3 kind=StaticMesh init_scale=(1.000,1.000,1.000) life=60 fpe=101 ppe=0
     attach=TargetActor blend=Additive blend_byte=00
     billboard=Xyz cam_bb=true rot_var=None init_rot=(0,0,0) pos_var=None sph_full=false vel=(0,0,0)
     init_color=(0.502, 0.502, 0.502, a=0.000)
```

- **kind** = StaticMesh — one quad, no flipbook frames (unlike g140/g143 SpriteSheets).
- **init_scale = (1,1,1)** — full size from frame 0. No scale k-track at all: every other visible
  hi14 generator starts at init_scale=(0,0,1) and grows via a track; g144 does not animate in.
- **life = 60** frames (1.0 s @ 60 fps).
- **fpe = 101, ppe = 0** — one-shot: frames-per-emission (101) exceeds life (60), so it emits
  exactly once and can never re-emit. It is *not* a repeating timer; all timing comes from the
  routine's delay/duration columns above.
- **attach = TargetActor** — placed at the victim, Xyz billboard facing camera.
- **blend = Additive, blend_byte = 0x00.**
- **init_color alpha = 0.000** — authored invisible. Under additive blending (src·srcA + dst),
  srcA=0 contributes nothing: g144 draws no pixels in retail.

## How it sits next to the others

g144 is the only hi14 generator with **both** full initial scale and zero alpha. The visible set
all start at scale 0, grow on k-tracks, and carry alphas of 0.25–0.50:

| gen  | mesh | init_scale      | growth track        | alpha | role in the flash            |
|------|------|-----------------|---------------------|-------|------------------------------|
| g14s | —    | —               | —                   | —     | crit sound (SE 5008)         |
| g140 | eis1 | (0,0,1)         | → 0.65×             | 0.271 | small sparkle                |
| g143 | hit1 | (0,0,1)         | → 0.65×             | 0.502 | central streak               |
| g141 | eis2 | (0,0,1)         | → **3.66×**         | 0.502 | the big expanding flash      |
| **g144** | **hit3** | **(1,1,1)**   | **none**            | **0.000** | **controller rumble cue — non-visual** |
| g142 | —    | —               | —                   | —     | screen-space haze smear      |

## What g144 actually is: controller rumble

**User-confirmed retail behavior: g144 is the controller-rumble cue for the crit, not a visual
effect.** That explains every oddity in the def at once — full initial scale, no growth track,
zero alpha: it was never meant to draw pixels. It's a non-visual element riding along in the
particle chain (the hit3 mesh is just its carrier).

Cross-check: xi-model-viewer also draws it invisible — `textureFactor = particle.getColor() ×
context opacity` (ParticleDrawer.kt:129), and the only alpha override, `shouldSnapAlpha`
(research/xim/src/jsMain/kotlin/xim/resource/Particle.kt:572), snaps to 1.0 only when
a ≥ 0.498 — g144's a=0.000 fails that. The "real crit" look in the viewer comes from **g141
(eis2 → 3.66×) + g140/g143**, not g144.


Knowledge carried with it: kuluu already renders nothing visible for g144 (correct — see alpha math
above); the genuinely-missing crit pieces were g142 distortion + g14s sound; a future controller-rumble
trigger point would be this same SpawnGenerator stage, resolved like the sound/distortion defs.
