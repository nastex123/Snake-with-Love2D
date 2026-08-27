-- core/world.lua — Estado del juego administrado por un World (sin variables globales).
-- Toda modificacion al proyecto debe acceder/actualizar via world.state.X o metodos World.
local World = {}
local helpers = require("core.helpers")

World.state = {}

-- Almacenamiento interno para instantáneas (snapshots) en memoria
local snapshots = {}

-- Observadores de cambio de estado
local listeners = {}

--- Inicializa el estado con una tabla de valores iniciales (sin perder la referencia de World.state).
-- @param initTable table Tabla con claves y valores iniciales.
-- @return table World.state
function World.stateInit(initTable)
    if type(initTable) == "table" then
        for k, v in pairs(initTable) do
            World.state[k] = v
        end
    end
    return World.state
end

--- Resetea el estado del mundo en el lugar (in-place).
-- @param defaults table|nil Opcional: nuevos valores por defecto tras el reseteo.
function World.reset(defaults)
    for k in pairs(World.state) do
        World.state[k] = nil
    end
    if type(defaults) == "table" then
        for k, v in pairs(defaults) do
            World.state[k] = v
        end
    end
end

--- Obtiene un valor del estado con soporte para valor por defecto si es nil.
-- @param key string Clave a consultar.
-- @param defaultVal any Valor de fallback si la clave no existe o es nil.
-- @return any
function World.get(key, defaultVal)
    local val = World.state[key]
    if val == nil then
        return defaultVal
    end
    return val
end

--- Establece un valor en el estado y notifica a observadores si existen.
-- @param key string Clave a modificar.
-- @param val any Nuevo valor.
function World.set(key, val)
    local oldVal = World.state[key]
    World.state[key] = val
    if listeners[key] then
        for _, cb in ipairs(listeners[key]) do
            pcall(cb, val, oldVal, key)
        end
    end
end

--- Comprueba si una clave existe (no es nil) en el estado.
-- @param key string Clave a verificar.
-- @return boolean
function World.has(key)
    return World.state[key] ~= nil
end

--- Elimina una clave del estado.
-- @param key string Clave a eliminar.
-- @return any Valor previo.
function World.delete(key)
    local oldVal = World.state[key]
    World.state[key] = nil
    if listeners[key] then
        for _, cb in ipairs(listeners[key]) do
            pcall(cb, nil, oldVal, key)
        end
    end
    return oldVal
end
World.remove = World.delete

--- Actualiza una clave mediante una función de transformación atómica.
-- @param key string Clave a transformar.
-- @param fn function Función (currentVal) -> newVal.
-- @param defaultVal any Valor inicial si es nil.
-- @return any Nuevo valor resultante.
function World.update(key, fn, defaultVal)
    local cur = World.get(key, defaultVal)
    local nextVal = fn(cur)
    World.set(key, nextVal)
    return nextVal
end

--- Incrementa un valor numérico en el estado, con límite superior opcional.
-- @param key string Clave numérica.
-- @param delta number|nil Cantidad a sumar (por defecto 1).
-- @param maxVal number|nil Límite máximo.
-- @return number Nuevo valor.
function World.increment(key, delta, maxVal)
    local current = World.get(key, 0) or 0
    delta = delta or 1
    local res = current + delta
    if maxVal and res > maxVal then
        res = maxVal
    end
    World.set(key, res)
    return res
end

--- Decrementa un valor numérico en el estado, con límite inferior opcional.
-- @param key string Clave numérica.
-- @param delta number|nil Cantidad a restar (por defecto 1).
-- @param minVal number|nil Límite mínimo.
-- @return number Nuevo valor.
function World.decrement(key, delta, minVal)
    local current = World.get(key, 0) or 0
    delta = delta or 1
    local res = current - delta
    if minVal and res < minVal then
        res = minVal
    end
    World.set(key, res)
    return res
end

--- Invierte el valor booleano de una clave en el estado.
-- @param key string Clave booleana.
-- @return boolean Nuevo valor.
function World.toggle(key)
    local cur = not not World.get(key, false)
    local nextVal = not cur
    World.set(key, nextVal)
    return nextVal
end

--- Delimita un valor numérico en el estado entre minVal y maxVal.
-- @param key string Clave numérica.
-- @param minVal number Límite mínimo.
-- @param maxVal number Límite máximo.
-- @return number Valor acotado.
function World.clamp(key, minVal, maxVal)
    local cur = World.get(key, minVal) or minVal
    local clamped = helpers.clamp(cur, minVal, maxVal)
    World.set(key, clamped)
    return clamped
end

--- Exporta una copia profunda completa del estado actual.
-- @return table Copia profunda de World.state.
function World.exportState()
    return helpers.deep_copy(World.state)
end

--- Importa un estado completo, reemplazando las claves in-place.
-- @param data table Tabla con el estado a importar.
function World.importState(data)
    if type(data) ~= "table" then return end
    for k in pairs(World.state) do
        World.state[k] = nil
    end
    for k, v in pairs(data) do
        World.state[k] = helpers.deep_copy(v)
    end
end

--- Guarda una instantánea del estado actual en memoria.
-- @param name string|nil Nombre de la instantánea (por defecto "default").
function World.saveSnapshot(name)
    name = name or "default"
    snapshots[name] = helpers.deep_copy(World.state)
end

--- Restaura una instantánea guardada en memoria hacia World.state.
-- @param name string|nil Nombre de la instantánea (por defecto "default").
-- @return boolean True si se restauró con éxito, false si no existía.
function World.loadSnapshot(name)
    name = name or "default"
    local snap = snapshots[name]
    if not snap then return false end
    World.importState(snap)
    return true
end
World.restoreSnapshot = World.loadSnapshot

--- Comprueba si existe una instantánea en memoria.
-- @param name string|nil
-- @return boolean
function World.hasSnapshot(name)
    name = name or "default"
    return snapshots[name] ~= nil
end

--- Elimina una instantánea guardada.
-- @param name string|nil
function World.deleteSnapshot(name)
    name = name or "default"
    snapshots[name] = nil
end

--- Limpia todas las instantáneas guardadas en memoria.
function World.clearSnapshots()
    snapshots = {}
end

--- Suscribe un listener a cambios en una clave específica del estado.
-- @param key string Clave a observar.
-- @param callback function Función (newVal, oldVal, key).
-- @return function Función para cancelar la suscripción.
function World.subscribe(key, callback)
    if not listeners[key] then
        listeners[key] = {}
    end
    table.insert(listeners[key], callback)
    return function()
        local list = listeners[key]
        if list then
            for i, cb in ipairs(list) do
                if cb == callback then
                    table.remove(list, i)
                    break
                end
            end
            if #list == 0 then listeners[key] = nil end
        end
    end
end
World.on = World.subscribe

--- Limpia los listeners registrados para una clave o todos los listeners.
-- @param key string|nil
function World.clearListeners(key)
    if key then
        listeners[key] = nil
    else
        listeners = {}
    end
end

return World