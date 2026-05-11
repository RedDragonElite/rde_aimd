--[[
    ██████╗ ██████╗ ███████╗
    ██╔══██╗██╔══██╗██╔════╝
    ██████╔╝██║  ██║█████╗
    ██╔══██╗██║  ██║██╔══╝
    ██║  ██║██████╔╝███████╗
    ╚═╝  ╚═╝╚═════╝ ╚══════╝

    🐉 rde_aimd v1.0.5 — SERVER
    RDE AI Medical Department | First Open-Source ox_core Death System

    Features:
        ✅ rde_nostr_log integration (toggle in config)
        ✅ isDead ALWAYS synced to DB — bulletproof persistence
        ✅ Rate limiting — anti-spam doctor calls
        ✅ Auto-create tables on startup
        ✅ Auto-prune old logs (keepLogsForDays)
        ✅ Proper ox_core ready check
        ✅ Atomic DB operations with retry
        ✅ doctorRevive event — natural departure (not instant despawn)
        ✅ adminRevive — instant cleanup (admin context)
]]

-- =============================================
-- 🔧 STATE
-- =============================================
local mysqlReady    = false
local oxReady       = false

local PlayerStates  = {}   -- [src] = { isDead, injuryType, bloodLoss, timestamp }
local DoctorCalls   = {}   -- [src] = db_call_id
local CallCooldowns = {}   -- [src] = last_call_time

local Stats = {
    totalDeaths           = 0,
    totalRevives          = 0,
    totalRespawns         = 0,
    totalDoctorCalls      = 0,
    successfulDoctorCalls = 0,
    totalRevenue          = 0,
}

-- =============================================
-- ⚡ rde_nostr_log INTEGRATION
-- https://github.com/RedDragonElite/rde_nostr_log
-- Decentralized, uncensorable FiveM logging.
-- Toggle: Config.NostrLog.enabled in config.lua
-- =============================================
local NostrLog = {}

local function NostrPost(message, tags)
    if not Config.NostrLog or not Config.NostrLog.enabled then return end
    local ok, err = pcall(function()
        exports[Config.NostrLog.resourceName]:postLog(message, tags)
    end)
    if not ok and Config.Debug then
        print(string.format('^3[RDE | AIMD NostrLog]^7 %s — %s', message, tostring(err)))
    end
end

function NostrLog.death(source, info)
    local icon = Config.NostrLog.icons and Config.NostrLog.icons.death or '💀'
    NostrPost(
        string.format('%s [AIMD] Player Death | %s | Injury: %s | Blood: %.0f%%',
            icon, info.name or 'Unknown',
            locale and locale(info.injuryKey or 'unknown') or (info.injuryKey or 'Unknown'),
            info.bloodLoss or 0),
        {
            { 'event_type', 'player_death'                    },
            { 'player',     info.name or 'Unknown'            },
            { 'injury',     info.injuryKey or 'unknown'       },
            { 'blood_loss', tostring(math.floor(info.bloodLoss or 0)) },
            { 'source',     'rde_aimd'                        },
        }
    )
end

function NostrLog.revive(source, info)
    local icon = Config.NostrLog.icons and Config.NostrLog.icons.revive or '💊'
    NostrPost(
        string.format('%s [AIMD] Player Revived | %s | Method: %s',
            icon, info.name or 'Unknown', info.method or 'unknown'),
        {
            { 'event_type', 'player_revive'           },
            { 'player',     info.name or 'Unknown'    },
            { 'method',     info.method or 'unknown'  },
            { 'source',     'rde_aimd'                },
        }
    )
end

function NostrLog.doctor(source, info)
    local icon = Config.NostrLog.icons and Config.NostrLog.icons.doctor or '🚑'
    NostrPost(
        string.format('%s [AIMD] Ambulance Dispatched | %s | Cost: $%d | ETA: %ds | Dist: %.0fm',
            icon, info.name or 'Unknown', info.cost or 0, info.eta or 0, info.distance or 0),
        {
            { 'event_type', 'ambulance_dispatch'              },
            { 'player',     info.name or 'Unknown'            },
            { 'cost',       tostring(info.cost or 0)          },
            { 'eta',        tostring(info.eta or 0)           },
            { 'distance',   tostring(math.floor(info.distance or 0)) },
            { 'source',     'rde_aimd'                        },
        }
    )
end

function NostrLog.respawn(source, info)
    local icon = Config.NostrLog.icons and Config.NostrLog.icons.respawn or '🏥'
    NostrPost(
        string.format('%s [AIMD] Hospital Respawn | %s → %s',
            icon, info.name or 'Unknown', info.hospital or 'Hospital'),
        {
            { 'event_type', 'hospital_respawn'           },
            { 'player',     info.name or 'Unknown'       },
            { 'hospital',   info.hospital or 'Unknown'   },
            { 'source',     'rde_aimd'                   },
        }
    )
end

