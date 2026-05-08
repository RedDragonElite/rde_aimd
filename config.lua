--[[
    ██████╗ ██████╗ ███████╗
    ██╔══██╗██╔══██╗██╔════╝
    ██████╔╝██║  ██║█████╗
    ██╔══██╗██║  ██║██╔══╝
    ██║  ██║██████╔╝███████╗
    ╚═╝  ╚═╝╚═════╝ ╚══════╝

    🐉 RedDragonElite | rde_aimd v1.0.4
    AI Medical Department — First Open-Source ox_core Death System

    📦 Dependencies:
        - ox_core       https://coxdocs.dev
        - ox_lib        https://coxdocs.dev
        - ox_inventory
        - oxmysql

    🌍 Locale: Set ox:locale convar in server.cfg
        Example: setr ox:locale "en"   or   setr ox:locale "de"
]]

Config = {}

-- =============================================
-- 🌐 LOCALE
-- Auto-detects from: setr ox:locale "en"
-- Supported: 'en' | 'de'
-- =============================================
Config.Locale = GetConvar('ox:locale', 'en')

-- =============================================
-- ⚡ rde_nostr_log INTEGRATION
-- https://github.com/RedDragonElite/rde_nostr_log
--
-- The world's first decentralized, uncensorable FiveM
-- logging system — powered by the Nostr protocol.
-- Replace Discord webhooks forever. Free. Forever.
--
-- Events logged by rde_aimd:
--   💀 Player death (with injury type + blood loss)
--   💊 Player revived (method: doctor / admin / respawn)
--   🚑 Ambulance dispatched (cost, ETA, distance)
--   🏥 Hospital respawn
--   🩸 Critical blood loss (≥75% threshold — no spam)
--   🛡️ Admin actions (/revive command)
--   🚑 Doctor treatment success
--
-- Set enabled = true if rde_nostr_log is installed & running.
-- rde_aimd works 100% WITHOUT it — this is optional enrichment.
-- =============================================
Config.NostrLog = {
    enabled         = true,           -- true = pipe all events to rde_nostr_log
    resourceName    = 'rde_nostr_log',

    -- Emojis used in Nostr post messages (purely cosmetic)
    icons = {
        death       = '💀',
        revive      = '💊',
        doctor      = '🚑',
        respawn     = '🏥',
        admin       = '🛡️',
    }
}

-- =============================================
-- ⚙️ CORE DEATH SYSTEM
-- =============================================
Config.Death = {
    respawnTime         = 120,      -- Seconds until respawn option becomes available
    bleedoutEnabled     = true,     -- Gradually increase blood loss over time
    bleedoutRate        = 0.3,      -- Base blood loss per second (0.0–1.0)
    ragdollEnabled      = true,     -- Enable realistic ragdoll physics
    ragdollInterval     = 3000,     -- Re-apply ragdoll every N ms (keeps player down)
    cameraEnabled       = true,     -- Enable cinematic death camera
    soundsEnabled       = true,     -- Enable heartbeat sounds
    spawnProtectionTime = 10000,    -- Ms of spawn protection after login/respawn
    deathMenuDelay      = 2500,     -- Ms before death menu appears (lets ragdoll settle)
}

