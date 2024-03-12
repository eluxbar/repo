local coinflipTables = {
    [1] = false,
    [2] = false,
    [5] = false,
    [6] = false,
}

local linkedTables = {
    [1] = 2,
    [2] = 1,
    [5] = 6,
    [6] = 5,
}

local coinflipGameInProgress = {}
local coinflipGameData = {}

local betId = 0

local MySQL = module("modules/MySQL")
MySQL.createCommand("casinochips/add_id_chips", "INSERT IGNORE INTO vrp_chips SET user_id = @user_id")
MySQL.createCommand("casinochips/get_chips","SELECT * FROM vrp_chips WHERE user_id = @user_id")
MySQL.createCommand("casinochips/add_chips", "UPDATE vrp_chips SET chips = (chips + @amount) WHERE user_id = @user_id")
MySQL.createCommand("casinochips/remove_chips", "UPDATE vrp_chips SET chips = CASE WHEN ((chips - @amount)>0) THEN (chips - @amount) ELSE 0 END WHERE user_id = @user_id")


function giveChips(source,amount)
    local user_id = vRP.getUserId(source)
    MySQL.execute("casinochips/add_chips", {user_id = user_id, amount = amount})
    TriggerClientEvent('Coinflip:chipsUpdated', source)
end

AddEventHandler('playerDropped', function (reason)
    local source = source
    for k,v in pairs(coinflipTables) do
        if v == source then
            coinflipTables[k] = false
            coinflipGameData[k] = nil
        end
    end
end)

RegisterNetEvent("Coinflip:requestCoinflipTableData")
AddEventHandler("Coinflip:requestCoinflipTableData", function()   
    local source = source
    TriggerClientEvent("Coinflip:sendCoinflipTableData",source,coinflipTables)
end)

RegisterNetEvent("Coinflip:requestSitAtCoinflipTable")
AddEventHandler("Coinflip:requestSitAtCoinflipTable", function(chairId)
    local source = source
    if source ~= nil then
        for k,v in pairs(coinflipTables) do
            if v == source then
                coinflipTables[k] = false
                return
            end
        end
        coinflipTables[chairId] = source
        local currentBetForThatTable = coinflipGameData[chairId]
        TriggerClientEvent("Coinflip:sendCoinflipTableData",-1,coinflipTables)
        TriggerClientEvent("Coinflip:sitAtCoinflipTable",source,chairId,currentBetForThatTable)
    end
end)

RegisterNetEvent("Coinflip:leaveCoinflipTable")
AddEventHandler("Coinflip:leaveCoinflipTable", function(chairId)
    local source = source
    if source ~= nil then 
        for k,v in pairs(coinflipTables) do 
            if v == source then 
                coinflipTables[k] = false
                coinflipGameData[k] = nil
            end
        end
        TriggerClientEvent("Coinflip:sendCoinflipTableData",-1,coinflipTables)
    end
end)

RegisterNetEvent("Coinflip:proposeCoinflip")
AddEventHandler("Coinflip:proposeCoinflip",function(betAmount)
    local source = source
    local user_id = vRP.getUserId(source)
    betId = betId+1
    if betAmount ~= nil then 
        if coinflipGameData[betId] == nil then
            coinflipGameData[betId] = {}
        end
        if not coinflipGameInProgress[betId] then
            if tonumber(betAmount) then
                betAmount = tonumber(betAmount)
                if betAmount >= 100000 then
                    MySQL.query("casinochips/get_chips", {user_id = user_id}, function(rows, affected)
                        chips = rows[1].chips
                        if chips >= betAmount then
                            TriggerClientEvent('Coinflip:chipsUpdated', source)
                            if coinflipGameData[betId][source] == nil then
                                coinflipGameData[betId][source] = {}
                            end
                            coinflipGameData[betId] = {betId = betId, betAmount = betAmount, user_id = user_id}
                            for k,v in pairs(coinflipTables) do
                                if v == source then
                                    TriggerClientEvent('Coinflip:addCoinflipProposal', source, betId, {betId = betId, betAmount = betAmount, user_id = user_id})
                                    if coinflipTables[linkedTables[k]] then
                                        TriggerClientEvent('Coinflip:addCoinflipProposal', coinflipTables[linkedTables[k]], betId, {betId = betId, betAmount = betAmount, user_id = user_id})
                                    end
                                end
                            end
                            vRPclient.notify(source,{"~g~Bet placed: " .. getMoneyStringFormatted(betAmount) .. " chips."})
                        else 
                            vRPclient.notify(source,{"Not enough chips!"})
                        end
                    end)
                else
                    vRPclient.notify(source,{'Minimum bet at this table is £100,000.'})
                    return
                end
            end
        end
    else
       vRPclient.notify(source,{"Error betting!"})
    end
end)

