-- systems/shopBioScanner.lua — Gothic Retablo & Sacred Dragon Spine Topology (GDD §13 / Propuesta C)
-- Renderiza el Retablo Mayor de la Cripta y el Esqueleto de la Sierpe Mística con Llamas de Alma.
local shopBioScanner = {}
local constants = require("constants")

-- Mapeo de zonas de impacto sagradas por ID de ítem/tarot
local TOPOLOGY_MAP = {
    -- 12 Cartas del Destino / Arcanos Mayores
    mercury = {target = "ALL", label = "BENDICION TOTAL // TODAS LAS ANCHURAS", roman = "I", tier = "S"},
    iron_spine = {target = {4, 5, 6}, label = "ESPINAZO DE HIERRO // V04-V06 COLA BLINDADA", roman = "II", tier = "B"},
    eagle_eye = {target = 0, label = "VISION CELESTIAL // CRANEO SAGRADO", roman = "III", tier = "A"},
    shadow_thief = {target = "ALL", label = "MANTO DE SOMBRAS // ROCE ESPECTRAL", roman = "IV", tier = "C"},
    alchemical_digestion = {target = {1, 2}, label = "TRANSMUTACION // NUCLEO METABOLICO", roman = "V", tier = "B"},
    dragon_blood = {target = "ALL", label = "SANGRE DE DRAGON // RASTRO DE BRASAS", roman = "VI", tier = "A"},
    absolute_zero = {target = {0, 1}, label = "ESCARCHA CRIPTA // VAPOR GLACIAL", roman = "VII", tier = "A"},
    magic_circle = {target = {2, 3, 4}, label = "CIRCULO DE PODER // CONSTREÑIMIENTO", roman = "VIII", tier = "B"},
    astral_mirror = {target = 0, label = "PASO ASTRAL // UMBRAL DE PAREDES", roman = "IX", tier = "B"},
    midas_pouch = {target = "ALL", label = "LLUVIA DE ORO // BENDICION SACRA", roman = "X", tier = "C"},
    iron_heart = {target = {0, 1}, label = "CORAZON DE TEMPLE // ESCUDO DE VIDA", roman = "XI", tier = "C"},
    reaper = {target = "ALL", label = "COSECHA DE ALMAS // BUFFER MORTAL", roman = "XII", tier = "S"},

    -- 22 Items activos/pasivos del Calabozo
    shield = {target = 0, label = "ESCUDO RUNICO // PROTECCION CRANEAL", tier = "B"},
    armor = {target = {0, 1, 2}, label = "CORAZA DE PLACAS // PECHO ACORAZADO", tier = "A"},
    ghost = {target = "ALL", label = "FORMA ESPECTRAL // INTANGIBILIDAD", tier = "A"},
    magnet = {target = 0, label = "ATRACCION MAGNETICA // ALIENTOS", tier = "C"},
    bomb = {target = 0, label = "GRANADA ALQUIMICA // DETONACION", tier = "B"},
    hunger = {target = {1, 2}, label = "VORACIDAD // COSECHA DE COLECTA", tier = "C"},
    speedReducer = {target = "ALL", label = "CALMA PROFUNDA // TODAS LAS ANCHURAS", tier = "B"},
    turbo = {target = {4, 5, 6}, label = "PROPULSION DE FUEGO // IMPULSO DE COLA", tier = "C"},
    slow = {target = 0, label = "ARENA DEL TIEMPO // CRANEO SAGRADO", tier = "B"},
    doubler = {target = "ALL", label = "CALIZ DUPLICADOR // RECOLECTA X2", tier = "B"},
    extraCoin = {target = "ALL", label = "DIEZMO DEL DEVOTO // MONEDA EXTRA", tier = "C"},
}

local TIER_COLORS = {
    S = {1.0, 0.82, 0.25}, -- Oro sacro
    A = {0.68, 0.38, 1.0},  -- Púrpura relicario
    B = {0.25, 0.75, 1.0},  -- Azul vidriera
    C = {0.65, 0.65, 0.75}, -- Plata de cripta
}

function shopBioScanner.getInfo(id)
    return TOPOLOGY_MAP[id] or {target = "ALL", label = "VINCULO DEL RETABLO", tier = "C"}
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

