fx_version 'cerulean'
game 'gta5'
lua54 'yes'

-- Motion Multicharacter. Keep the folder named esx_multicharacter:
-- es_extended only turns on multicharacter mode when a resource with that name exists.
name 'esx_multicharacter'
author 'Motion'
description 'Motion Multicharacter - character select and creation for ESX Legacy + illenium-appearance'
version '1.0.0'

dependencies { 'es_extended', 'oxmysql', 'illenium-appearance' }

shared_scripts {
    '@es_extended/imports.lua',
    'config.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua',
}

client_script 'client/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/logo.png',
}
