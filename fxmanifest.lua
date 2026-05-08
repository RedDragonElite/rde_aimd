--[[
    ██████╗ ██████╗ ███████╗
    ██╔══██╗██╔══██╗██╔════╝
    ██████╔╝██║  ██║█████╗
    ██╔══██╗██║  ██║██╔══╝
    ██║  ██║██████╔╝███████╗
    ╚═╝  ╚═╝╚═════╝ ╚══════╝
    🐉 RedDragonElite | rde_aimd v1.0.5
    AI Medical Department — First Open-Source ox_core Death System
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name        'rde_aimd'
author      'RDE | SerpentsByte | RedDragonElite'
version     '1.0.5'
description 'AI Medical Department — First Open-Source Advanced Death System for ox_core'
url         'https://github.com/RedDragonElite/rde_aimd'

dependencies {
    '/server:7290',
    'oxmysql',
    'ox_lib',
    'ox_core',
    'ox_inventory',
}

-- CRITICAL: ox_lib MUST be first!
shared_script '@ox_lib/init.lua'

shared_scripts {
    '@ox_core/lib/init.lua',
    'config.lua',
}

files {
    'locales/en.lua',
    'locales/de.lua',
}

client_scripts {
    'client.lua',
}

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua',
}

provide 'deathSystem'
