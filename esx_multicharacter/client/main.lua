local Appearance = exports['illenium-appearance']

local state = {
    active = false,
    cam = nil,
    characters = {},  -- [slot] = character
    previewing = nil, -- slot currently shown
    creating = false,
    canRelog = true,
}

local DEFAULT_MODELS = { m = `mp_m_freemode_01`, f = `mp_f_freemode_01` }

-- ---------------------------------------------------------------------------
-- Helpers
-- ---------------------------------------------------------------------------
local function waitFade(out)
    while (out and IsScreenFadingOut()) or (not out and IsScreenFadingIn()) do Wait(50) end
end

local function hideHud(hide)
    DisplayRadar(not hide)
    MumbleSetVolumeOverride(PlayerId(), hide and 0.0 or -1.0)
end

local function placePed()
    local p = Config.Scene.ped
    local ped = PlayerPedId()
    SetEntityCoordsNoOffset(ped, p.x, p.y, p.z, false, false, false)
    SetEntityHeading(ped, p.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    ClearPedTasksImmediately(ped)
    return ped
end

local function startCamera()
    local p = Config.Scene.ped
    local heading = math.rad(p.w)
    -- Offsets are relative to the way the character faces.
    local function rel(o)
        return vector3(
            p.x + o.x * math.cos(heading) - o.y * math.sin(heading),
            p.y + o.x * math.sin(heading) + o.y * math.cos(heading),
            p.z + o.z)
    end
    local camPos, lookAt = rel(Config.Scene.camOffset), rel(Config.Scene.lookOffset)
    state.cam = CreateCamWithParams('DEFAULT_SCRIPTED_CAMERA', camPos.x, camPos.y, camPos.z, 0.0, 0.0, 0.0, 40.0, false, 2)
    PointCamAtCoord(state.cam, lookAt.x, lookAt.y, lookAt.z)
    SetCamActive(state.cam, true)
    RenderScriptCams(true, false, 0, true, true)
end

local function stopCamera()
    if not state.cam then return end
    RenderScriptCams(false, false, 0, true, true)
    DestroyCam(state.cam, false)
    state.cam = nil
end

local function loadModel(hash)
    RequestModel(hash)
    local deadline = GetGameTimer() + 5000
    while not HasModelLoaded(hash) and GetGameTimer() < deadline do Wait(0) end
    return HasModelLoaded(hash)
end

local function setDefaultPed(sex)
    local model = DEFAULT_MODELS[sex] or DEFAULT_MODELS.m
    if GetEntityModel(PlayerPedId()) ~= model and loadModel(model) then
        SetPlayerModel(PlayerId(), model)
        SetModelAsNoLongerNeeded(model)
    end
    local ped = PlayerPedId()
    SetPedDefaultComponentVariation(ped)
    SetPedHeadBlendData(ped, 0, 0, 0, 0, 0, 0, 0.5, 0.5, 0.0, false)
end

local function send(action, data)
    SendNUIMessage({ action = action, data = data })
end

-- ---------------------------------------------------------------------------
-- Preview
-- ---------------------------------------------------------------------------
local function preview(slot)
    state.previewing = slot
    local character = state.characters[slot]
    if character and type(character.skin) == 'table' and character.skin.model then
        Appearance:setPlayerAppearance(character.skin)
    else
        setDefaultPed(character and character.sex or 'm')
    end
    local ped = placePed()
    SetEntityVisible(ped, character ~= nil, false)
end

-- ---------------------------------------------------------------------------
-- Opening the menu
-- ---------------------------------------------------------------------------
local function begin()
    state.active = true
    state.characters = {}
    ESX.PlayerLoaded = false
    ESX.PlayerData = {}

    DoScreenFadeOut(0)
    placePed()
    SetPlayerControl(PlayerId(), false, 0)
    hideHud(true)
    if Config.Scene.hour then NetworkOverrideClockTime(Config.Scene.hour, 0, 0) end
    startCamera()

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    TriggerEvent('esx:loadingScreenOff')
    SetTimeout(200, function() TriggerServerEvent('motion_multichar:setup') end)
end

RegisterNetEvent('motion_multichar:open', function(list, slots, canDelete)
    state.characters = {}
    local first
    for _, c in ipairs(list) do
        state.characters[c.slot] = c
        if not first or c.slot < first then first = c.slot end
    end

    preview(first or 1)
    DoScreenFadeIn(600)

    -- The UI doesn't need the full skin JSON.
    local ui = {}
    for _, c in ipairs(list) do
        local copy = {}
        for k, v in pairs(c) do if k ~= 'skin' then copy[k] = v end end
        ui[#ui + 1] = copy
    end
    SetNuiFocus(true, true)
    send('open', { characters = ui, slots = slots, canDelete = canDelete, selected = first or 1, identity = Config.Identity })
end)

RegisterNetEvent('motion_multichar:error', function(message)
    send('error', { message = message })
end)

-- ---------------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------------
RegisterNUICallback('preview', function(data, cb)
    cb(1)
    local slot = tonumber(data.slot)
    if slot and slot ~= state.previewing then preview(slot) end
end)

RegisterNUICallback('previewSex', function(data, cb)
    cb(1)
    setDefaultPed(data.sex == 'f' and 'f' or 'm')
    SetEntityVisible(placePed(), true, false)
end)

RegisterNUICallback('play', function(data, cb)
    cb(1)
    local slot = tonumber(data.slot)
    if not slot or not state.characters[slot] then return end
    SetNuiFocus(false, false)
    send('close')
    DoScreenFadeOut(500)
    waitFade(true)
    TriggerServerEvent('motion_multichar:choose', slot)
end)

RegisterNUICallback('create', function(data, cb)
    cb(1)
    state.creating = true
    TriggerServerEvent('motion_multichar:create', tonumber(data.slot), data.character)
end)

RegisterNUICallback('delete', function(data, cb)
    cb(1)
    TriggerServerEvent('motion_multichar:delete', tonumber(data.slot))
end)

-- ---------------------------------------------------------------------------
-- After es_extended loads the character
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:playerLoaded', function(playerData, isNew, skin)
    if not state.active then return end
    SetNuiFocus(false, false)
    send('close')
    DoScreenFadeOut(500)
    waitFade(true)
    stopCamera()
    NetworkClearClockTimeOverride()

    if type(skin) == 'string' then skin = json.decode(skin) end
    local needsCreator = isNew or type(skin) ~= 'table' or not skin.model

    if needsCreator then
        setDefaultPed(playerData.sex == 'f' and 'f' or 'm')
        placePed()
        SetEntityVisible(PlayerPedId(), true, false)
        DoScreenFadeIn(500)

        -- illenium-appearance answers the ESX skin events: open its creator and wait until it's saved.
        local done = promise.new()
        TriggerEvent('esx_skin:openSaveableMenu', function() done:resolve(true) end, function() done:resolve(false) end)
        Citizen.Await(done)

        skin = Appearance:getPedAppearance(PlayerPedId())
        DoScreenFadeOut(500)
        waitFade(true)
    end

    local spawn
    if not isNew and playerData.coords then
        spawn = playerData.coords
    else
        local spawns = ESX.GetConfig().DefaultSpawns
        spawn = Config.NewCharacterSpawn or (spawns and spawns[math.random(#spawns)])
            or { x = -269.4, y = -955.3, z = 31.2, heading = 205.8 }
    end
    if spawn.w and not spawn.heading then spawn = { x = spawn.x, y = spawn.y, z = spawn.z, heading = spawn.w } end

    ESX.SpawnPlayer(skin, spawn, function()
        local ped = PlayerPedId()
        FreezeEntityPosition(ped, false)
        SetEntityInvincible(ped, false)
        SetEntityVisible(ped, true, false)
        SetEntityCollision(ped, true, true)
        SetPlayerControl(PlayerId(), true, 0)
        hideHud(false)
        DoScreenFadeIn(750)

        TriggerServerEvent('esx:onPlayerSpawn')
        TriggerEvent('esx:onPlayerSpawn')
        TriggerEvent('esx:restoreLoadout')

        state.active = false
        state.creating = false
        state.characters = {}
        state.canRelog = false
        SetTimeout(10000, function() state.canRelog = true end)
    end)
end)

-- ---------------------------------------------------------------------------
-- Logout / relog
-- ---------------------------------------------------------------------------
RegisterNetEvent('esx:onPlayerLogout', function()
    DoScreenFadeOut(500)
    waitFade(true)
    Wait(1500) -- let es_extended finish saving
    TriggerEvent('esx_skin:resetFirstSpawn')
    begin()
end)

if Config.Relog then
    RegisterCommand('relog', function()
        if not state.canRelog or state.active then return end
        state.canRelog = false
        TriggerServerEvent('motion_multichar:relog')
    end, false)
end

-- ---------------------------------------------------------------------------
-- First join
-- ---------------------------------------------------------------------------
CreateThread(function()
    while not NetworkIsPlayerActive(PlayerId()) do Wait(100) end
    ESX.DisableSpawnManager()
    begin()
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    if state.active then
        SetNuiFocus(false, false)
        stopCamera()
        hideHud(false)
        DoScreenFadeIn(0)
    end
end)