-- =============================================
-- 🚑 AI AMBULANCE SYSTEM
-- =============================================
Config.Doctor = {
    enabled             = true,
    baseCost            = 750,          -- Base fee in dollars
    distanceCostPerKm   = 50,           -- Extra cost per km from hospital
    maxServiceDistance  = 10000,        -- Max dispatch distance in meters
    callCooldown        = 5,            -- Seconds between allowed calls (anti-spam)

    responseTime = {
        min      = 20,      -- Minimum ETA in seconds
        max      = 120,     -- Maximum ETA in seconds
        baseTime = 30,      -- Base preparation time before driving
    },

    treatmentTime   = 10,       -- Seconds of treatment animation
    successRate     = 95,       -- % chance of successful treatment (future use)
    arrivalRadius   = 18.0,     -- Distance (m) at which ambulance counts as "arrived"

    --[[
        🌿 GRASS FIX: forcedArrivalDist
        If the ambulance gets stuck (e.g. player is on grass, park, field, beach)
        and is within this range, it will force arrival and the paramedic will
        EXIT the vehicle and WALK to the player on foot across any terrain.
        Increase this if your server has large off-road play areas.
    ]]
    forcedArrivalDist   = 80.0,     -- Meters — force arrival if stuck within range

    vehicle = {
        model       = 'ambulance',
        livery      = 0,
        plateText   = 'LSMD',
        blip = {
            sprite      = 637,      -- Ambulance blip sprite
            color       = 1,        -- Red
            scale       = 0.8,
            shortRange  = false,
        },
    },

    ped = {
        model   = 's_m_m_paramedic_01',
        -- Treatment animation (played when paramedic reaches player)
        treatAnim = {
            dict   = 'mini@cpr@char_a@cpr_str',
            clip   = 'cpr_pumpchest',
        },
    },

    driving = {
        speed           = 45.0,     -- Driving speed in m/s (~162 km/h)
        --[[
            🚨 EMERGENCY DRIVING STYLE: 786468
            ✅ Follows road network
            ✅ Ignores traffic signals (runs red lights!)
            ✅ Avoids crashes where possible
            ✅ Uses shortest route
            ✅ Override set AFTER task (critical for effect)
        ]]
        style           = 786468,
        useSirens       = true,
        useHorn         = true,     -- Honk when blocked by traffic
    },

    spawn = {
        minSpawnDistance    = 200,  -- Minimum spawn distance from player
        maxSpawnDistance    = 450,  -- Maximum spawn distance from player
        searchAttempts      = 15,   -- Attempts to find a valid road spawn point
    },

    returnDelay     = 3000,     -- Ms before doctor walks back to vehicle after revive
    despawnDelay    = 20000,    -- Ms the ambulance drives away before despawning (15-30s)
}

-- =============================================
-- 🩹 INJURY TYPES
-- Randomly assigned on death. Higher severity = faster bleed rate.
-- =============================================
Config.Injuries = {
    { id = 1, key = 'bleeding_out',   severity = 1, bleedRate = 0.5,  icon = '🩸', color = '#DC2626' },
    { id = 2, key = 'cardiac_arrest', severity = 3, bleedRate = 1.2,  icon = '❤️‍🩹', color = '#7C2D12' },
    { id = 3, key = 'severe_trauma',  severity = 2, bleedRate = 0.8,  icon = '💥', color = '#991B1B' },
    { id = 4, key = 'head_injury',    severity = 3, bleedRate = 1.0,  icon = '🧠', color = '#450A0A' },
    { id = 5, key = 'gunshot_wound',  severity = 3, bleedRate = 1.5,  icon = '🔫', color = '#7C2D12' },
    { id = 6, key = 'vehicle_crash',  severity = 2, bleedRate = 0.7,  icon = '🚗', color = '#B91C1C' },
}

-- =============================================
-- 🏥 HOSPITALS
-- respawnPoint = where the player teleports on respawn (vector4)
-- =============================================
Config.Hospitals = {
    {
        name            = 'Pillbox Hill Medical Center',
        coords          = vector4(307.3,  -595.3, 43.28,  70.0),
        respawnPoint    = vector4(329.0,  -595.0, 43.28,  70.0),
        blip            = true,
    },
    {
        name            = 'Sandy Shores Medical Center',
        coords          = vector4(1820.0, 3672.0, 34.28, 210.0),
        respawnPoint    = vector4(1835.0, 3675.0, 34.28, 210.0),
        blip            = true,
    },
    {
        name            = 'Paleto Bay Medical Center',
        coords          = vector4(-250.0, 6330.0, 32.43, 225.0),
        respawnPoint    = vector4(-245.0, 6320.0, 32.43, 225.0),
        blip            = true,
    },
}

Config.HospitalBlip = {
    sprite      = 61,
    color       = 1,
    scale       = 0.8,
    shortRange  = true,
}

