Tasks = {}

local DRIVE_NORMAL = 786603
local DRIVE_RUSHED = 1074528293
local WALK, RUN = 1.0, 2.0

local function botCoords(ctx)
    return GetEntityCoords(ctx.ped)
end

local function weaponHash(name)
    name = name:upper()
    if not name:find('^WEAPON_') then name = 'WEAPON_' .. name end
    return joaat(name), name
end

local function ensureArmed(ped)
    local _, current = GetCurrentPedWeapon(ped, true)
    if current == `WEAPON_UNARMED` then
        local hash = weaponHash(Config.Bot.defaultWeapon)
        GiveWeaponToPed(ped, hash, 250, false, true)
        SetCurrentPedWeapon(ped, hash, true)
    end
end

local function requestControl(entity)
    if NetworkHasControlOfEntity(entity) then return true end
    NetworkRequestControlOfEntity(entity)
    local deadline = GetGameTimer() + 1500
    while not NetworkHasControlOfEntity(entity) and GetGameTimer() < deadline do
        Wait(0)
        NetworkRequestControlOfEntity(entity)
    end
    return NetworkHasControlOfEntity(entity)
end

local function anyPlayerAimingAt(ped)
    for _, player in ipairs(GetActivePlayers()) do
        if IsPlayerFreeAimingAtEntity(player, ped) or IsPlayerTargettingEntity(player, ped) then
            return GetPlayerPed(player)
        end
    end
    return nil
end

local function playAnim(ped, dict, name, flag)
    if not Util.LoadAnimDict(dict) then return ('unknown anim dict "%s"'):format(dict) end
    TaskPlayAnim(ped, dict, name, 8.0, -8.0, -1, flag or 1, 0.0, false, false, false)
    RemoveAnimDict(dict)
end

local function freeDriverVehicle(origin)
    local best, bestDist = nil, Config.Bot.nearbyRadius
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        if IsVehicleSeatFree(veh, -1) and IsVehicleDriveable(veh, false) then
            local dist = #(GetEntityCoords(veh) - origin)
            if dist < bestDist then best, bestDist = veh, dist end
        end
    end
    return best
end

local function enterVehicle(ctx, veh, seat)
    TaskEnterVehicle(ctx.ped, veh, 20000, seat, RUN, 1, 0)
    if not Bots.WaitUntil(ctx, function() return IsPedInVehicle(ctx.ped, veh, false) end, 25000) then
        return 'could not get into the vehicle'
    end
end

-- Every task: usage, help, persistent (keeps going after the queue ends), run(ctx, args).
-- run returns nil on success or an error message.
local defs = {}

defs.follow = {
    usage = 'follow [me|bot:<id>|player:<id>]', persistent = true,
    help = 'Follow you (or another target) around.',
    run = function(ctx, args)
        local target = Util.ResolveEntity(args[1] or 'me', botCoords(ctx), ctx.ped)
        if not target then return 'target not found' end
        TaskFollowToOffsetOfEntity(ctx.ped, target, 1.0, -1.5, 0.0, RUN, -1, 1.5, true)
    end,
}

defs.stay = {
    usage = 'stay', persistent = true,
    help = 'Stand still where it is.',
    run = function(ctx)
        ClearPedTasks(ctx.ped)
        TaskStandStill(ctx.ped, -1)
    end,
}

