local QBCore = exports['qb-core']:GetCoreObject()

local knownPlayers = {} -- [serverId] = true/false
local playerNames = {} -- [serverId] = name
local playerCitizenids = {} -- [serverId] = citizenid
local hasPendingRequest = false
local requestFromSource = nil
local requestFromName = nil
local showPlayerNames = true

-- Función para dibujar texto 3D
local function DrawText3D(x, y, z, text, r, g, b, a)
    local onScreen, screenX, screenY = GetScreenCoordFromWorldCoord(x, y, z)
    if not onScreen then return end

    SetTextScale(Config.TextScale, Config.TextScale)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(r, g, b, a)
    SetTextDropshadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 150)
    SetTextDropShadow()
    SetTextOutline()
    SetTextCentre(1)

    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(screenX, screenY)
end

-- Verificar si un jugador está en rango
local function IsPlayerInRange(targetPed, maxDistance)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local targetCoords = GetEntityCoords(targetPed)
    return #(coords - targetCoords) <= maxDistance
end

-- Solicitar datos de jugadores al servidor
local function RequestPlayersData()
    local players = GetActivePlayers()
    local playersData = {}

    for _, player in ipairs(players) do
        local serverId = GetPlayerServerId(player)
        if serverId ~= GetPlayerServerId(PlayerId()) then
            table.insert(playersData, {
                serverId = serverId,
                citizenid = playerCitizenids[serverId]
            })
        end
    end

    if #playersData > 0 then
        TriggerServerEvent('ic-names:server:getKnownStatus', playersData)
    end
end

-- Thread principal para mostrar nombres
CreateThread(function()
    while true do
        local sleep = 1000
        local myPed = PlayerPedId()
        local myCoords = GetEntityCoords(myPed)
        local myServerId = GetPlayerServerId(PlayerId())

        for _, player in ipairs(GetActivePlayers()) do
            local serverId = GetPlayerServerId(player)
            if serverId ~= myServerId then
                local ped = GetPlayerPed(player)
                if DoesEntityExist(ped) then
                    local coords = GetEntityCoords(ped)
                    local distance = #(myCoords - coords)

                    if distance <= Config.MaxDistance then
                        sleep = 0

                        if not showPlayerNames then
                            goto continuePlayerLoop
                        end

                        -- Obtener datos del jugador si no los tenemos
                        if not playerNames[serverId] then
                            TriggerServerEvent('ic-names:server:getPlayerData', serverId)
                        end

                        local name = playerNames[serverId] or Config.UnknownText
                        local isKnown = knownPlayers[serverId] or false

                        -- Si no lo conocemos, mostrar "Desconocido"
                        if not isKnown then
                            name = Config.UnknownText
                        end

                        local displayName = '[' .. serverId .. '] ' .. name
                        local r, g, b, a
                        if hasPendingRequest and requestFromSource == serverId then
                            r, g, b, a = Config.PendingColor[1], Config.PendingColor[2], Config.PendingColor[3], Config.PendingColor[4]
                        else
                            r, g, b, a = Config.TextColor[1], Config.TextColor[2], Config.TextColor[3], Config.TextColor[4]
                        end

                        DrawText3D(coords.x, coords.y, coords.z + Config.HeightOffset, displayName, r, g, b, a)
                    end
                    ::continuePlayerLoop::
                end
            end
        end

        Wait(sleep)
    end
end)

-- Thread para teclas de aceptar/rechazar
CreateThread(function()
    while true do
        Wait(0)

        if hasPendingRequest then
            -- Tecla Y para aceptar
            if IsControlJustPressed(0, Config.AcceptKey) then
                TriggerServerEvent('ic-names:server:acceptRequest')
                hasPendingRequest = false
                requestFromSource = nil
                requestFromName = nil
            end

            -- Tecla N para rechazar
            if IsControlJustPressed(0, Config.DeclineKey) then
                TriggerServerEvent('ic-names:server:declineRequest')
                hasPendingRequest = false
                requestFromSource = nil
                requestFromName = nil
            end
        end
    end
end)

-- Comando para ocultar/mostrar nombres e IDs
RegisterCommand(Config.ToggleIdsCommand, function()
    showPlayerNames = not showPlayerNames
    local status = showPlayerNames and 'activados' or 'desactivados'
    QBCore.Functions.Notify('Nombres e IDs ' .. status, 'success')
end, false)

-- Recibir solicitud de conocer
RegisterNetEvent('ic-names:client:meetRequest', function(fromSource, fromName)
    hasPendingRequest = true
    requestFromSource = fromSource
    requestFromName = fromName

    QBCore.Functions.Notify(fromName .. ' quiere conocerte', 'primary', Config.RequestTimeout * 1000)
    QBCore.Functions.Notify('Presiona Y para aceptar o N para rechazar', 'primary', Config.RequestTimeout * 1000)
end)

-- Actualizar estado de conocidos
RegisterNetEvent('ic-names:client:updateKnownStatus', function(status)
    knownPlayers = status
end)

-- Recibir datos de un jugador
RegisterNetEvent('ic-names:client:receivePlayerData', function(serverId, name, citizenid)
    playerNames[serverId] = name
    playerCitizenids[serverId] = citizenid
end)

-- Refrescar nombres después de conocer a alguien
RegisterNetEvent('ic-names:client:refreshNames', function()
    RequestPlayersData()
end)

-- Cargar datos al conectar
RegisterNetEvent('QBCore:Client:OnPlayerLoaded', function()
    RequestPlayersData()
end)

-- Limpiar datos de jugadores desconectados
CreateThread(function()
    while true do
        Wait(5000)

        local activeIds = {}
        for _, player in ipairs(GetActivePlayers()) do
            activeIds[GetPlayerServerId(player)] = true
        end

        for serverId in pairs(playerNames) do
            if not activeIds[serverId] then
                playerNames[serverId] = nil
                playerCitizenids[serverId] = nil
                knownPlayers[serverId] = nil
            end
        end
    end
end)

-- Inicializar al cargar el recurso
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end
    Wait(2000)
    RequestPlayersData()
end)
