-- =============================================================================
-- ENUNCIADO 1: MÓDULO DE PERSISTENCIA (MANEJO DE ARCHIVOS)
-- Centraliza la carga y guardado del puntaje máximo utilizando el sistema de
-- archivos seguro de Love2D, garantizando que los datos queden en el disco local.
-- =============================================================================
local persistence = {}

-- Inicializa el identificador del juego en el disco
function persistence.init()
    -- Crea una carpeta dedicada en AppData/Roaming/LOVE/ (en Windows)
    love.filesystem.setIdentity("Snake_Brandon_IUB")
end

-- Carga el puntaje desde el almacenamiento local
function persistence.cargar()
    local nombreArchivo = "highscore.txt"
    
    -- Comprobamos si el archivo existe en el disco antes de leerlo
    if love.filesystem.getInfo(nombreArchivo) then
        local contenido = love.filesystem.read(nombreArchivo)
        -- Convertimos el texto leído a número. Si falla, por defecto es 0
        return tonumber(contenido) or 0
    end
    
    return 0 -- Si el archivo no existe, el récord inicial es cero
end

-- Evalúa y guarda el puntaje si se superó el récord actual
function persistence.guardar(puntajeActual, recordActual)
    local nombreArchivo = "highscore.txt"
    
    -- Solo sobreescribimos el disco si el jugador superó el récord anterior
    if puntajeActual > recordActual then
        love.filesystem.write(nombreArchivo, tostring(puntajeActual))
        return puntajeActual -- Devolvemos el nuevo récord
    end
    
    return recordActual -- Retornamos el récord sin cambios
end

return persistence