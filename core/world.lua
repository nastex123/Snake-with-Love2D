-- core/world.lua — Estado del juego administrado por un World (sin variables globales).
-- Toda modificacion al proyecto debe acceder/actualizar via world.state.X
local World = {}

World.state = {}

-- Acceso de solo lectura/escritura al estado global del juego.
function World.stateInit(initTable)
    for k, v in pairs(initTable) do
        World.state[k] = v
    end
    return World.state
end

function World.reset()
    for k in pairs(World.state) do
        World.state[k] = nil
    end
end

function World.get(key)
    return World.state[key]
end

function World.set(key, val)
    World.state[key] = val
end

return World