defs['goto'] = {
    usage = 'goto <waypoint|me|ped|x y z> [walk]',
    help = 'Walk/run to a place. Finishes when it arrives.',
    run = function(ctx, args)
        local dest = Util.ResolveCoords(args, botCoords(ctx), ctx.ped)
        if not dest then return 'no destination (set a waypoint?)' end
        local speed = (args[#args] == 'walk') and WALK or RUN
        TaskGoToCoordAnyMeans(ctx.ped, dest.x, dest.y, dest.z, speed, 0, false, DRIVE_NORMAL, -1.0)
        local arrived = Bots.WaitUntil(ctx, function()
            local c = botCoords(ctx)
            return #(vector2(c.x, c.y) - vector2(dest.x, dest.y)) < 3.0
        end, 300000)
        if not arrived and ctx.active() then return 'did not arrive within 5 minutes' end
    end,
}

defs.tp = {
    usage = 'tp <me|waypoint|ped|x y z>',
    help = 'Teleport the bot.',
    run = function(ctx, args)
        local dest = Util.ResolveCoords(args, botCoords(ctx), ctx.ped)
        if not dest then return 'no destination' end
        if (args[1] or ''):lower() == 'me' then
            dest = GetOffsetFromEntityInWorldCoords(PlayerPedId(), 0.0, 1.5, 0.0)
        end
        SetEntityCoords(ctx.ped, dest.x, dest.y, dest.z, false, false, false, false)
    end,
}

defs.car = {
    usage = 'car [model]',
    help = 'Spawn a car next to the bot and put it in the driver seat.',
    run = function(ctx, args)
        local model = args[1] or 'sultan'
        local hash = Util.LoadModel(model)
        if not hash or not IsModelAVehicle(hash) then return ('unknown vehicle "%s"'):format(model) end
        local at = GetOffsetFromEntityInWorldCoords(ctx.ped, 0.0, 4.0, 0.0)
        local veh = CreateVehicle(hash, at.x, at.y, at.z, GetEntityHeading(ctx.ped), true, false)
        SetModelAsNoLongerNeeded(hash)
        SetVehicleOnGroundProperly(veh)
        SetPedIntoVehicle(ctx.ped, veh, -1)
        ctx.bot.vehicle = veh
    end,
}

defs.enter = {
    usage = 'enter [driver|passenger]',
    help = "Get into your vehicle, or the nearest one.",
    run = function(ctx, args)
        local veh = GetVehiclePedIsIn(PlayerPedId(), false)
        if veh == 0 then veh = Util.NearestVehicle(botCoords(ctx), Config.Bot.nearbyRadius) end
        if not veh then return 'no vehicle nearby' end
        local seat = -1
        if args[1] == 'passenger' or not IsVehicleSeatFree(veh, -1) then
            seat = nil
            for s = 0, GetVehicleMaxNumberOfPassengers(veh) - 1 do
                if IsVehicleSeatFree(veh, s) then seat = s break end
            end
            if not seat then return 'no free seat' end
        end
        return enterVehicle(ctx, veh, seat)
    end,
}

defs.leave = {
    usage = 'leave',
    help = 'Get out of the vehicle.',
    run = function(ctx)
        TaskLeaveAnyVehicle(ctx.ped, 0, 0)
        Bots.WaitUntil(ctx, function() return not IsPedInAnyVehicle(ctx.ped, false) end, 10000)
    end,
}

defs.drive = {
    usage = 'drive <waypoint|me|x y z> [fast]',
    help = 'Drive to a place (uses its car, or steals the nearest free one).',
    run = function(ctx, args)
        local dest = Util.ResolveCoords(args, botCoords(ctx), ctx.ped)
        if not dest then return 'no destination (set a waypoint?)' end
        local veh = GetVehiclePedIsIn(ctx.ped, false)
        if veh == 0 then
            veh = freeDriverVehicle(botCoords(ctx))
            if not veh then return 'no free vehicle nearby (try "car" first)' end
            local err = enterVehicle(ctx, veh, -1)
            if err then return err end
        end
        local fast = args[#args] == 'fast'
        TaskVehicleDriveToCoordLongrange(ctx.ped, veh, dest.x, dest.y, dest.z,
            fast and 40.0 or 20.0, fast and DRIVE_RUSHED or DRIVE_NORMAL, 15.0)
        Bots.WaitUntil(ctx, function()
            local c = botCoords(ctx)
            return #(vector2(c.x, c.y) - vector2(dest.x, dest.y)) < 25.0
        end)
        if ctx.active() then TaskVehicleTempAction(ctx.ped, veh, 27, 3000) end -- brake
    end,
}

defs.weapon = {
    usage = 'weapon <name|none>',
    help = 'Give the bot a weapon (e.g. pistol, carbinerifle, motion_glock17).',
    run = function(ctx, args)
        if not args[1] then return 'which weapon?' end
        if args[1]:lower() == 'none' then
            RemoveAllPedWeapons(ctx.ped, true)
            return
        end
        local hash, name = weaponHash(args[1])
        if not IsWeaponValid(hash) then return ('unknown weapon %s'):format(name) end
        GiveWeaponToPed(ctx.ped, hash, 250, false, true)
        SetCurrentPedWeapon(ctx.ped, hash, true)
    end,
}

defs.aim = {
    usage = 'aim [me|ped|bot:<id>|player:<id>]', persistent = true,
    help = 'Point a gun at a target and hold it.',
    run = function(ctx, args)
        local target = Util.ResolveEntity(args[1] or 'me', botCoords(ctx), ctx.ped)
        if not target then return 'target not found' end
        ensureArmed(ctx.ped)
        TaskAimGunAtEntity(ctx.ped, target, -1, false)
    end,
}

defs.shoot = {
    usage = 'shoot [target] [seconds]',
    help = 'Shoot at a target for a few seconds (default 3).',
    run = function(ctx, args)
        local target = Util.ResolveEntity(args[1] or 'ped', botCoords(ctx), ctx.ped)
        if not target then return 'target not found' end
        ensureArmed(ctx.ped)
        local ms = math.floor((tonumber(args[2]) or 3) * 1000)
        TaskShootAtEntity(ctx.ped, target, ms, `FIRING_PATTERN_FULL_AUTO`)
        Bots.WaitUntil(ctx, function() return false end, ms)
    end,
}

defs.attack = {
    usage = 'attack [me|ped|bot:<id>|player:<id>]', persistent = true,
    help = 'Fight a target until told otherwise.',
    run = function(ctx, args)
        local target = Util.ResolveEntity(args[1] or 'me', botCoords(ctx), ctx.ped)
        if not target then return 'target not found' end
        ensureArmed(ctx.ped)
        TaskCombatPed(ctx.ped, target, 0, 16)
    end,
}

defs.rob = {
    usage = 'rob [ped|me|bot:<id>|player:<id>]', persistent = true,
    help = 'Walk up to a target (nearest ped by default), pull a gun and hold them up.',
    run = function(ctx, args)
        local target = Util.ResolveEntity(args[1] or 'ped', botCoords(ctx), ctx.ped)
        if not target then return 'no one to rob nearby' end
        ensureArmed(ctx.ped)
        TaskGoToEntity(ctx.ped, target, -1, 3.0, RUN, 1073741824, 0)
        local reached = Bots.WaitUntil(ctx, function()
            return #(botCoords(ctx) - GetEntityCoords(target)) < 4.0
        end, 60000)
        if not ctx.active() then return end
        if not reached then return 'could not reach the target' end

        if not IsPedAPlayer(target) and requestControl(target) then
            SetBlockingOfNonTemporaryEvents(target, true)
            TaskHandsUp(target, -1, ctx.ped, -1, true)
        end
        TaskAimGunAtEntity(ctx.ped, target, -1, false)
    end,
}

defs.victim = {
    usage = 'victim [stay|flee] [seconds]', persistent = true,
    help = 'Act like a robbery victim: hands up while a player aims at it, then calm down (or flee) after N seconds (default 8).',
    run = function(ctx, args)
        local after = (args[1] == 'flee') and 'flee' or 'stay'
        local releaseMs = math.floor((tonumber(args[2] or args[1]) or 8) * 1000)
        ClearPedTasks(ctx.ped)
        TaskTurnPedToFaceEntity(ctx.ped, PlayerPedId(), 2000)

        local handsUp, lastAimed = false, 0
        while ctx.active() do
            local robber = anyPlayerAimingAt(ctx.ped)
            if robber then
                lastAimed = GetGameTimer()
                if not handsUp then
                    handsUp = true
                    TaskHandsUp(ctx.ped, -1, robber, -1, true)
                    Util.Notify(('Bot %d: hands up!'):format(ctx.bot.id))
                end
            elseif handsUp and GetGameTimer() - lastAimed > releaseMs then
                handsUp = false
                if after == 'flee' then
                    TaskSmartFleePed(ctx.ped, PlayerPedId(), 200.0, -1, false, false)
                    Util.Notify(('Bot %d: fleeing.'):format(ctx.bot.id))
                    return
                end
                ClearPedTasks(ctx.ped)
                TaskStandStill(ctx.ped, -1)
                Util.Notify(('Bot %d: calmed down.'):format(ctx.bot.id))
            end
            Wait(100)
        end
    end,
}

defs.handsup = {
    usage = 'handsup [seconds]',
    help = 'Put hands up (forever, or for N seconds).',
    run = function(ctx, args)
        local secs = tonumber(args[1])
        TaskHandsUp(ctx.ped, secs and math.floor(secs * 1000) or -1, PlayerPedId(), -1, true)
        if secs then Bots.WaitUntil(ctx, function() return false end, secs * 1000) end
    end,
}

defs.kneel = {
    usage = 'kneel', persistent = true,
    help = 'Kneel with hands on head (arrest pose).',
    run = function(ctx)
        return playAnim(ctx.ped, 'random@arrests@busted', 'idle_a', 1)
    end,
}

defs.flee = {
    usage = 'flee [me|ped|...]', persistent = true,
    help = 'Run away from a target.',
    run = function(ctx, args)
        local from = Util.ResolveEntity(args[1] or 'me', botCoords(ctx), ctx.ped) or PlayerPedId()
        TaskSmartFleePed(ctx.ped, from, 200.0, -1, false, false)
    end,
}

defs.wander = {
    usage = 'wander', persistent = true,
    help = 'Walk around like a normal ped.',
    run = function(ctx)
        TaskWanderStandard(ctx.ped, 10.0, 10)
    end,
}

defs.anim = {
    usage = 'anim <dict> <name> [upper]', persistent = true,
    help = 'Loop an animation ("upper" = upper body only, so it can still walk).',
    run = function(ctx, args)
        if not args[2] then return 'usage: anim <dict> <name>' end
        return playAnim(ctx.ped, args[1], args[2], args[3] == 'upper' and 49 or 1)
    end,
}

defs.scenario = {
    usage = 'scenario <name>', persistent = true,
    help = 'Play a scenario, e.g. WORLD_HUMAN_SMOKING, WORLD_HUMAN_CLIPBOARD, PROP_HUMAN_ATM.',
    run = function(ctx, args)
        if not args[1] then return 'which scenario?' end
        ClearPedTasks(ctx.ped)
        TaskStartScenarioInPlace(ctx.ped, args[1]:upper(), 0, true)
    end,
}

defs.ragdoll = {
    usage = 'ragdoll [seconds]',
    help = 'Fall over for N seconds (default 3).',
    run = function(ctx, args)
        local ms = math.floor((tonumber(args[1]) or 3) * 1000)
        SetPedToRagdoll(ctx.ped, ms, ms, 0, false, false, false)
        Bots.WaitUntil(ctx, function() return false end, ms)
    end,
}

defs.kill = {
    usage = 'kill',
    help = 'Kill the bot (for testing death, loot or EMS scripts).',
    run = function(ctx)
        SetEntityInvincible(ctx.ped, false)
        SetEntityHealth(ctx.ped, 0)
    end,
}

defs.revive = {
    usage = 'revive',
    help = 'Bring a dead bot back.',
    run = function(ctx)
        local c = botCoords(ctx)
        ResurrectPed(ctx.ped)
        SetEntityCoords(ctx.ped, c.x, c.y, c.z, false, false, false, false)
        SetEntityHealth(ctx.ped, GetEntityMaxHealth(ctx.ped))
        ClearPedTasksImmediately(ctx.ped)
        SetEntityInvincible(ctx.ped, Config.Bot.invincible)
    end,
}

defs.wait = {
    usage = 'wait <seconds>',
    help = 'Pause the queue.',
    run = function(ctx, args)
        local ms = math.floor((tonumber(args[1]) or 1) * 1000)
        Bots.WaitUntil(ctx, function() return false end, ms)
    end,
}

defs.stop = {
    usage = 'stop',
    help = 'Stop everything and stand still.',
    run = function(ctx)
        ClearPedTasks(ctx.ped)
    end,
}

Tasks.defs = defs

function Tasks.Exists(name)
    return defs[name] ~= nil
end

function Tasks.IsInstant(name)
    return not (defs[name] and defs[name].persistent)
end

function Tasks.Run(ctx, step)
    return defs[step.name].run(ctx, step.args)
end

function Tasks.PrintHelp()
    local names = {}
    for name in pairs(defs) do names[#names + 1] = name end
    table.sort(names)
    for _, name in ipairs(names) do
        Util.Notify(('%s - %s'):format(defs[name].usage, defs[name].help))
    end
end
