-- systems/shopBioScanner.lua — Holographic Bio-Scanner & Vertebrae Topology (GDD §13 / Bio-Rack v3)
-- Renderiza el panel de inspección táctica y el chasis bio-topológico de 7 vértebras (HEAD + V01-V06).
local shopBioScanner = {}
local constants = require("constants")

-- Mapeo de zonas de impacto bio-topológicas por ID de ítem/tarot
-- target: "ALL", 0 (HEAD), o array de índices {1..6}
local TOPOLOGY_MAP = {
    -- Tarots (12 arcanos)
    mercury = {target = "ALL", label = "GLOBAL LINK // ALL SEGMENTS", roman = "I", tier = "S"},
    iron_spine = {target = {4, 5, 6}, label = "TAIL MATRIX // V04-V06 IRON REINFORCEMENT", roman = "II", tier = "B"},
    eagle_eye = {target = 0, label = "SENSORY CORTEX // CRANIAL SENSORS", roman = "III", tier = "A"},
    shadow_thief = {target = "ALL", label = "EPIDERMAL FRICTION // SHADOW ABSORBERS", roman = "IV", tier = "C"},
    alchemical_digestion = {target = {1, 2}, label = "GASTRIC CORE // METABOLIC ENZYMES", roman = "V", tier = "B"},
    dragon_blood = {target = "ALL", label = "VASCULAR SYSTEM // PYRO-TRAIL EMITTERS", roman = "VI", tier = "A"},
    absolute_zero = {target = {0, 1}, label = "CRYOGENIC EMITTERS // CRANIAL FOCUS", roman = "VII", tier = "A"},
    magic_circle = {target = {2, 3, 4}, label = "CONSTRICTION LOOP // MAGNETIC GRAVITY", roman = "VIII", tier = "B"},
    astral_mirror = {target = 0, label = "QUANTUM PHASE SHIFT // HEAD DISPLACEMENT", roman = "IX", tier = "B"},
    midas_pouch = {target = "ALL", label = "AURA GENERATOR // BOUNTY DISPERSION", roman = "X", tier = "C"},
    iron_heart = {target = {0, 1}, label = "CORE DEFENSE // VITAL ORGANS", roman = "XI", tier = "C"},
    reaper = {target = "ALL", label = "NECRO-CATALYST // SOUL BUFFER", roman = "XII", tier = "S"},

    -- Items activos/pasivos (22 items)
    shield = {target = 0, label = "FORCEFIELD DOME // CRANIAL DEFENSE", tier = "B"},
    armor = {target = {0, 1, 2}, label = "PLATED EXOSKELETON // UPPER CHASSIS", tier = "A"},
    ghost = {target = "ALL", label = "MOLECULAR PHASE // TOTAL INTANGIBILITY", tier = "A"},
    magnet = {target = 0, label = "MAGNETIC NOZZLE // INTAKE ATTRACTOR", tier = "C"},
    bomb = {target = 0, label = "CONCUSSION WARHEAD // FRONT BURST", tier = "B"},
    hunger = {target = {1, 2}, label = "HYPER-DIGESTION // NUTRIENT RADAR", tier = "C"},
    speedReducer = {target = "ALL", label = "KINETIC STABILIZER // ALL VERTEBRAE", tier = "B"},
    turbo = {target = {4, 5, 6}, label = "AFTERBURNER THRUST // REAR PROPULSION", tier = "C"},
    slow = {target = 0, label = "TEMPORAL PULSER // CRANIAL DRIVER", tier = "B"},
    doubler = {target = "ALL", label = "SCORE MATRIX // HARVEST MULTIPLIER", tier = "B"},
    extraCoin = {target = "ALL", label = "MINING RECEPTORS // EXTRACTOR COILS", tier = "C"},
}

local TIER_COLORS = {
    S = {1.0, 0.82, 0.24}, -- Oro
    A = {0.61, 0.36, 1.0},  -- Púrpura
    B = {0.0, 0.94, 1.0},   -- Cian
    C = {0.47, 0.50, 0.60}, -- Gris azulado
}

function shopBioScanner.getInfo(id)
    return TOPOLOGY_MAP[id] or {target = "ALL", label = "STANDARD CHASSIS LINK", tier = "C"}
end

local function isNodeAffected(target, nodeIndex)
    if target == "ALL" then return true end
    if type(target) == "number" and target == nodeIndex then return true end
    if type(target) == "table" then
        for _, idx in ipairs(target) do
            if idx == nodeIndex then return true end
        end
    end
    return false
end