function NostrLog.admin(source, info)
    local icon = Config.NostrLog.icons and Config.NostrLog.icons.admin or '🛡️'
    NostrPost(
        string.format('%s [AIMD] Admin Action | By: %s | Action: %s | Target: %s',
            icon,
            GetPlayerName(source) or tostring(source),
            info.action or '?',
            info.target or '?'),
        {
            { 'event_type', 'admin_action'                   },
            { 'admin',      GetPlayerName(source) or tostring(source) },
            { 'action',     info.action or '?'               },
            { 'target',     info.target or '?'               },
            { 'source',     'rde_aimd'                       },
        }
    )
end

function NostrLog.doctorSuccess(source, info)
    local icon = Config.NostrLog.icons and Config.NostrLog.icons.doctor or '🚑'
    NostrPost(
        string.format('%s [AIMD] Doctor Treatment Success | %s | Cost: $%d',
            icon, info.name or 'Unknown', info.cost or 0),
        {
            { 'event_type', 'doctor_success'             },
            { 'player',     info.name or 'Unknown'       },
            { 'cost',       tostring(info.cost or 0)     },
            { 'source',     'rde_aimd'                   },
        }
    )
end

function NostrLog.bloodLoss(source, info)
    -- Only log critical thresholds to avoid spam
    local icon = '🩸'
    NostrPost(
        string.format('%s [AIMD] Critical Blood Loss | %s | %.0f%%',
            icon, info.name or 'Unknown', info.bloodLoss or 0),
        {
            { 'event_type', 'critical_blood_loss'                     },
            { 'player',     info.name or 'Unknown'                    },
            { 'blood_loss', tostring(math.floor(info.bloodLoss or 0)) },
            { 'source',     'rde_aimd'                                },
        }
    )
end

-- =============================================
-- 🛡️ UTILITIES
-- =============================================
local function Debug(...)
    if Config.Debug then
        print('^3[RDE | AIMD Server]^7', ...)
    end
end

local function GetOxPlayer(source)
    if not source or source == 0 then return nil end
    if not oxReady then return nil end
    local ok, player = pcall(function()
        return exports.ox_core:GetPlayer(tonumber(source))
    end)
    return (ok and player) or nil
end

local function GetName(source)
    local player = GetOxPlayer(source)
    if not player then return 'Unknown' end
    local ok, name = pcall(function()
        local fn   = player.firstName or ''
        local ln   = player.lastName  or ''
        local full = (fn .. ' ' .. ln):match('^%s*(.-)%s*$')
        return full ~= '' and full or (GetPlayerName(source) or 'Unknown')
    end)
    return ok and name or 'Unknown'
end

local function GetCharId(source)
    local player = GetOxPlayer(source)
    if not player then return nil end
    local ok, id = pcall(function() return player.charId end)
    return (ok and id) or nil
end

local function IsAdmin(source)
    if not source then return false end

    if IsPlayerAceAllowed(tostring(source), Config.Admin.acePermission) then
        return true
    end

    local player = GetOxPlayer(source)
    if player then
        local ok, groups = pcall(function()
            return player.getGroups and player.getGroups() or {}
        end)
        if ok and groups then
            for _, adminGroup in ipairs(Config.Admin.groups) do
                if groups[adminGroup] and groups[adminGroup] >= 1 then
                    return true
                end
            end
        end
    end

    return false
end

local function CanCallDoctor(source)
    local now   = os.time()
    local last  = CallCooldowns[source] or 0
    if (now - last) < Config.Doctor.callCooldown then
        return false, Config.Doctor.callCooldown - (now - last)
    end
    CallCooldowns[source] = now
    return true
end

local function NearestHospital(coords)
    if not Config.Hospitals or #Config.Hospitals == 0 then return nil end
    local bestDist = math.huge
    local best     = nil
    for _, h in ipairs(Config.Hospitals) do
        if h.coords then
            local d = #(coords - vector3(h.coords.x, h.coords.y, h.coords.z))
            if d < bestDist then bestDist = d; best = h end
        end
    end
    return best or Config.Hospitals[1]
end

-- =============================================
-- 💰 MONEY SYSTEM
-- Priority: ox_inventory cash → ox_core account
-- =============================================
local function GetMoney(source)
    local ok, amount = pcall(function()
        local item = exports.ox_inventory:GetItem(source, 'money', nil, true)
        return tonumber(item) or 0
    end)
    if ok and amount and amount > 0 then return amount end

    local player = GetOxPlayer(source)
    if player then
        local ok2, acc = pcall(function()
            return player.getAccount and player.getAccount('money') or 0
        end)
        if ok2 and acc then return acc end
    end
    return 0
end

local function RemoveMoney(source, amount)
    if not amount or amount <= 0 then return false end
    amount = math.floor(amount)

    local ok, result = pcall(function()
        return exports.ox_inventory:RemoveItem(source, 'money', amount)
    end)
    if ok and result then
        Debug(string.format('Removed $%d from %d via ox_inventory', amount, source))
        return true
    end

    local player = GetOxPlayer(source)
    if player then
        local ok2, r2 = pcall(function()
            return player.removeAccount and player.removeAccount('money', amount)
        end)
        if ok2 and r2 then
            Debug(string.format('Removed $%d from %d via ox_core', amount, source))
            return true
        end
    end

    Debug(string.format('FAILED to remove $%d from %d', amount, source))
    return false
