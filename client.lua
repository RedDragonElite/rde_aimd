--[[
    ██████╗ ██████╗ ███████╗
    ██╔══██╗██╔══██╗██╔════╝
    ██████╔╝██║  ██║█████╗
    ██╔══██╗██║  ██║██╔══╝
    ██║  ██║██████╔╝███████╗
    ╚═╝  ╚═╝╚═════╝ ╚══════╝

    🐉 rde_aimd v1.0.5 — CLIENT
    RDE AI Medical Department | First Open-Source ox_core Death System

    Features:
        ✅ Emergency driving style 786468 — RUNS RED LIGHTS
        ✅ lib.progressBar treatment animation
        ✅ Live death HUD — top-center position
        ✅ Cinematic orbiting death camera
        ✅ Metadata-rich context menu with ox_lib
        ✅ Aggressive caching (cache.ped, GameTimer)
        ✅ Zero unnecessary frame usage
        ✅ 🌿 GRASS FIX: Smart stuck-detection + forced off-road arrival
        ✅ Paramedic walks to player on foot across any terrain
        ✅ Doctor returns to vehicle & drives away naturally post-revive
        ✅ Admin /revive = instant cleanup | Doctor revive = realistic exit
        ✅ FIX #7: TriggerEvent('rde_death:localRevive') nach jedem Revive
                   → externe Scripts (rde_aipd etc.) werden sofort informiert
                   → ox:playerRevived feuert nur bei ox_core-internen Revives,
                     nicht bei rde_aimd Revives — dieser Fix schließt die Lücke
]]

-- =============================================
-- 🔧 STATE
-- =============================================
local State = {
    isDead              = false,
    deathTime           = 0,
    injuryType          = 1,
    bloodLoss           = 0.0,
    deathCoords         = vector3(0,0,0),
    isReviving          = false,
    ambulanceEnRoute    = false,
    ambulanceCost       = 0,
    ambulanceETA        = 0,
    doctorCallSent      = false,
    fullyLoaded         = false,
    spawnProtected      = true,
    firstSpawnDone      = false,
    lastReviveTime      = 0,
    lastDoctorCall      = 0,
}

local Doctor = {
    vehicle = nil,
    ped     = nil,
    blip    = nil,
}

local DeathCam = {
    handle  = nil,
    angle   = 0.0,
}

local Threads = {
    bleedout    = nil,
    effects     = nil,
    hud         = nil,
    camera      = nil,
}

local ActiveEffects     = {}
local HeartbeatSoundId  = nil
local LastHeartbeat     = 0

-- =============================================
-- 🛡️ UTILITIES
-- =============================================
local function Debug(...)
    if Config.Debug then
        print('^3[RDE | AIMD Client]^7', ...)
    end
end

local function FormatTime(secs)
    secs = math.floor(secs)
    if secs < 60 then return string.format('%ds', secs) end
    return string.format('%dm %02ds', math.floor(secs / 60), secs % 60)
end

local function RequestModelSafe(model)
    if type(model) == 'string' then model = joaat(model) end
    if not IsModelValid(model) then return false end
    if HasModelLoaded(model) then return true end
    RequestModel(model)
    local t = 0
    while not HasModelLoaded(model) and t < 100 do Wait(10); t = t + 1 end
    return HasModelLoaded(model)
end

local function GetCurrentInjury()
    return Config.Injuries[State.injuryType] or Config.Injuries[1]
end

local function GetInjuryName()
    local inj = GetCurrentInjury()
    return locale(inj.key) or inj.key
end

local function GetNearestHospital()
    local pos   = GetEntityCoords(cache.ped)
    local best  = nil
    local bestD = math.huge
    for _, h in ipairs(Config.Hospitals) do
        if h.coords then
            local d = #(pos - vector3(h.coords.x, h.coords.y, h.coords.z))
            if d < bestD then bestD = d; best = h end
        end
    end
    return best or Config.Hospitals[1]
end

-- =============================================
-- 🔊 AUDIO
-- =============================================
local function StopHeartbeat()
    if HeartbeatSoundId then
        StopSound(HeartbeatSoundId)
        ReleaseSoundId(HeartbeatSoundId)
        HeartbeatSoundId = nil
    end
    LastHeartbeat = 0
end

local function TickHeartbeat()
    if not Config.Effects.heartbeat.enabled or not State.isDead then return end
    local cfg      = Config.Effects.heartbeat
    local interval = cfg.baseInterval
    if cfg.progressive then
        interval = math.floor(interval * math.max(0.35, 1.0 - (State.bloodLoss / 130.0)))
    end
    local now = GetGameTimer()
    if LastHeartbeat == 0 or (now - LastHeartbeat) >= interval then
        StopHeartbeat()
        HeartbeatSoundId = GetSoundId()
        PlaySoundFrontend(HeartbeatSoundId, cfg.sound, cfg.soundSet, false)
        LastHeartbeat = now
    end
