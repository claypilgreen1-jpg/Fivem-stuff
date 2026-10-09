local PED_ROLES = { [6] = 'cop', [27] = 'swat', [20] = 'medic', [21] = 'fireman', [29] = 'army' }
local ANIMAL = 28

local GESTURES = {
    male = { dict = 'gestures@m@standing@casual', anims = {
        'gesture_easy_now', 'gesture_hand_down', 'gesture_me', 'gesture_no_way', 'gesture_shrug_hard',
        'gesture_what_hard', 'gesture_why', 'gesture_you_soft', 'gesture_bring_it_on', 'gesture_point' } },
    female = { dict = 'gestures@f@standing@casual', anims = {
        'gesture_easy_now', 'gesture_hand_down', 'gesture_me', 'gesture_no_way', 'gesture_shrug_hard',
        'gesture_what_hard', 'gesture_why', 'gesture_you_soft', 'gesture_point' } },
}

local partner        -- the ped you're currently talking to
local talking = {}   -- [ped] = { lastTalk = time, waiting = bool }

local function notify(msg)
    TriggerEvent('chat:addMessage', { color = { 180, 180, 180 }, args = { msg } })
end

local function canTalkTo(ped)
    return DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true)
        and GetPedType(ped) ~= ANIMAL and IsPedHuman(ped)
end

local function distanceTo(ped)
    return #(GetEntityCoords(ped) - GetEntityCoords(PlayerPedId()))
end

-- Closest talkable ped in front of the player within TalkDistance.
local function findNearby()
    local player = PlayerPedId()
    local origin = GetEntityCoords(player)
    local forward = GetEntityForwardVector(player)
    local best, bestScore = nil, math.huge
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= player and canTalkTo(ped) then
            local offset = GetEntityCoords(ped) - origin
            local dist = #offset
            if dist <= Config.TalkDistance then
                local facing = (offset.x * forward.x + offset.y * forward.y) / math.max(dist, 0.01)
                local score = dist - facing -- prefer peds in front of you
                if facing > -0.3 and score < bestScore then best, bestScore = ped, score end
            end
        end
    end
    return best
end

-- Who hears what you say: the person you're already talking to if they're still around,
-- otherwise whoever is closest in front of you.
local function listener()
    if partner and canTalkTo(partner) and distanceTo(partner) <= Config.StayInRange then
        return partner
    end
    return findNearby()
end

local function requestControl(ped)
    if not NetworkGetEntityIsNetworked(ped) or NetworkHasControlOfEntity(ped) then return true end
    NetworkRequestControlOfEntity(ped)
    local deadline = GetGameTimer() + 500
    while not NetworkHasControlOfEntity(ped) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(ped)
    end
    return NetworkHasControlOfEntity(ped)
end

local function speak(ped, line)
    PlayPedAmbientSpeechNative(ped, line, 'SPEECH_PARAMS_FORCE_NORMAL')
end

-- Stop the NPC, greet the player and keep facing them while the conversation lasts.
local function engage(ped)
    local state = talking[ped]
    if not state then
        state = {}
        talking[ped] = state
        if requestControl(ped) then
            SetBlockingOfNonTemporaryEvents(ped, true)
            if IsPedInAnyVehicle(ped, false) then
                TaskVehicleTempAction(ped, GetVehiclePedIsIn(ped, false), 27, -1) -- pull up and wait
            else
                ClearPedTasks(ped)
                TaskTurnPedToFaceEntity(ped, PlayerPedId(), 1500)
                SetTimeout(1500, function()
                    if talking[ped] and DoesEntityExist(ped) then TaskStandStill(ped, -1) end
                end)
            end
            TaskLookAtEntity(ped, PlayerPedId(), -1, 2048, 3)
        end
        speak(ped, 'GENERIC_HI')
    end
    partner = ped
    state.lastTalk = GetGameTimer()
    return state
end

