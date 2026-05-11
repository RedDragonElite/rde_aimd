# 🐉 RDE AIMD — AI Medical Department

[![Version](https://img.shields.io/badge/version-1.0.6-red?style=for-the-badge)](https://github.com/RedDragonElite/rde_aimd)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag-black?style=for-the-badge)](./LICENSE)
[![Framework](https://img.shields.io/badge/Framework-ox__core-blue?style=for-the-badge)](https://github.com/overextended/ox_core)
[![ox_lib](https://img.shields.io/badge/UI-ox__lib-purple?style=for-the-badge)](https://github.com/overextended/ox_lib)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-blue?style=for-the-badge)](https://fivem.net)
[![Free](https://img.shields.io/badge/Price-FREE%20FOREVER-green?style=for-the-badge)](https://github.com/RedDragonElite)
[![Status](https://img.shields.io/badge/status-STABLE-brightgreen?style=for-the-badge)](https://github.com/RedDragonElite/rde_aimd)

<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/ead04a76-b88d-4218-840c-b44cdda00573" />

> **The world's first open-source advanced death system for ox_core.**
> Built by [Red Dragon Elite](https://rd-elite.com) — Free Forever. No Paywalls. No Gatekeepers.

---

## 🔥 What is rde_aimd?

**rde_aimd** (AI Medical Department) is a complete, production-ready death and revival system for FiveM servers running **ox_core**. While every other death system on the market is either locked behind a Tebex paywall or built for legacy frameworks — we built the real thing, open source, for free, forever.

Provides the `deathSystem` resource interface — other scripts can depend on it via `fxmanifest.lua`.

### Why this changes everything

| ❌ Paid/Legacy Systems | ✅ rde_aimd |
|---|---|
| ESX/QB only or Tebex locked | Pure ox_core — zero legacy dependencies |
| Ambulance circles roads forever | 🌿 **Grass Fix** — forces off-road arrival |
| Instant despawn after revive | Doctor walks back, drives away naturally |
| Static, ugly death HUD | Live `top-center` TextUI with ox_lib |
| Discord webhook logging | Optional **rde_nostr_log** — decentralized forever |
| Admin revive = same as doctor | Separate events — realistic behavior per context |
| No DB persistence | **isDead** bulletproof DB sync — survives restarts |

---

## 📋 Changelog

### v1.0.6 — isDead Sync Root Cause Fix
- **FIX: `isDead` stays `true` in DB after doctor heal or respawn**
  The previous approach wrote `isDead=0` directly to `characters.isDead` via `MySQL.update` — but ox_core maintains its **own in-memory character state**. When ox_core called `player.save()` (on disconnect, logout, or periodic save), it wrote its in-memory state back to the DB, silently overwriting our direct write. The `isDead=true` from login survived because ox_core never knew it had changed.
  **The fix:** `DB_SetIsDead` now calls `player.set('isDead', false)` first — this updates ox_core's in-memory state so its next `player.save()` commits `false`, not the old stale value. The direct `MySQL.update` follows as belt-and-suspenders. Both are now in sync and ox_core can no longer overwrite the revive.

### v1.0.5
- FIX #7: `TriggerEvent('rde_death:localRevive')` after every revive path — closes isDead sync gap for `rde_aipd` and other external scripts
- `isDead=1` on login: auto-clear + hospital respawn instead of re-applying death state
- `onResourceStop`: reset `isDead=0` in DB for all currently-dead players — no more stuck-dead after server restart
- `resolvedCharId` threading: `ox:playerLoaded` resolves charId once and passes it all the way through `ClearDeathState` → `DB_SetIsDead`
- Separate `doctorRevive` / `adminRevive` events — doctor departs naturally, admin cleanup is instant
- 🌿 Grass Fix: stuck-detection loop + forced off-road arrival via `TaskGoToCoordAnyMeans`

---

## ✨ Features

### 💀 Death System
- **Realistic bleedout** — blood loss increases over time, rate scales with injury severity (`bleedoutRate = 0.3` base)
- **6 injury types** — Bleeding Out, Cardiac Arrest, Severe Trauma, Head Trauma, Gunshot Wound, Vehicle Crash
- **Cinematic death camera** — smooth orbiting camera (FOV `50.0`, orbit speed `0.15`) around the player body
- **Live death HUD** — `top-center` TextUI showing blood loss bar, time down, injury type
- **Progressive effects** — blur (intensity `12.0`) intensifies and heartbeat speeds up as blood loss rises
- **Blood screen** — `DeathFailOut` screen effect applied on death
- **Timecycle modifier** — `spectator3` at strength `1.0` while downed
- **Heartbeat sound** — `HEARTBEAT_FAST` from `DLC_PRISON_BREAK_HEIST_SOUNDS`, progressive interval (base `1200ms`)
- **Ragdoll persistence** — re-applied every `3000ms` to keep player on the ground
- **Spawn protection** — `10000ms` window after login/respawn prevents false death triggers
- **Death menu keybind** — `F5` opens the emergency status context menu
- **isDead=1 login fix** — if a player reconnects with `isDead=1` in DB (server crashed while they were dead), they are auto-cleared and respawned at the nearest hospital — no more stuck-dead-on-login

### 🚑 AI Ambulance
- **Emergency driving style `786468`** — runs red lights, ignores traffic signals, uses shortest route
- **Sirens + horn** — active during response, honks when blocked by traffic
- **Plate: `LSMD`**, livery `0`, ped model `s_m_m_paramedic_01`
- **Treatment animation** — `mini@cpr@char_a@cpr_str` / `cpr_pumpchest`
- **🌿 Grass Fix** — stuck-detection loop: if ambulance can't reach off-road player within `forcedArrivalDist` (80m default), it parks and the paramedic **exits and walks on foot** via `TaskGoToCoordAnyMeans` across any terrain
- **Realistic departure** — after reviving, doctor walks back to the ambulance, enters, drives away with sirens, then despawns after `despawnDelay` (`20000ms`)
- **lib.progressBar treatment** — 10-second visible treatment timer, cannot be cancelled
- **Smart spawn** — `200–450m` from player, `15` road-node search attempts
- **Ambulance blip** — sprite `637`, red (`color 1`), tracked on minimap until paramedic departs
- **Anti-spam rate limiting** — `5-second` cooldown between calls
- **Max service distance** — `10,000m`; calls beyond this are rejected
- **Dynamic ETA** — randomized `20–120s` with `30s` base prep time (cosmetic display)
- **Distance-based pricing** — base cost `$750` + `$50/km` from nearest hospital

### 🎭 Admin System
- **`/revive [playerid]`** — instant revive + immediate ambulance/ped cleanup
- **`/deathstatus [playerid]`** — check any player's death state (isDead, bloodLoss, injuryType)
- **`/aidmdstats`** — view server-wide statistics (deaths, revives, respawns, doctor calls, successful calls, revenue)
- **Triple-layer auth** — ACE permission `rde.admin` → ox_core groups (`admin`, `superadmin`, `god`) → fallback
- **Export API** — `IsDead()`, `RevivePlayer()`, `GetDeathState()`, `GetStats()`

### 🔗 Inter-Resource Events
- **`rde_death:localRevive`** — fired via `TriggerEvent` on **every** revive path so external scripts (e.g. `rde_aipd`) can sync isDead state immediately
- **`rde_death:forceDeathState`** — net event to force-apply death state on the client from server side

### 📊 Persistence & Logging
- **Bulletproof isDead sync** — `player.set('isDead', ...)` keeps ox_core in-memory state correct; direct `MySQL.update` as belt-and-suspenders (v1.0.6)
- **onResourceStop cleanup** — resets `isDead=0` for all currently-dead players on server/resource restart
- **Auto-create tables** — `rde_death_logs`, `rde_doctor_calls`, `rde_death_statistics`
- **Auto-prune** — configurable log retention (default: `30 days`)
- **Server stats** — deaths, revives, respawns, doctor calls, successful calls, revenue — DB-backed
- **rde_nostr_log** — optional decentralized logging (see below)

### 🌍 Localization
- English (`en`) and German (`de`) built in
- Auto-detected from `ox:locale` convar
- **Tri-method loader**: `lib.load` → `locales/xx.lua` → `xx.lua` (root fallback)
- Add any language by creating `locales/xx.lua`

---

## 📦 Dependencies

```
# server.cfg — CRITICAL: start in this exact order!
ensure oxmysql
ensure ox_lib
ensure ox_core
ensure ox_inventory
ensure rde_aimd
```

| Dependency | Required | Notes |
|---|---|---|
| [ox_core](https://github.com/overextended/ox_core) | ✅ Required | Player management |
| [ox_lib](https://github.com/overextended/ox_lib) | ✅ Required | UI, callbacks, commands |
| [ox_inventory](https://github.com/overextended/ox_inventory) | ✅ Required | Cash item (`money`) handling |
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ Required | Database |
| [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) | ⚡ Optional | Decentralized logging |

> **Note:** rde_aimd requires FiveM server build `≥ 7290` (declared in `fxmanifest.lua`).

---

## 🚀 Installation

```bash
# 1. Clone into your resources folder
cd resources
git clone https://github.com/RedDragonElite/rde_aimd.git
```

```cfg
# 2. Add to server.cfg — full block for rde_aimd:

## FOR RDE_AIMD DEATH SYSTEM
setr ox:deathSystem false

ensure oxmysql
ensure ox_lib
ensure ox_core
ensure ox_inventory
ensure rde_aimd

# 3. Add ACE permission for admins
add_ace group.admin rde.admin allow

# 4. (Optional) Set locale
setr ox:locale "en"   # or "de"
```

```
# 5. Start your server — tables are auto-created on first run
```

> ⚠️ **`setr ox:deathSystem false` is required.** This tells ox_core to disable its built-in death handling so rde_aimd can take full control. Without this line, both systems will fight over death events and you will get broken behavior.

That's it. No SQL imports. No manual setup. Tables create themselves.

---

## ⚙️ Configuration

All configuration lives in `config.lua`. Key settings:

### Death System
```lua
Config.Death = {
    respawnTime         = 120,      -- Seconds until hospital respawn unlocks
    bleedoutEnabled     = true,     -- Progressive blood loss
    bleedoutRate        = 0.3,      -- Blood loss per second (base)
    ragdollEnabled      = true,     -- Keep player ragdolled
    ragdollInterval     = 3000,     -- Re-apply ragdoll every N ms
    cameraEnabled       = true,     -- Cinematic death camera
    soundsEnabled       = true,     -- Heartbeat sounds
    spawnProtectionTime = 10000,    -- Ms of protection after login/respawn
    deathMenuDelay      = 2500,     -- Ms before death menu appears
}
```

### AI Ambulance
```lua
Config.Doctor = {
    enabled             = true,
    baseCost            = 750,          -- Base fee in dollars
    distanceCostPerKm   = 50,           -- Extra cost per km from hospital
    maxServiceDistance  = 10000,        -- Max dispatch distance in meters
    callCooldown        = 5,            -- Seconds between allowed calls (anti-spam)

    responseTime = {
        min      = 20,      -- Minimum ETA in seconds (display)
        max      = 120,     -- Maximum ETA in seconds (display)
        baseTime = 30,      -- Base preparation time before driving
    },

    treatmentTime   = 10,       -- Seconds of treatment animation
    successRate     = 95,       -- % chance of success (reserved — future use)
    arrivalRadius   = 18.0,     -- Meters = "arrived"

    --[[ 🌿 GRASS FIX: force arrival if ambulance stuck within this range ]]
    forcedArrivalDist = 80.0,

    vehicle = {
        model     = 'ambulance',
        livery    = 0,
        plateText = 'LSMD',
        blip = {
            sprite     = 637,
            color      = 1,
            scale      = 0.8,
            shortRange = false,
        },
    },

    ped = {
        model = 's_m_m_paramedic_01',
        treatAnim = {
            dict = 'mini@cpr@char_a@cpr_str',
            clip = 'cpr_pumpchest',
        },
    },

    driving = {
        speed     = 45.0,   -- m/s (~162 km/h)
        style     = 786468, -- Emergency: runs red lights
        useSirens = true,
        useHorn   = true,
    },

    spawn = {
        minSpawnDistance = 200,
        maxSpawnDistance = 450,
        searchAttempts   = 15,
    },

    returnDelay  = 3000,    -- Ms before doctor walks back after revive
    despawnDelay = 20000,   -- Ms ambulance drives before despawning
}
```

### Visual & Audio Effects
```lua
Config.Effects = {
    bloodScreen = { enabled = true, effect = 'DeathFailOut' },
    blur        = { enabled = true, intensity = 12.0, progressive = true },
    deathCam    = { enabled = true, fov = 50.0, height = 2.0, orbitSpeed = 0.15 },
    heartbeat   = {
        enabled      = true,
        sound        = 'HEARTBEAT_FAST',
        soundSet     = 'DLC_PRISON_BREAK_HEIST_SOUNDS',
        baseInterval = 1200,
        progressive  = true,
    },
    timecycle   = { enabled = true, modifier = 'spectator3', strength = 1.0 },
}
```

### Injury Types
```lua
Config.Injuries = {
    { id = 1, key = 'bleeding_out',   severity = 1, bleedRate = 0.5,  icon = '🩸' },
    { id = 2, key = 'cardiac_arrest', severity = 3, bleedRate = 1.2,  icon = '❤️‍🩹' },
    { id = 3, key = 'severe_trauma',  severity = 2, bleedRate = 0.8,  icon = '💥' },
    { id = 4, key = 'head_injury',    severity = 3, bleedRate = 1.0,  icon = '🧠' },
    { id = 5, key = 'gunshot_wound',  severity = 3, bleedRate = 1.5,  icon = '🔫' },
    { id = 6, key = 'vehicle_crash',  severity = 2, bleedRate = 0.7,  icon = '🚗' },
}
```

### rde_nostr_log (Optional)
```lua
Config.NostrLog = {
    enabled      = false,           -- Set to true when rde_nostr_log is running
    resourceName = 'rde_nostr_log',
}
```

### Hospitals
Three hospitals pre-configured. The nearest hospital is used for cost calculation and respawn.

```lua
Config.Hospitals = {
    {
        name         = 'Pillbox Hill Medical Center',
        coords       = vector4(307.3,  -595.3, 43.28,  70.0),
        respawnPoint = vector4(329.0,  -595.0, 43.28,  70.0),
        blip         = true,
    },
    {
        name         = 'Sandy Shores Medical Center',
        coords       = vector4(1820.0, 3672.0, 34.28, 210.0),
        respawnPoint = vector4(1835.0, 3675.0, 34.28, 210.0),
        blip         = true,
    },
    {
        name         = 'Paleto Bay Medical Center',
        coords       = vector4(-250.0, 6330.0, 32.43, 225.0),
        respawnPoint = vector4(-245.0, 6320.0, 32.43, 225.0),
        blip         = true,
    },
}
```

---

## ⚡ rde_nostr_log Integration

[rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) is the world's first decentralized FiveM logging system — powered by the Nostr protocol. No Discord. No rate limits. Permanent. Uncensorable.

**Events logged by rde_aimd:**

| Event | Trigger |
|---|---|
| 💀 Player Death | Every death with injury type + blood loss % |
| 💊 Player Revived | Method: `doctor_treatment` / `admin` / `respawn` |
| 🚑 Ambulance Dispatched | Cost, ETA, distance at time of dispatch |
| 🏥 Hospital Respawn | Player name + hospital name |
| 🛡️ Admin Action | Admin name + target + action |
| 🚑 Doctor Success | Successful treatment completion |

> ℹ️ Critical blood loss (≥75%) logging is coded but not yet triggered in the main bleedout loop. Planned for next release.

**Enable in config.lua:**
```lua
Config.NostrLog = {
    enabled      = true,
    resourceName = 'rde_nostr_log',
}
```

**Example Nostr post:**
```
🚑 [AIMD] Ambulance Dispatched | John Doe | Cost: $850 | ETA: 45s | Dist: 1200m
```

---

## 🌿 The Grass Fix — How It Works

GTA's vehicle pathfinder is road-only. If a player dies on grass, in a park, on a beach, or on any off-road terrain, a standard ambulance will circle the nearest road endlessly without ever arriving.

**rde_aimd solves this with a 3-layer system:**

1. **Road-Node Target** — the ambulance drives toward the nearest road node *adjacent* to the player, not the player's exact coordinates. Calculated via `GetClosestVehicleNode()`.

2. **Stuck-Detection** — every 800ms, the system checks if the ambulance is nearly stationary (speed < 0.5 m/s). After 3 consecutive stuck frames:
   - If within `forcedArrivalDist` (default 80m) → **Force arrival**. The ambulance parks and the paramedic exits and **walks on foot** to the player.
   - If still far → re-task toward the road node and reset the counter.

3. **Off-Road Walk** — `TaskGoToCoordAnyMeans` with flag `0` (no vehicle) allows peds to navigate over grass, sand, fields, any terrain. The paramedic will always reach the player.

**Configure the threshold:**
```lua
Config.Doctor.forcedArrivalDist = 80.0  -- Increase for larger off-road areas
```

---

## 🔄 Revive Behavior

Three distinct revive paths — by design:

| Scenario | Event | Doctor Behavior |
|---|---|---|
| Doctor treatment completes | `rde_death:doctorRevive` | Doctor finishes, walks back to ambulance, drives away, despawns after `despawnDelay` |
| Admin `/revive [id]` | `rde_death:adminRevive` | **Immediate** ambulance/ped cleanup |
| Hospital respawn | `rde_death:doRespawn` | Immediate cleanup, fade to hospital |

After **every** revive path, `TriggerEvent('rde_death:localRevive')` fires locally — external scripts like `rde_aipd` can listen on this event for instant isDead sync.

---

## 📤 Exports (For Other Scripts)

```lua
-- Check if a player is currently dead
local isDead = exports['rde_aimd']:IsDead(source)

-- Get full death state
local state = exports['rde_aimd']:GetDeathState(source)
-- Returns: { isDead, bloodLoss, injuryType, coords, timestamp }

-- Revive a player from another script (admin context — instant cleanup)
local success = exports['rde_aimd']:RevivePlayer(source)
-- Returns: true on success, false if source invalid

-- Get server-wide statistics
local stats = exports['rde_aimd']:GetStats()
-- Returns: {
--   totalDeaths, totalRevives, totalRespawns,
--   totalDoctorCalls, successfulDoctorCalls, totalRevenue
-- }
```

---

## 🗃️ Database

Tables are auto-created on first server start. No SQL file to import.

**`rde_death_logs`** — every player death with injury type, coords, blood loss, cause
**`rde_doctor_calls`** — every ambulance dispatch with cost, distance, response time, success
**`rde_death_statistics`** — global server totals (single row, persisted, auto-updated)

Also writes to `characters.isDead` (ox_core standard column) to persist death state across restarts.

**On resource stop:** `isDead` is reset to `0` in DB for all currently-dead players in memory — prevents the "stuck dead after restart" bug.

---

## 📁 File Structure

```
rde_aimd/
├── fxmanifest.lua          ← Resource manifest (provides 'deathSystem', requires build 7290)
├── config.lua              ← All configuration + tri-method locale system
├── client.lua              ← Death detection, camera, HUD, ambulance AI (Grass Fix)
├── server.lua              ← Events, DB, money, Nostr logging, admin commands, exports
├── LICENSE                 ← RDE Black Flag Source License v6.66
├── README.md               ← You are here
└── locales/
    ├── en.lua              ← English strings
    └── de.lua              ← German strings
```

---

## 🛡️ Admin Setup

```cfg
# server.cfg — ACE permission (recommended)
add_ace group.admin rde.admin allow
```

Fallback: ox_core groups `admin`, `superadmin`, `god`.

**Admin Commands:**

| Command | Description |
|---|---|
| `/revive [playerid]` | Instantly revive a downed player |
| `/deathstatus [playerid]` | Check a player's death state |
| `/aidmdstats` | View server-wide AIMD statistics |

---

## 🐛 Known Issues / Limitations

- `successRate = 95` is in config but not yet wired to a failure path — treatment always succeeds. Marked as future use.
- Critical blood loss Nostr event (≥75% threshold) is coded in `NostrLog` but not called from the bleedout loop yet.
- `responseTime` ETA is displayed to the player but does not affect actual ambulance arrival speed.
- `Config.Debug = false` by default — set to `true` for verbose server console output during testing.

---

## 📜 License

**RDE Black Flag Source License v6.66** — see [LICENSE](./LICENSE)

**TL;DR:**
- ✅ Free to use, edit, and learn from — forever
- ✅ Keep the header / credit the creator
- ❌ Do NOT sell this on Tebex, Patreon, or in any paid pack
- ❌ Do NOT be a skid

---

## 🌐 Community & Links

| | |
|---|---|
| 🐙 GitHub | [github.com/RedDragonElite](https://github.com/RedDragonElite) |
| 🌍 Website | [rd-elite.com](https://rd-elite.com) |
| ⚡ rde_nostr_log | [Decentralized Logging](https://github.com/RedDragonElite/rde_nostr_log) |
| 📖 OX Standards | [rde_ox_standards](https://github.com/RedDragonElite/rde_ox_standards) |
| 🚗 RDE Car Service | [rde_carservice](https://github.com/RedDragonElite/rde_carservice) |

---

> *"We build the future on the graves of paid resources."*
> **REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**
> 🐍🔥🖤 **RDE FOREVER. SYSTEM FAILURE.** ⚡777⚡