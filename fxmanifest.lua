fx_version 'cerulean'
games { 'gta5' }

client_scripts {
    "client/cl_casinocoinflip.lua",
}

server_scripts {
    "@vrp/lib/utils.lua",
    "modules/sv_casinocoinflip.lua",
    "modules/sv_webhooks.lua",
}