end

-- =============================================
-- 🗃️ DATABASE — isDead SYNC (CRITICAL)
-- =============================================
-- FIX: Accept optional pre-resolved charId to avoid race conditions where
-- GetCharId(source) returns nil right after login/revive (ox_core not yet settled).
local function DB_SetIsDead(source, isDeadBool, resolvedCharId)
    if not Config.Database.enabled then return false end

    local val = isDeadBool and 1 or 0

    -- PRIMARY: set ox_core's own isDead player statebag directly.
    -- ox_core's player.save() reads Player(source).state.isDead when committing to DB.
    -- Without this, ox_core overwrites our MySQL update with the old stale value on save.
    pcall(function()
        Player(source).state:set('isDead', isDeadBool, true)
    end)
    Debug(string.format('📡 Player(%d).state:set(isDead, %s)', source, tostring(isDeadBool)))

    -- Also hit player.set() for any in-memory metadata path ox_core may use
    local player = GetOxPlayer(source)
    if player then
        pcall(function() player.set('isDead', isDeadBool) end)
    end

    -- SECONDARY: direct MySQL write as belt-and-suspenders
    if not mysqlReady then return false end

    local charId = resolvedCharId or GetCharId(source)

    if not charId then
        CreateThread(function()
            Wait(1000)
            -- Retry statebag in case player wasn't fully initialised yet
            pcall(function() Player(source).state:set('isDead', isDeadBool, true) end)
            charId = GetCharId(source)
            if charId then
                pcall(function()
                    MySQL.update.await(
                        'UPDATE `characters` SET `isDead` = ? WHERE `charid` = ?',
                        { val, charId })
                    Debug(string.format('🔄 isDead retry → %d for charId=%d', val, charId))
                end)
            else
                Debug(string.format('DB_SetIsDead: giving up — no charId for source %d', source))
            end
        end)
        return false
    end

    local ok, rows = pcall(function()
        return MySQL.update.await(
            'UPDATE `characters` SET `isDead` = ? WHERE `charid` = ?',
            { val, charId })
    end)

    if ok and rows then
        Debug(string.format('✅ isDead → %d for charId=%d', val, charId))
        return true
    else
        Debug(string.format('⚠️ MySQL update failed for charId=%d', charId))
        return false
    end
end

-- =============================================
-- 📊 STATEBAGS
-- =============================================
local function SetDeathState(source, data, resolvedCharId)
    if not source or source == 0 then return false end
    local ok = pcall(function()
        Player(source).state:set('deathData', data, true)
    end)
    if not ok then Debug(string.format('Statebag set failed for %d', source)) end
    PlayerStates[source] = data
    if data.isDead ~= nil then DB_SetIsDead(source, data.isDead, resolvedCharId) end
    return true
end

local function GetDeathState(source)
    if not source or source == 0 then return nil end
    if PlayerStates[source] then return PlayerStates[source] end
    local ok, val = pcall(function() return Player(source).state.deathData end)
    return (ok and val) or nil
end

-- FIX: Accept optional resolvedCharId and forward it to DB_SetIsDead.
-- This breaks the double race condition: ox:playerLoaded resolves charId once
-- and passes it all the way through so DB_SetIsDead never hits the nil-charId path.
local function ClearDeathState(source, resolvedCharId)
    if not source or source == 0 then return end
    SetDeathState(source, { isDead = false }, resolvedCharId)
end

-- =============================================
-- 📈 STATISTICS (DB-backed)
-- =============================================
local function SaveStats()
    if not mysqlReady or not Config.Database.enabled then return end
    pcall(function()
        local prefix = Config.Database.tablePrefix
        MySQL.update.await(string.format([[
            UPDATE `%sdeath_statistics` SET
                total_deaths              = ?,
                total_revives             = ?,
                total_respawns            = ?,
                total_doctor_calls        = ?,
                successful_doctor_calls   = ?,
                total_revenue             = ?
        ]], prefix), {
            Stats.totalDeaths,
            Stats.totalRevives,
            Stats.totalRespawns,
            Stats.totalDoctorCalls,
            Stats.successfulDoctorCalls,
            Stats.totalRevenue,
        })
    end)
end

local function LoadStats()
    if not mysqlReady or not Config.Database.enabled then return end
    local ok, rows = pcall(function()
        return MySQL.query.await(string.format(
            'SELECT * FROM `%sdeath_statistics` LIMIT 1',
            Config.Database.tablePrefix))
    end)
    if ok and rows and #rows > 0 then
        local r = rows[1]
        Stats.totalDeaths             = tonumber(r.total_deaths)            or 0
        Stats.totalRevives            = tonumber(r.total_revives)           or 0
        Stats.totalRespawns           = tonumber(r.total_respawns)          or 0
        Stats.totalDoctorCalls        = tonumber(r.total_doctor_calls)      or 0
        Stats.successfulDoctorCalls   = tonumber(r.successful_doctor_calls) or 0
        Stats.totalRevenue            = tonumber(r.total_revenue)           or 0
        Debug('Statistics loaded from DB')
    end
