local ox_inv = GetResourceState('ox_inventory') == 'started'
Bridge = {}

-- Get framework
if GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
    Framework = 'esx'
elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    Framework = 'qb'
else
    -- Add support for a custom framework here
    return
end

-- Get player from source
Bridge.GetPlayer = function(source)
    if not source then return end
    if Framework == 'esx' then
        return ESX.GetPlayerFromId(source)
    elseif Framework == 'qb' then
        return QBCore.Functions.GetPlayer(source)
    else
        -- Add support for a custom framework here
    end
end

-- Function to get a player identifier by source
Bridge.GetIdentifier = function(source)
    local player = Bridge.GetPlayer(source)
    if not player then return end
    if Framework == 'esx' then
        return player.getIdentifier()
    elseif Framework == 'qb' then
        return player.PlayerData.citizenid
    else
        -- Add support for custom framework here
    end
end

-- Function to get a players name
Bridge.GetName = function(source)
    local player = Bridge.GetPlayer(source)
    if not player then return end
    if Framework == 'esx' then
        return player.getName()
    elseif Framework == 'qb' then
        return player.PlayerData.charinfo.firstname..' '..player.PlayerData.charinfo.lastname
    end
end

-- Function to return the specific amount of an item
Bridge.ItemCount = function(source, item)
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end
    if ox_inv then
        local count = exports.ox_inventory:Search(source, 'count', item)
        return count
    else
        if Framework == 'esx' then
            local item = player.getInventoryItem(item)
            if item ~= nil then
                return item.count
            else
                return 0
            end
        elseif Framework == 'qb' then
            local item = player.Functions.GetItemByName(item)
            if item ~= nil then
                return item.amount
            else
                return 0
            end
        else
            -- Add support for a custom framework here
        end
    end
end

-- Function to add an item to inventory
Bridge.AddItem = function(source, item, count, slot, metadata)
    if count <= 0 then return end
    local player = Bridge.GetPlayer(source)
    if not player then return end
    if ox_inv then
        exports.ox_inventory:AddItem(source, item, count, metadata, slot)
    else
        if Framework == 'esx' then
            player.addInventoryItem(item, count, metadata, slot)
        elseif Framework == 'qb' then
            if item == 'cash' or item == 'money' then
                Bridge.AddMoney(source, item, count)
                return
            end
            if item == 'markedbills' then
                if Config.Metadata then
                    local info = {worth = count}
                    player.Functions.AddItem(item, 1, false, info)
                    return
                end
            end
            player.Functions.AddItem(item, count, slot, metadata)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], 'add')
        else
            -- Add support for a custom framework here
        end
    end
end

-- Function to remove an item from inventory
Bridge.RemoveItem = function(source, item, count, slot, metadata)
    local player = Bridge.GetPlayer(source)
    if not player then return end
    if ox_inv then
        exports.ox_inventory:RemoveItem(source, item, count, metadata, slot)
    else
        if Framework == 'esx' then
            player.removeInventoryItem(item, count, metadata, slot)
        elseif Framework == 'qb' then
            player.Functions.RemoveItem(item, count, slot, metadata)
            TriggerClientEvent('inventory:client:ItemBox', source, QBCore.Shared.Items[item], "remove")
        else
            -- Add support for a custom framework here
        end
    end
end

-- Function to convert moneyType to match framework
ConvertMoneyType = function(moneyType)
    if moneyType == 'money' and Framework == 'qb' then
        moneyType = 'cash'
    elseif moneyType == 'cash' and Framework == 'esx' then
        moneyType = 'money'
    else
        -- Add support for a custom framework here
    end
    return moneyType
end

-- Function to add money to a players account
Bridge.AddMoney = function(source, moneyType, amount)
    local player = Bridge.GetPlayer(source)
    if not player then return end
    moneyType = ConvertMoneyType(moneyType)
    if Framework == 'esx' then
        player.addAccountMoney(moneyType, amount)
    elseif Framework == 'qb' then
        if moneyType == 'markedbills' and Config.Metadata then
            local info = {worth = amount}
            player.Functions.AddItem(moneyType, 1, false, info)
            return
        elseif moneyType == 'markedbills' and not Config.Metadata then
            player.Functions.AddItem(moneyType, amount)
            return
        end
        player.Functions.AddMoney(moneyType, amount)
    else
        -- Add support for a custom framework here
    end
end

-- Function to remove money from a players account
Bridge.RemoveMoney = function(source, moneyType, amount)
    local player = Bridge.GetPlayer(source)
    if not player then return end
    moneyType = ConvertMoneyType(moneyType)
    if Framework == 'esx' then
        player.removeAccountMoney(moneyType, amount)
    elseif Framework == 'qb' then
        player.Functions.RemoveMoney(moneyType, amount)
    else
        -- Add support for a custom framework here
    end
end

-- Function used to get players account balance
Bridge.GetPlayerAccountFunds = function(source, moneyType)
    local player = Bridge.GetPlayer(source)
    if not player then return 0 end
    moneyType = ConvertMoneyType(moneyType)
    if Framework == 'qb' then
        return player.PlayerData.money[moneyType]
    elseif Framework == 'esx' then
        return player.getAccount(moneyType).money
    else
        -- Add support for a custom framework here
    end
end

-- Function to register a usable item
Bridge.RegisterUsableItem = function(item, ...)
    if Framework == 'esx' then
        ESX.RegisterUsableItem(item, ...)
    elseif Framework == 'qb' then
        QBCore.Functions.CreateUseableItem(item, ...)
    else
        -- Add support for a custom framework here
    end
end

Bridge.RegisterStash = function(id, slots, weight)
    local ox_inv = GetResourceState('ox_inventory') == 'started'
    if ox_inv then exports.ox_inventory:RegisterStash(id, 'Storage', slots or 50, weight or 1000000) end
end

Bridge.CheckMetadatas = function(metadatas)
    lib.versionCheck(metadatas.repo)
    for _,dependency in pairs(metadatas.dependencies) do
        if not lib.checkDependency(dependency.resource, dependency.version) then
            lib.print.error(('Missing dependency `%s` with minimum version `%s`'):format(dependency.resource, dependency.version))
        end
    end
end

return Bridge