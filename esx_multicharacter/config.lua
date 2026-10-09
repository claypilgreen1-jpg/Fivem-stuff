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

-- Where your character stands on the select screen. One is picked at random each time you log in.
-- ped        = where the character stands (x, y, z, heading the character faces)
-- camOffset  = camera position relative to the character's feet (x = right, y = in front, z = up)
-- lookOffset = where the camera aims, relative to the character's feet (1.15 = about chest height)
-- hour / weather = time and weather shown (only on your screen)
-- ipl        = map pieces to load (GTA Online interiors). Fine to leave on if you run bob74_ipl.
-- snapToGround = find the ground under outdoor spots, in case the z is a little off
--
-- To move a scene: stand where you want the character, face the way they should face, put the
-- gameplay camera where you want it, then run /mcscene. It prints a ready-to-paste line in F8.
Config.SceneMode = 'random' -- 'random', or one scene name like 'beach'

Config.Scenes = {
    penthouse = {
        label = 'Eclipse Towers Penthouse',
        ped = vector4(-787.78, 334.92, 215.84, 160.0),
        camOffset = vector3(0.0, 2.6, 1.45),
        lookOffset = vector3(0.0, 0.0, 1.15),
        hour = 22, weather = 'CLEAR',
        ipl = { 'apa_v_mp_h_01_a' },
        interior = true,
    },
    beach = {
        label = 'Vespucci Beach',
        ped = vector4(-1280.0, -1620.0, 4.2, 315.0), -- facing inland, so the ocean and sunset are behind you
        camOffset = vector3(0.0, 2.8, 1.50),
        lookOffset = vector3(0.0, 0.0, 1.20),
        hour = 19, weather = 'EXTRASUNNY',
        snapToGround = true,
    },
    rooftop = {
        label = 'Maze Bank Tower Roof',
        ped = vector4(-75.0, -818.5, 326.2, 160.0),
        camOffset = vector3(0.0, 2.8, 1.60),
        lookOffset = vector3(0.0, 0.0, 1.10),
        hour = 23, weather = 'CLEAR',
        snapToGround = true,
    },
    yacht = {
        label = 'The Yacht',
        ped = vector4(-2043.97, -1031.58, 11.98, 300.0),
        camOffset = vector3(0.0, 2.7, 1.50),
        lookOffset = vector3(0.0, 0.0, 1.15),
        hour = 18, weather = 'EXTRASUNNY',
        ipl = { 'hei_yacht_heist', 'hei_yacht_heist_bar', 'hei_yacht_heist_bedrm', 'hei_yacht_heist_bridge',
            'hei_yacht_heist_enginrm', 'hei_yacht_heist_lounge', 'hei_yacht_heist_lod', 'hei_yacht_heist_slod' },
        snapToGround = true,
    },
}

-- New characters spawn here after the clothing creator (nil = es_extended's DefaultSpawns)
Config.NewCharacterSpawn = nil