end

-- =============================================
-- 🗃️ DATABASE LOGGING
-- =============================================
local function LogDeath(source, injuryType, coords, reason, bloodLoss)
    if not mysqlReady or not Config.Database.logDeaths then return end
    local charId = GetCharId(source)
    if not charId then return end

    pcall(function()
        MySQL.insert.await(string.format([[
            INSERT INTO `%sdeath_logs`
                (char_id, player_name, injury_type, death_coords, death_reason, blood_loss)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], Config.Database.tablePrefix), {
            charId,
            GetName(source),
            injuryType or 1,
            coords and string.format('%.2f,%.2f,%.2f', coords.x, coords.y, coords.z) or '0,0,0',
            reason or 0,
            math.floor(bloodLoss or 0),
        })
        Stats.totalDeaths = Stats.totalDeaths + 1
        SaveStats()
    end)
end

local function LogDoctorCall(source, cost, distance, responseTime)
    if not mysqlReady or not Config.Database.logDoctorCalls then return end
    local charId = GetCharId(source)
    if not charId then return end

    local ped    = GetPlayerPed(source)
    local coords = ped ~= 0 and GetEntityCoords(ped) or vector3(0, 0, 0)

    pcall(function()
        local callId = MySQL.insert.await(string.format([[
            INSERT INTO `%sdoctor_calls`
                (char_id, player_name, call_coords, cost, distance, response_time)
            VALUES (?, ?, ?, ?, ?, ?)
        ]], Config.Database.tablePrefix), {
            charId,
            GetName(source),
            string.format('%.2f,%.2f,%.2f', coords.x, coords.y, coords.z),
            math.floor(cost),
            math.floor(distance),
            math.floor(responseTime),
        })
        DoctorCalls[source]      = callId
        Stats.totalDoctorCalls   = Stats.totalDoctorCalls + 1
        Stats.totalRevenue       = Stats.totalRevenue + math.floor(cost)
        SaveStats()
    end)
end

local function MarkDoctorCallSuccess(source, success)
    if not mysqlReady or not DoctorCalls[source] then return end
    pcall(function()
        MySQL.update.await(string.format([[
            UPDATE `%sdoctor_calls`
            SET success = ?, completion_time = NOW()
            WHERE id = ?
        ]], Config.Database.tablePrefix), {
            success and 1 or 0,
            DoctorCalls[source],
        })
        if success then
            Stats.successfulDoctorCalls = Stats.successfulDoctorCalls + 1
        end
        DoctorCalls[source] = nil
        SaveStats()
    end)
end

-- =============================================
-- 💊 DISPATCH CALCULATION
-- =============================================
local function CalculateDoctorDispatch(playerCoords)
    local cfg      = Config.Doctor
    local hospital = NearestHospital(playerCoords)
    local distance = 0

    if hospital then
        distance = #(playerCoords - vector3(hospital.coords.x, hospital.coords.y, hospital.coords.z))
    end

    local cost     = cfg.baseCost + math.floor((distance / 1000) * cfg.distanceCostPerKm)
    local rt       = cfg.responseTime
    local speedKmh = (cfg.driving.speed or 45.0) * 3.6
    local travelMin = (distance / 1000) / speedKmh * 60
    local eta = math.max(
        rt.min,
        math.min(rt.max, rt.baseTime + (travelMin * 60) + math.random(5, 15))
    )

    Debug(string.format('Dispatch: dist=%.0fm cost=$%d eta=%ds', distance, cost, math.ceil(eta)))
    return cost, math.ceil(eta), distance, hospital
end

-- =============================================
-- 📡 EVENT HANDLERS
-- =============================================

RegisterNetEvent('rde_death:syncState', function(state)
    local src = source
    if not src or src == 0 then return end

    -- BUG FIX: Do NOT gate the entire handler on GetOxPlayer.
    -- If ox_core is momentarily unavailable, isDead=false (the revive clear)
    -- would never reach ClearDeathState, leaving isDead=1 in DB permanently.
    -- Only the death-path needs a valid player object.
    if state.isDead then
        if not GetOxPlayer(src) then return end
        local data = {
            isDead     = true,
            coords     = state.coords,
            injuryType = state.injuryType or 1,
            bloodLoss  = state.bloodLoss  or 0,
            timestamp  = os.time(),
        }
        SetDeathState(src, data)

        if state.coords and state.injuryType then
            LogDeath(src, state.injuryType, state.coords, state.reason, state.bloodLoss)
        end

        -- Resolve injury key for Nostr log
        local injuryKey = 'unknown'
        if state.injuryType and Config.Injuries[state.injuryType] then
            injuryKey = Config.Injuries[state.injuryType].key
        end

        NostrLog.death(src, {
            name       = GetName(src),
            injuryKey  = injuryKey,
            bloodLoss  = state.bloodLoss,
        })
    else
        ClearDeathState(src)
        NostrLog.revive(src, { name = GetName(src), method = 'sync' })
    end
end)

RegisterNetEvent('rde_death:updateBloodLoss', function(bloodLoss)
    local src = source
    if not src or src == 0 then return end

    local state = GetDeathState(src)
    if state and state.isDead then
        local prev = state.bloodLoss or 0
        state.bloodLoss = tonumber(bloodLoss) or 0
        PlayerStates[src] = state
        pcall(function()
            Player(src).state:set('deathData', state, true)
        end)

        -- Log to Nostr only at critical threshold (75%) — avoid spam
        if Config.NostrLog and Config.NostrLog.enabled then
            if prev < 75 and state.bloodLoss >= 75 then
                NostrLog.bloodLoss(src, {
                    name      = GetName(src),
                    bloodLoss = state.bloodLoss,
                })
            end
        end
    end
end)

RegisterNetEvent('rde_death:callDoctor', function()
    local src = source
    if not src or src == 0 then return end

    -- 🔒 LOCK FIRST — before ANY yield (GetOxPlayer, GetDeathState, CanCallDoctor
    -- all yield internally in FiveM). Two coroutines for the same player can run
    -- concurrently — this must be the very first read+write on shared state.
    if DoctorCalls[src] then
        Debug(string.format('callDoctor blocked — already locked for %d', src))
        return
    end
    DoctorCalls[src] = true  -- locked — no yield between check and set

    local player = GetOxPlayer(src)
    if not player then DoctorCalls[src] = nil; return end

    local state = GetDeathState(src)
    if not state or not state.isDead then
        Debug(string.format('callDoctor rejected: player %d not dead', src))
        DoctorCalls[src] = nil
        return
    end

    local canCall, cooldownLeft = CanCallDoctor(src)
    if not canCall then
        DoctorCalls[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            title       = 'Cooldown Active',
            description = string.format('Please wait %ds before calling again', cooldownLeft),
            type        = 'warning',
        })
        return
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then DoctorCalls[src] = nil; return end
    local coords = GetEntityCoords(ped)

    local cost, responseTime, distance, hospital = CalculateDoctorDispatch(coords)

    if Config.Doctor.maxServiceDistance and distance > Config.Doctor.maxServiceDistance then
        DoctorCalls[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            title       = locale('too_far'),
            description = 'Emergency services cannot reach your location',
            type        = 'error',
        })
        return
    end

    local money = GetMoney(src)
    if money < cost then
        DoctorCalls[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            title       = locale('no_money', cost - money),
            description = string.format('Need $%d — You have $%d', cost, money),
            type        = 'error',
            icon        = 'circle-dollar-sign',
        })
        return
    end

    if not RemoveMoney(src, cost) then
        DoctorCalls[src] = nil
        TriggerClientEvent('ox_lib:notify', src, {
            title = locale('payment_failed'),
            type  = 'error',
        })
        return
    end

    LogDoctorCall(src, cost, distance, responseTime)

    TriggerClientEvent('rde_death:spawnDoctor', src, {
        cost         = cost,
        responseTime = responseTime,
        distance     = distance,
        hospital     = hospital,
    })

    NostrLog.doctor(src, {
        name     = GetName(src),
        cost     = cost,
        eta      = responseTime,
        distance = distance,
    })
