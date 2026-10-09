fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'motion_testbot'
description 'Admin free cam + task-driven test bot peds for testing scripts live'
version '1.0.0'

shared_script 'config.lua'

client_scripts {
    'client/util.lua',
    'client/freecam.lua',
    'client/photo.lua',
    'client/outfit.lua',
    'client/bot.lua',
    'client/tasks.lua',
    'client/menu.lua',
    'client/main.lua',
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/peds.js',
}

server_script 'server/main.lua'
