local HELP = {
    '/bot cam - toggle the free cam (LMB in free cam = screenshot)',
    '/bot photo [label] - screenshot right now',
    '/bot tour [spot ...] | tour stop - fly to Config.PhotoSpots and photograph each',
    '/bot spot <name> - print a PhotoSpots line for the current free cam view',
    '/bot spawn [model] | list | select <id> | dismiss [id|all]',
    '/bot <task> [args] ; <task> [args] ... - queue tasks on the selected bot',
    '/bot on <id> <tasks> | /bot all <tasks> - queue tasks on a specific bot / every bot',
    '/bot event server|client <event> [json args array] - fire an event to test a script',
    '/bot tasks - list every task',
}

-- "goto waypoint ; handsup 5 ; flee" -> { {name='goto', args={'waypoint'}}, ... }
local function parseQueue(text)
    local steps = {}
    for _, part in ipairs(Util.Split(text, ';')) do
        local words = Util.Split(part, ' ')
        local name = table.remove(words, 1):lower()
        if not Tasks.Exists(name) then
            return nil, ('unknown task "%s" (see /bot tasks)'):format(name)
        end
        steps[#steps + 1] = { name = name, args = words }
    end
    if #steps == 0 then return nil, 'no tasks given' end
    return steps
end

local function runOn(bots, text)
    local steps, err = parseQueue(text)
    if not steps then return Util.Notify(err) end
    if #bots == 0 then return Util.Notify('No bot to command. Use "/bot spawn" first.') end
    for _, bot in ipairs(bots) do Bots.Run(bot, steps) end
end

local function fireEvent(words, rest)
    local side, name = (words[2] or ''):lower(), words[3]
    if (side ~= 'server' and side ~= 'client') or not name then
        return Util.Notify('Usage: /bot event server|client <event> [json args array]')
    end
    local args = {}
    local json_args = rest:match('^%s*%S+%s+%S+%s+%S+%s+(.+)$')
    if json_args then
        local ok, decoded = pcall(json.decode, json_args)
        if not ok or type(decoded) ~= 'table' then
            return Util.Notify('Args must be a JSON array, e.g. ["store_1", 500]')
        end
        args = decoded
    end
    if side == 'server' then
        TriggerServerEvent(name, table.unpack(args))
    else
        TriggerEvent(name, table.unpack(args))
    end
    Util.Notify(('Fired %s event %s with %d arg(s).'):format(side, name, #args))
end

RegisterNetEvent('motion_testbot:command', function(text)
    local words = Util.Split(text, ' ')
    local cmd = (words[1] or 'help'):lower()

    if cmd == 'help' then
        for _, line in ipairs(HELP) do Util.Notify(line) end
    elseif cmd == 'tasks' then
        Tasks.PrintHelp()
    elseif cmd == 'cam' or cmd == 'freecam' then
        Freecam.Toggle()
    elseif cmd == 'photo' then
        CreateThread(function() Photo.Take(words[2] or 'shot') end)
    elseif cmd == 'tour' then
        if (words[2] or ''):lower() == 'stop' then
            Photo.StopTour()
        else
            table.remove(words, 1)
            CreateThread(function() Photo.Tour(words) end)
        end
    elseif cmd == 'spot' then
        Photo.PrintSpot(words[2])
    elseif cmd == 'spawn' then
        Bots.Spawn(words[2])
    elseif cmd == 'list' then
        Bots.PrintList()
    elseif cmd == 'select' then
        local bot = Bots.Get(tonumber(words[2]))
        if bot then
            Bots.selected = bot.id
            Util.Notify(('Selected bot %d.'):format(bot.id))
        else
            Util.Notify('No bot with that id.')
        end
    elseif cmd == 'dismiss' then
        if (words[2] or ''):lower() == 'all' then
            Bots.DismissAll()
            Util.Notify('Dismissed all bots.')
        else
            local bot = Bots.Get(tonumber(words[2]))
            if not bot then return Util.Notify('No bot to dismiss.') end
            Bots.Dismiss(bot)
            Util.Notify(('Dismissed bot %d.'):format(bot.id))
        end
    elseif cmd == 'event' then
        fireEvent(words, text)
    elseif cmd == 'on' then
        local bot = Bots.Get(tonumber(words[2]))
        if not bot then return Util.Notify('No bot with that id.') end
        runOn({ bot }, text:match('^%s*%S+%s+%S+%s+(.*)$') or '')
    elseif cmd == 'all' then
        local bots = {}
        for id in pairs(Bots.list) do
            local bot = Bots.Get(id)
            if bot then bots[#bots + 1] = bot end
        end
        runOn(bots, text:match('^%s*%S+%s+(.*)$') or '')
    else
        local bot = Bots.Get()
        runOn(bot and { bot } or {}, text)
    end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource == GetCurrentResourceName() then
        Photo.StopTour()
        Freecam.Stop()
    end
end)

TriggerEvent('chat:addSuggestion', '/' .. Config.Command, 'TestBot: free cam, photos and test peds. "/bot help" for commands.', {
    { name = 'command', help = 'help, cam, photo, tour, spawn, list, tasks, or a task like "follow"' },
})
