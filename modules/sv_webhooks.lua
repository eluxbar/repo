local webhooks = {
    ["coinflip-bet"] = "https://discord.com/api/webhooks/xxx/yyyy"
}


function vRP.sendWebhook(hook_name, name, message)
    PerformHttpRequest(webhooks[hook_name], function(err, text, headers) 
    end, "POST", json.encode({username = "vRP Logs", embeds = {
        {
            ["color"] = 0xd16feb,
            ["title"] = name,
            ["description"] = message,
            ["footer"] = {
                ["text"] = "ARMA - "..os.date("%c"),
                ["icon_url"] = "",
            }
    }
    }}), { ["Content-Type"] = "application/json" })
end