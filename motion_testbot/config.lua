Config = {}

-- Everything runs through one admin command. Allow it with:
--   add_ace group.admin command.bot allow
Config.Command = 'bot'

Config.Freecam = {
    fov = 50.0,
    minFov = 10.0,
    maxFov = 110.0,
    speed = 12.0,        -- metres per second
    fastMultiplier = 6.0, -- hold SHIFT
    slowMultiplier = 0.2, -- hold CTRL
    sensitivity = 6.0,
}

-- Screenshots need the screenshot-basic resource running.
-- Files are saved on the server in motion_testbot/screenshots/.
Config.Screenshots = {
    folder = 'screenshots',
    encoding = 'jpg',
    quality = 0.95,
    settleTime = 1500, -- ms to wait after moving the camera before a tour shot
}

-- Spots used by "/bot tour". cam = where the camera sits, look = what it points at.
-- hour is optional (local time override while the photo is taken).
-- Fly the free cam somewhere and run "/bot spot <name>" to print a new line for this list.
Config.PhotoSpots = {
    { name = 'legion_square', cam = vec3(120.0, -1010.0, 110.0),  look = vec3(195.0, -934.0, 30.0) },
    { name = 'downtown',      cam = vec3(-500.0, -1100.0, 120.0), look = vec3(-75.0, -818.0, 200.0), hour = 19 },
    { name = 'vinewood_sign', cam = vec3(650.0, 1000.0, 380.0),   look = vec3(711.0, 1198.0, 348.0), hour = 9 },
    { name = 'del_perro',     cam = vec3(-1800.0, -1300.0, 80.0), look = vec3(-1663.0, -1126.0, 13.0), hour = 18 },
    { name = 'mirror_park',   cam = vec3(950.0, -800.0, 120.0),   look = vec3(1100.0, -650.0, 57.0) },
    { name = 'lsia',          cam = vec3(-900.0, -2950.0, 120.0), look = vec3(-1037.0, -2737.0, 14.0) },
    { name = 'port',          cam = vec3(800.0, -3300.0, 120.0),  look = vec3(1000.0, -3000.0, 6.0) },
    { name = 'sandy_shores',  cam = vec3(1700.0, 3500.0, 150.0),  look = vec3(1850.0, 3700.0, 33.0) },
    { name = 'paleto_bay',    cam = vec3(-350.0, 6150.0, 120.0),  look = vec3(-150.0, 6350.0, 31.0) },
    { name = 'chiliad',       cam = vec3(501.0, 5604.0, 810.0),   look = vec3(200.0, 0.0, 100.0), hour = 7 },
}

Config.Bot = {
    defaultModel = 'a_m_y_business_02',
    maxBots = 10,
    invincible = true,        -- bots can't die unless you run "/bot kill"
    defaultWeapon = 'WEAPON_PISTOL', -- used by rob / aim / shoot / attack if the bot is unarmed
    nearbyRadius = 25.0,      -- how far "ped" / "vehicle" targets search
    blip = true,
}
