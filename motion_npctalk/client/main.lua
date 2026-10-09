local PED_ROLES = { [6] = 'cop', [27] = 'swat', [20] = 'medic', [21] = 'fireman', [29] = 'army' }
local ANIMAL = 28

local target        -- ped the player is looking at / standing next to
local talking = {}  -- [ped] = { lastTalk = time, waiting = bool }
local bubbles = {}  -- list of { ped, coords, text, untilTime }

local function notify(msg)
    TriggerEvent('chat:addMessage', { color = { 200, 200, 200 }, args = { msg } })
end

local function canTalkTo(ped)
    return DoesEntityExist(ped) and not IsPedAPlayer(ped) and not IsPedDeadOrDying(ped, true)
        and GetPedType(ped) ~= ANIMAL and IsPedHuman(ped)
end

-- Closest talkable ped in front of the player within TalkDistance.
local function findTarget()
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
                if facing > -0.2 and score < bestScore then best, bestScore = ped, score end
            end
        end
    end
    return best
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

-- Stop the NPC and have it face the player while the conversation lasts.
local function engage(ped)
    local state = talking[ped]
    if not state then
        state = {}
        talking[ped] = state
        if requestControl(ped) then
            SetBlockingOfNonTemporaryEvents(ped, true)
            if not IsPedInAnyVehicle(ped, false) then
                ClearPedTasks(ped)
                TaskTurnPedToFaceEntity(ped, PlayerPedId(), 1500)
                SetTimeout(1500, function()
                    if talking[ped] and DoesEntityExist(ped) then TaskStandStill(ped, -1) end
                end)
            else
                TaskVehicleTempAction(ped, GetVehiclePedIsIn(ped, false), 27, -1) -- stop the car
            end
        end
    end
    state.lastTalk = GetGameTimer()
    return state
end

local function release(ped)
    talking[ped] = nil
    if not DoesEntityExist(ped) or IsPedDeadOrDying(ped, true) then return end
    if requestControl(ped) then
        SetBlockingOfNonTemporaryEvents(ped, false)
        ClearPedTasks(ped)
        if IsPedInAnyVehicle(ped, false) then
            TaskVehicleDriveWander(ped, GetVehiclePedIsIn(ped, false), 15.0, 786603)
        else
            TaskWanderStandard(ped, 10.0, 10)
        end
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

local function say(ped, message)
    message = (message or ''):match('^%s*(.-)%s*$')
    if message == '' then return end
    if not canTalkTo(ped) then return notify('No one close enough to talk to.') end

    local state = engage(ped)
    if state.waiting then return notify('They are still answering.') end
    state.waiting = true

    local netId = NetworkGetEntityIsNetworked(ped) and NetworkGetNetworkIdFromEntity(ped) or nil
    TriggerServerEvent('motion_npctalk:say', ped, netId, message:sub(1, Config.MaxMessageLength), personaInfo(ped))
end

local function openKeyboard()
    local ped = target
    if not ped then return end
    AddTextEntry('MOTION_NPCTALK', 'Say something:')
    DisplayOnscreenKeyboard(1, 'MOTION_NPCTALK', '', '', '', '', '', Config.MaxMessageLength)
    while UpdateOnscreenKeyboard() == 0 do Wait(0) end
    if UpdateOnscreenKeyboard() == 1 then
        say(ped, GetOnscreenKeyboardResult())
    end
end

RegisterCommand('npctalk', function()
    if target and not IsPauseMenuActive() then CreateThread(openKeyboard) end
end, false)
RegisterKeyMapping('npctalk', 'Talk to the nearest NPC', 'keyboard', Config.TalkKey)

RegisterCommand(Config.TalkCommand, function(_, _, raw)
    local ped = target or findTarget()
    if not ped then return notify('No one close enough to talk to.') end
    say(ped, raw:match('^%S+%s*(.*)$'))
end, false)
TriggerEvent('chat:addSuggestion', '/' .. Config.TalkCommand, 'Say something to the closest NPC', {
    { name = 'message', help = 'What you say' },
})

RegisterNetEvent('motion_npctalk:reject', function(reason)
    for _, state in pairs(talking) do state.waiting = false end
    notify(reason)
end)

local function wrap(text, width)
    local lines, line = {}, ''
    for word in text:gmatch('%S+') do
        if #line + #word + 1 > width and line ~= '' then
            lines[#lines + 1] = line
            line = word
        else
            line = line == '' and word or (line .. ' ' .. word)
        end
    end
    if line ~= '' then lines[#lines + 1] = line end
    return table.concat(lines, '\n')
end

RegisterNetEvent('motion_npctalk:line', function(line)
    if line.kind == 'player' then
        TriggerEvent('chat:addMessage', { color = { 255, 255, 255 }, args = { line.speaker, line.text } })
        return
    end

    TriggerEvent('chat:addMessage', { color = { 120, 220, 140 }, args = { line.speaker, line.text } })

    -- The player who spoke knows the ped handle; everyone else finds it by network id.
    local ped
    if line.owner == GetPlayerServerId(PlayerId()) then
        ped = line.pedKey
        local state = talking[ped]
        if state then
            state.waiting = false
            state.lastTalk = GetGameTimer()
        end
    elseif line.netId and NetworkDoesNetworkIdExist(line.netId) then
        ped = NetworkGetEntityFromNetworkId(line.netId)
    end
    if not ped or not DoesEntityExist(ped) then return end

    PlayFacialAnim(ped, 'mic_chatter', 'mp_facial')
    bubbles[#bubbles + 1] = { ped = ped, text = wrap(line.text, 40), untilTime = GetGameTimer() + Config.BubbleTime }
end)

local function drawText3D(coords, text)
    local onScreen, x, y = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end
    SetTextScale(0.33, 0.33)
    SetTextFont(4)
    SetTextCentre(true)
    SetTextColour(255, 255, 255, 230)
    SetTextOutline()
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(x, y)
end

-- Find who you're facing a few times a second.
CreateThread(function()
    while true do
        target = findTarget()
        Wait(250)
    end
end)

-- Release NPCs you stopped talking to.
CreateThread(function()
    while true do
        Wait(1000)
        local now = GetGameTimer()
        for ped, state in pairs(talking) do
            if not DoesEntityExist(ped) then
                talking[ped] = nil
            elseif not state.waiting and now - state.lastTalk > Config.ReleaseAfter * 1000 then
                release(ped)
            end
        end
    end
end)

-- Prompt, "..." while waiting, and speech bubbles.
CreateThread(function()
    while true do
        local sleep = 250
        local now = GetGameTimer()

        if target and not IsPauseMenuActive() then
            sleep = 0
            local head = GetPedBoneCoords(target, 31086, 0.0, 0.0, 0.0)
            local state = talking[target]
            if state and state.waiting then
                drawText3D(head + vector3(0.0, 0.0, 0.35), '...')
            else
                drawText3D(head + vector3(0.0, 0.0, 0.35), ('[%s] Talk'):format(Config.TalkKey))
            end
        end

        for i = #bubbles, 1, -1 do
            local bubble = bubbles[i]
            if now > bubble.untilTime or not DoesEntityExist(bubble.ped) then
                table.remove(bubbles, i)
            else
                sleep = 0
                if bubble.ped ~= target or not talking[bubble.ped] or not talking[bubble.ped].waiting then
                    local head = GetPedBoneCoords(bubble.ped, 31086, 0.0, 0.0, 0.0)
                    drawText3D(head + vector3(0.0, 0.0, 0.55), bubble.text)
                end
            end
        end
        Wait(sleep)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for ped in pairs(talking) do release(ped) end
end)
