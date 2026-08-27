-- Utility helper functions for Snake Love2D
local helpers = {}

-- Realiza una copia profunda recursiva con soporte para ciclos y metatablas
function helpers.deep_copy(orig, copies)
    copies = copies or {}
    local orig_type = type(orig)
    if orig_type ~= 'table' then
        return orig
    end
    if copies[orig] then
        return copies[orig]
    end
    local copy = {}
    copies[orig] = copy
    for k, v in pairs(orig) do
        local copy_k = helpers.deep_copy(k, copies)
        local copy_v = helpers.deep_copy(v, copies)
        copy[copy_k] = copy_v
    end
    local mt = getmetatable(orig)
    if mt ~= nil then
        setmetatable(copy, helpers.deep_copy(mt, copies))
    end
    return copy
end
helpers.deepCopy = helpers.deep_copy

-- Restringe un valor dentro de los limites minimo y maximo
function helpers.clamp(val, min_val, max_val)
    if min_val > max_val then
        min_val, max_val = max_val, min_val
    end
    if val < min_val then
        return min_val
    elseif val > max_val then
        return max_val
    end
    return val
end

-- Calcula la distancia euclidiana entre dos puntos (escalares o tablas {x, y})
function helpers.distance(x1, y1, x2, y2)
    if type(x1) == "table" and type(y1) == "table" then
        local p1, p2 = x1, y1
        x1, y1 = p1.x or p1[1] or 0, p1.y or p1[2] or 0
        x2, y2 = p2.x or p2[1] or 0, p2.y or p2[2] or 0
    end
    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    return math.sqrt(dx * dx + dy * dy)
end

-- Calcula la distancia euclidiana al cuadrado (optimizacion sin raiz cuadrada)
function helpers.distance_sq(x1, y1, x2, y2)
    if type(x1) == "table" and type(y1) == "table" then
        local p1, p2 = x1, y1
        x1, y1 = p1.x or p1[1] or 0, p1.y or p1[2] or 0
        x2, y2 = p2.x or p2[1] or 0, p2.y or p2[2] or 0
    end
    local dx = (x2 or 0) - (x1 or 0)
    local dy = (y2 or 0) - (y1 or 0)
    return dx * dx + dy * dy
end
helpers.distanceSq = helpers.distance_sq

-- Calcula la distancia Manhattan entre dos puntos
function helpers.manhattan(x1, y1, x2, y2)
    if type(x1) == "table" and type(y1) == "table" then
        local p1, p2 = x1, y1
        x1, y1 = p1.x or p1[1] or 0, p1.y or p1[2] or 0
        x2, y2 = p2.x or p2[1] or 0, p2.y or p2[2] or 0
    end
    local dx = math.abs((x2 or 0) - (x1 or 0))
    local dy = math.abs((y2 or 0) - (y1 or 0))
    return dx + dy
end

-- Interpolacion lineal entre a y b segun el factor t
function helpers.lerp(a, b, t)
    return a + (b - a) * t
end

-- Interpolacion lineal con factor t delimitado en [0, 1]
function helpers.lerp_clamped(a, b, t)
    return helpers.lerp(a, b, helpers.clamp(t, 0, 1))
end
helpers.lerpClamped = helpers.lerp_clamped

-- Retorna el signo numerico (1 para positivo, -1 para negativo, 0 para cero)
function helpers.sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

-- Redondea un numero al entero mas cercano o a N decimales
function helpers.round(x, decimals)
    if decimals and decimals > 0 then
        local mult = 10 ^ decimals
        if x >= 0 then
            return math.floor(x * mult + 0.5) / mult
        else
            return math.ceil(x * mult - 0.5) / mult
        end
    end
    if x >= 0 then
        return math.floor(x + 0.5)
    else
        return math.ceil(x - 0.5)
    end
end

-- Mapea un valor de un rango origen a un rango destino con proteccion contra division por cero
function helpers.map_range(val, in_min, in_max, out_min, out_max)
    if in_max == in_min then
        return out_min
    end
    return out_min + (val - in_min) * (out_max - out_min) / (in_max - in_min)
end
helpers.mapRange = helpers.map_range

-- Comprueba si dos rectangulos se solapan (soporta tablas {x, y, w, h} o 8 escalares)
function helpers.rect_overlap(x1, y1, w1, h1, x2, y2, w2, h2)
    if type(x1) == "table" and type(y1) == "table" then
        local r1, r2 = x1, y1
        x1 = r1.x or r1[1] or 0
        y1 = r1.y or r1[2] or 0
        w1 = r1.w or r1.width or r1[3] or 0
        h1 = r1.h or r1.height or r1[4] or 0
        x2 = r2.x or r2[1] or 0
        y2 = r2.y or r2[2] or 0
        w2 = r2.w or r2.width or r2[3] or 0
        h2 = r2.h or r2.height or r2[4] or 0
    end
    if w1 < 0 then x1 = x1 + w1; w1 = -w1 end
    if h1 < 0 then y1 = y1 + h1; h1 = -h1 end
    if w2 < 0 then x2 = x2 + w2; w2 = -w2 end
    if h2 < 0 then y2 = y2 + h2; h2 = -h2 end
    if w1 <= 0 or h1 <= 0 or w2 <= 0 or h2 <= 0 then
        return false
    end
    return (x1 < x2 + w2) and (x1 + w1 > x2) and (y1 < y2 + h2) and (y1 + h1 > y2)
