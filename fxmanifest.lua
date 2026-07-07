fx_version 'cerulean'

game 'gta5'

lua54 'yes'

author 'JACK'
description 'ESX/QBCore/OX compatible rich NUI chat for FiveM. QQ: 2518926462'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/test.html',
    'html/index.css',
    'html/app.js',
}

shared_script 'config.lua'

client_scripts {
    'framework/client.lua',
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'framework/server.lua',
    'server.lua',
}
