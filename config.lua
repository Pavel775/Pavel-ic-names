Config = {}

-- Texto que se muestra cuando no se conoce al personaje
Config.UnknownText = 'Desconocido'

-- Distancia máxima para ver los nombres (en metros)
Config.MaxDistance = 10.0

-- Distancia para el comando de conocer (en metros)
Config.MeetDistance = 3.0

-- Tecla para aceptar/rechazar solicitudes (https://docs.fivem.net/docs/game-references/controls/)
Config.AcceptKey = 246 -- Y
Config.DeclineKey = 249 -- N

-- Tiempo en segundos para responder a una solicitud
Config.RequestTimeout = 60

-- Offset de altura del texto sobre la cabeza
Config.HeightOffset = 1.2

-- Tamaño del texto
Config.TextScale = 0.4

-- Color del texto (RGBA)
Config.TextColor = {255, 255, 255, 255}

-- Color del texto para solicitudes pendientes
Config.PendingColor = {255, 255, 0, 255}

-- Comandos
Config.MeetCommand = 'conocer' -- Comando para enviar solicitud
Config.AcceptCommand = 'aceptar' -- Comando alternativo para aceptar
Config.DeclineCommand = 'rechazar' -- Comando alternativo para rechazar
Config.ResetCommand = 'resetconocidos' -- Comando admin para resetear conocidos

-- Permisos admin para resetear
Config.AdminPermission = 'admin'
