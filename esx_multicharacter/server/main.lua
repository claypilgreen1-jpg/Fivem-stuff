local PREFIX = Config.Prefix
local ID_LENGTH = 42 + #PREFIX -- "char1:" + a 40-character license

local dbReady = false
local identifierTables = { users = 'identifier' } -- every table that stores a character identifier
local sessions = {}      -- [src] = { identifier, slots, characters }
local online = {}        -- [license] = src, so one account can't be on twice

-- ---------------------------------------------------------------------------
-- Database setup: create what we need, so there is no SQL file to run by hand.
-- ---------------------------------------------------------------------------
local USER_COLUMNS = {
    firstname = 'VARCHAR(16) NULL DEFAULT NULL',
    lastname = 'VARCHAR(16) NULL DEFAULT NULL',
    dateofbirth = 'VARCHAR(10) NULL DEFAULT NULL',
    sex = 'VARCHAR(1) NULL DEFAULT NULL',
    height = 'INT NULL DEFAULT NULL',
    skin = 'LONGTEXT NULL DEFAULT NULL',
    disabled = 'TINYINT(1) NULL DEFAULT 0',
}

MySQL.ready(function()
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `multicharacter_slots` (
            `identifier` VARCHAR(60) NOT NULL,
            `slots` INT NOT NULL,
            PRIMARY KEY (`identifier`)
        )
    ]])

    local existing = {}
    for _, row in ipairs(MySQL.query.await([[
        SELECT COLUMN_NAME FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND TABLE_NAME = 'users'
    ]]) or {}) do
        existing[row.COLUMN_NAME] = true
    end
    for column, definition in pairs(USER_COLUMNS) do
        if not existing[column] then
            MySQL.query.await(('ALTER TABLE `users` ADD COLUMN `%s` %s'):format(column, definition))
            print(('[^2esx_multicharacter^7] Added users.%s'):format(column))
        end
    end

    -- Find every identifier/owner column so deleting a character removes all of its data,
    -- and widen any that are too short for "char1:license...".
    for _, row in ipairs(MySQL.query.await([[
        SELECT TABLE_NAME, COLUMN_NAME, CHARACTER_MAXIMUM_LENGTH FROM INFORMATION_SCHEMA.COLUMNS
        WHERE TABLE_SCHEMA = DATABASE() AND DATA_TYPE = 'varchar' AND COLUMN_NAME IN ('identifier', 'owner')
    ]]) or {}) do
        if row.TABLE_NAME ~= 'multicharacter_slots' then
            identifierTables[row.TABLE_NAME] = row.COLUMN_NAME
            if (row.CHARACTER_MAXIMUM_LENGTH or 0) < ID_LENGTH then
                MySQL.query.await(('ALTER TABLE `%s` MODIFY COLUMN `%s` VARCHAR(%d)')
                    :format(row.TABLE_NAME, row.COLUMN_NAME, ID_LENGTH))
                print(('[^2esx_multicharacter^7] Widened %s.%s to VARCHAR(%d)'):format(row.TABLE_NAME, row.COLUMN_NAME, ID_LENGTH))
            end
        end
    end

    dbReady = true
end)

local function charIdentifier(slot, license)
    return ('%s%d:%s'):format(PREFIX, slot, license)
end

local function getSlots(license)
    return tonumber(MySQL.scalar.await('SELECT slots FROM multicharacter_slots WHERE identifier = ?', { license }))
        or Config.Slots
end

local function jobLabels(jobName, grade)
    local jobs = ESX.GetJobs() or {}
    local job = jobs[jobName]
    if not job then return jobName or 'Unemployed', '' end
    local gradeInfo = job.grades and job.grades[tostring(grade)]
    return job.label, (jobName ~= 'unemployed' and gradeInfo and gradeInfo.label) or ''
end

