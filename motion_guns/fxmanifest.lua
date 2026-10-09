fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'motion_guns'
description 'Motion Guns - mega add-on weapon pack'
version '1.0.0'

shared_scripts {
    'config.lua',
    'shared/weapons.lua',
}

client_script 'client/main.lua'
server_script 'server/main.lua'

files {
    'meta/weapons.meta',
    'meta/weaponarchetypes.meta',
    'meta/weaponanimations.meta',
    'meta/pedpersonality.meta',
}

data_file 'WEAPONINFO_FILE' 'meta/weapons.meta'
data_file 'WEAPON_METADATA_FILE' 'meta/weaponarchetypes.meta'
data_file 'WEAPON_ANIMATIONS_FILE' 'meta/weaponanimations.meta'
data_file 'PED_PERSONALITY_FILE' 'meta/pedpersonality.meta'
