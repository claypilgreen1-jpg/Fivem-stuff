fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'motion_npctalk'
description 'Talk to any NPC in the city and get an in-character reply (Claude API)'
version '1.0.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_scripts {
    'server/personas.lua',
    'server/main.lua',
}