-- Dibuja el Retablo Mayor gótico y la espina de dragón místico
function shopBioScanner.draw(offer, def, x, y, w, h, fontNormal, fontSmall, fontLarge)
    local time = (love.timer and love.timer.getTime and love.timer.getTime() or 0)
    local info = def and shopBioScanner.getInfo(def.id) or {target = "ALL", label = "SIN RELIQUIA", tier = "C"}
    local tierColor = TIER_COLORS[info.tier or "C"] or {1.0, 0.82, 0.25}

    -- 1. Fondo de Piedra de Cripta con pilastras y arcos
    love.graphics.setColor(0.05, 0.04, 0.08, 0.96)
    love.graphics.rectangle("fill", x, y, w, h, 4)

    -- Marco exterior de hierro forjado gótico
    love.graphics.setColor(0.22, 0.18, 0.32, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", x, y, w, h, 4)
    love.graphics.setLineWidth(1)

    -- Remates ojivales en las 4 esquinas interiores
    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.7)
    love.graphics.line(x + 4, y + 16, x + 16, y + 4)
    love.graphics.line(x + w - 4, y + 16, x + w - 16, y + 4)
    love.graphics.line(x + 4, y + h - 16, x + 16, y + h - 4)
    love.graphics.line(x + w - 4, y + h - 16, x + w - 16, y + h - 4)

    -- Moldura horizontal gótica (Dintel de separación)
    love.graphics.setColor(0.35, 0.30, 0.48, 0.6)
    love.graphics.line(x + 8, y + 24, x + w - 8, y + 24)

    -- 2. Dintel Superior del Retablo
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.95)
    love.graphics.print("RETABLO SAGRADO // RELIQUIA GRADO " .. (info.tier or "C"), x + 12, y + 7)

    -- Flor de lis / Glifo en el encabezado
    love.graphics.setColor(1.0, 0.82, 0.25, 0.8)
    love.graphics.printf("✦", x + w - 24, y + 7, 16, "center")

    if not offer or not def then
        if fontNormal then love.graphics.setFont(fontNormal) end
        love.graphics.setColor(0.45, 0.40, 0.55)
        love.graphics.printf("NINGUNA OFRENDA EN EL ALTAR", x, y + h / 2 - 10, w, "center")
        return
    end

    -- 3. Título Cincelado en Mármol & Subtítulo Sacro
    if fontNormal then love.graphics.setFont(fontNormal) end

    local priceW = 90
    local titleMaxW = w - priceW - 28

    -- Sombra de bajo relieve
    love.graphics.setColor(0, 0, 0, 0.9)
    love.graphics.printf(def.name or def.id, x + 13, y + 33, titleMaxW, "left")
    -- Texto principal
    love.graphics.setColor(1.0, 0.96, 0.88, 1.0)
    love.graphics.printf(def.name or def.id, x + 12, y + 32, titleMaxW, "left")

    -- Precio / Ofrenda en esquina superior derecha
    love.graphics.setColor(constants.COLOR_GOLD[1], constants.COLOR_GOLD[2], constants.COLOR_GOLD[3])
    if fontNormal then love.graphics.setFont(fontNormal) end
    love.graphics.printf((offer.price or 0) .. " ORO", x + w - priceW - 12, y + 32, priceW, "right")

    -- Subtítulo sacro
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.9)
    local sub = offer.kind == "tarot"
        and ("ARCANO DEL DESTINO " .. (info.roman or "MAYOR") .. " // SELLO PERPETUO")
        or "TALISMAN SAGRADO // ARTEFACTO DE MAZMORRA"
    love.graphics.print(sub, x + 12, y + 50)

    -- 4. Texto del Manuscrito / Explicación de la Reliquia
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(0.85, 0.82, 0.78, 0.9)
    local descText = def.desc or ""
    if def.desc2 and #def.desc2 > 0 then
        descText = descText .. " " .. def.desc2
    end
    love.graphics.printf(descText, x + 12, y + 66, w - 24, "left")

    -- Separador con arco rebajado
    love.graphics.setColor(0.28, 0.24, 0.40, 0.8)
    love.graphics.line(x + 12, y + 92, x + w - 12, y + 92)

    -- 5. Esqueleto del Dragón Ancestral & Llamas de Alma
    love.graphics.setColor(0.85, 0.65, 0.25, 0.95)
    love.graphics.print("ANATOMIA SAGRADA // CANALIZACION DEL ALMA", x + 12, y + 96)

    local cx = x + w / 2
    local cy = y + 148
    local nodeSpacing = (w - 70) / 6
    local nodes = {}

    for i = 0, 6 do
        local nx = x + 35 + i * nodeSpacing
        local ny = cy + math.sin(time * 2.2 + i * 0.75) * 6
        nodes[i] = {x = nx, y = ny}
    end

    -- Cadenas de hierro forjado que unen las vértebras
    love.graphics.setColor(0.25, 0.22, 0.35, 0.9)
    love.graphics.setLineWidth(2)
    for i = 0, 5 do
        love.graphics.line(nodes[i].x, nodes[i].y, nodes[i + 1].x, nodes[i + 1].y)
    end
    love.graphics.setLineWidth(1)

    -- Dibujar los 7 nodos óseos con llamas de alma
    for i = 0, 6 do
        local node = nodes[i]
        local affected = isNodeAffected(info.target, i)

        -- Llamas de alma ascendentes en vértebras consagradas
        if affected then
            local pulse = (math.sin(time * 4.5 + i) + 1) * 0.5
            local flameH = 12 + pulse * 6
            local flameColor = (offer.kind == "tarot") and {0.75, 0.45, 1.0} or {1.0, 0.78, 0.25}

            -- Halos concéntricos de fuego fatuo
            love.graphics.setColor(flameColor[1], flameColor[2], flameColor[3], 0.25 + pulse * 0.35)
            love.graphics.circle("fill", node.x, node.y, 13 + pulse * 3)

            -- Lengüeta de fuego ascendente
            local fpts = {
                node.x - 5, node.y,
                node.x, node.y - flameH,
                node.x + 5, node.y
            }
            love.graphics.setColor(flameColor[1], flameColor[2], flameColor[3], 0.8)
            love.graphics.polygon("fill", fpts)
        end

        -- Relleno del fragmento óseo (Marfil sacro)
        local boneColor = affected and {0.95, 0.90, 0.80} or {0.35, 0.32, 0.42}
        love.graphics.setColor(boneColor[1], boneColor[2], boneColor[3], 0.9)

        if i == 0 then
            -- Cráneo Draconiano frontal: polígono angular
            local skullPts = {
                node.x - 10, node.y - 8,
                node.x + 10, node.y,
                node.x - 10, node.y + 8,
                node.x - 5, node.y
            }
            love.graphics.polygon("fill", skullPts)
            love.graphics.setColor(1.0, 0.82, 0.25, affected and 1 or 0.5)
            love.graphics.polygon("line", skullPts)
            -- Cuencas de ojos brillantes
            if affected then
                love.graphics.setColor(1, 0.3, 0.2, 0.9)
                love.graphics.circle("fill", node.x - 2, node.y - 3, 1.5)
                love.graphics.circle("fill", node.x - 2, node.y + 3, 1.5)
            end
        else
            -- Vértebra facetada en cruz/diamante
            local vpts = {
                node.x, node.y - 7,
                node.x + 6, node.y,
                node.x, node.y + 7,
                node.x - 6, node.y
            }
            love.graphics.polygon("fill", vpts)
            love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], affected and 1 or 0.4)
            love.graphics.polygon("line", vpts)
        end

        -- Marcador superior: Cruz o estrella dorada
        if affected then
            love.graphics.setColor(1.0, 0.82, 0.25, 0.95)
            love.graphics.print("✦", node.x - 4, node.y - 20)
        end

        -- Etiqueta inferior del nodo
        if fontSmall then love.graphics.setFont(fontSmall) end
        love.graphics.setColor(affected and {1, 0.95, 0.8, 0.95} or {0.45, 0.42, 0.52, 0.7})
        local lbl = (i == 0) and "TESTA" or ("V0" .. i)
        love.graphics.printf(lbl, node.x - 20, node.y + 13, 40, "center")
    end

    -- 6. Papiro de Consagración al Pie del Retablo
    if fontSmall then love.graphics.setFont(fontSmall) end
    love.graphics.setColor(tierColor[1], tierColor[2], tierColor[3], 0.95)
    love.graphics.printf("SELLO SACRO: " .. (info.label or "VINCULO DEL PURGATORIO"), x + 10, y + h - 16, w - 20, "center")
end

return shopBioScanner