end

-- =============================================
-- 🎥 DEATH CAMERA
-- =============================================
local function StartDeathCamera()
    if not Config.Effects.deathCam.enabled or DeathCam.handle then return end
    local cfg = Config.Effects.deathCam
    local ped = cache.ped

    DeathCam.handle = CreateCam('DEFAULT_SCRIPTED_CAMERA', true)
    DeathCam.angle  = GetEntityHeading(ped)

    local pos = GetEntityCoords(ped)
    SetCamCoord(DeathCam.handle, pos.x, pos.y, pos.z + cfg.height)
    PointCamAtEntity(DeathCam.handle, ped, 0.0, 0.0, 0.0, true)
    SetCamFov(DeathCam.handle, cfg.fov)
    SetCamActive(DeathCam.handle, true)
    RenderScriptCams(true, true, 800, true, true)

    Threads.camera = true
    CreateThread(function()
        local orbitDist = 3.0
        local speed     = cfg.orbitSpeed
        local height    = cfg.height

        while State.isDead and Threads.camera do
            Wait(0)
            if not DoesEntityExist(DeathCam.handle) then break end
            DeathCam.angle = (DeathCam.angle + speed) % 360.0
            local bodyPos = GetEntityCoords(cache.ped)
            local rad     = math.rad(DeathCam.angle)
            SetCamCoord(DeathCam.handle,
                bodyPos.x + orbitDist * math.cos(rad),
                bodyPos.y + orbitDist * math.sin(rad),
                bodyPos.z + height)
            PointCamAtEntity(DeathCam.handle, cache.ped, 0.0, 0.0, 0.3, true)
        end
        Threads.camera = nil
    end)
end

local function StopDeathCamera()
    Threads.camera = nil
    if DeathCam.handle then
        RenderScriptCams(false, true, 600, true, true)
        DestroyCam(DeathCam.handle, false)
        DeathCam.handle = nil
    end
end

-- =============================================
-- ✨ SCREEN EFFECTS
-- =============================================
local function ApplyScreenEffects()
    local cfg = Config.Effects

    if cfg.bloodScreen.enabled then
        local fx = cfg.bloodScreen.effect
        if not ActiveEffects[fx] then
            StartScreenEffect(fx, 0, true)
            ActiveEffects[fx] = true
        end
    end

    if cfg.blur.enabled then
        local amount = cfg.blur.intensity
        if cfg.blur.progressive then amount = amount * math.min(1.0, State.bloodLoss / 100.0) end
        TriggerScreenblurFadeIn(math.max(1, math.floor(amount)))
    end

    if cfg.timecycle.enabled then
        SetTimecycleModifier(cfg.timecycle.modifier)
        SetTimecycleModifierStrength(cfg.timecycle.strength)
    end

    TickHeartbeat()
end

local function ClearAllEffects()
    Threads.effects = nil
    for fx in pairs(ActiveEffects) do StopScreenEffect(fx) end
    ActiveEffects = {}
    TriggerScreenblurFadeOut(600)
    ClearTimecycleModifier()
    StopHeartbeat()
    StopDeathCamera()
end

-- =============================================
-- 🖥️ DEATH HUD (top-center)
-- =============================================
local function FormatHUD()
    local injury  = GetInjuryName()
    local elapsed = (GetGameTimer() - State.deathTime) / 1000
    local blood   = math.floor(State.bloodLoss)
    local filled  = math.floor(blood / 10)
    local bar     = ('█'):rep(filled) .. ('░'):rep(10 - filled)

    return string.format(
        '%s\n%s [%s] %d%%\n%s\n%s',
        locale('death_ui_header'),
        locale('death_ui_bleeding', blood),
        bar, blood,
        locale('death_ui_time', FormatTime(elapsed)),
        locale('death_ui_injury', injury)
    )
end

local function StartDeathHUD()
    if Threads.hud then return end
    Threads.hud = true

    lib.showTextUI(FormatHUD(), {
        position  = 'top-center',
        icon      = 'heart-pulse',
        iconColor = '#ef4444',
        style     = { borderRadius = 6 }
    })

    CreateThread(function()
        while State.isDead and Threads.hud do
            Wait(1000)
            if not State.isDead or not Threads.hud then break end
            lib.hideTextUI()
            lib.showTextUI(FormatHUD(), {
                position  = 'top-center',
                icon      = 'heart-pulse',
                iconColor = '#ef4444',
            })
        end
        lib.hideTextUI()
        Threads.hud = nil
    end)
end

local function StopDeathHUD()
    Threads.hud = nil
    lib.hideTextUI()
