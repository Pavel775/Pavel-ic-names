local QBCore = exports['qb-core']:GetCoreObject()

-- Tabla para almacenar los conocidos de cada jugador
-- Formato: [citizenid] = { [other_citizenid] = true }
local KnownPlayers = {}

-- Tabla para solicitudes pendientes
-- Formato: [targetSource] = { fromSource, fromCitizenid, fromName, timestamp }
local PendingRequests = {}

-- Cargar conocidos al conectar
RegisterNetEvent('QBCore:Server:PlayerLoaded', function()
    local src = source
    local Player = QBCore.Functions.GetPlayer(src)
    if not Player then return end

    local citizenid = Player.PlayerData.citizenid
    LoadKnownPlayers(citizenid)
end)

-- Cargar conocidos desde archivo
function LoadKnownPlayers(citizenid)
    if KnownPlayers[citizenid] then return end

    local file = LoadResourceFile(GetCurrentResourceName(), 'data/' .. citizenid .. '.json')
    if file and file ~= '' then
        local ok, data = pcall(json.decode, file)
        KnownPlayers[citizenid] = ok and data or {}
    else
        KnownPlayers[citizenid] = {}
    end
end

-- Guardar conocidos a archivo
function SaveKnownPlayers(citizenid)
    if not KnownPlayers[citizenid] then return end

    SaveResourceFile(GetCurrentResourceName(), 'data/' .. citizenid .. '.json', json.encode(KnownPlayers[citizenid]), -1)
end

