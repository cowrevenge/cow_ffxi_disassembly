# LSB Docker Stack — Kuluu Test Bed

> **Consolidated from `Cow_doc/LSB_DOCKER.md` during the 2026-09-13 doc reorg into
> `Cow_doc/`.** Content carried over verbatim (it described the 2026-08-29
> deterministic-networking rebuild and was verified current on 2026-09-13).

Docker hosts our **LandSandBoat (LSB)** server stack. It is the live test bed / protocol
oracle for **kuluu**: kuluu speaks retail FFXI wire protocol against these containers,
so anything we can reproduce here (login, zone-in, movement sync, auction house, …)
is verified against a real implementation rather than a mock.

Defined in `dev-live/docker-compose.yml` (compose project `dev-live`).
Everything below reflects the **2026-08-29 deterministic-networking rebuild**. The older
`Archived_cowengine/dev/` stack and its RUNBOOK §3 describe the previous layout
(project `dev`, one-shot manual DNAT, `C:\CowEngine` paths) — treat those as history.

## Why Docker

- LSB is C++ with a heavy build matrix (gcc/clang, MariaDB headers, sol2, …). Containers
  give us a reproducible `ghcr.io/landsandboat/server:latest` runtime without polluting
  the Windows host toolchain.
- One command brings up the full multi-process server (connect/search/world/map + DB),
  with healthchecks and ordered startup (`db → dbtool update → everything else`).
- Volumes make the MariaDB data and the FFXI mesh sets survive container recreation.

## Containers

