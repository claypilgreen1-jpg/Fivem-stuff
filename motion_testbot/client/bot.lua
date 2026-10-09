Bots = { list = {}, selected = nil, nextId = 1 }

local function count()
    local n = 0
    for _ in pairs(Bots.list) do n = n + 1 end
    return n
end

function Bots.Spawn(model)
    if count() >= Config.Bot.maxBots then
        Util.Notify(('Bot limit reached (%d). Dismiss one first.'):format(Config.Bot.maxBots))
        return
    end
    model = model or Config.Bot.defaultModel
    local hash = Util.LoadModel(model)
    if not hash then
        Util.Notify(('Unknown ped model "%s".'):format(model))
        return
    end

    local player = PlayerPedId()
    local spawnAt = GetOffsetFromEntityInWorldCoords(player, 0.0, 2.0, 0.0)
    local ped = CreatePed(4, hash, spawnAt.x, spawnAt.y, spawnAt.z - 1.0, GetEntityHeading(player) + 180.0, true, true)
    SetModelAsNoLongerNeeded(hash)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true) -- only do what we tell it
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)     -- always fight when told to
    SetPedKeepTask(ped, true)
    SetPedCanBeTargetted(ped, true)
    SetEntityInvincible(ped, Config.Bot.invincible)

    local id = Bots.nextId
    Bots.nextId = id + 1
    local bot = { id = id, ped = ped, model = model, status = 'idle', token = 0 }

    if Config.Bot.blip then
        bot.blip = AddBlipForEntity(ped)
        SetBlipSprite(bot.blip, 280)
        SetBlipColour(bot.blip, 3)
        BeginTextCommandSetBlipName('STRING')
        AddTextComponentSubstringPlayerName(('TestBot %d'):format(id))
        EndTextCommandSetBlipName(bot.blip)
    end

    Bots.list[id] = bot
    Bots.selected = id
    Util.Notify(('Spawned bot %d (%s). It is now selected.'):format(id, model))
    return bot
end

function Bots.Dismiss(bot)
    bot.token = bot.token + 1
    if bot.blip and DoesBlipExist(bot.blip) then RemoveBlip(bot.blip) end
    if DoesEntityExist(bot.ped) then
        SetEntityAsMissionEntity(bot.ped, true, true)
        DeletePed(bot.ped)
    end
    Bots.list[bot.id] = nil
    if Bots.selected == bot.id then
        Bots.selected = nil
        for id in pairs(Bots.list) do Bots.selected = id end
    end
end

function Bots.DismissAll()
    for _, bot in pairs(Bots.list) do Bots.Dismiss(bot) end
end

function Bots.Get(id)
    local bot = Bots.list[id or Bots.selected]
    if bot and not DoesEntityExist(bot.ped) then
        Bots.Dismiss(bot)
        return nil
    end
    return bot
end

function Bots.PrintList()
    if count() == 0 then
        Util.Notify('No bots. Use "/bot spawn [model]".')
        return
    end
    for id, bot in pairs(Bots.list) do
        local marker = id == Bots.selected and ' (selected)' or ''
        Util.Notify(('Bot %d: %s - %s%s'):format(id, bot.model, bot.status, marker))
    end
end

-- Runs a queue of steps on a bot. A new queue cancels whatever it was doing.
-- Each step is { name = 'goto', args = { 'waypoint' } }.
function Bots.Run(bot, steps)
    bot.token = bot.token + 1
    local token = bot.token
    ClearPedTasks(bot.ped)
    local ctx = {
        bot = bot,
        ped = bot.ped,
        active = function()
            return bot.token == token and DoesEntityExist(bot.ped)
        end,
    }

    CreateThread(function()
        for i, step in ipairs(steps) do
            if not ctx.active() then return end
            bot.status = step.name
            local ok, err = pcall(Tasks.Run, ctx, step)
            if not ok then
                Util.Notify(('Bot %d: step %d (%s) errored: %s'):format(bot.id, i, step.name, err))
                break
            elseif err then
                Util.Notify(('Bot %d: step %d (%s) failed: %s'):format(bot.id, i, step.name, err))
                break
            end
        end
        if ctx.active() and Tasks.IsInstant(steps[#steps].name) then
            bot.status = 'idle'
        end
    end)
end

-- Waits until cond() is true. Returns false if the queue was cancelled or it timed out.
function Bots.WaitUntil(ctx, cond, timeoutMs)
    local deadline = timeoutMs and (GetGameTimer() + timeoutMs)
    while ctx.active() do
        if cond() then return true end
        if deadline and GetGameTimer() > deadline then return false end
        Wait(250)
    end
    return false
end

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        Bots.DismissAll()
    end
end)
