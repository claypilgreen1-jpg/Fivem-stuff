local API_URL = 'https://api.anthropic.com/v1/messages'
local FALLBACK_LINES = {
    'Uh... sorry, what? I zoned out.',
    "Not now, man. I've got somewhere to be.",
    'Hm? Yeah... sure.',
    "I don't really want to talk right now.",
}

local apiKey = GetConvar(Config.ApiKeyConvar, '')
if apiKey == '' then
    print(('^1[motion_npctalk] No API key. Add  set %s "sk-ant-..."  to server.cfg. NPCs will only give canned replies.^0')
        :format(Config.ApiKeyConvar))
end

-- conversations[src][pedKey] = { persona, info, messages, lastActive, busy }
local conversations = {}
local lastMessageAt = {}

local function cannedLine()
    return FALLBACK_LINES[math.random(#FALLBACK_LINES)]
end

local function getConversation(src, pedKey, info)
    conversations[src] = conversations[src] or {}
    local convo = conversations[src][pedKey]
    if convo and os.time() - convo.lastActive > Config.ForgetAfter then convo = nil end
    if not convo then
        convo = { persona = Personas.Create(info), info = info, messages = {}, lastActive = os.time() }
        conversations[src][pedKey] = convo
    end
    return convo
end

-- Keep the last N exchanges. Always cut at a user message so roles keep alternating.
local function trimHistory(messages)
    local max = Config.HistoryTurns * 2
    while #messages > max do
        table.remove(messages, 1)
        table.remove(messages, 1)
    end
end

local function extractText(body)
    local ok, data = pcall(json.decode, body or '')
    if not ok or type(data) ~= 'table' then return nil, 'unreadable response' end
    if data.stop_reason == 'refusal' then return nil, 'refusal' end
    local parts = {}
    for _, block in ipairs(data.content or {}) do
        if block.type == 'text' and block.text then parts[#parts + 1] = block.text end
    end
    local text = table.concat(parts, ' '):gsub('%s+', ' '):match('^%s*(.-)%s*$')
    if text == '' then return nil, 'empty reply (stop_reason: ' .. tostring(data.stop_reason) .. ')' end
    return text
end

local function askClaude(convo, cb)
    if apiKey == '' then return cb(nil, 'no API key') end

    local body = json.encode({
        model = Config.Model,
        max_tokens = Config.MaxTokens,
        output_config = { effort = Config.Effort },
        fallbacks = 'default', -- if a request is declined, the API retries it on a recommended model
        system = Personas.SystemPrompt(convo.persona, convo.info),
        messages = convo.messages,
    })

    PerformHttpRequest(API_URL, function(status, response)
        if status ~= 200 then
            return cb(nil, ('HTTP %s: %s'):format(tostring(status), tostring(response):sub(1, 300)))
        end
        cb(extractText(response))
    end, 'POST', body, {
        ['Content-Type'] = 'application/json',
        ['x-api-key'] = apiKey,
        ['anthropic-version'] = '2023-06-01',
        ['anthropic-beta'] = 'server-side-fallback-2026-07-01',
    })
end

-- Sends a line to everyone close enough to hear it.
local function broadcast(src, payload)
    local origin = GetEntityCoords(GetPlayerPed(src))
    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if target == src or #(GetEntityCoords(GetPlayerPed(target)) - origin) <= Config.HearingRange then
            TriggerClientEvent('motion_npctalk:line', target, payload)
        end
    end
end

local function cleanString(value, maxLen)
    if type(value) ~= 'string' then return nil end
    value = value:gsub('[%c]', ' '):match('^%s*(.-)%s*$')
    if value == '' then return nil end
    return value:sub(1, maxLen)
end

RegisterNetEvent('motion_npctalk:say', function(pedKey, netId, message, info, fromChat)
    local src = source
    message = cleanString(message, Config.MaxMessageLength)
    if not message or type(pedKey) ~= 'number' or type(info) ~= 'table' then return end

    local now = os.time()
    if lastMessageAt[src] and now - lastMessageAt[src] < Config.Cooldown then
        TriggerClientEvent('motion_npctalk:reject', src, 'Slow down a little.')
        return
    end

    local safeInfo = {
        gender = info.gender == 'female' and 'female' or 'male',
        role = cleanString(info.role, 16),
        area = cleanString(info.area, 48),
        street = cleanString(info.street, 48),
        hour = tonumber(info.hour),
        inVehicle = info.inVehicle == true,
    }
    local convo = getConversation(src, pedKey, safeInfo)
    if convo.busy then
        TriggerClientEvent('motion_npctalk:reject', src, 'They are still answering.')
        return
    end

    lastMessageAt[src] = now
    convo.busy = true
    convo.lastActive = now
    convo.messages[#convo.messages + 1] = { role = 'user', content = message }

    local npcName = convo.persona.name
    netId = tonumber(netId)
    if not fromChat then
        broadcast(src, { kind = 'player', speaker = GetPlayerName(src), text = message })
    end

    askClaude(convo, function(reply, err)
        convo.busy = false
        local leaving = false
        if reply then
            local tagAt = reply:find(Personas.LEAVE_TAG, 1, true)
            if tagAt then
                leaving = true
                reply = reply:sub(1, tagAt - 1):match('^%s*(.-)%s*$')
                if reply == '' then reply = '...' end
            end
        end
        if not reply then
            print(('[motion_npctalk] reply failed: %s'):format(err))
            table.remove(convo.messages) -- drop the unanswered line so roles keep alternating
            reply = cannedLine()
        else
            convo.messages[#convo.messages + 1] = { role = 'assistant', content = reply }
            trimHistory(convo.messages)
        end
        convo.lastActive = os.time()
        if GetPlayerName(src) then
            broadcast(src, {
                kind = 'npc', speaker = npcName, text = reply, pedKey = pedKey, netId = netId, owner = src, leaving = leaving,
            })
        end
    end)
end)

-- Players talk to NPCs by typing in normal chat. Commands are ignored; the client decides
-- whether anyone is close enough to hear.
AddEventHandler('chatMessage', function(src, _, text)
    if type(text) == 'string' and text:sub(1, 1) ~= '/' then
        TriggerClientEvent('motion_npctalk:heard', src, text)
    end
end)

AddEventHandler('playerDropped', function()
    conversations[source] = nil
    lastMessageAt[source] = nil
end)

-- Forget stale conversations so memory doesn't grow forever.
CreateThread(function()
    while true do
        Wait(60000)
        local now = os.time()
        for src, peds in pairs(conversations) do
            for key, convo in pairs(peds) do
                if not convo.busy and now - convo.lastActive > Config.ForgetAfter then peds[key] = nil end
            end
        end
    end
end)