| Container | Image | Role | Published port(s) | Static IP |
|---|---|---|---|---|
| `cow-db` | `mariadb:12.3` | Database (`xidb`; utf8mb4) | — | 172.30.0.10 |
| `cow-dbupdate` | `landsandboat/server:latest` | One-off `dbtool.py update` migrations (runs at boot, then exits) | — | 172.30.0.60 |
| `cow-connect` | `landsandboat/server:latest` | `xi_connect` — lobby: char list/select | 54001/tcp (view), 54230/tcp (data), 54231/tcp (auth/TLS) | 172.30.0.30 |
| `cow-search` | `landsandboat/server:latest` | `xi_search` — item search (auction house) | 54002/tcp | 172.30.0.50 |
| `cow-world` | `landsandboat/server:latest` | `xi_world` — GM/orchestration, HTTP API | 8088/tcp | 172.30.0.20 |
| `cow-map` | `landsandboat/server:latest` | `xi_map` — gameplay (zone) server | 54230/**udp** | 172.30.0.40 |
| `cow-dnat` | `alpine:latest` | s2c return-path keeper (see below) | shares `cow-map`'s netns | — |
| `cow-udp-probe` | `python:3-alpine` | Echo probe for the published-UDP return path (`network_mode: host`) | 19475/udp echo, 19476/udp counter | host |

Shared env for the LSB services: `XI_NETWORK_SQL_HOST=cow-db`, `XI_NETWORK_ZMQ_IP=cow-world`,
`XI_NETWORK_HTTP_HOST=0.0.0.0`, plus DB creds `xiadmin / password / xidb`.

Notes:
- `cow-dbupdate` mounts the local LSB clone
  (`Archived_cowengine/third_party/lsb` → `/server`) so `sql/` + `tools/` exist for dbtool,
  pinned by `REPO_URL` + `COMMIT_SHA=1bcb818…` (same pin as the rest of the spec).
- `cow-map` mounts the `navmeshes` + `ximeshes` volumes into `/server/…` (global volume
  names `dev_cow_navmeshes` / `dev_cow_ximeshes`, carried over from the old stack).
- All client-facing traffic enters through **published ports on this PC**; inter-service
  traffic uses DNS names on the internal bridge.

## Deterministic networking (why this layout exists)

The old stack suffered the "UDP dies every PC restart" bug class. The fix, baked into
the compose file:

1. One named bridge network `cow` with an **explicit subnet** (`172.30.0.0/16`) — Docker
   can never silently re-pick a range on boot.
2. Every service gets a **fixed static IP** (`ipv4_address`) — topology is identical after
   every reboot/recreate.
3. Inter-service references use **DNS names**, not IPs. Nothing depends on addresses except
   the compose file itself.
4. Client-facing ports are declared once, here.

## The DNAT sidecar (`cow-dnat`) — load-bearing, do not remove

Docker Desktop's published-UDP proxy delivers *our* datagrams to `cow-map` but **never
delivers `cow-map`'s s2c replies back to this PC**. Without compensation the login succeeds
and then map traffic goes silent (no `[sync]` line, "datagram silently dropped").

`cow-dnat` joins `cow-map`'s network namespace (`network_mode: service:map`, `NET_ADMIN`)
and keeps two iptables rules alive in a loop:

```
raw PREROUTING:  -p udp --dport 54230 -j NOTRACK
nat OUTPUT:      -p udp --sport 54230 -j DNAT --to-destination $HOST_IP:$CLIENT_PORT
```

- `NOTRACK` is load-bearing: without it conntrack reverse-mapping bypasses nat OUTPUT.
- `HOST_IP` = this PC's LAN IP. **The test machine holds a forced/static IP of
  `192.168.40.231`** — it does not move, so the compose default is correct as-is.
  If you ever run the stack from a different machine, put `HOST_IP=<ip>` in a `.env`
  file next to the compose file (picked up automatically).
- `CLIENT_PORT` (default **47500**) must match `FFXI_MAP_LOCAL_PORT` — the port kuluu binds
  its map socket to (`play_cowland.bat` sets it).
- Cadence: re-checks every 15 s while stable, 3 s if a rule vanished. A
  `[dnat] VERIFIED: both rules live` line in `docker logs cow-dnat` = safe to log in.
- Rules live in `cow-map`'s netns and die when it restarts — the keeper re-arms itself,
  which is why nothing is manual anymore.

## UDP health check

`cow-udp-probe` runs a tiny Python echo server on the PC's real interfaces
(`network_mode: host`) and answers `ECHO:<payload>`. From the host:

```powershell
powershell -NoProfile -File C:\Cow_Kuluu_ffxi-engine\dev-live\udp-probe.ps1
```

- `19475/udp` PASS (echo received) ⇒ Docker Desktop's published-UDP return path is healthy.
- `FAIL sent ok, no reply` ⇒ return path dead ⇒ gameplay UDP will be black-holed; check
  Docker Desktop / WSL state before blaming kuluu or the firewall.
- `54230/udp` is send-only here; delivery is confirmed server-side via `cow-map` logs.

## Bring-up & verification

```bat
:: start / restart the whole stack
docker compose -f C:\Cow_Kuluu_ffxi-engine\dev-live\docker-compose.yml up -d

:: 1. map server ready?
docker logs cow-map --tail 3        :: want: "The map-server is ready to work"

:: 2. zone endpoints must be all-loopback (kuluu dials what the DB says)
docker exec cow-db mariadb -uxiadmin -ppassword xidb ^
  -e "SELECT zoneid,zoneip,zoneport FROM zone_settings WHERE zoneip<>'127.0.0.1'"

:: 3. dnat armed?
docker logs cow-dnat --tail 5       :: want "[dnat] VERIFIED ..." after each fresh cow-map netns

:: 4. published-UDP round trip
powershell -NoProfile -File C:\Cow_Kuluu_ffxi-engine\dev-live\udp-probe.ps1

:: 5. nothing squatting the client port (leaked PowerShell UdpClients hold it forever)
powershell -NoProfile -Command "Get-NetUDPEndpoint -LocalPort 47500"   :: expect: no objects

:: 6. character ground truth
docker exec cow-db mariadb -uxiadmin -ppassword xidb ^
  -e "SELECT charname,pos_x,pos_y,pos_z,pos_rot,pos_zone FROM chars WHERE charname='Cowpoke'"
```

Then launch the client pinned to the local port:

```bat
play_cowland.bat            :: kuluu.exe --server 127.0.0.1 play  (sets FFXI_MAP_LOCAL_PORT=47500)
```

## Failure patterns (observed)

| Symptom | Cause / fix |
|---|---|
| Lobby OK, then **no s2c map traffic at all** ("silently dropped") | DNAT rules gone (fresh `cow-map` netns / Docker restart). Watch `docker logs cow-dnat` for the re-arm; verify with `udp-probe.ps1`. Historically misdiagnosed as Windows Firewall — it isn't. |
| `next_login FAIL got 36` shortly after a previous run | Char still online server-side (netend saves late). Wait ~60 s, relog. |
| Logins drop silently after touching `zone_settings` | `docker restart cow-world cow-map`, wait for ready, let the keeper re-arm. xi_map's ZMQ identity derives from that table — skipping the restart = zero-log silent drops. |
| Lobby TLS `handshake timed out` / `unexpected eof` | Flaky connect; `docker compose restart connect` sometimes fixes it. |
| `pipe-not-found` on any docker command | Docker Desktop itself is down. Start it first. |
| `udp-probe.ps1` fails on 19475 even though TCP ports work | Published-UDP return path broken (Docker Desktop/WSL state). Restart Docker Desktop; don't chase kuluu code. |

## Ports cheat-sheet (client → server)

| Port | Proto | Server | What kuluu does there |
|---|---|---|---|
| 54231 | tcp/TLS | xi_connect | auth handshake (JSON over TLS, self-signed cert) |
| 54230 | tcp | xi_connect | xiloader data channel (world/char lists, char select, `next_login`) |
| 54001 | tcp | xi_connect | login view |
| 54002 | tcp | xi_search | item/auction search |
| 54230 | **udp** | xi_map | gameplay: login 0x0A, movement c2s 0x15, s2c spawn/WPOS |
| 8088 | tcp | xi_world | HTTP API (GM/debug) |
| 47500 | udp (local bind) | — | kuluu's own map socket; the DNAT target |

`next_login` (lobby s2c 0x0B) hands kuluu the map endpoint from `zone_settings`
(`zoneIp@+56`, `zonePort@+60`); with the loopback config above that resolves to
`127.0.0.1:54230/udp` → published port → `cow-map`.