end)

--[[
    rde_death:doctorTreat — paramedic finished treatment.
    Triggers rde_death:doctorRevive (NOT adminRevive) so the client
    can revive the player while letting Phase 5 handle doctor departure.
]]
RegisterNetEvent('rde_death:doctorTreat', function()
    local src = source
    if not src or src == 0 then return end

    local state = GetDeathState(src)
    if not state or not state.isDead then return end

    -- Anti-exploit: only allow doctorTreat if there's an active dispatched doctor.
    if not DoctorCalls[src] then
        Debug(string.format('doctorTreat rejected: no active doctor call for %d', src))
        return
    end

    -- Resolve charId BEFORE ClearDeathState so both the statebag clear
    -- and the direct DB update share the same guaranteed charId.
    -- GetCharId() can return nil inside an event handler if ox_core hasn't
    -- fully settled — resolving it once here avoids two separate race windows.
    local charId = GetCharId(src)

    -- Pass resolvedCharId through so DB_SetIsDead never hits the nil-retry path
    ClearDeathState(src, charId)

    -- Belt-and-suspenders: direct DB update with the already-resolved charId.
    -- This runs synchronously (await) so isDead=0 is committed before doctorRevive fires.
    if charId and mysqlReady then
        pcall(function()
            MySQL.update.await('UPDATE `characters` SET `isDead` = 0 WHERE `charid` = ?', { charId })
            Debug(string.format('✅ doctorTreat: isDead=0 committed for charId=%d', charId))
        end)
    else
        -- charId still nil (extreme edge case) — schedule one guaranteed retry
        SetTimeout(1500, function()
            local retryCharId = GetCharId(src)
            if retryCharId and mysqlReady then
                pcall(function()
                    MySQL.update.await('UPDATE `characters` SET `isDead` = 0 WHERE `charid` = ?', { retryCharId })
                    Debug(string.format('🔄 doctorTreat retry: isDead=0 committed for charId=%d', retryCharId))
                end)
            end
        end)
    end

    -- Use doctorRevive — preserves Phase 5 departure sequence
    TriggerClientEvent('rde_death:doctorRevive', src)

    Stats.totalRevives = Stats.totalRevives + 1
    MarkDoctorCallSuccess(src, true)
    SaveStats()

    NostrLog.doctorSuccess(src, {
        name = GetName(src),
        cost = DoctorCalls[src] and 0 or 0,  -- Cost already logged at dispatch
    })
    NostrLog.revive(src, { name = GetName(src), method = 'doctor_treatment' })
    Debug(string.format('Doctor revived %s [%d]', GetName(src), src))
end)

