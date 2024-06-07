PlayerLoaded, PlayerData = nil, {}
Bridge = {}

-- Get framework
if GetResourceState('es_extended') == 'started' then
    ESX = exports['es_extended']:getSharedObject()
    Framework = 'esx'

    RegisterNetEvent('esx:playerLoaded', function(xPlayer)
        PlayerData = xPlayer
        PlayerLoaded = true
        TriggerEvent('zf-groups:onPlayerLoaded')
    end)

    RegisterNetEvent('esx:onPlayerLogout', function()
        table.wipe(PlayerData)
        PlayerLoaded = false
    end)

    AddEventHandler('onResourceStart', function(resourceName)
        if GetCurrentResourceName() ~= resourceName or not ESX.PlayerLoaded then return end
        PlayerData = ESX.GetPlayerData()
        PlayerLoaded = true
        TriggerEvent('zf-groups:onPlayerLoaded')
    end)

elseif GetResourceState('qb-core') == 'started' then
    QBCore = exports['qb-core']:GetCoreObject()
    Framework = 'qb'

    AddStateBagChangeHandler('isLoggedIn', '', function(_bagName, _key, value, _reserved, _replicated)
        if value then
            PlayerData = QBCore.Functions.GetPlayerData()
        else
            table.wipe(PlayerData)
        end
        PlayerLoaded = value
    end)

    RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
        TriggerEvent('zf-groups:onPlayerLoaded')
    end)

    AddEventHandler('onResourceStart', function(resourceName)
        if GetCurrentResourceName() ~= resourceName or not LocalPlayer.state.isLoggedIn then return end
        PlayerData = QBCore.Functions.GetPlayerData()
        PlayerLoaded = true
        TriggerEvent('zf-groups:onPlayerLoaded')
    end)
else
    -- Add support for a custom framework here
end

-- Function used to get latest player data
Bridge.GetPlayerData = function()
    if Framework == 'esx' then
        return ESX.GetPlayerData()
    elseif Framework == 'qb' then
        return QBCore.Functions.GetPlayerData()
    else
        -- Add support for a custom framework here
    end
end

-- Function to return nearby players
--- @param coords vector3 | vector4
Bridge.GetNearbyPlayers = function(coords)
    if Framework == 'esx' then
        return ESX.Game.GetPlayersInArea(coords, 400)
    elseif Framework == 'qb' then
        return QBCore.Functions.GetPlayersFromCoords(coords, 400)
    else
        -- Add support for a custom framework here
    end
end

-- Function the get the time difference between to given values
--- @param time1 number
--- @param time2 number
--- @return minutes number
Bridge.TimeAgo = function(time1, time2)
    return math.floor((time2 - time1) / 60)
end

-- Function to get a local player identifier
Bridge.GetIdentifier = function()
    local PlayerData = Bridge.GetPlayerData()
    if not PlayerData then return end
    if Framework == 'esx' then
        return PlayerData.identifier
    elseif Framework == 'qb' then
        return PlayerData.citizenid
    else
        -- Add support for custom framework here
    end
end

Bridge.Round = function(float, numDecimalPlaces)
    local mult = 10^(numDecimalPlaces or 0)
    return math.floor(float * mult + 0.5) / mult
end

Bridge.OpenInventory = function(id, slots, weight)
    local ox_inv = GetResourceState('ox_inventory') == 'started'
    if ox_inv then
        TriggerServerEvent('zf-foodplaza:bridge:registerInventory', id, slots, weight)
        exports.ox_inventory:openInventory('stash', {id = id})
   end
end

return Bridge