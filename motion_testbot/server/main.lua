local ACE = 'command.' .. Config.Command

-- Restricted command: only players with the ACE above can use it.
RegisterCommand(Config.Command, function(src, _, raw)
    if src == 0 then
        print('[motion_testbot] /' .. Config.Command .. ' must be used in game.')
        return
    end
    local text = raw:match('^%S+%s*(.*)$') or ''
    TriggerClientEvent('motion_testbot:command', src, text)
end, true)

local shotCount = 0

local function safeLabel(label)
    label = tostring(label or 'shot'):gsub('[^%w_%-]', '_'):sub(1, 40)
    return label ~= '' and label or 'shot'
end

RegisterNetEvent('motion_testbot:screenshot', function(label)
    local src = source
    if not IsPlayerAceAllowed(src, ACE) then return end

    if GetResourceState('screenshot-basic') ~= 'started' then
        TriggerClientEvent('motion_testbot:screenshotDone', src, false, 'screenshot-basic is not running')
        return
    end

    local cfg = Config.Screenshots
    shotCount = shotCount + 1
    local fileName = ('%s_%03d_%s.%s'):format(os.date('%Y%m%d_%H%M%S'), shotCount % 1000, safeLabel(label), cfg.encoding)
    local path = ('%s/%s/%s'):format(GetResourcePath(GetCurrentResourceName()), cfg.folder, fileName)

    exports['screenshot-basic']:requestClientScreenshot(src, {
        fileName = path,
        encoding = cfg.encoding,
        quality = cfg.quality,
    }, function(err)
        if err then
            TriggerClientEvent('motion_testbot:screenshotDone', src, false, tostring(err))
        else
            print(('[motion_testbot] %s saved %s'):format(GetPlayerName(src), fileName))
            TriggerClientEvent('motion_testbot:screenshotDone', src, true, fileName)
        end
    end)
end)
