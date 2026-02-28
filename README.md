# 🐉 RDE AIMD — AI Medical Department

[![Version](https://img.shields.io/badge/version-1.0.0-red?style=for-the-badge)](https://github.com/RedDragonElite/rde_aimd)
[![License](https://img.shields.io/badge/license-RDE%20Black%20Flag-black?style=for-the-badge)](./LICENSE)
[![Framework](https://img.shields.io/badge/Framework-ox__core-blue?style=for-the-badge)](https://github.com/overextended/ox_core)
[![ox_lib](https://img.shields.io/badge/UI-ox__lib-purple?style=for-the-badge)](https://github.com/overextended/ox_lib)
[![FiveM](https://img.shields.io/badge/FiveM-Compatible-blue?style=for-the-badge)](https://fivem.net)
[![Free](https://img.shields.io/badge/Price-FREE%20FOREVER-green?style=for-the-badge)](https://github.com/RedDragonElite)

<img width="1024" height="1024" alt="image" src="https://github.com/user-attachments/assets/ead04a76-b88d-4218-840c-b44cdda00573" />

> **The world's first open-source advanced death system for ox_core.**  
> Built by [Red Dragon Elite](https://rd-elite.com) — Free Forever. No Paywalls. No Gatekeepers.

---

## 🔥 What is rde_aimd?

**rde_aimd** (AI Medical Department) is a complete, production-ready death and revival system for FiveM servers running **ox_core**. While every other death system on the market is either locked behind a Tebex paywall or built for legacy frameworks — we built the real thing, open source, for free, forever.

### Why this changes everything

| ❌ Paid/Legacy Systems | ✅ rde_aimd |
|---|---|
| ESX/QB only or Tebex locked | Pure ox_core — zero legacy dependencies |
| Ambulance circles roads forever | 🌿 **Grass Fix** — forces off-road arrival |
| Instant despawn after revive | Doctor walks back, drives away naturally |
| Static, ugly death HUD | Live top-center TextUI with ox_lib |
| Discord webhook logging | Optional **rde_nostr_log** — decentralized forever |
| Admin revive = same as doctor | Separate events — realistic behavior per context |
| No DB persistence | **isDead** bulletproof DB sync — survives restarts |

---

## ✨ Features

### 💀 Death System
- **Realistic bleedout** — blood loss increases over time based on injury severity
- **6 injury types** — Bleeding Out, Cardiac Arrest, Severe Trauma, Head Trauma, Gunshot Wound, Vehicle Crash
- **Cinematic death camera** — smooth orbiting camera around the player body
- **Live death HUD** — `top-center` TextUI showing blood loss bar, time down, injury type
- **Progressive effects** — blur intensifies, heartbeat speeds up as blood loss rises
- **Ragdoll persistence** — keeps player on the ground with re-application loop
- **Spawn protection** — prevents false death triggers on login

### 🚑 AI Ambulance
- **Emergency driving style `786468`** — runs red lights, ignores signals, uses shortest route
- **🌿 Grass Fix** — smart stuck-detection: if ambulance can't reach off-road player, forces arrival and paramedic **walks on foot** through grass, parks, fields — any terrain
- **Realistic departure** — after reviving, doctor walks back to ambulance, enters, drives away with sirens, then despawns after a natural delay
- **lib.progressBar treatment** — visible treatment timer, can't be cancelled
- **Smart parking** — parks roadside when player is on off-road terrain
- **Anti-spam rate limiting** — configurable cooldown between calls
- **Distance-based pricing** — cost increases with distance from nearest hospital
- **Ambulance blip** — tracked on map until paramedic departs

### 🎭 Admin System
- **`/revive [playerid]`** — instant revive + immediate ambulance cleanup (admin context)
- **`/deathstatus [playerid]`** — check any player's death state
- **`/aidmdstats`** — view server-wide statistics
- **Triple-layer auth** — ACE permissions → ox_core groups → fallback
- **Export API** — `IsDead()`, `RevivePlayer()`, `GetDeathState()`, `GetStats()`

### 📊 Persistence & Logging
- **bulletproof isDead sync** — always written to `characters.isDead` in DB
- **Auto-create tables** — `rde_death_logs`, `rde_doctor_calls`, `rde_death_statistics`
- **Auto-prune** — configurable log retention (default: 30 days)
- **Server stats** — deaths, revives, respawns, doctor calls, revenue — DB-backed
- **rde_nostr_log** — optional decentralized logging (see below)

### 🌍 Localization
- English (`en`) and German (`de`) built in
- Auto-detected from `ox:locale` convar
- Easily add any language by adding a new `locales/xx.lua` file

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
| [ox_inventory](https://github.com/overextended/ox_inventory) | ✅ Required | Cash item handling |
| [oxmysql](https://github.com/overextended/oxmysql) | ✅ Required | Database |
| [rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) | ⚡ Optional | Decentralized logging |

---

## 🚀 Installation

```bash
# 1. Clone into your resources folder
cd resources
git clone https://github.com/RedDragonElite/rde_aimd.git

# 2. Add to server.cfg (after ox_core, ox_lib, ox_inventory, oxmysql)
ensure rde_aimd

# 3. Add ACE permission for admins
add_ace group.admin rde.admin allow

# 4. (Optional) Set locale
setr ox:locale "en"   # or "de"

# 5. Start your server — tables are auto-created on first run
```

That's it. No SQL imports. No manual setup. Tables create themselves.

---

## ⚙️ Configuration

All configuration lives in `config.lua`. Key settings:

### Death System
```lua
Config.Death = {
    respawnTime         = 120,      -- Seconds until hospital respawn unlocks
    bleedoutEnabled     = true,     -- Progressive blood loss
    bleedoutRate        = 0.5,      -- Blood loss per second (base)
    ragdollEnabled      = true,     -- Keep player ragdolled
    spawnProtectionTime = 10000,    -- Ms of protection after login
    deathMenuDelay      = 2500,     -- Ms before death menu appears
}
```

### AI Ambulance
```lua
Config.Doctor = {
    baseCost          = 750,        -- Base dispatch fee ($)
    distanceCostPerKm = 50,         -- Surcharge per km from hospital
    treatmentTime     = 10,         -- Treatment animation seconds
    arrivalRadius     = 18.0,       -- Meters = "arrived"
    forcedArrivalDist = 80.0,       -- 🌿 GRASS FIX: force arrival if stuck within range
    returnDelay       = 6000,       -- Ms before doctor walks back after revive
    despawnDelay      = 20000,      -- Ms ambulance drives before despawning
    driving = {
        speed  = 45.0,              -- m/s driving speed
        style  = 786468,            -- Emergency: runs red lights
    },
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
Add or remove hospitals and respawn points. The nearest hospital is used for cost calculation and respawn.

```lua
Config.Hospitals = {
    {
        name         = 'Pillbox Hill Medical Center',
        coords       = vector4(307.3, -595.3, 43.28, 70.0),
        respawnPoint = vector4(329.0, -595.0, 43.28, 70.0),
        blip         = true,
    },
    -- add more...
}
```

---

## ⚡ rde_nostr_log Integration

[rde_nostr_log](https://github.com/RedDragonElite/rde_nostr_log) is the world's first decentralized FiveM logging system — powered by the Nostr protocol. No Discord. No rate limits. Permanent. Uncensorable.

**Events logged by rde_aimd:**

| Event | Trigger |
|---|---|
| 💀 Player Death | Every death with injury type + blood loss % |
| 💊 Player Revived | Method: `doctor_treatment` / `admin` / `respawn` / `sync` |
| 🚑 Ambulance Dispatched | Cost, ETA, distance at time of dispatch |
| 🏥 Hospital Respawn | Player name + hospital name |
| 🩸 Critical Blood Loss | Logged once at ≥75% threshold (no spam) |
| 🛡️ Admin Action | Admin name + target + action |
| 🚑 Doctor Success | Successful treatment completion |

**Enable in config.lua:**
```lua
Config.NostrLog = {
    enabled      = true,            -- Flip this on
    resourceName = 'rde_nostr_log', -- Resource name (default)
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
   - If within `forcedArrivalDist` (default 80m) → **Force arrival**. The ambulance parks in place and the paramedic exits and **walks on foot** to the player through any terrain.
   - If still far → re-task toward the road node and reset the counter.

3. **Off-Road Walk** — `TaskGoToCoordAnyMeans` with flag `0` (no vehicle) allows peds to navigate over grass, sand, fields, anywhere. The paramedic will always reach the player.

**Configure the threshold:**
```lua
Config.Doctor.forcedArrivalDist = 80.0  -- Increase for larger off-road areas
```

---

## 🔄 Revive Behavior

Two distinct revive paths — by design:

| Scenario | Event | Doctor Behavior |
|---|---|---|
| Doctor treatment completes | `rde_death:doctorRevive` | Doctor finishes, walks back to ambulance, drives away, despawns after `despawnDelay` |
| Admin `/revive [id]` | `rde_death:adminRevive` | **Immediate** ambulance/ped cleanup |
| Hospital respawn | `rde_death:doRespawn` | Immediate cleanup, fade to hospital |

This means players who pay for an ambulance get the full cinematic experience. Admins get instant action.

---

## 📤 Exports (For Other Scripts)

```lua
-- Check if a player is currently dead
local isDead = exports['rde_aimd']:IsDead(source)

-- Get full death state (isDead, bloodLoss, injuryType, coords, timestamp)
local state = exports['rde_aimd']:GetDeathState(source)

-- Revive a player from another script (admin context — instant cleanup)
exports['rde_aimd']:RevivePlayer(source)

-- Get server-wide statistics
local stats = exports['rde_aimd']:GetStats()
-- { totalDeaths, totalRevives, totalRespawns, totalDoctorCalls, totalRevenue }
```

---

## 🗃️ Database

Tables are auto-created on first server start. No SQL file to import.

**`rde_death_logs`** — every player death with injury, coords, blood loss  
**`rde_doctor_calls`** — every ambulance dispatch with cost, distance, success  
**`rde_death_statistics`** — global server totals (persisted, single row)

Also writes to `characters.isDead` (ox_core standard column) to persist death state across restarts and reconnects.

---

## 📁 File Structure

```
rde_aimd/
├── fxmanifest.lua          ← Resource manifest
├── config.lua              ← All configuration + locale system
├── client.lua              ← Death detection, camera, HUD, ambulance AI
├── server.lua              ← Events, DB, money, Nostr, admin commands
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

Fallback: ox_core groups `admin`, `superadmin`, `god` (grade ≥ 1 required).

**Admin Commands:**

| Command | Description |
|---|---|
| `/revive [playerid]` | Instantly revive a downed player |
| `/deathstatus [playerid]` | Check a player's death state |
| `/aidmdstats` | View server-wide AIMD statistics |

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

---

> *"We build the future on the graves of paid resources."*  
> **REJECT MODERN MEDIOCRITY. EMBRACE RDE SUPERIORITY.**  
> 🐍🔥🖤 **RDE FOREVER. SYSTEM FAILURE.** ⚡777⚡