-- =============================================
-- 🎭 VISUAL & AUDIO EFFECTS
-- =============================================
Config.Effects = {
    bloodScreen = {
        enabled = true,
        effect  = 'DeathFailOut',
    },

    blur = {
        enabled     = true,
        intensity   = 12.0,
        progressive = true,     -- Blur increases with blood loss
    },

    deathCam = {
        enabled     = true,
        fov         = 50.0,
        height      = 2.0,
        orbitSpeed  = 0.15,     -- Slow cinematic orbit speed
    },

    heartbeat = {
        enabled      = true,
        sound        = 'HEARTBEAT_FAST',
        soundSet     = 'DLC_PRISON_BREAK_HEIST_SOUNDS',
        baseInterval = 1200,
        progressive  = true,    -- Beats faster as blood loss increases
    },

    timecycle = {
        enabled   = true,
        modifier  = 'spectator3',
        strength  = 1.0,
    },
}

-- =============================================
-- 🛡️ ADMIN
-- =============================================
Config.Admin = {
    acePermission = 'rde.admin',
    groups        = { 'admin', 'superadmin', 'god' },
}

-- =============================================
-- 🗃️ DATABASE
-- =============================================
Config.Database = {
    enabled         = true,
    tablePrefix     = 'rde_',
    logDeaths       = true,
    logDoctorCalls  = true,
    keepLogsForDays = 30,
}

-- =============================================
-- ⌨️ KEYBINDS
-- =============================================
Config.Keys = {
    openDeathMenu = 'F5',
}

-- =============================================
-- 🐛 DEBUG
-- =============================================
Config.Debug = false

-- =============================================
-- 🌍 LOCALE SYSTEM — BULLETPROOF MULTI-PATH LOADER
-- =============================================
--[[
    Loads locale in priority order:
      1. lib.load('locales.xx')  — requires locales/ subfolder + files{} registration
      2. LoadResourceFile('locales/xx.lua') — direct read from locales/ subfolder
      3. LoadResourceFile('xx.lua')         — direct read from resource root

    This means your locale files work whether they are in:
      • rde_aimd/locales/en.lua   ← recommended structure
      • rde_aimd/en.lua           ← also works (root level)
]]
do
    local resourceName = GetCurrentResourceName()

    local function TryLoadFile(path)
        local content = LoadResourceFile(resourceName, path)
        if not content then return nil end
        local fn, err = load('return ' .. content)
        if not fn then
            print(string.format('^1[RDE | AIMD]^7 Locale parse error (%s): %s', path, tostring(err)))
            return nil
        end
        local ok, result = pcall(fn)
        if ok and type(result) == 'table' then return result end
        return nil
    end

    local function LoadLocaleTable(lang)
        -- Method 1: ox_lib loader (needs locales/ subfolder + files{} registration)
        local ok, tbl = pcall(lib.load, ('locales.%s'):format(lang))
        if ok and type(tbl) == 'table' and next(tbl) then return tbl end

        -- Method 2: Direct file read — locales/ subfolder
        local tbl2 = TryLoadFile(('locales/%s.lua'):format(lang))
        if tbl2 then return tbl2 end

        -- Method 3: Direct file read — resource root (fallback)
        local tbl3 = TryLoadFile(('%s.lua'):format(lang))
        if tbl3 then return tbl3 end

        return nil
    end

    local L = LoadLocaleTable(Config.Locale)
        or LoadLocaleTable('en')
        or {}

    if not next(L) then
        print('^1[RDE | AIMD]^7 ⚠️ Locale failed to load! Showing keys. Put en.lua in locales/ subfolder.')
    else
        print(string.format('^2[RDE | AIMD]^7 Locale loaded: %s', Config.Locale))
    end

    ---@param key string
    ---@param ... any
    ---@return string
    function locale(key, ...)
        local str = L[key]
        if not str then return key end
        if select('#', ...) > 0 then return string.format(str, ...) end
        return str
    end
end

return Config