end
helpers.rectsOverlap = helpers.rect_overlap

-- Comprueba si un punto esta contenido dentro de un rectangulo (inclusivo)
function helpers.point_in_rect(px, py, rx, ry, rw, rh)
    if type(px) == "table" and type(py) == "table" then
        local p, r = px, py
        px = p.x or p[1] or 0
        py = p.y or p[2] or 0
        rx = r.x or r[1] or 0
        ry = r.y or r[2] or 0
        rw = r.w or r.width or r[3] or 0
        rh = r.h or r.height or r[4] or 0
    elseif type(rx) == "table" then
        local r = rx
        rx = r.x or r[1] or 0
        ry = r.y or r[2] or 0
        rw = r.w or r.width or r[3] or 0
        rh = r.h or r.height or r[4] or 0
    end
    if rw < 0 then rx = rx + rw; rw = -rw end
    if rh < 0 then ry = ry + rh; rh = -rh end
    return px >= rx and px <= rx + rw and py >= ry and py <= ry + rh
end
helpers.rectContains = helpers.point_in_rect

-- Retorna las coordenadas del centro de un rectangulo
function helpers.rect_center(x, y, w, h)
    if type(x) == "table" then
        local r = x
        x = r.x or r[1] or 0
        y = r.y or r[2] or 0
        w = r.w or r.width or r[3] or 0
        h = r.h or r.height or r[4] or 0
    end
    return x + (w or 0) * 0.5, y + (h or 0) * 0.5
end
helpers.rectCenter = helpers.rect_center

-- Mezcla aleatoriamente los elementos de un array usando Fisher-Yates
function helpers.shuffle(list, rng)
    if type(list) ~= "table" then
        return list
    end
    local n = #list
    if n <= 1 then
        return list
    end
    local rand_fn = rng or (love and love.math and love.math.random) or math.random
    for i = n, 2, -1 do
        local j = rand_fn(i)
        list[i], list[j] = list[j], list[i]
    end
    return list
end

-- Retorna la diferencia angular minima en radianes entre a y b en el rango [-pi, pi]
function helpers.angle_diff(a, b)
    local two_pi = math.pi * 2
    local diff = (b - a) % two_pi
    if diff > math.pi then
        diff = diff - two_pi
    elseif diff < -math.pi then
        diff = diff + two_pi
    end
    return diff
end
helpers.angleDiff = helpers.angle_diff

-- Normaliza un angulo en radianes al rango [0, 2*pi)
function helpers.normalize_angle(angle)
    local two_pi = math.pi * 2
    return (angle % two_pi + two_pi) % two_pi
end
helpers.normalizeAngle = helpers.normalize_angle

-- Selecciona un elemento aleatorio de una lista
function helpers.choice(list, rng)
    if type(list) ~= "table" or #list == 0 then
        return nil
    end
    local rand_fn = rng or (love and love.math and love.math.random) or math.random
    return list[rand_fn(#list)]
end

-- Retorna un array con todas las claves de una tabla
function helpers.keys(tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    local result = {}
    for k in pairs(tbl) do
        table.insert(result, k)
    end
    return result
end
helpers.table_keys = helpers.keys

-- Retorna un array con todos los valores de una tabla
function helpers.values(tbl)
    if type(tbl) ~= "table" then
        return {}
    end
    local result = {}
    for _, v in pairs(tbl) do
        table.insert(result, v)
    end
    return result
end
helpers.table_values = helpers.values

-- Filtra elementos de un array segun una funcion predicado
function helpers.filter(list, predicate)
    if type(list) ~= "table" then
        return {}
    end
    local result = {}
    for i, v in ipairs(list) do
        if predicate(v, i) then
            table.insert(result, v)
        end
    end
    return result
end

-- Transforma los elementos de un array aplicando una funcion
function helpers.map(list, fn)
    if type(list) ~= "table" then
        return {}
    end
    local result = {}
    for i, v in ipairs(list) do
        table.insert(result, fn(v, i))
    end
    return result
end

-- Seeded random number generator (LCG PRNG)
local rngState = 0
function helpers.seedRandom(seed)
    if seed then
        rngState = seed
    end
    rngState = (rngState * 1103515245 + 12345) % 2147483648
    return rngState / 2147483648
end

return helpers