-- Dibuja el panel de escaneo holográfico derecho y la anatomía de 7 nodos
function shopBioScanner.draw(offer, def, x, y, w, h, fontNormal, fontSmall, fontLarge)
    local time = (love.timer and love.timer.getTime and love.timer.getTime() or 0)
    local info = def and shopBioScanner.getInfo(def.id) or {target = "ALL", label = "STANDBY", tier = "C"}
    local tierColor = TIER_COLORS[info.tier or "C"] or {0.0, 0.94, 1.0}

    -- 1. Caja contenedora con esquinas y borde brillante
    love.graphics.setColor(0.04, 0.03, 0.08, 0.95)
    love.graphics.rectangle("fill", x, y, w, h, 4)

    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.65)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4)

    -- Retícula / Header separator
    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.3)
    love.graphics.line(x, y + 22, x + w, y + 22)

    -- 2. Header Text
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.0, 0.94, 1.0, 0.9)
    love.graphics.print("HOLOGRAPHIC BIO-SCAN // SPEC: " .. (info.tier or "C"), x + 8, y + 6)

    if not offer or not def then
        if fontNormal then love.graphics.setFont(fontNormal) end
        love.graphics.setColor(0.4, 0.45, 0.5)
        love.graphics.printf("SIN SELECCIÓN EN RACK", x, y + h / 2 - 10, w, "center")
        return
    end

    -- 3. Título & Subtítulo
    if fontNormal then love.graphics.setFont(fontNormal) end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(def.name or def.id, x + 10, y + 28)

    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.9)
    local sub = offer.kind == "tarot" and ("ARCANA " .. (info.roman or "MAYOR") .. " // PASSIVE CORE") or "CYBERNETIC ACTIVE MODULE"
    love.graphics.print(sub, x + 10, y + 43)

    -- Precio en esquina superior derecha del panel
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    love.graphics.printf((offer.price or 0) .. " COINS", x + w - 110, y + 28, 100, "right")

    -- 4. Descripción técnica
    love.graphics.setColor(0.8, 0.85, 0.95, 0.85)
    local descText = def.desc or ""
    if def.desc2 and #def.desc2 > 0 then
        descText = descText .. " " .. def.desc2
    end
    love.graphics.printf(descText, x + 10, y + 58, w - 20, "left")

    -- Separador a sección Bio-Topología
    love.graphics.setColor(0.16, 0.15, 0.25, 0.8)
    love.graphics.line(x + 10, y + 84, x + w - 10, y + 84)

    -- 5. Bio-Topología: Título y Spine de 7 Vértebras
    love.graphics.setColor(0.61, 0.36, 1.0, 0.9)
    love.graphics.print("BIO-TOPOLOGY // CHASSIS IMPACT", x + 10, y + 88)

    local cx = x + w / 2
    local cy = y + 140
    local nodeSpacing = (w - 70) / 6
    local nodes = {}

    for i = 0, 6 do
        local nx = x + 35 + i * nodeSpacing
        local ny = cy + math.sin(time * 2.5 + i * 0.8) * 6
        nodes[i] = {x = nx, y = ny}
    end

    -- Dibujar espina dorsal (líneas conectoras)
    love.graphics.setColor(0.2, 0.18, 0.3, 0.8)
    love.graphics.setLineWidth(2)
    for i = 0, 5 do
        love.graphics.line(nodes[i].x, nodes[i].y, nodes[i + 1].x, nodes[i + 1].y)
    end
    love.graphics.setLineWidth(1)

    -- Dibujar los 7 nodos y sus halos
    for i = 0, 6 do
        local node = nodes[i]
        local affected = isNodeAffected(info.target, i)
        local nodeColor = affected and (offer.kind == "tarot" and {0.61, 0.36, 1.0} or {0.0, 0.94, 1.0}) or {0.2, 0.18, 0.28}

        -- Pulso exterior para nodos afectados
        if affected then
            local pulse = (math.sin(time * 4.0 + i) + 1) * 0.5
            love.graphics.setColor(1.0, 0.82, 0.24, 0.3 + pulse * 0.4)
            love.graphics.circle("line", node.x, node.y, 11 + pulse * 4)
        end

        -- Relleno del nodo
        love.graphics.setColor(nodeColor[1], nodeColor[2], nodeColor[3], affected and 0.4 or 0.15)
        if i == 0 then
            -- Cabeza: triángulo táctico
            local pts = {node.x - 9, node.y - 7, node.x + 9, node.y, node.x - 9, node.y + 7}
            love.graphics.polygon("fill", pts)
            love.graphics.setColor(nodeColor[1], nodeColor[2], nodeColor[3], affected and 1 or 0.5)
            love.graphics.polygon("line", pts)
        else
            -- Vértebras V01-V06: círculos
            love.graphics.circle("fill", node.x, node.y, 7)
            love.graphics.setColor(nodeColor[1], nodeColor[2], nodeColor[3], affected and 1 or 0.5)
            love.graphics.circle("line", node.x, node.y, 7)
        end

        -- Marcador superior diamond si está activo
        if affected then
            love.graphics.setColor(1.0, 0.82, 0.24, 0.9)
            love.graphics.print("◆", node.x - 4, node.y - 18)
        end

        -- Label inferior
        if fontSmall then love.graphics.setFont(fontSmall) end
        love.graphics.setColor(affected and {1, 1, 1, 0.9} or {0.4, 0.45, 0.5, 0.6})
        local lbl = (i == 0) and "HEAD" or ("V0" .. i)
        love.graphics.printf(lbl, node.x - 18, node.y + 12, 36, "center")
    end

    -- 6. Indicador de enlace de impacto
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.9)
    love.graphics.printf(info.label or "DIRECT LINK", x + 10, y + h - 16, w - 20, "center")
end

return shopBioScanner
