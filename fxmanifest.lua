fx_version 'cerulean'

game 'gta5'

lua54 'yes'

author 'JACK'
description 'FiveM rich NUI chat for ESX/QBCore with ox_inventory metadata, ck_realplate, dynamic frames, red packets and channels. QQ: 2518926462'
version '1.0.0'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/test.html',
    'html/index.css',
    'html/app.js',
    'html/txk/*',
    'html/ltk/*',
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