RegisterNetEvent("Coinflip:requestCoinflipTableData")
AddEventHandler("Coinflip:requestCoinflipTableData", function()   
    local source = source
    TriggerClientEvent("Coinflip:sendCoinflipTableData",source,coinflipTables)
end)

RegisterNetEvent("Coinflip:cancelCoinflip")
AddEventHandler("Coinflip:cancelCoinflip", function()   
    local source = source
    local user_id = vRP.getUserId(source)
    for k,v in pairs(coinflipGameData) do
        if v.user_id == user_id then
            coinflipGameData[k] = nil
            TriggerClientEvent("Coinflip:cancelCoinflipBet",-1,k)
        end
    end
end)

RegisterNetEvent("Coinflip:acceptCoinflip")
AddEventHandler("Coinflip:acceptCoinflip", function(gameid)   
    local source = source
    local user_id = vRP.getUserId(source)
    for k,v in pairs(coinflipGameData) do
        if v.betId == gameid then
            MySQL.query("casinochips/get_chips", {user_id = user_id}, function(rows, affected)
                chips = rows[1].chips
                if chips >= v.betAmount then
                    MySQL.execute("casinochips/remove_chips", {user_id = user_id, amount = v.betAmount})
                    TriggerClientEvent('Coinflip:chipsUpdated', source)
                    MySQL.execute("casinochips/remove_chips", {user_id = v.user_id, amount = v.betAmount})
                    TriggerClientEvent('Coinflip:chipsUpdated', vRP.getUserSource(v.user_id))
                    local coinFlipOutcome = math.random(0,1)
                    if coinFlipOutcome == 0 then
                        local game = {amount = v.betAmount, winner = vRP.getPlayerName(source), loser = vRP.getPlayerName(vRP.getUserSource(v.user_id))}
                        TriggerClientEvent('Coinflip:coinflipOutcome', source, true, game)
                        TriggerClientEvent('Coinflip:coinflipOutcome', vRP.getUserSource(v.user_id), false, game)
                        Wait(10000)
                        MySQL.execute("casinochips/add_chips", {user_id = user_id, amount = v.betAmount*2})
                        TriggerClientEvent('Coinflip:chipsUpdated', source)
                        if v.betAmount > 10000000 then
                            TriggerClientEvent('chatMessage', -1, "^7Coin Flip |", { 124, 252, 0 }, ""..vRP.getPlayerName(source).." has WON a coin flip against "..vRP.getPlayerName(vRP.getUserSource(v.user_id)).." for "..getMoneyStringFormatted(v.betAmount).." chips!")
                        end
                        vRP.sendWebhook('coinflip-bet',"vRP Coinflip Logs", "> Winner Name: **"..vRP.getPlayerName(source).."**\n> Winner TempID: **"..source.."**\n> Winner PermID: **"..user_id.."**\n> Loser Name: **"..vRP.getPlayerName(vRP.getUserSource(v.user_id)).."**\n> Loser TempID: **"..vRP.getUserSource(v.user_id).."**\n> Loser PermID: **"..v.user_id.."**\n> Amount: **"..getMoneyStringFormatted(v.betAmount).."**")
                    else
                        local game = {amount = v.betAmount, winner = vRP.getPlayerName(vRP.getUserSource(v.user_id)), loser = vRP.getPlayerName(source)}
                        TriggerClientEvent('Coinflip:coinflipOutcome', source, false, game)
                        TriggerClientEvent('Coinflip:coinflipOutcome', vRP.getUserSource(v.user_id), true, game)
                        Wait(10000)
                        MySQL.execute("casinochips/add_chips", {user_id = v.user_id, amount = v.betAmount*2})
                        TriggerClientEvent('Coinflip:chipsUpdated', vRP.getUserSource(v.user_id))
                        if v.betAmount > 10000000 then
                            TriggerClientEvent('chatMessage', -1, "^7Coin Flip |", { 124, 252, 0 }, ""..vRP.getPlayerName(source).." has WON a coin flip against "..vRP.getPlayerName(vRP.getUserSource(v.user_id)).." for "..getMoneyStringFormatted(v.betAmount).." chips!")
                        end
                        vRP.sendWebhook('coinflip-bet',"vRP Coinflip Logs", "> Winner Name: **"..vRP.getPlayerName(vRP.getUserSource(v.user_id)).."**\n> Winner TempID: **"..vRP.getUserSource(v.user_id).."**\n> Winner PermID: **"..v.user_id.."**\n> Loser Name: **"..vRP.getPlayerName(source).."**\n> Loser TempID: **"..source.."**\n> Loser PermID: **"..user_id.."**\n> Amount: **"..getMoneyStringFormatted(v.betAmount).."**")
                    end
                else 
                    vRPclient.notify(source,{"Not enough chips!"})
                end
            end)
        end
    end
end)

RegisterCommand('tables', function(source)
    print(json.encode(coinflipTables))
end)