end

-- =============================================
-- 📋 DEATH MENU
-- =============================================
local function BuildDeathMenu()
    local options     = {}
    local elapsed     = (GetGameTimer() - State.deathTime) / 1000
    local respawnTime = Config.Death.respawnTime
    local canRespawn  = elapsed >= respawnTime
    local injury      = GetInjuryName()
    local blood       = math.floor(State.bloodLoss)

    table.insert(options, {
        title       = locale('menu_vitals'),
        description = locale('menu_vitals_desc', injury, blood, FormatTime(elapsed)),
        icon        = 'heart-pulse',
        iconColor   = blood > 60 and '#ef4444' or blood > 30 and '#f59e0b' or '#10b981',
        metadata    = {
            { label = 'Injury',     value = injury },
            { label = 'Blood Loss', value = blood .. '%' },
            { label = 'Time Down',  value = FormatTime(elapsed) },
            { label = 'Status',     value = locale('menu_status_dead') },
        },
        disabled = true,
    })

    if State.ambulanceEnRoute then
        local dist = 0
        if Doctor.vehicle and DoesEntityExist(Doctor.vehicle) then
            dist = math.floor(#(GetEntityCoords(cache.ped) - GetEntityCoords(Doctor.vehicle)))
        end
        table.insert(options, {
            title       = locale('menu_ambulance_enroute'),
            description = locale('menu_ambulance_dist', math.ceil(State.ambulanceETA), dist),
            icon        = 'truck-medical',
            iconColor   = '#f59e0b',
            metadata    = {
                { label = 'ETA',      value = math.ceil(State.ambulanceETA) .. 's' },
                { label = 'Distance', value = dist .. 'm' },
                { label = 'Cost',     value = '$' .. State.ambulanceCost .. ' (charged)' },
            },
            disabled = true,
        })
    elseif Config.Doctor.enabled then
        local cost = Config.Doctor.baseCost
        table.insert(options, {
            title       = locale('menu_call_ambulance'),
            description = locale('menu_call_cost', cost),
            icon        = 'ambulance',
            iconColor   = '#10b981',
            onSelect    = function()
                if State.ambulanceEnRoute or State.doctorCallSent then return end
                State.doctorCallSent = true
                TriggerServerEvent('rde_death:callDoctor')
                -- Reset after 15s in case server rejects (no money etc.)
                SetTimeout(15000, function() State.doctorCallSent = false end)
            end,
        })
    end

    if canRespawn then
        table.insert(options, {
            title       = locale('menu_respawn'),
            description = locale('menu_respawn_desc'),
            icon        = 'house-medical',
            iconColor   = '#3b82f6',
            onSelect    = function()
                TriggerServerEvent('rde_death:respawn')
            end,
        })
    else
        local timeLeft = math.ceil(respawnTime - elapsed)
        table.insert(options, {
            title       = locale('menu_respawn_locked', timeLeft),
            description = locale('menu_respawn_locked_desc'),
            icon        = 'lock',
            iconColor   = '#6b7280',
            disabled    = true,
        })
    end

    return options
end

local function OpenDeathMenu()
    if not State.isDead then return end
    lib.registerContext({
        id      = 'rde_death_menu',
        title   = locale('menu_title'),
        options = BuildDeathMenu(),
    })
    lib.showContext('rde_death_menu')
end

-- =============================================
-- 🧟 RAGDOLL
-- =============================================
local function StartRagdoll()
    if not Config.Death.ragdollEnabled then return end
    local ped = cache.ped
    SetPedToRagdoll(ped, 10000, 10000, 0, true, true, false)
    CreateThread(function()
        while State.isDead and not State.isReviving do
            if not IsPedRagdoll(ped) then
                SetPedToRagdoll(ped, 10000, 10000, 0, true, true, false)
            end
            Wait(Config.Death.ragdollInterval)
        end
    end)
end

-- =============================================
-- 🚑 AMBULANCE SYSTEM
-- =============================================
local function CleanupDoctor()
    Debug('Cleaning up doctor entities')

    if Doctor.blip and DoesBlipExist(Doctor.blip) then RemoveBlip(Doctor.blip) end
    if Doctor.ped and DoesEntityExist(Doctor.ped) then DeleteEntity(Doctor.ped) end
    if Doctor.vehicle and DoesEntityExist(Doctor.vehicle) then
        SetEntityAsMissionEntity(Doctor.vehicle, false, true)
        DeleteEntity(Doctor.vehicle)
    end

    Doctor.vehicle          = nil
    Doctor.ped              = nil
    Doctor.blip             = nil
    State.ambulanceEnRoute  = false
    State.ambulanceCost     = 0
    State.ambulanceETA      = 0
    State.doctorCallSent    = false
end

local function FindSpawnPoint(playerCoords)
    local minD  = Config.Doctor.spawn.minSpawnDistance
    local maxD  = Config.Doctor.spawn.maxSpawnDistance
    local tries = Config.Doctor.spawn.searchAttempts

    for _ = 1, tries do
        local ox = math.random(-maxD, maxD)
        local oy = math.random(-maxD, maxD)
        local found, pos, heading = GetClosestVehicleNodeWithHeading(
            playerCoords.x + ox, playerCoords.y + oy, playerCoords.z, 1, 3.0, 0)
        if found then
            local dist = #(playerCoords - pos)
            if dist >= minD and dist <= maxD then
                Debug(string.format('Spawn found %.0fm away', dist))
                return pos, heading
            end
        end
    end

    Debug('No ideal spawn — fallback')
    return vector3(playerCoords.x + Config.Doctor.spawn.minSpawnDistance, playerCoords.y, playerCoords.z), 0.0
end

local function SpawnAmbulance(playerCoords)
    local cfg       = Config.Doctor
    local vehModel  = joaat(cfg.vehicle.model)
    local pedModel  = joaat(cfg.ped.model)

    if not RequestModelSafe(vehModel) or not RequestModelSafe(pedModel) then
        Debug('Model loading failed')
        return false
    end

    local spawnPos, heading = FindSpawnPoint(playerCoords)
    local veh = CreateVehicle(vehModel, spawnPos.x, spawnPos.y, spawnPos.z, heading, true, false)
    if not DoesEntityExist(veh) then
        Debug('Failed to create vehicle')
        SetModelAsNoLongerNeeded(vehModel)
        SetModelAsNoLongerNeeded(pedModel)
        return false
    end

    SetVehicleOnGroundProperly(veh)
    SetEntityAsMissionEntity(veh, true, true)
    SetVehicleDoorsLocked(veh, 4)
    SetVehicleEngineOn(veh, true, true, false)
    SetVehicleModKit(veh, 0)

    if cfg.driving.useSirens then
        SetVehicleSiren(veh, true)
        SetVehicleHasBeenOwnedByPlayer(veh, true)
    end

    if cfg.vehicle.plateText then
        SetVehicleNumberPlateText(veh, cfg.vehicle.plateText)
    end

    local ped = CreatePedInsideVehicle(veh, 26, pedModel, -1, true, false)
    if not DoesEntityExist(ped) then
        Debug('Failed to create ped')
        DeleteEntity(veh)
        SetModelAsNoLongerNeeded(vehModel)
        SetModelAsNoLongerNeeded(pedModel)
        return false
    end

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true)
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 17, true)
    SetPedCanBeTargetted(ped, false)
    SetDriverAbility(ped, 1.0)
    SetDriverAggressiveness(ped, 0.3)

    local blip = AddBlipForEntity(veh)
    SetBlipSprite(blip, cfg.vehicle.blip.sprite)
    SetBlipColour(blip, cfg.vehicle.blip.color)
    SetBlipScale(blip, cfg.vehicle.blip.scale)
    SetBlipAsShortRange(blip, cfg.vehicle.blip.shortRange)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName('🚑 Emergency Services')
    EndTextCommandSetBlipName(blip)

    Doctor.vehicle  = veh
    Doctor.ped      = ped
    Doctor.blip     = blip

    SetModelAsNoLongerNeeded(vehModel)
    SetModelAsNoLongerNeeded(pedModel)

    Debug('Ambulance spawned successfully')
    return true
