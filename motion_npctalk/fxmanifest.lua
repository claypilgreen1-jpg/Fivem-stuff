fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'motion_npctalk'
description 'Talk to any NPC in the city with your voice and get an in-character reply'
version '1.0.0'

shared_script 'config.lua'
client_script 'client/main.lua'
server_scripts {
    'server/personas.lua',
    'server/main.lua',
    'server/stt.js',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/voice.js',
}
