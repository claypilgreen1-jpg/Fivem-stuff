Util = {}

function Util.Notify(msg)
    TriggerEvent('chat:addMessage', { color = { 120, 200, 255 }, args = { 'TestBot', msg } })
    if Menu then Menu.Toast(msg) end
end

function Util.Split(str, sep)
    local out = {}
    for part in str:gmatch('[^' .. sep .. ']+') do
        part = part:match('^%s*(.-)%s*$')
        if part ~= '' then out[#out + 1] = part end
    end
    return out
end

local function request(loaded, requestFn, value, timeout)
    if loaded(value) then return true end
    requestFn(value)
    local deadline = GetGameTimer() + (timeout or 5000)
    while not loaded(value) do
        if GetGameTimer() > deadline then return false end
        Wait(0)
    end
    return true
end

function Util.LoadModel(model)
    local hash = type(model) == 'number' and model or joaat(model)
    if not IsModelInCdimage(hash) then return nil end
    if not request(HasModelLoaded, RequestModel, hash) then return nil end
    return hash
end

function Util.LoadAnimDict(dict)
    if not DoesAnimDictExist(dict) then return false end
    return request(HasAnimDictLoaded, RequestAnimDict, dict)
end

-- Camera rotation (degrees, rotation order 2) that points from one position to another.
function Util.RotationTo(from, to)
    local d = to - from
    local flat = math.sqrt(d.x * d.x + d.y * d.y)
    return vector3(math.deg(math.atan(d.z, flat)), 0.0, math.deg(math.atan(-d.x, d.y)))
end

function Util.RotationToDirection(rot)
    local x, z = math.rad(rot.x), math.rad(rot.z)
    local c = math.abs(math.cos(x))
    return vector3(-math.sin(z) * c, math.cos(z) * c, math.sin(x))
end

function Util.WaypointCoords()
    local blip = GetFirstBlipInfoId(8)
    if not DoesBlipExist(blip) then return nil end
    local c = GetBlipInfoIdCoord(blip)
    return vector3(c.x, c.y, GetApproxHeightForPoint(c.x, c.y))
end

local function isBot(entity)
    for _, bot in pairs(Bots.list) do
        if bot.ped == entity then return true end
    end
    return false
end

-- Closest ambient ped to a position (skips players and test bots).
function Util.NearestPed(origin, radius, ignore)
    local best, bestDist = nil, radius
    for _, ped in ipairs(GetGamePool('CPed')) do
        if ped ~= ignore and not IsPedAPlayer(ped) and not isBot(ped) and not IsPedDeadOrDying(ped, true) then
            local dist = #(GetEntityCoords(ped) - origin)
            if dist < bestDist then best, bestDist = ped, dist end
        end
    end
    return best
end

function Util.NearestVehicle(origin, radius)
    local best, bestDist = nil, radius
    for _, veh in ipairs(GetGamePool('CVehicle')) do
        local dist = #(GetEntityCoords(veh) - origin)
        if dist < bestDist then best, bestDist = veh, dist end
    end
    return best
end

-- Turns a target word into an entity: me, ped (nearest ambient ped),
-- player:<server id>, or bot:<bot id>.
function Util.ResolveEntity(word, origin, self)
    word = (word or 'me'):lower()
    if word == 'me' then return PlayerPedId() end
    if word == 'ped' then return Util.NearestPed(origin, Config.Bot.nearbyRadius, self) end
    local kind, id = word:match('^(%a+):(%d+)$')
    if kind == 'player' then
        local player = GetPlayerFromServerId(tonumber(id))
        if player ~= -1 then return GetPlayerPed(player) end
    elseif kind == 'bot' then
        local bot = Bots.list[tonumber(id)]
        if bot then return bot.ped end
    end
    return nil
end

-- Turns target words into a position: me, waypoint, ped, bot:<id>, player:<id>, or "x y z".
function Util.ResolveCoords(args, origin, self)
    local x, y, z = tonumber(args[1]), tonumber(args[2]), tonumber(args[3])
    if x and y then
        return vector3(x, y, z or GetApproxHeightForPoint(x, y))
    end
    if (args[1] or ''):lower() == 'waypoint' then
        return Util.WaypointCoords()
    end
    local entity = Util.ResolveEntity(args[1], origin, self)
    return entity and GetEntityCoords(entity) or nil
end