end

local function RunDoctorBehavior()
    if not Doctor.vehicle or not Doctor.ped then
        CleanupDoctor()
        return
    end

    CreateThread(function()
        local cfg           = Config.Doctor
        local driveSpeed    = cfg.driving.speed
        local driveStyle    = cfg.driving.style  -- 786468 = runs red lights
        local arrivalRadius = cfg.arrivalRadius
        local playerPed     = cache.ped

        -- ── PHASE 1: DRIVE TO SCENE ──────────────────────────────
        local dest = GetEntityCoords(playerPed)

        TaskVehicleDriveToCoordLongrange(
            Doctor.ped, Doctor.vehicle,
            dest.x, dest.y, dest.z,
            driveSpeed, driveStyle, 5.0
        )
        SetDriveTaskDrivingStyle(Doctor.ped, driveStyle)

        if cfg.driving.useHorn then
            CreateThread(function()
                while State.ambulanceEnRoute do
                    Wait(math.random(8000, 15000))
                    if Doctor.vehicle and DoesEntityExist(Doctor.vehicle) then
                        if GetEntitySpeed(Doctor.vehicle) < 3.0 then
                            SoundVehicleHornThisFrame(Doctor.vehicle)
                        end
                    end
                end
            end)
        end

        Debug('Ambulance driving to scene...')

        local FORCED_ARRIVAL_DIST = cfg.forcedArrivalDist or 80.0
        local stuckFrames         = 0

        local function GetRoadTarget()
            local plrPos = GetEntityCoords(playerPed)
            local found, roadPos = GetClosestVehicleNode(plrPos.x, plrPos.y, plrPos.z, 1, 3.0, 0)
            return found and roadPos or plrPos
        end

        local roadTarget = GetRoadTarget()

        while State.ambulanceEnRoute and State.isDead do
            Wait(800)

            if not DoesEntityExist(Doctor.vehicle) or not DoesEntityExist(Doctor.ped) then
                Debug('Doctor entities lost during transit')
                CleanupDoctor()
                return
            end

            local vehPos = GetEntityCoords(Doctor.vehicle)
            local plrPos = GetEntityCoords(playerPed)
            local dist   = #(vehPos - plrPos)
            local vSpeed = GetEntitySpeed(Doctor.vehicle)

            State.ambulanceETA = math.max(0, dist / math.max(1.0, vSpeed))

            if dist < arrivalRadius then
                Debug('Arrived (standard radius)')
                break
            end

            if #(vehPos - roadTarget) < arrivalRadius then
                Debug('Arrived at player road node — forcing off-road arrival')
                break
            end

            if vSpeed < 0.5 then
                stuckFrames = stuckFrames + 1

                if stuckFrames >= 3 then
                    stuckFrames = 0

                    if dist <= FORCED_ARRIVAL_DIST then
                        Debug(string.format('🌿 Grass fix: forced arrival at %.0fm', dist))
                        break
                    else
                        roadTarget = GetRoadTarget()
                        TaskVehicleDriveToCoordLongrange(
                            Doctor.ped, Doctor.vehicle,
                            roadTarget.x, roadTarget.y, roadTarget.z,
                            driveSpeed, driveStyle, 5.0
                        )
                        SetDriveTaskDrivingStyle(Doctor.ped, driveStyle)
                        Debug('Re-tasked to road node near player')
                        Wait(1500)
                    end
                end
            else
                stuckFrames = 0
            end
        end

        if not State.isDead then
            CleanupDoctor()
            return
        end

        -- ── PHASE 2: ARRIVAL ─────────────────────────────────────
        Debug('Ambulance arrived at scene')

        if cfg.driving.useSirens then
            SetVehicleSiren(Doctor.vehicle, false)
        end

        lib.notify({
            title     = locale('doctor_arrived'),
            type      = 'inform',
            icon      = 'truck-medical',
            iconColor = '#f59e0b',
            duration  = 4000,
            position  = 'top-right',
        })

        local plrPos       = GetEntityCoords(playerPed)
        local distToPlayer = #(GetEntityCoords(Doctor.vehicle) - plrPos)
        ClearPedTasks(Doctor.ped)

        if distToPlayer > 15.0 then
            local vPos = GetEntityCoords(Doctor.vehicle)
            TaskVehiclePark(Doctor.ped, Doctor.vehicle, vPos.x, vPos.y, vPos.z, GetEntityHeading(Doctor.vehicle), 1, 5.0, true)
            Debug(string.format('Roadside park (%.0fm — off-road scenario)', distToPlayer))
        else
            TaskVehiclePark(Doctor.ped, Doctor.vehicle, plrPos.x, plrPos.y, plrPos.z, 0.0, 1, 20.0, true)
        end
        Wait(2500)

        TaskLeaveVehicle(Doctor.ped, Doctor.vehicle, 0)
        Wait(1800)

        -- ── PHASE 3: WALK TO PLAYER ───────────────────────────────
        local targetPos = GetEntityCoords(playerPed)

        TaskGoToCoordAnyMeans(Doctor.ped, targetPos.x, targetPos.y, targetPos.z, 2.0, 0, 0, 0, 0)

        local reached = false
        local timeout = 0
        while timeout < 20 and not reached do
            Wait(500)
            timeout = timeout + 1
            if not DoesEntityExist(Doctor.ped) then return end
            if #(GetEntityCoords(Doctor.ped) - GetEntityCoords(playerPed)) < 2.5 then
                reached = true
            end
        end

        if not reached then
            local pp   = GetEntityCoords(playerPed)
            local h    = GetEntityHeading(playerPed)
            SetEntityCoords(Doctor.ped,
                pp.x + math.cos(math.rad(h + 90)) * 1.5,
                pp.y + math.sin(math.rad(h + 90)) * 1.5,
                pp.z, false, false, false, true)
            Debug('Paramedic teleported (fallback)')
        end

        -- ── PHASE 4: TREATMENT ────────────────────────────────────
        if not State.isDead then
            CleanupDoctor()
            return
        end

        TaskTurnPedToFaceEntity(Doctor.ped, playerPed, -1)
        Wait(700)

        local animDict = cfg.ped.treatAnim.dict
        local animClip = cfg.ped.treatAnim.clip

        RequestAnimDict(animDict)
        local t = 0
        while not HasAnimDictLoaded(animDict) and t < 50 do Wait(10); t = t + 1 end

        if HasAnimDictLoaded(animDict) then
            TaskPlayAnim(Doctor.ped, animDict, animClip, 8.0, -8.0, -1, 1, 0, false, false, false)
        else
            TaskStartScenarioInPlace(Doctor.ped, 'CODE_HUMAN_MEDIC_TEND_TO_DEAD', 0, true)
        end

        lib.notify({
            title     = locale('doctor_treating'),
            type      = 'inform',
            icon      = 'user-doctor',
            iconColor = '#10b981',
            duration  = (cfg.treatmentTime * 1000) + 500,
            position  = 'top-right',
        })

        if lib.progressBar({
            duration      = cfg.treatmentTime * 1000,
            label         = locale('doctor_treating'),
            useWhileDead  = true,
            canCancel     = false,
            disable       = { move = true, car = true, combat = true },
        }) then
            if State.isDead then
                TriggerServerEvent('rde_death:doctorTreat')
            end
        end

        -- ── PHASE 5: DOCTOR DEPARTS ───────────────────────────────
        ClearPedTasksImmediately(Doctor.ped)
        Wait(cfg.returnDelay)

        if DoesEntityExist(Doctor.ped) and DoesEntityExist(Doctor.vehicle) then
            lib.notify({
                title     = '🚑 Paramedic Departing',
                type      = 'inform',
                icon      = 'truck-medical',
                iconColor = '#6b7280',
                duration  = 4000,
                position  = 'top-right',
            })

            local vehPos = GetEntityCoords(Doctor.vehicle)
            TaskGoToCoordAnyMeans(Doctor.ped, vehPos.x, vehPos.y, vehPos.z, 2.0, 0, 0, 0, 0)
            Wait(4000)

            TaskEnterVehicle(Doctor.ped, Doctor.vehicle, -1, -1, 1.0, 1, 0)
            Wait(3500)

            if DoesEntityExist(Doctor.vehicle) then
                if cfg.driving.useSirens then
                    SetVehicleSiren(Doctor.vehicle, true)
                end

                if Doctor.blip and DoesBlipExist(Doctor.blip) then
                    RemoveBlip(Doctor.blip)
                    Doctor.blip = nil
                end

                TaskVehicleDriveWander(Doctor.ped, Doctor.vehicle, driveSpeed, driveStyle)
                SetDriveTaskDrivingStyle(Doctor.ped, driveStyle)
                Debug('Doctor driving away from scene')
            end
        end

        SetTimeout(cfg.despawnDelay, function()
            CleanupDoctor()
            Debug('Ambulance despawned after scene departure')
        end)
    end)
