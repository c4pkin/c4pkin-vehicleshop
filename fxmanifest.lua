fx_version 'cerulean'
game 'gta5'

author 'c4pkin'
description 'c4pkin Developments | .gg/mtxF3yFCz5'
version '1.0.0'

client_script 'client.lua'

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server.lua'
}

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/styles.css',
    'html/scripts.js',
    'html/imgs/*.jpg',
    'html/imgs/*.png'
}

lua54 'yes'

dependencies {
    'qb-core',
    'oxmysql'
}