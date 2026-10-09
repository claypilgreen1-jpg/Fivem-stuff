Menu = { open = false }

local function botList()
    local list = {}
    for id, bot in pairs(Bots.list) do
        if DoesEntityExist(bot.ped) then
            list[#list + 1] = {
                id = id, model = bot.model, status = bot.status,
                invincible = bot.invincible == true, frozen = bot.frozen == true,
            }
        end
    end
    table.sort(list, function(a, b) return a.id < b.id end)
    return list
end

function Menu.State()
    local spots = {}
    for _, spot in ipairs(Config.PhotoSpots) do spots[#spots + 1] = spot.name end
    local bot = Bots.Get()
    return {
        bots = botList(),
        selected = bot and bot.id or false,
        outfit = bot and Outfit.Get(bot.ped) or false,
        spots = spots,
        touring = Photo.touring,
        freecam = Freecam.active,
        maxBots = Config.Bot.maxBots,
    }
end

function Menu.Open()
    if Menu.open then return end
    Menu.open = true
    SetNuiFocus(true, true)
    SendNUIMessage({ type = 'open', state = Menu.State() })
end

function Menu.Close()
    if not Menu.open then return end
    Menu.open = false
    SetNuiFocus(false, false)
    SendNUIMessage({ type = 'close' })
end

function Menu.Toast(text)
    if Menu.open then SendNUIMessage({ type = 'toast', text = text }) end
end

-- Push fresh state while the menu is open so bot statuses stay current.
CreateThread(function()
    while true do
        Wait(1000)
        if Menu.open then SendNUIMessage({ type = 'state', state = Menu.State() }) end
    end
end)

local function toStrings(args)
    local out = {}
    for _, v in ipairs(type(args) == 'table' and args or {}) do
        if v ~= nil and v ~= '' then out[#out + 1] = tostring(v) end
    end
    return out
end

local function closeThen(fn)
    Menu.Close()
    CreateThread(function()
        Wait(150)
        fn()
    end)
end

local actions = {}

actions.close = function() Menu.Close() end
actions.refresh = function() end

actions.spawn = function(d)
    if type(d.model) == 'string' and d.model ~= '' then Bots.Spawn(d.model) end
end

actions.changeModel = function(d)
    local bot = Bots.Get()
    if not bot then return Menu.Toast('Spawn or select a bot first.') end
    if type(d.model) == 'string' and d.model ~= '' then Bots.ChangeModel(bot, d.model) end
end

actions.select = function(d)
    local bot = Bots.Get(tonumber(d.id))
    if bot then Bots.selected = bot.id end
end

actions.dismiss = function(d)
    local bot = Bots.Get(tonumber(d.id))
    if bot then Bots.Dismiss(bot) end
end

actions.dismissAll = function() Bots.DismissAll() end

actions.botToMe = function(d)
    local bot = Bots.Get(tonumber(d.id))
    if bot then Bots.Run(bot, { { name = 'tp', args = { 'me' } } }) end
end

actions.meToBot = function(d)
    local bot = Bots.Get(tonumber(d.id))
    if not bot then return end
    local at = GetOffsetFromEntityInWorldCoords(bot.ped, 0.0, -1.5, 0.0)
    SetEntityCoords(PlayerPedId(), at.x, at.y, at.z, false, false, false, false)
end

actions.setFlag = function(d)
    local bot = Bots.Get(tonumber(d.id))
    if not bot then return end
    if d.flag == 'invincible' then
        bot.invincible = d.value == true
        SetEntityInvincible(bot.ped, bot.invincible)
    elseif d.flag == 'frozen' then
        bot.frozen = d.value == true
        FreezeEntityPosition(bot.ped, bot.frozen)
    end
end

actions.outfitSet = function(d)
    local bot = Bots.Get()
    if bot then Outfit.Set(bot.ped, d.kind, tonumber(d.id) or 0, tonumber(d.drawable) or 0, tonumber(d.texture) or 0) end
end

actions.outfitRandom = function()
    local bot = Bots.Get()
    if bot then Outfit.Randomize(bot.ped) end
end

actions.outfitDefault = function()
    local bot = Bots.Get()
    if bot then Outfit.Default(bot.ped) end
end

actions.outfitApply = function(d)
    local bot = Bots.Get()
    if bot and type(d.preset) == 'table' then Outfit.Apply(bot.ped, d.preset) end
end

-- d.steps = { { name = 'goto', args = { 'waypoint' } }, ... }, d.all = run on every bot
actions.run = function(d)
    local steps = {}
    for _, step in ipairs(type(d.steps) == 'table' and d.steps or {}) do
        local name = tostring(step.name or ''):lower()
        if not Tasks.Exists(name) then return Menu.Toast(('Unknown task "%s".'):format(name)) end
        steps[#steps + 1] = { name = name, args = toStrings(step.args) }
    end
    if #steps == 0 then return end

    local bots = {}
    if d.all then
        for id in pairs(Bots.list) do
            local bot = Bots.Get(id)
            if bot then bots[#bots + 1] = bot end
        end
    else
        bots[1] = Bots.Get()
    end
    if #bots == 0 then return Menu.Toast('Spawn a bot first.') end
    for _, bot in ipairs(bots) do Bots.Run(bot, steps) end
end

actions.freecam = function() closeThen(Freecam.Toggle) end
actions.photo = function() closeThen(function() Photo.Take('menu') end) end
actions.tour = function(d)
    local names = type(d.spot) == 'string' and d.spot ~= '' and { d.spot } or {}
    closeThen(function() Photo.Tour(names) end)
end
actions.tourStop = function() Photo.StopTour() end
actions.saveSpot = function(d)
    if not Freecam.active then return Menu.Toast('Open the free cam, frame the shot, then save it.') end
    Photo.PrintSpot(type(d.name) == 'string' and d.name ~= '' and d.name or 'spot')
end

actions.event = function(d)
    local side, name = d.side, d.name
    if (side ~= 'server' and side ~= 'client') or type(name) ~= 'string' or name == '' then return end
    local args = {}
    if type(d.args) == 'string' and d.args:match('%S') then
        local ok, decoded = pcall(json.decode, d.args)
        if not ok or type(decoded) ~= 'table' then
            return Menu.Toast('Event args must be a JSON array, e.g. ["store_1", 500]')
        end
        args = decoded
    end
    if side == 'server' then TriggerServerEvent(name, table.unpack(args)) else TriggerEvent(name, table.unpack(args)) end
    Menu.Toast(('Fired %s event %s.'):format(side, name))
end

RegisterNUICallback('action', function(data, cb)
    local fn = actions[data and data.action]
    if fn then
        local ok, err = pcall(fn, data)
        if not ok then Menu.Toast('Error: ' .. tostring(err)) end
    end
    -- Model loads and spawns may yield; give the game a frame before reading state back.
    Wait(0)
    cb(Menu.State())
end)

RegisterNetEvent('motion_testbot:openMenu', function()
    Menu.Open()
end)

-- The key asks the server first, so only players with the ACE can open the menu.
RegisterCommand('testbotmenu', function()
    if Menu.open then Menu.Close() else TriggerServerEvent('motion_testbot:requestMenu') end
end, false)
RegisterKeyMapping('testbotmenu', 'Open the TestBot menu', 'keyboard', Config.MenuKey)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() and Menu.open then SetNuiFocus(false, false) end
end)
