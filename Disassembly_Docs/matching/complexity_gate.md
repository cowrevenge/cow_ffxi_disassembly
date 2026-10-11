# Complexity gate

Decides what an unattended run is allowed to pick up. The point is to keep
overnight runs producing exact functions instead of burning hours on one
monster.

## Default queue rule

Queue a remaining function automatically only when all hold:

- padded size below about `0x60`
- small, unambiguous local state
- low relocation count
- no large inlined helper or private-ABI cluster dominating it
- not already exact, credited, or parked in the ledger

## Bigger functions

Anything larger needs a written leverage reason in its ledger row before it
gets a lane:

- new structure proof (a recovered class layout, descriptor, or field owner)
- a hardware-forced register anchor that unlocks a cluster
- reusable subsystem insight (e.g. solving one event VM handler shape
  that the other 218 jump-table entries share)

## Ordering hint

Within a TU, do leaf functions and forced-register callers first, then
propagate. Large x87 math routines (joint integrator, camera basis) go last
unless a pass doc already pins their structure.