local function release(ped, sayBye)
    talking[ped] = nil
    if partner == ped then partner = nil end
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end
    if sayBye then speak(ped, 'GENERIC_BYE') end
    if requestControl(ped) then
        TaskClearLookAt(ped)
        SetBlockingOfNonTemporaryEvents(ped, false)
        ClearPedTasks(ped)
        if IsPedInAnyVehicle(ped, false) then
            TaskVehicleDriveWander(ped, GetVehiclePedIsIn(ped, false), 15.0, 786603)
        else
            TaskWanderStandard(ped, 10.0, 10)
        end
    end
end

-- Mouth movement plus a hand gesture while the NPC talks.
local function animateTalking(ped, text)
    PlayFacialAnim(ped, 'mic_chatter', 'mp_facial')
    if IsPedInAnyVehicle(ped, false) or not NetworkHasControlOfEntity(ped) then return end
    local set = GESTURES[IsPedMale(ped) and 'male' or 'female']
    if not HasAnimDictLoaded(set.dict) then
        RequestAnimDict(set.dict)
        local deadline = GetGameTimer() + 1000
        while not HasAnimDictLoaded(set.dict) and GetGameTimer() < deadline do Wait(0) end
    end
    if HasAnimDictLoaded(set.dict) and #text > 12 then
        TaskPlayAnim(ped, set.dict, set.anims[math.random(#set.anims)], 4.0, -4.0, -1, 48, 0.0, false, false, false)
    end
end

local function personaInfo(ped)
    local c = GetEntityCoords(ped)
    local street = GetStreetNameAtCoord(c.x, c.y, c.z)
    return {
        gender = IsPedMale(ped) and 'male' or 'female',
        role = PED_ROLES[GetPedType(ped)],
        area = GetLabelText(GetNameOfZone(c.x, c.y, c.z)),
        street = GetStreetNameFromHashKey(street),
        hour = GetClockHours(),
        inVehicle = IsPedInAnyVehicle(ped, false),
    }
end

local function say(ped, message, fromChat)
    message = (message or ''):match('^%s*(.-)%s*$')
    if message == '' or not canTalkTo(ped) then return end

    local state = engage(ped)
    if state.waiting then return end -- they're still thinking about your last line
    state.waiting = true

    local netId = NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or nil
    TriggerServerEvent('motion_npctalk:say', ped, netId, message:sub(1, Config.MaxMessageLength), personaInfo(ped), fromChat)
end

-- Normal chat: if someone is close enough to hear you, they answer.
RegisterNetEvent('motion_npctalk:heard', function(text)
    local ped = listener()
    if ped then say(ped, text, true) end
end)

RegisterCommand(Config.TalkCommand, function(_, _, raw)
    local ped = listener()
    if not ped then return notify('No one is close enough to hear you.') end
    say(ped, raw:match('^%S+%s*(.*)$'), false)
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.TalkCommand, 'Say something to the person next to you', {
    { name = 'message', help = 'What you say' },
})

RegisterNetEvent('motion_npctalk:reject', function(reason)
    for _, state in pairs(talking) do state.waiting = false end
    notify(reason)
end)

local function showSubtitle(name, text)
    BeginTextCommandPrint('STRING')
    AddTextComponentSubstringPlayerName(('~b~%s:~s~ %s'):format(name, text))
    EndTextCommandPrint(math.min(12000, 2500 + #text * 60), true)
end

RegisterNetEvent('motion_npctalk:line', function(line)
    if line.kind == 'player' then
        TriggerEvent('chat:addMessage', { color = { 255, 255, 255 }, args = { line.speaker, line.text } })
        return
    end

    TriggerEvent('chat:addMessage', { color = Config.NameColor, args = { line.speaker, line.text } })

    -- The player who spoke knows the ped handle; everyone else finds it by network id.
    local ped
    local mine = line.owner == GetPlayerServerId(PlayerId())
    if mine then
        ped = line.pedKey
        local state = talking[ped]
        if state then
            state.waiting = false
            state.lastTalk = GetGameTimer()
        end
        if Config.Subtitles then showSubtitle(line.speaker, line.text) end
    elseif line.netId and NetworkDoesNetworkIdExist(line.netId) then
        ped = NetworkGetEntityFromNetworkId(line.netId)
    end
    if not ped or not DoesEntityExist(ped) then return end

    CreateThread(function()
        animateTalking(ped, line.text)
        if mine and line.leaving then
            Wait(math.min(6000, 1500 + #line.text * 40))
            release(ped, true)
        end
    end)
end)

-- Keep facing you while you move around, and let them go once you stop talking.
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        local player = PlayerPedId()
        for ped, state in pairs(talking) do
            if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then
                talking[ped] = nil
                if partner == ped then partner = nil end
            elseif not state.waiting and (now - state.lastTalk > Config.ReleaseAfter * 1000
                    or distanceTo(ped) > Config.StayInRange * 2) then
                release(ped, distanceTo(ped) <= Config.StayInRange)
            elseif not IsPedInAnyVehicle(ped, false) and not IsPedFacingPed(ped, player, 60.0)
                    and NetworkHasControlOfEntity(ped) then
                TaskTurnPedToFaceEntity(ped, player, 1000)
            end
        end
    end
end)

-- ---------------------------------------------------------------------------
-- Voice: hold push-to-talk next to someone and they hear you.
-- The hidden page in html/ records the mic only while the key is held and an NPC is listening.
-- ---------------------------------------------------------------------------
local recording       -- { ped = handle } while the mic is recording
local voiceKeyHeld = false
local micBroken = false

local function startListening()
    if recording or micBroken then return end
    local ped = listener()
    if not ped then return end
    local state = talking[ped]
    if state and state.waiting then return end
    engage(ped) -- they stop and turn to you as soon as you start talking
    recording = { ped = ped }
    SendNUIMessage({ type = 'start' })
end

local function stopListening()
    if recording then SendNUIMessage({ type = 'stop' }) end
end

RegisterNUICallback('voiceClip', function(data, cb)
    cb('ok')
    local rec = recording
    recording = nil
    if not rec or data.skipped or type(data.audio) ~= 'string' or data.audio == '' then return end
    local ped = rec.ped
    if not canTalkTo(ped) then return end

    local state = engage(ped)
    if state.waiting then return end
    state.waiting = true
    SetTimeout(30000, function() -- never leave them stuck "thinking" if a reply is lost
        if talking[ped] == state then state.waiting = false end
    end)

    local netId = NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or nil
    TriggerLatentServerEvent('motion_npctalk:voice', 200000, ped, netId, personaInfo(ped), data.audio, data.mime)
end)

RegisterNUICallback('voiceError', function(data, cb)
    cb('ok')
    recording = nil
    if not micBroken then
        micBroken = true
        notify(('NPCs can\'t hear you: the game couldn\'t open your microphone (%s). Run /voicetest for details.')
            :format(tostring(data.message)))
    end
end)

RegisterNUICallback('voiceTest', function(data, cb)
    cb('ok')
    if data.ok then micBroken = false end
    notify((data.ok and 'Voice test: ' or 'Voice test failed: ') .. tostring(data.message))
end)

RegisterCommand('voicetest', function()
    micBroken = false
    SendNUIMessage({ type = 'test' })
end, false)

RegisterNetEvent('motion_npctalk:voiceStatus', function(msg)
    notify(msg)
end)

RegisterNetEvent('motion_npctalk:voiceDone', function()
    for _, state in pairs(talking) do state.waiting = false end
end)

if Config.Voice.key then
    RegisterCommand('+npcvoice', function() voiceKeyHeld = true end, false)
    RegisterCommand('-npcvoice', function() voiceKeyHeld = false end, false)
    RegisterKeyMapping('+npcvoice', 'Talk to the NPC in front of you (hold)', 'keyboard', Config.Voice.key)
end

CreateThread(function()
    if not Config.Voice.enabled then return end
    while true do
        local held = voiceKeyHeld
        if Config.Voice.usePushToTalk and (IsControlPressed(0, 249) or IsDisabledControlPressed(0, 249)) then
            held = true
        end
        if held and not recording then
            startListening()
        elseif not held and recording then
            stopListening()
        end
        Wait(recording and 30 or 100)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for ped in pairs(talking) do release(ped, false) end
end)