RegisterNetEvent('rde_death:respawn', function()
    local src = source
    if not src or src == 0 then return end
    if not GetOxPlayer(src) then return end

    -- Anti-exploit: only allow respawn if actually dead.
    local state = GetDeathState(src)
    if not state or not state.isDead then
        Debug(string.format('respawn rejected: player %d not dead', src))
        return
    end

    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return end

    local hospital = NearestHospital(GetEntityCoords(ped))
    if not hospital then return end

    local charId = GetCharId(src)
    ClearDeathState(src, charId)
    if charId and mysqlReady then
        pcall(function()
            MySQL.update.await('UPDATE `characters` SET `isDead` = 0 WHERE `charid` = ?', { charId })
            Debug(string.format('✅ respawn: isDead=0 committed for charId=%d', charId))
        end)
    end
    TriggerClientEvent('rde_death:doRespawn', src, hospital)

    Stats.totalRespawns = Stats.totalRespawns + 1
    SaveStats()

    NostrLog.respawn(src, { name = GetName(src), hospital = hospital.name })
    Debug(string.format('%s [%d] respawned at %s', GetName(src), src, hospital.name))
end)

-- =============================================
-- 🎖️ ADMIN COMMANDS
-- =============================================
-- Build restricted list from Config.Admin so all configured groups work.
local function BuildAdminRestricted()
    local r = {}
    for _, g in ipairs(Config.Admin.groups or {}) do
        r[#r + 1] = 'group.' .. g
    end
    if Config.Admin.acePermission and Config.Admin.acePermission ~= '' then
        r[#r + 1] = Config.Admin.acePermission
    end
    if #r == 0 then r[1] = 'group.admin' end
    return r
end

lib.addCommand('revive', {
    help       = '🚑 Revive a downed player (instant)',
    params     = {
        { name = 'target', type = 'playerId', help = 'Target player ID' },
    },
    restricted = BuildAdminRestricted(),
}, function(source, args)
    local src      = source
    local targetId = tonumber(args.target)
    if not targetId or targetId <= 0 then return end

    local targetName = GetName(targetId)

    ClearDeathState(targetId)
    -- adminRevive = immediate doctor cleanup on client side
    TriggerClientEvent('rde_death:adminRevive', targetId)

    lib.notify(src, {
        title       = 'Player Revived',
        description = string.format('%s has been revived', targetName),
        type        = 'success',
    })

    NostrLog.admin(src, {
        action = 'revive',
        target = string.format('%s [%d]', targetName, targetId),
    })

    Debug(string.format('Admin %d revived %s [%d]', src, targetName, targetId))
end)

lib.addCommand('deathstatus', {
    help       = '📊 Check a player\'s death status',
    params     = {
        { name = 'target', type = 'playerId', help = 'Target player ID' },
    },
    restricted = BuildAdminRestricted(),
}, function(source, args)
    local targetId = tonumber(args.target)
    if not targetId then return end

    local state  = GetDeathState(targetId)
    local isDead = state and state.isDead or false
    local blood  = state and state.bloodLoss or 0
    local injury = state and state.injuryType or 0

    lib.notify(source, {
        title       = string.format('Status: %s', GetName(targetId)),
        description = string.format('Dead: %s | Blood: %d%% | Injury: %d',
            tostring(isDead), blood, injury),
        type        = isDead and 'error' or 'success',
    })
end)

lib.addCommand('aidmdstats', {
    help       = '📈 View AIMD server statistics',
    restricted = BuildAdminRestricted(),
}, function(source)
    lib.notify(source, {
        title       = '🐉 AIMD Statistics',
        description = string.format(
            'Deaths: %d | Revives: %d | Respawns: %d | Doctor Calls: %d | Revenue: $%d',
            Stats.totalDeaths,
            Stats.totalRevives,
            Stats.totalRespawns,
            Stats.totalDoctorCalls,
            Stats.totalRevenue
        ),
        type     = 'inform',
        duration = 8000,
    })
end)

-- =============================================
-- 👤 PLAYER LIFECYCLE
-- =============================================
AddEventHandler('ox:playerLoaded', function(source, userid, charid)
    local src = source

    -- Wait for ox_core to fully settle the character session.
    Wait(1500)

    -- Prefer the charid passed by ox:playerLoaded — it's the most reliable source
    -- and avoids calling GetCharId() which can still return nil at this point.
    local charId = charid or GetCharId(src)

    --[[
        FIX: isDead=1 on login bug.

        BEFORE (broken): If isDead=1 in DB, the server re-applied the death state
        and fired rde_death:forceDeathState → player was dead again on every login.
        Even setting isDead=0 in Navicat didn't help if the server restarted while
        a player was dead, because the DB never got cleared on resource stop.

        NOW (correct): isDead=1 in the DB means the player was dead when they last
        disconnected (crash, server restart, etc.). On next login we ALWAYS:
          1. Clear the in-memory death state
          2. Reset isDead=0 in the DB (via ClearDeathState → DB_SetIsDead)
          3. Trigger a hospital respawn on the client side so the player wakes up
             at the nearest hospital instead of being stuck dead forever.

        This matches real RP server behavior: you never come back to life mid-bleed.
        You respawn at the hospital. Period.
    ]]
    if not mysqlReady or not charId then
        -- No DB available — still clear in-memory state so player isn't stuck dead
        ClearDeathState(src)
        return
    end

    local ok, rows = pcall(function()
        return MySQL.query.await(
            'SELECT `isDead` FROM `characters` WHERE `charid` = ?',
            { charId })
    end)

    if ok and rows and #rows > 0 then
        local dbDead = tonumber(rows[1].isDead) or 0
        if dbDead == 1 then
            print(string.format('^3[RDE | AIMD]^7 ⚠️ Player %s [%d] had isDead=1 — auto-clearing & respawning at hospital', GetName(src), src))

            -- 1. Clear in-memory + reset DB to 0
            ClearDeathState(src, charId)

            -- 2. Give client another moment to fully load in before teleporting
            Wait(1000)

            -- 3. Find nearest hospital and send the client there
            local ped     = GetPlayerPed(src)
            local coords  = (ped and ped ~= 0) and GetEntityCoords(ped) or vector3(0, 0, 0)
            local hospital = NearestHospital(coords)
            if not hospital then hospital = Config.Hospitals[1] end

            TriggerClientEvent('rde_death:doRespawn', src, hospital)

            Stats.totalRespawns = Stats.totalRespawns + 1
            SaveStats()

            NostrLog.respawn(src, {
                name     = GetName(src),
                hospital = hospital and hospital.name or 'Hospital',
            })
        else
            -- Player was alive — nothing to do, just make sure state is clean
            ClearDeathState(src, charId)
        end
    else
        ClearDeathState(src, charId)
    end

    Debug(string.format('Player loaded: %s [%d]', GetName(src), src))
end)

AddEventHandler('ox:playerLogout', function(source, userid, charid)
    DoctorCalls[source]   = nil
    CallCooldowns[source] = nil
    Debug(string.format('Player logout: [%d]', source))
end)

AddEventHandler('playerDropped', function(reason)
    local src = source
    DoctorCalls[src]   = nil
    CallCooldowns[src] = nil
    Debug(string.format('Player dropped [%d]: %s', src, reason))
end)

-- =============================================
-- 📤 EXPORTS
-- =============================================
exports('GetDeathState', function(source)
    return GetDeathState(tonumber(source))
end)

exports('IsDead', function(source)
    local state = GetDeathState(tonumber(source))
    return state and state.isDead or false
end)

exports('RevivePlayer', function(source)
    local src = tonumber(source)
    if not src or src == 0 then return false end
    ClearDeathState(src)
    TriggerClientEvent('rde_death:adminRevive', src)
    return true
end)

exports('GetStats', function()
    return Stats
end)

-- =============================================
-- 🗃️ AUTO-CREATE TABLES
-- =============================================
local function CreateTables()
    if not mysqlReady or not Config.Database.enabled then return end
    local prefix = Config.Database.tablePrefix

    MySQL.query.await(string.format([[
        CREATE TABLE IF NOT EXISTS `%sdeath_logs` (
            `id`            INT AUTO_INCREMENT PRIMARY KEY,
            `char_id`       INT NOT NULL,
            `player_name`   VARCHAR(100) NOT NULL,
            `injury_type`   TINYINT DEFAULT 1,
            `death_coords`  VARCHAR(60),
            `death_reason`  INT DEFAULT 0,
            `blood_loss`    TINYINT DEFAULT 0,
            `created_at`    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_char_id` (`char_id`),
            INDEX `idx_created` (`created_at`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], prefix))

    MySQL.query.await(string.format([[
        CREATE TABLE IF NOT EXISTS `%sdoctor_calls` (
            `id`              INT AUTO_INCREMENT PRIMARY KEY,
            `char_id`         INT NOT NULL,
            `player_name`     VARCHAR(100) NOT NULL,
            `call_coords`     VARCHAR(60),
            `cost`            INT DEFAULT 0,
            `distance`        INT DEFAULT 0,
            `response_time`   INT DEFAULT 0,
            `success`         TINYINT DEFAULT 0,
            `completion_time` TIMESTAMP NULL,
            `created_at`      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            INDEX `idx_char_id` (`char_id`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], prefix))

    MySQL.query.await(string.format([[
        CREATE TABLE IF NOT EXISTS `%sdeath_statistics` (
            `id`                        INT AUTO_INCREMENT PRIMARY KEY,
            `total_deaths`              INT DEFAULT 0,
            `total_revives`             INT DEFAULT 0,
            `total_respawns`            INT DEFAULT 0,
            `total_doctor_calls`        INT DEFAULT 0,
            `successful_doctor_calls`   INT DEFAULT 0,
            `total_revenue`             INT DEFAULT 0,
            `updated_at`                TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci
    ]], prefix))

    MySQL.query.await(string.format([[
        INSERT IGNORE INTO `%sdeath_statistics` (id) VALUES (1)
    ]], prefix))

    print(string.format('^2[RDE | AIMD]^7 Database tables ready (prefix: %s)', prefix))
end

local function PruneLogs()
    if not mysqlReady or not Config.Database.enabled then return end
    if not Config.Database.keepLogsForDays or Config.Database.keepLogsForDays <= 0 then return end
    local prefix = Config.Database.tablePrefix
    local days   = Config.Database.keepLogsForDays
    pcall(function()
        MySQL.query.await(string.format(
            'DELETE FROM `%sdeath_logs` WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
            prefix), { days })
        MySQL.query.await(string.format(
            'DELETE FROM `%sdoctor_calls` WHERE created_at < DATE_SUB(NOW(), INTERVAL ? DAY)',
            prefix), { days })
        Debug(string.format('Pruned logs older than %d days', days))
    end)
end

-- =============================================
-- 🧹 CLEANUP
-- =============================================
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end

    --[[
        FIX: On resource stop (server restart / txAdmin restart / resource restart),
        reset isDead=0 for every player that is currently marked as dead in memory.
        Without this, if a player dies and the server restarts before they revive,
        isDead=1 stays in the DB and they will be dead again on next login.
    ]]
    if mysqlReady and Config.Database.enabled then
        for src, state in pairs(PlayerStates) do
            if state and state.isDead then
                local charId = GetCharId(src)
                if charId then
                    pcall(function()
                        MySQL.update.await(
                            'UPDATE `characters` SET `isDead` = 0 WHERE `charid` = ?',
                            { charId })
                        Debug(string.format('onResourceStop: cleared isDead for charId=%d', charId))
                    end)
                end
            end
        end
        SaveStats()
    end

    for src in pairs(PlayerStates)  do PlayerStates[src]  = nil end
    for src in pairs(DoctorCalls)   do DoctorCalls[src]   = nil end
    for src in pairs(CallCooldowns) do CallCooldowns[src]  = nil end
    print('^3[RDE | AIMD]^7 Server cleanup complete')
end)

-- =============================================
-- ✅ INITIALIZATION
-- =============================================
CreateThread(function()
    local tries = 0
    repeat
        Wait(200)
        tries = tries + 1
        local ok = pcall(function()
            exports.ox_core:GetPlayer(0)
            oxReady = true
        end)
    until oxReady or tries >= 50

    if oxReady then
        print('^2[RDE | AIMD]^7 ox_core ✅')
    else
        print('^1[RDE | AIMD]^7 ⚠️ ox_core not detected — some features disabled')
    end

    if Config.Database.enabled then
        if GetResourceState('oxmysql') == 'started' then
            MySQL.ready(function()
                mysqlReady = true
                print('^2[RDE | AIMD]^7 MySQL ✅')
                CreateTables()
                SetTimeout(500, LoadStats)
                SetTimeout(1000, PruneLogs)
            end)
        else
            print('^3[RDE | AIMD]^7 oxmysql not running — database disabled')
        end
    else
        print('^3[RDE | AIMD]^7 Database disabled in config')
    end

    Wait(3000)
    print('^2[RDE | AIMD]^7 🐉 AI Medical Department v1.0.0 — SERVER OPERATIONAL')
    print(string.format('^3  ✅^7 NostrLog: %s',
        Config.NostrLog and Config.NostrLog.enabled
        and 'rde_nostr_log ⚡ ACTIVE' or 'disabled (enable in config.lua)'))
    print('^3  ✅^7 isDead bulletproof DB sync')
    print('^3  ✅^7 Rate limiting + anti-spam')
    print('^3  ✅^7 Auto-create tables + log pruning')
    print('^3  ✅^7 doctorRevive = natural departure | adminRevive = instant cleanup')
    print('^3  ✅^7 ox_core | https://coxdocs.dev')
end)