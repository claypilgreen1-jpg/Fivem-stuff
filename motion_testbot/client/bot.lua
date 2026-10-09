Bots = { list = {}, selected = nil, nextId = 1 }

local function count()
    local n = 0
    for _ in pairs(Bots.list) do n = n + 1 end
    return n
end

local function addBlip(bot)
    if not Config.Bot.blip then return end
    if bot.blip and DoesBlipExist(bot.blip) then RemoveBlip(bot.blip) end
    bot.blip = AddBlipForEntity(bot.ped)
    SetBlipSprite(bot.blip, 280)
    SetBlipColour(bot.blip, 3)
    BeginTextCommandSetBlipName('STRING')
    AddTextComponentSubstringPlayerName(('TestBot %d'):format(bot.id))
    EndTextCommandSetBlipName(bot.blip)
end

local function createPed(model, coords, heading)
    local hash = Util.LoadModel(model)
    if not hash then
        Util.Notify(('Unknown ped model "%s".'):format(model))
        return nil
    end
    local ped = CreatePed(4, hash, coords.x, coords.y, coords.z, heading, true, true)
    SetModelAsNoLongerNeeded(hash)

    SetEntityAsMissionEntity(ped, true, true)
    SetBlockingOfNonTemporaryEvents(ped, true) -- only do what we tell it
    SetPedFleeAttributes(ped, 0, false)
    SetPedCombatAttributes(ped, 46, true)     -- always fight when told to
    SetPedKeepTask(ped, true)
    SetPedCanBeTargetted(ped, true)
    SetEntityInvincible(ped, Config.Bot.invincible)
    Outfit.SetupNew(ped, model)
    return ped
end

function Bots.Spawn(model)
    if count() >= Config.Bot.maxBots then
        Util.Notify(('Bot limit reached (%d). Dismiss one first.'):format(Config.Bot.maxBots))
        return
    end
    model = (model or Config.Bot.defaultModel):lower()

    local player = PlayerPedId()
    local spawnAt = GetOffsetFromEntityInWorldCoords(player, 0.0, 2.0, -1.0)
    local ped = createPed(model, spawnAt, GetEntityHeading(player) + 180.0)
    if not ped then return end

    local id = Bots.nextId
    Bots.nextId = id + 1
    local bot = { id = id, ped = ped, model = model, status = 'idle', token = 0, invincible = Config.Bot.invincible }
    addBlip(bot)

    Bots.list[id] = bot
    Bots.selected = id
    Util.Notify(('Spawned bot %d (%s). It is now selected.'):format(id, model))
    return bot
end

-- Swaps a bot to another ped model in the same spot, keeping its id.
function Bots.ChangeModel(bot, model)
    model = model:lower()
    local old = bot.ped
    local coords = GetEntityCoords(old)
    local ped = createPed(model, coords - vector3(0.0, 0.0, 1.0), GetEntityHeading(old))
    if not ped then return end
    SetEntityInvincible(ped, bot.invincible)

    bot.token = bot.token + 1
    bot.ped, bot.model, bot.status, bot.frozen = ped, model, 'idle', false
    SetEntityAsMissionEntity(old, true, true)
    DeletePed(old)
    addBlip(bot)
    Util.Notify(('Bot %d is now %s.'):format(bot.id, model))
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