local function loadCharacters(license, slots)
    local ids = {}
    for i = 1, slots do ids[i] = charIdentifier(i, license) end

    local rows = MySQL.query.await(([[
        SELECT identifier, accounts, job, job_grade, firstname, lastname, dateofbirth, sex, height, skin, disabled
        FROM users WHERE identifier IN (%s)
    ]]):format(('?,'):rep(#ids):sub(1, -2)), ids) or {}

    local characters = {}
    for _, row in ipairs(rows) do
        local slot = tonumber(row.identifier:match('^' .. PREFIX .. '(%d+):'))
        if slot then
            local accounts = json.decode(row.accounts or '{}') or {}
            local job, grade = jobLabels(row.job, row.job_grade)
            characters[slot] = {
                slot = slot,
                firstname = row.firstname or 'Unknown',
                lastname = row.lastname or '',
                dateofbirth = row.dateofbirth or '',
                sex = row.sex == 'f' and 'f' or 'm',
                height = row.height,
                job = job,
                grade = grade,
                money = accounts.money or 0,
                bank = accounts.bank or 0,
                skin = row.skin and json.decode(row.skin) or false,
                disabled = row.disabled == 1 or row.disabled == true,
            }
        end
    end
    return characters
end

local function setup(src)
    while not dbReady do Wait(100) end
    local license = ESX.GetIdentifier(src)
    if not license then return DropPlayer(src, 'Could not read your license identifier.') end

    online[license] = src
    SetPlayerRoutingBucket(src, src) -- alone while choosing, so nobody sees the preview ped
    local slots = math.max(1, math.floor(getSlots(license)))
    local characters = loadCharacters(license, slots)
    sessions[src] = { license = license, slots = slots, characters = characters }

    -- Arrays travel better than sparse tables, so send a list.
    local list = {}
    for _, c in pairs(characters) do list[#list + 1] = c end
    TriggerClientEvent('motion_multichar:open', src, list, slots, Config.CanDelete)
end

local function validSlot(src, slot)
    local session = sessions[src]
    slot = tonumber(slot)
    if not session or not slot or slot < 1 or slot > session.slots or slot ~= math.floor(slot) then return nil end
    if session.license ~= ESX.GetIdentifier(src) then return nil end
    return slot, session
end

local function enterGame(src, slot, newData)
    sessions[src] = nil
    SetPlayerRoutingBucket(src, 0)
    TriggerEvent('esx:onPlayerJoined', src, PREFIX .. slot, newData)
end

-- ---------------------------------------------------------------------------
-- Character creation checks (never trust the client)
-- ---------------------------------------------------------------------------
local function cleanName(name)
    if type(name) ~= 'string' then return nil end
    name = name:gsub('^%s+', ''):gsub('%s+$', ''):gsub('%s+', ' ')
    local id = Config.Identity
    if #name < id.minNameLength or #name > id.maxNameLength then return nil end
    if not name:match("^[%a][%a%s%-']*$") then return nil end
    return name:sub(1, 1):upper() .. name:sub(2)
end

local function parseDate(value)
    if type(value) ~= 'string' then return nil end
    local y, m, d = value:match('^(%d%d%d%d)%-(%d%d)%-(%d%d)$')
    y, m, d = tonumber(y), tonumber(m), tonumber(d)
    if not y or m < 1 or m > 12 or d < 1 or d > 31 then return nil end
    local now = os.date('*t')
    local age = now.year - y - ((now.month < m or (now.month == m and now.day < d)) and 1 or 0)
    if age < Config.Identity.minAge or age > Config.Identity.maxAge then return nil end
    local fmt = Config.Identity.dateFormat
    return (fmt:gsub('YYYY', ('%04d'):format(y)):gsub('MM', ('%02d'):format(m)):gsub('DD', ('%02d'):format(d)))
end

local function validateNewCharacter(data)
    if type(data) ~= 'table' then return nil, 'Invalid form.' end
    local id = Config.Identity
    local firstname, lastname = cleanName(data.firstname), cleanName(data.lastname)
    if not firstname or not lastname then
        return nil, ('Names must be %d-%d letters.'):format(id.minNameLength, id.maxNameLength)
    end
    local dob = parseDate(data.dateofbirth)
    if not dob then return nil, ('Your character must be %d-%d years old.'):format(id.minAge, id.maxAge) end
    local height = tonumber(data.height)
    if not height or height < id.minHeight or height > id.maxHeight then
        return nil, ('Height must be %d-%d cm.'):format(id.minHeight, id.maxHeight)
    end
    local sex = data.sex == 'f' and 'f' or (data.sex == 'm' and 'm' or nil)
    if not sex then return nil, 'Pick a sex.' end
    return { firstname = firstname, lastname = lastname, dateofbirth = dob, sex = sex, height = math.floor(height) }
end

-- ---------------------------------------------------------------------------
-- Events
-- ---------------------------------------------------------------------------
RegisterNetEvent('motion_multichar:setup', function()
    setup(source)
end)

RegisterNetEvent('motion_multichar:choose', function(slot)
    local src = source
    local s, session = validSlot(src, slot)
    if not s then return end
    local character = session.characters[s]
    if not character then return end
    if character.disabled then
        return TriggerClientEvent('motion_multichar:error', src, 'This character has been disabled by staff.')
    end
    if ESX.GetPlayerFromIdentifier(charIdentifier(s, session.license)) then
        return DropPlayer(src, 'That character is already on the server.')
    end
    enterGame(src, s)
end)

RegisterNetEvent('motion_multichar:create', function(slot, data)
    local src = source
    local s, session = validSlot(src, slot)
    if not s then return end
    if session.characters[s] then
        return TriggerClientEvent('motion_multichar:error', src, 'That slot is already used.')
    end
    local character, err = validateNewCharacter(data)
    if not character then
        return TriggerClientEvent('motion_multichar:error', src, err)
    end
    if MySQL.scalar.await('SELECT 1 FROM users WHERE identifier = ?', { charIdentifier(s, session.license) }) then
        return TriggerClientEvent('motion_multichar:error', src, 'That slot is already used.')
    end
    enterGame(src, s, character)
end)

RegisterNetEvent('motion_multichar:delete', function(slot)
    local src = source
    if not Config.CanDelete then return end
    local s, session = validSlot(src, slot)
    if not s or not session.characters[s] then return end

    local identifier = charIdentifier(s, session.license)
    local queries = {}
    for tableName, column in pairs(identifierTables) do
        queries[#queries + 1] = { query = ('DELETE FROM `%s` WHERE `%s` = ?'):format(tableName, column), values = { identifier } }
    end
    if MySQL.transaction.await(queries) then
        print(('[^2esx_multicharacter^7] %s deleted %s'):format(GetPlayerName(src), identifier))
    else
        print(('[^1esx_multicharacter^7] Failed to delete %s'):format(identifier))
    end
    setup(src)
end)

RegisterNetEvent('motion_multichar:relog', function()
    if Config.Relog then TriggerEvent('esx:playerLogout', source) end
end)

-- One session per account.
AddEventHandler('playerConnecting', function(_, _, deferrals)
    local src = source
    deferrals.defer()
    Wait(0)
    local ok, license = pcall(ESX.GetIdentifier, src)
    if not ok or not license then return deferrals.done('Could not read your license identifier.') end
    local other = online[license]
    if other and GetPlayerPing(other) > 0 and not ESX.GetConfig().EnableDebug then
        return deferrals.done('This account is already connected to the server.')
    end
    deferrals.done()
end)

AddEventHandler('playerDropped', function()
    local src = source
    sessions[src] = nil
    for license, id in pairs(online) do
        if id == src then online[license] = nil end
    end
end)

-- ---------------------------------------------------------------------------
-- Admin commands
-- ---------------------------------------------------------------------------
ESX.RegisterCommand('setslots', 'admin', function(xPlayer, args)
    MySQL.insert('INSERT INTO multicharacter_slots (identifier, slots) VALUES (?, ?) ON DUPLICATE KEY UPDATE slots = VALUES(slots)',
        { args.identifier, args.slots })
    if xPlayer then xPlayer.showNotification(('%s now has %d slots.'):format(args.identifier, args.slots)) end
end, true, { help = 'Set how many character slots a license gets', validate = true, arguments = {
    { name = 'identifier', help = 'license without "license:"', type = 'string' },
    { name = 'slots', help = 'number of slots', type = 'number' },
} })

ESX.RegisterCommand('remslots', 'admin', function(xPlayer, args)
    MySQL.update('DELETE FROM multicharacter_slots WHERE identifier = ?', { args.identifier })
    if xPlayer then xPlayer.showNotification(('%s is back to the default slots.'):format(args.identifier)) end
end, true, { help = 'Reset a license to the default slot count', validate = true, arguments = {
    { name = 'identifier', help = 'license without "license:"', type = 'string' },
} })

local function setDisabled(xPlayer, args, value)
    local changed = MySQL.update.await('UPDATE users SET disabled = ? WHERE identifier = ?',
        { value, charIdentifier(args.slot, args.identifier) })
    if xPlayer then
        xPlayer.showNotification(changed > 0 and ('Character %d %s.'):format(args.slot, value == 1 and 'disabled' or 'enabled')
            or 'Character not found.')
    end
end

ESX.RegisterCommand('disablechar', 'admin', function(xPlayer, args) setDisabled(xPlayer, args, 1) end, true, {
    help = 'Lock a character', validate = true, arguments = {
        { name = 'identifier', help = 'license without "license:"', type = 'string' },
        { name = 'slot', help = 'character slot', type = 'number' },
    } })

ESX.RegisterCommand('enablechar', 'admin', function(xPlayer, args) setDisabled(xPlayer, args, 0) end, true, {
    help = 'Unlock a character', validate = true, arguments = {
        { name = 'identifier', help = 'license without "license:"', type = 'string' },
        { name = 'slot', help = 'character slot', type = 'number' },
    } })
