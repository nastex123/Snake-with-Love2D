local helpers = {}

function helpers.deep_copy(orig)
    local orig_type = type(orig)
    if orig_type ~= 'table' then return orig end
    local copy = {}
    for k, v in pairs(orig) do copy[k] = helpers.deep_copy(v) end
    return copy
end

-- Debounce helper: devuelve una función que ejecuta fn después de delay segundos desde la última llamada
-- (Removed debounce helper — menu.lua implements debounce directly)

return helpers
