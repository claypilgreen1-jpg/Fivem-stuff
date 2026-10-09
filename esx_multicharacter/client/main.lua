local Appearance = exports['illenium-appearance']

local state = {
    active = false,
    cam = nil,
    characters = {},  -- [slot] = character
    previewing = nil, -- slot currently shown
    creating = false,
    canRelog = true,
    scene = nil,      -- the Config.Scenes entry in use
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

local function scenePos()
    return state.scene.ped
end

local function placePed()
    local p = scenePos()
    local ped = PlayerPedId()
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false) -- z is where the feet go
    SetEntityHeading(ped, p.w)
    FreezeEntityPosition(ped, true)
    SetEntityInvincible(ped, true)
    ClearPedTasksImmediately(ped)
    return ped
end

local function startCamera()
    local p = scenePos()
    local heading = math.rad(p.w)
    -- Offsets are relative to the way the character faces.
    local function rel(o)
        return vector3(
            p.x + o.x * math.cos(heading) - o.y * math.sin(heading),
            p.y + o.x * math.sin(heading) + o.y * math.cos(heading),
            p.z + o.z)
    end
    local camPos = rel(state.scene.camOffset or vector3(0.0, 2.6, 1.45))
    local lookAt = rel(state.scene.lookOffset or vector3(0.0, 0.0, 1.15))
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
-- Scenes (penthouse, beach, rooftop, yacht...)
-- ---------------------------------------------------------------------------
-- The player's own choice from the settings menu wins, then the server default.
local KVP_SCENE = 'motion_multichar:scene'

local function sceneChoice()
    local saved = GetResourceKvpString(KVP_SCENE)
    if saved == 'random' or (saved and Config.Scenes[saved]) then return saved end
    return Config.SceneMode
end

local function sceneList()
    local list = {}
    for id, scene in pairs(Config.Scenes) do list[#list + 1] = { id = id, label = scene.label or id } end
    table.sort(list, function(a, b) return a.label < b.label end)
    return list
end

local function pickScene()
    local mode = sceneChoice()
    if mode ~= 'random' and Config.Scenes[mode] then return Config.Scenes[mode] end
    local list = {}
    for _, scene in pairs(Config.Scenes) do list[#list + 1] = scene end
    return list[math.random(#list)]
end

-- Loads map pieces and collision around the scene, then sets the mood (time + weather).
local function loadScene(scene)
    local p = scene.ped
    for _, ipl in ipairs(scene.ipl or {}) do
        if not IsIplActive(ipl) then RequestIpl(ipl) end
    end
    if scene.interior then
        local interior = GetInteriorAtCoords(p.x, p.y, p.z)
        if interior ~= 0 then
            PinInteriorInMemory(interior)
            local deadline = GetGameTimer() + 5000
            while not IsInteriorReady(interior) and GetGameTimer() < deadline do Wait(0) end
        end
    end

    local ped = PlayerPedId()
    SetEntityCoords(ped, p.x, p.y, p.z, false, false, false, false)
    RequestCollisionAtCoord(p.x, p.y, p.z)
    local deadline = GetGameTimer() + 5000
    while not HasCollisionLoadedAroundEntity(ped) and GetGameTimer() < deadline do Wait(0) end

    if scene.snapToGround and not scene._snapped then
        local found, z = GetGroundZFor_3dCoord(p.x, p.y, p.z + 3.0, false)
        if found then scene.ped = vector4(p.x, p.y, z, p.w) end
        scene._snapped = true
    end

    if scene.hour then NetworkOverrideClockTime(scene.hour, 0, 0) end
    if scene.weather then
        SetOverrideWeather(scene.weather)
        SetWeatherTypeNowPersist(scene.weather)
    end
end

local function clearSceneMood()
    NetworkClearClockTimeOverride()
    ClearOverrideWeather()
end

-- /mcscene: stand where the character should be, face their way, aim the gameplay camera,
-- and this prints a Config.Scenes line to paste.
RegisterCommand('mcscene', function(_, args)
    local ped = PlayerPedId()
    local c, heading = GetEntityCoords(ped), GetEntityHeading(ped)
    local cam = GetGameplayCamCoord()
    local h = math.rad(heading)
    local d = cam - c
    -- world offset -> character-relative (x = right, y = in front)
    local rx = d.x * math.cos(h) + d.y * math.sin(h)
    local ry = -d.x * math.sin(h) + d.y * math.cos(h)
    local line = ("%s = { label = '%s', ped = vector4(%.2f, %.2f, %.2f, %.1f), camOffset = vector3(%.2f, %.2f, %.2f), lookOffset = vector3(0.0, 0.0, 1.15), hour = %d },")
        :format(args[1] or 'myscene', args[1] or 'My Scene', c.x, c.y, c.z - 1.0, heading, rx, ry, d.z + 1.0, GetClockHours())
    print(line)
    TriggerEvent('chat:addMessage', { args = { 'mcscene', 'Printed to F8 console: ' .. line } })
end, false)

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
    state.scene = pickScene()
    loadScene(state.scene)
    placePed()
    SetPlayerControl(PlayerId(), false, 0)
    hideHud(true)
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
    send('open', {
        characters = ui, slots = slots, canDelete = canDelete, selected = first or 1,
        identity = Config.Identity, location = state.scene and state.scene.label or nil,
        scenes = sceneList(), sceneChoice = sceneChoice(),
    })
end)

RegisterNetEvent('motion_multichar:error', function(message)
    send('error', { message = message })
end)

-- ---------------------------------------------------------------------------
-- NUI
-- ---------------------------------------------------------------------------
-- Settings: switch the background live and remember it for next time.
RegisterNUICallback('setScene', function(data, cb)
    local choice = data.scene
    if choice ~= 'random' and not Config.Scenes[choice] then return cb({}) end
    SetResourceKvp(KVP_SCENE, choice)

    DoScreenFadeOut(300)
    waitFade(true)
    stopCamera()
    state.scene = pickScene()
    loadScene(state.scene)
    local slot = state.previewing
    state.previewing = nil
    preview(slot or 1)
    startCamera()
    DoScreenFadeIn(400)
    cb({ location = state.scene.label, sceneChoice = choice })
end)

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
    clearSceneMood()

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
        clearSceneMood()
        hideHud(false)
        DoScreenFadeIn(0)
    end
end)
