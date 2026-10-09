Config = {}

Config.Slots = 4             -- character slots per player (give someone more with /setslots)
Config.Prefix = 'char'       -- users.identifier becomes char1:license..., char2:license...
Config.CanDelete = true      -- players can delete their own characters
Config.Relog = true          -- /relog goes back to character select

-- Character creation rules
Config.Identity = {
    minNameLength = 2,
    maxNameLength = 16,
    minAge = 18,
    maxAge = 90,
    minHeight = 140,         -- cm
    maxHeight = 210,
    dateFormat = 'DD/MM/YYYY', -- how dateofbirth is stored; match your esx_identity setting if you used it before
}

-- Where the character-select scene happens. The camera looks at the character standing here.
Config.Scene = {
    ped = vector4(-284.29, 562.46, 172.92, 19.99), -- Vinewood Hills overlook
    camOffset = vector3(0.0, 2.6, 0.55),            -- camera position relative to the character
    lookOffset = vector3(0.0, 0.0, 0.25),           -- where the camera aims, relative to the character
    hour = 19,                                      -- time of day shown behind the menu (nil = real server time)
}

-- New characters spawn here after the clothing creator (nil = es_extended's DefaultSpawns)
Config.NewCharacterSpawn = nil