end

-- =============================================
-- 💀 DEATH HANDLER
-- =============================================
local function OnPlayerDied(killer, weaponHash)
    if not State.fullyLoaded or State.spawnProtected then
        Debug('Death blocked by spawn protection')
        return
    end
    if State.isDead or State.isReviving then return end
    if GetGameTimer() - State.lastReviveTime < 5000 then return end

    Debug('Player died')

    local ped = cache.ped

    State.isDead        = true
    State.deathTime     = GetGameTimer()
    State.deathCoords   = GetEntityCoords(ped)
    State.injuryType    = math.random(1, #Config.Injuries)
    State.bloodLoss     = 0.0
    State.isReviving    = false

    StartRagdoll()

    SetTimeout(400, function()
        StartDeathCamera()
        StartDeathHUD()

        Threads.effects = true
        CreateThread(function()
            while State.isDead and Threads.effects do
                ApplyScreenEffects()
                Wait(500)
            end
            Threads.effects = nil
        end)
    end)

    if Config.Death.bleedoutEnabled then
        local injury = GetCurrentInjury()
        Threads.bleedout = true
        CreateThread(function()
            while State.isDead and Threads.bleedout and not State.isReviving do
                State.bloodLoss = math.min(100.0, State.bloodLoss + injury.bleedRate)
                TriggerServerEvent('rde_death:updateBloodLoss', State.bloodLoss)
                if State.bloodLoss >= 100.0 and not State.ambulanceEnRoute then
                    TriggerServerEvent('rde_death:respawn')
                    break
                end
                Wait(1000)
            end
            Threads.bleedout = nil
        end)
    end

    TriggerServerEvent('rde_death:syncState', {
        isDead     = true,
        coords     = State.deathCoords,
        injuryType = State.injuryType,
        bloodLoss  = State.bloodLoss,
        reason     = weaponHash or 0,
        timestamp  = GetGameTimer(),
    })

    SetTimeout(Config.Death.deathMenuDelay, OpenDeathMenu)
end

-- =============================================
-- 💊 REVIVE PLAYER
-- =============================================
local function RevivePlayer()
    if State.isReviving then return end

    Debug('Reviving player')
    State.isReviving     = true
    State.lastReviveTime = GetGameTimer()

    -- Spawn protection on every revive — verhindert sofortigen Re-Tod
    -- durch Backup-Polling-Thread während NetworkResurrectLocalPlayer settled
    State.spawnProtected = true
    SetTimeout(5000, function()
        if not State.isDead then
            State.spawnProtected = false
        end
    end)

    Threads.bleedout = nil
    Threads.effects  = nil
    Threads.hud      = nil

    ClearAllEffects()

    local ped = cache.ped
    ClearPedTasksImmediately(ped)
    SetPedToRagdoll(ped, 0, 0, 0, false, false, false)
    SetEntityInvincible(ped, false)

    NetworkResurrectLocalPlayer(GetEntityCoords(ped), GetEntityHeading(ped), true, false)
    Wait(100)

    if IsEntityDead(ped) then ResurrectPed(ped) end
    Wait(150)

    SetEntityHealth(ped, 200)
    SetPedArmour(ped, 0)
    SetPedCanRagdoll(ped, true)
    SetEntityVisible(ped, true, false)
    SetEntityCollision(ped, true, true)
    FreezeEntityPosition(ped, false)
    ResetPedMovementClipset(ped, 0.0)
    ResetPedWeaponMovementClipset(ped)
    EnableAllControlActions(0)

    State.isDead      = false
    State.bloodLoss   = 0.0
    State.injuryType  = 1
    State.deathCoords = vector3(0,0,0)
    State.isReviving  = false

    TriggerServerEvent('rde_death:syncState', { isDead = false })

    -- ✅ FIX #7: Lokales Event feuern damit externe Scripts sofort
    -- über den Revive informiert werden.
    -- rde_aipd hört auf dieses Event via AddEventHandler('rde_death:localRevive')
    -- in client/main.lua. Ohne dieses Event blieb WantedSystem.isDead = true
    -- nach jedem rde_aimd Revive → SetLevel() blockiert dauerhaft.
    TriggerEvent('rde_death:localRevive')

    lib.notify({
        title     = locale('revived_success'),
        type      = 'success',
        icon      = 'heart',
        iconColor = '#10b981',
        duration  = 6000,
        position  = 'top-right',
    })
end

-- =============================================
-- 🔍 DEATH DETECTION
-- =============================================
AddEventHandler('gameEventTriggered', function(event, data)
    if event ~= 'CEventNetworkEntityDamage' then return end
    if not State.fullyLoaded or State.spawnProtected then return end
    if GetGameTimer() - State.lastReviveTime < 5000 then return end

    local victim = data[1]
    local died   = data[4] == 1

    if victim == cache.ped and died and not State.isDead and not State.isReviving then
        Wait(100)
        if GetEntityHealth(cache.ped) <= 100 then
            OnPlayerDied(data[2], data[7])
        end
    end
end)

-- Fallback polling (catches edge cases)
CreateThread(function()
    while true do
        Wait(1000)
        if not State.fullyLoaded or State.spawnProtected then goto continue end
        if State.isDead or State.isReviving then goto continue end
        if GetGameTimer() - State.lastReviveTime < 5000 then goto continue end

        local ped = cache.ped
        if GetEntityHealth(ped) <= 100 or IsEntityDead(ped) then
            Debug('Backup death detection triggered')
            OnPlayerDied()
        end
        ::continue::
    end
end)

-- =============================================
-- 📡 NETWORK EVENTS
-- =============================================

RegisterNetEvent('rde_death:adminRevive', function()
    RevivePlayer()
    CleanupDoctor()
    lib.notify({
        title    = locale('admin_revived_by'),
        type     = 'success',
        icon     = 'user-shield',
        duration = 5000,
    })
end)

RegisterNetEvent('rde_death:doctorRevive', function()
    RevivePlayer()
    lib.notify({
        title     = locale('doctor_success'),
        type      = 'success',
        icon      = 'heart',
        iconColor = '#10b981',
        duration  = 5000,
        position  = 'top-right',
    })
end)

RegisterNetEvent('rde_death:doRespawn', function(hospital)
    RevivePlayer()
    CleanupDoctor()
    DoScreenFadeOut(600)
    Wait(600)

    local ped = cache.ped
    if hospital and hospital.respawnPoint then
        SetEntityCoords(ped,
            hospital.respawnPoint.x, hospital.respawnPoint.y, hospital.respawnPoint.z,
            false, false, false, true)
        SetEntityHeading(ped, hospital.respawnPoint.w or 0.0)
    end

    Wait(500)
    DoScreenFadeIn(700)
    EnableAllControlActions(0)

    lib.notify({
        title    = locale('respawned', hospital and hospital.name or 'Hospital'),
        type     = 'success',
        icon     = 'house-medical',
        duration = 6000,
    })
end)

RegisterNetEvent('rde_death:spawnDoctor', function(data)
    if not State.isDead then return end

    State.ambulanceEnRoute = true
    State.doctorCallSent   = false  -- confirmed, guard no longer needed
    State.ambulanceCost    = data.cost         or Config.Doctor.baseCost
    State.ambulanceETA     = data.responseTime or 30

    lib.notify({
        title       = locale('doctor_called'),
        description = locale('doctor_called_desc', State.ambulanceETA, State.ambulanceCost),
        type        = 'success',
        icon        = 'ambulance',
        iconColor   = '#ef4444',
        duration    = 6000,
        position    = 'top-right',
    })

    SetTimeout(2500, function()
        if not State.isDead or not State.ambulanceEnRoute then return end

        if SpawnAmbulance(GetEntityCoords(cache.ped)) then
            RunDoctorBehavior()
        else
            CleanupDoctor()
            lib.notify({
                title    = locale('service_unavailable'),
                type     = 'error',
                duration = 5000,
            })
        end
    end)
end)

RegisterNetEvent('rde_death:forceDeathState', function()
    if not State.isDead then OnPlayerDied(nil, nil) end
end)

-- =============================================
-- 🎮 KEYBINDS
-- =============================================
lib.addKeybind({
    name        = 'rde_open_death_menu',
    description = 'Open Emergency Status Menu',
    defaultKey  = Config.Keys.openDeathMenu,
    onPressed   = function()
        if State.isDead and not State.isReviving then OpenDeathMenu() end
    end,
})

-- =============================================
-- 🏥 SPAWN / SESSION
-- =============================================
local function OnPlayerLoaded()
    Debug('Player loaded')
    State.fullyLoaded    = true
    State.spawnProtected = true
    SetTimeout(Config.Death.spawnProtectionTime, function()
        State.spawnProtected = false
        State.firstSpawnDone = true
        Debug('Spawn protection lifted')
    end)
end

AddEventHandler('ox:playerLoaded', OnPlayerLoaded)

CreateThread(function()
    Wait(5000)
    if not State.fullyLoaded then
        local ped = cache.ped
        if ped and ped ~= 0 and GetEntityHealth(ped) > 100 then
            OnPlayerLoaded()
            Debug('Player loaded via fallback')
        end
    end
end)

-- =============================================
-- 🗺️ HOSPITAL BLIPS
-- =============================================
CreateThread(function()
    Wait(2000)
    if not Config.HospitalBlip then return end
    for _, h in ipairs(Config.Hospitals) do
        if h.blip and h.coords then
            local blip = AddBlipForCoord(h.coords.x, h.coords.y, h.coords.z)
            SetBlipSprite(blip, Config.HospitalBlip.sprite)
            SetBlipColour(blip, Config.HospitalBlip.color)
            SetBlipScale(blip, Config.HospitalBlip.scale)
            SetBlipAsShortRange(blip, Config.HospitalBlip.shortRange)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentSubstringPlayerName('🏥 ' .. h.name)
            EndTextCommandSetBlipName(blip)
        end
    end
end)

-- =============================================
-- 🧹 CLEANUP
-- =============================================
AddEventHandler('onResourceStop', function(name)
    if name ~= GetCurrentResourceName() then return end
    if State.isDead then RevivePlayer() end
    CleanupDoctor()
    ClearAllEffects()
    StopDeathHUD()
    Debug('Resource stopped — cleanup complete')
end)

-- =============================================
-- ✅ STARTUP
-- =============================================
CreateThread(function()
    Wait(1000)
    print('^2[RDE | AIMD]^7 🐉 AI Medical Department v1.0.5 — CLIENT OPERATIONAL')
    print('^3  ✅^7 Emergency driving 786468 (runs red lights)')
    print('^3  ✅^7 Death HUD top-center | lib.progressBar treatment')
    print('^3  ✅^7 🌿 Grass fix: stuck-detection + off-road arrival')
    print('^3  ✅^7 Doctor departs naturally | Admin /revive = instant cleanup')
    print('^3  ✅^7 FIX #7: TriggerEvent(rde_death:localRevive) — rde_aipd isDead sync')
    print('^3  ✅^7 ox_core + ox_lib | https://coxdocs.dev')
end)