-- Obtener citizenid de un source
local function GetCitizenidBySource(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        return Player.PlayerData.citizenid
    end
    return nil
end

-- Obtener nombre IC de un source
local function GetICName(src)
    local Player = QBCore.Functions.GetPlayer(src)
    if Player then
        return Player.PlayerData.charinfo.firstname .. ' ' .. Player.PlayerData.charinfo.lastname
    end
    return Config.UnknownText
end

-- Comando para conocer a alguien
RegisterCommand(Config.MeetCommand, function(source, args)
    local src = source
    if not args[1] then
        TriggerClientEvent('QBCore:Notify', src, 'Uso: /' .. Config.MeetCommand .. ' [id]', 'error')
        return
    end

    local targetId = tonumber(args[1])
    if not targetId then
        TriggerClientEvent('QBCore:Notify', src, 'ID inválido', 'error')
        return
    end

    if targetId == src then
        TriggerClientEvent('QBCore:Notify', src, 'No puedes conocerte a ti mismo', 'error')
        return
    end

    local targetPed = GetPlayerPed(targetId)
    if not targetPed then
        TriggerClientEvent('QBCore:Notify', src, 'Jugador no encontrado', 'error')
        return
    end

    local srcCitizenid = GetCitizenidBySource(src)
    local targetCitizenid = GetCitizenidBySource(targetId)

    if not srcCitizenid or not targetCitizenid then
        TriggerClientEvent('QBCore:Notify', src, 'Error al obtener datos del jugador', 'error')
        return
    end

    -- Verificar si ya se conocen
    LoadKnownPlayers(srcCitizenid)
    if KnownPlayers[srcCitizenid][targetCitizenid] then
        TriggerClientEvent('QBCore:Notify', src, 'Ya conoces a esta persona', 'error')
        return
    end

    -- Verificar si ya hay solicitud pendiente
    if PendingRequests[targetId] then
        TriggerClientEvent('QBCore:Notify', src, 'Este jugador ya tiene una solicitud pendiente', 'error')
        return
    end

    local srcName = GetICName(src)
    local targetName = GetICName(targetId)

    -- Crear solicitud pendiente
    PendingRequests[targetId] = {
        fromSource = src,
        fromCitizenid = srcCitizenid,
        fromName = srcName,
        timestamp = os.time()
    }

    TriggerClientEvent('QBCore:Notify', src, 'Solicitud enviada a ' .. targetName, 'success')
    TriggerClientEvent('ic-names:client:meetRequest', targetId, src, srcName)
end, false)

-- Función para aceptar solicitud
local function AcceptRequest(src)
    local request = PendingRequests[src]

    if not request then
        TriggerClientEvent('QBCore:Notify', src, 'No tienes solicitudes pendientes', 'error')
        return
    end

    local srcCitizenid = GetCitizenidBySource(src)
    if not srcCitizenid then return end

    -- Añadir a conocidos mutuamente
    LoadKnownPlayers(srcCitizenid)
    LoadKnownPlayers(request.fromCitizenid)

    KnownPlayers[srcCitizenid][request.fromCitizenid] = true
    KnownPlayers[request.fromCitizenid][srcCitizenid] = true

    SaveKnownPlayers(srcCitizenid)
    SaveKnownPlayers(request.fromCitizenid)

    local srcName = GetICName(src)

    TriggerClientEvent('QBCore:Notify', src, 'Ahora conoces a ' .. request.fromName, 'success')
    TriggerClientEvent('QBCore:Notify', request.fromSource, srcName .. ' ha aceptado tu solicitud', 'success')
    TriggerClientEvent('ic-names:client:refreshNames', src)
    TriggerClientEvent('ic-names:client:refreshNames', request.fromSource)

    PendingRequests[src] = nil
end

-- Función para rechazar solicitud
local function DeclineRequest(src)
    local request = PendingRequests[src]

    if not request then
        TriggerClientEvent('QBCore:Notify', src, 'No tienes solicitudes pendientes', 'error')
        return
    end

    TriggerClientEvent('QBCore:Notify', src, 'Solicitud rechazada', 'primary')
    TriggerClientEvent('QBCore:Notify', request.fromSource, 'Tu solicitud fue rechazada', 'error')

    PendingRequests[src] = nil
end

-- Aceptar solicitud por evento
RegisterNetEvent('ic-names:server:acceptRequest', function()
    AcceptRequest(source)
end)

-- Rechazar solicitud por evento
RegisterNetEvent('ic-names:server:declineRequest', function()
    DeclineRequest(source)
end)

-- Comando para aceptar
RegisterCommand(Config.AcceptCommand, function(source, args)
    AcceptRequest(source)
end, false)

-- Comando para rechazar
RegisterCommand(Config.DeclineCommand, function(source, args)
    DeclineRequest(source)
end, false)

-- Comando admin para resetear conocidos
RegisterCommand(Config.ResetCommand, function(source, args)
    local src = source

    if src > 0 then
        local Player = QBCore.Functions.GetPlayer(src)
        if not Player or not QBCore.Functions.HasPermission(src, Config.AdminPermission) then
            TriggerClientEvent('QBCore:Notify', src, 'No tienes permisos', 'error')
            return
        end
    end

    if not args[1] then
        TriggerClientEvent('QBCore:Notify', src, 'Uso: /' .. Config.ResetCommand .. ' [citizenid]', 'error')
        return
    end

    local citizenid = args[1]
    KnownPlayers[citizenid] = {}
    SaveKnownPlayers(citizenid)
    TriggerClientEvent('QBCore:Notify', src, 'Conocidos reseteados para ' .. citizenid, 'success')
end, false)

-- Callback para verificar si un jugador conoce a otro
RegisterNetEvent('ic-names:server:getKnownStatus', function(players)
    local src = source
    local srcCitizenid = GetCitizenidBySource(src)
    if not srcCitizenid then return end

    LoadKnownPlayers(srcCitizenid)

    local knownStatus = {}
    for _, playerData in pairs(players) do
        local targetCitizenid = playerData.citizenid
        if targetCitizenid and targetCitizenid ~= srcCitizenid then
            knownStatus[playerData.serverId] = KnownPlayers[srcCitizenid][targetCitizenid] or false
        end
    end

    TriggerClientEvent('ic-names:client:updateKnownStatus', src, knownStatus)
end)

-- Obtener nombre IC para el cliente
RegisterNetEvent('ic-names:server:getPlayerData', function(serverId)
    local src = source
    local name = GetICName(serverId)
    local citizenid = GetCitizenidBySource(serverId)
    TriggerClientEvent('ic-names:client:receivePlayerData', src, serverId, name, citizenid)
end)

-- Limpiar solicitudes expiradas
CreateThread(function()
    while true do
        Wait(10000)
        local currentTime = os.time()
        for targetId, request in pairs(PendingRequests) do
            if currentTime - request.timestamp > Config.RequestTimeout then
                TriggerClientEvent('QBCore:Notify', targetId, 'La solicitud ha expirado', 'error')
                TriggerClientEvent('QBCore:Notify', request.fromSource, 'Tu solicitud ha expirado', 'error')
                PendingRequests[targetId] = nil
            end
        end
    end
end)

-- Cargar datos al iniciar el recurso
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    local players = QBCore.Functions.GetQBPlayers()
    for _, Player in pairs(players) do
        LoadKnownPlayers(Player.PlayerData.citizenid)
    end
end)

-- Guardar datos al detener el recurso
AddEventHandler('onResourceStop', function(resourceName)
    if GetCurrentResourceName() ~= resourceName then return end

    for citizenid in pairs(KnownPlayers) do
        SaveKnownPlayers(citizenid)
    end
end)
