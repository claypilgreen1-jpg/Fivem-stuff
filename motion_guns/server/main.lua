local byName = {}
for _, weapon in ipairs(MotionGuns.Weapons) do
    byName[weapon.name] = weapon
end

local function reply(src, msg)
    if src == 0 then
        print(msg)
    else
        TriggerClientEvent('chat:addMessage', src, { args = { 'Motion Guns', msg } })
    end
end

if Config.EnableCommand then
    -- /motionguns                 list every weapon
    -- /motionguns <name> [id]     give a weapon (name with or without WEAPON_MOTION_)
    -- /motionguns all [id]        give the whole pack
    RegisterCommand(Config.CommandName, function(src, args)
        if not args[1] then
            local names = {}
            for _, weapon in ipairs(MotionGuns.Weapons) do
                names[#names + 1] = weapon.name:sub(15):lower()
            end
            reply(src, table.concat(names, ', '))
            return
        end

        local target = tonumber(args[2]) or src
        if target == 0 or not GetPlayerName(target) then
            reply(src, 'Player not found.')
            return
        end

        local query = args[1]:upper()
        local list = {}
        if query == 'ALL' then
            list = MotionGuns.Weapons
        else
            local weapon = byName[query] or byName['WEAPON_MOTION_' .. query]
            if not weapon then
                reply(src, ('Unknown weapon "%s".'):format(args[1]))
                return
            end
            list = { weapon }
        end

        for _, weapon in ipairs(list) do
            TriggerClientEvent('motion_guns:give', target, weapon.name, weapon.clip * Config.GiveClips)
        end
        reply(src, ('Gave %d weapon(s) to %s.'):format(#list, GetPlayerName(target)))
    end, true)
end
