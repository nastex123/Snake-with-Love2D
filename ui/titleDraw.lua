-- ui/titleDraw.lua - Renderizado 100% procedural del logotipo 'S N A K E' Estilo #12
local titleDraw = {}

-- Paleta Metálica y Joyas Arcane
local COLOR_CYAN_GLOW  = {0.0, 0.94, 1.0}
local COLOR_CYAN_MID   = {0.08, 0.80, 0.95}
local COLOR_CYAN_DARK  = {0.0, 0.40, 0.60}
local COLOR_CYAN_LIGHT = {0.75, 0.98, 1.0}

local COLOR_STEEL_HIGHLIGHT = {0.92, 0.96, 1.0}  -- Brillo especular superior
local COLOR_STEEL_TOP       = {0.80, 0.88, 0.96}  -- Platino claro
local COLOR_STEEL_MID       = {0.50, 0.60, 0.72}  -- Acero medio
local COLOR_STEEL_SHADOW    = {0.26, 0.32, 0.42}  -- Sombra de acero
local COLOR_STEEL_DEEP      = {0.12, 0.16, 0.22}  -- Silueta y chasis
local COLOR_OUTLINE         = {0.02, 0.03, 0.05}  -- Sombra profunda

-- =============================================================================
-- GEOMETRÍA CONVEXA DE CADA LETRA (Gothic Chiseled Facets)
-- =============================================================================

-- === LETRA S ===
-- Silueta externa
local s_silhouette = {
    -128,-30, -78,-28, -78,-14, -102,-14, -102,-6, -80,-2,
    -74,12, -74,30, -126,30, -126,14, -98,14, -98,6, -120,2, -128,-14
}
-- Facetas superiores (luz platino)
local s_top_facets = {
    {-128,-30, -78,-28, -80,-20, -122,-20},
    {-128,-30, -122,-20, -102,-14, -124,-14},
    {-102,-14, -80,-2, -90,-2, -112,-6},
    {-126,14, -98,14, -100,20, -124,20}
}
-- Facetas inferiores (sombra de acero)
local s_bot_facets = {
    {-122,-20, -78,-20, -78,-14, -102,-14},
    {-112,-6, -90,-2, -74,12, -84,12},
    {-84,12, -74,12, -74,30, -84,30},
    {-126,30, -84,30, -84,20, -124,20}
}
-- Cresta central brillante (líneas)
local s_ridges = {
    {-124,-24, -80,-22},
    {-106,-8, -86,0},
    {-124,22, -78,22}
}

-- === LETRA N ===
local n_silhouette = {
    -70,-28, -56,-28, -42,6, -42,-28, -30,-28, -30,30, -44,30, -58,-4, -58,30, -70,30
}
local n_top_facets = {
    {-70,-28, -63,-28, -63,30, -70,30},      -- Pilar izquierdo facetado luz
    {-58,-28, -48,-28, -34,20, -44,20},      -- Diagonal facetada luz
    {-42,-28, -36,-28, -36,30, -42,30}       -- Pilar derecho facetado luz
}
local n_bot_facets = {
    {-63,-28, -56,-28, -56,30, -63,30},      -- Pilar izquierdo facetado sombra
    {-48,-28, -38,-28, -30,30, -40,30},      -- Diagonal facetada sombra
    {-36,-28, -30,-28, -30,30, -36,30}       -- Pilar derecho facetado sombra
}
local n_ridges = {
    {-63,-26, -63,28},
    {-53,-26, -37,28},
    {-36,-26, -36,28}
}

-- === LETRA A === (Ápice gótico elevado hacia la gema)
local a_silhouette = {
    0,-36, 22,30, 8,30, 3,12, -3,12, -8,30, -22,30
}
local a_hole = {
    0,-18, 5,6, -5,6
}
local a_top_facets = {
    {0,-36, 0,-18, -6,6, -12,6, -14,0, -22,30},   -- Brazo izquierdo luz
    {-12,6, 12,6, 0,11}                           -- Travesaño luz
}
local a_bot_facets = {
    {0,-36, 22,30, 14,0, 12,6, 6,6, 0,-18},      -- Brazo derecho sombra
    {-12,6, 12,6, 0,14}                           -- Travesaño sombra
}
local a_ridges = {
    {0,-34, -18,28},
    {0,-34, 18,28},
    {-10,6, 10,6}
}

-- === LETRA K ===
local k_silhouette = {
    32,-28, 44,-28, 44,-4, 58,-28, 74,-28, 52,0, 76,30, 60,30, 44,8, 44,30, 32,30
}
local k_top_facets = {
    {32,-28, 38,-28, 38,30, 32,30},          -- Pilar izquierdo luz
    {44,-4, 58,-28, 66,-28, 48,0},           -- Brazo superior luz
    {44,0, 52,0, 68,30, 60,30}               -- Pierna inferior luz
}
local k_bot_facets = {
    {38,-28, 44,-28, 44,30, 38,30},          -- Pilar izquierdo sombra
    {48,0, 66,-28, 74,-28, 52,0},            -- Brazo superior sombra
    {52,0, 60,0, 76,30, 68,30}               -- Pierna inferior sombra
}
local k_ridges = {
    {38,-26, 38,28},
    {44,-2, 68,-26},
    {48,2, 70,28}
}

-- === LETRA E ===
local e_silhouette = {
    74,-28, 126,-30, 126,-14, 88,-14, 88,-4, 114,-4, 114,6, 88,6, 88,14, 126,14, 126,30, 74,30
}
local e_top_facets = {
    {74,-28, 81,-28, 81,30, 74,30},          -- Pilar izquierdo luz
    {88,-28, 126,-30, 126,-22, 88,-22},      -- Brazo superior luz
    {88,-4, 114,-4, 114,1, 88,1},            -- Brazo central luz
    {88,14, 126,14, 126,22, 88,22}           -- Brazo inferior luz
}
local e_bot_facets = {
    {81,-28, 88,-28, 88,30, 81,30},          -- Pilar izquierdo sombra
    {88,-22, 126,-22, 126,-14, 88,-14},      -- Brazo superior sombra
    {88,1, 114,1, 114,6, 88,6},              -- Brazo central sombra
    {88,22, 126,22, 126,30, 88,30}           -- Brazo inferior sombra
}
local e_ridges = {
    {81,-26, 81,28},
    {88,-22, 124,-24},
    {88,1, 112,1},
    {88,22, 124,24}
}

-- === GEMAS Y MONTURAS METÁLICAS ===
-- Montura Superior (Cradle de acero sobre 'A')
local mount_top = {
    -32,-38, -12,-40, 0,-38, 12,-40, 32,-38, 20,-44, 0,-41, -20,-44
}
-- Montura Inferior (Cradle de acero bajo 'A')
local mount_bot = {
    -32,38, -12,40, 0,38, 12,40, 32,38, 20,44, 0,41, -20,44
}

-- Diamante Superior (Centro 0, -52)
local jewel_top_outer = { 0,-63, 13,-52, 0,-41, -13,-52 }
local jewel_top_tr    = { 0,-63, 13,-52, 0,-52 }
local jewel_top_tl    = { 0,-63, 0,-52, -13,-52 }
local jewel_top_br    = { 0,-52, 13,-52, 0,-41 }
local jewel_top_bl    = { -13,-52, 0,-52, 0,-41 }
local jewel_top_core  = { 0,-56, 4,-52, 0,-48, -4,-52 }

-- Diamante Inferior (Centro 0, +52)
local jewel_bot_outer = { 0,41, 13,52, 0,63, -13,52 }
local jewel_bot_tr    = { 0,41, 13,52, 0,52 }
local jewel_bot_tl    = { 0,41, 0,52, -13,52 }
local jewel_bot_br    = { 0,52, 13,52, 0,63 }
local jewel_bot_bl    = { -13,52, 0,52, 0,63 }
local jewel_bot_core  = { 0,48, 4,52, 0,56, -4,52 }

-- Barras de marco superior e inferior con alas
local bar_top_left  = { -132,-36, -38,-36, -38,-33, -128,-33, -136,-39 }
local bar_top_right = { 38,-36, 132,-36, 136,-39, 128,-33, 38,-33 }
local bar_bot_left  = { -132,36, -38,36, -38,33, -128,33, -136,39 }
local bar_bot_right = { 38,36, 132,36, 136,39, 128,33, 38,33 }

local function drawPolygonWithOffset(pts, ox, oy)
    local shifted = {}
    for i = 1, #pts, 2 do
        shifted[i] = pts[i] + ox
        shifted[i + 1] = pts[i + 1] + oy
    end
    love.graphics.polygon('fill', shifted)
end

local function drawPolygonLineWithOffset(pts, ox, oy)
    local shifted = {}
    for i = 1, #pts, 2 do
        shifted[i] = pts[i] + ox
        shifted[i + 1] = pts[i + 1] + oy
    end
    love.graphics.polygon('line', shifted)
end

local function drawFacetList(facets, ox, oy)
    for _, f in ipairs(facets) do
        drawPolygonWithOffset(f, ox, oy)
    end
end

local function drawRidgeList(ridges, ox, oy)
    for _, r in ipairs(ridges) do
        love.graphics.line(r[1] + ox, r[2] + oy, r[3] + ox, r[4] + oy)
    end
end

function titleDraw.draw(x, y, scale, alpha, globalTime, floatOffset)
    scale = scale or 1.0
    alpha = alpha or 1.0
    floatOffset = floatOffset or 0
    local pulse = 0.85 + math.sin((globalTime or 0) * 3) * 0.15

    love.graphics.push()
    love.graphics.translate(x, y + floatOffset)
    love.graphics.scale(scale, scale)

    -- =========================================================================
    -- PASE 1: SOMBRA 3D PROFUNDA (Black Drop Shadow offset +4, +5)
    -- =========================================================================
    love.graphics.setColor(COLOR_OUTLINE[1], COLOR_OUTLINE[2], COLOR_OUTLINE[3], alpha * 0.95)
    for _, offset in ipairs({{4, 5}, {3, 4}, {2, 3}}) do
        local ox, oy = offset[1], offset[2]
        drawPolygonWithOffset(s_silhouette, ox, oy)
        drawPolygonWithOffset(n_silhouette, ox, oy)
        drawPolygonWithOffset(a_silhouette, ox, oy)
        drawPolygonWithOffset(k_silhouette, ox, oy)
        drawPolygonWithOffset(e_silhouette, ox, oy)
        drawPolygonWithOffset(mount_top, ox, oy)
        drawPolygonWithOffset(mount_bot, ox, oy)
        drawPolygonWithOffset(jewel_top_outer, ox, oy)
        drawPolygonWithOffset(jewel_bot_outer, ox, oy)
        drawPolygonWithOffset(bar_top_left, ox, oy)
        drawPolygonWithOffset(bar_top_right, ox, oy)
        drawPolygonWithOffset(bar_bot_left, ox, oy)
        drawPolygonWithOffset(bar_bot_right, ox, oy)
    end

    -- =========================================================================
    -- PASE 2: SILUETA BASE Y BISELADO OSCURO (Dark Steel Chassis)
    -- =========================================================================
    love.graphics.setColor(COLOR_STEEL_DEEP[1], COLOR_STEEL_DEEP[2], COLOR_STEEL_DEEP[3], alpha * 0.98)
    drawPolygonWithOffset(s_silhouette, 0, 0)
    drawPolygonWithOffset(n_silhouette, 0, 0)
    drawPolygonWithOffset(a_silhouette, 0, 0)
    drawPolygonWithOffset(k_silhouette, 0, 0)
    drawPolygonWithOffset(e_silhouette, 0, 0)

    -- Monturas metálicas y barras de marco
    love.graphics.setColor(COLOR_STEEL_SHADOW[1], COLOR_STEEL_SHADOW[2], COLOR_STEEL_SHADOW[3], alpha * 0.95)
    drawPolygonWithOffset(mount_top, 0, 0)
    drawPolygonWithOffset(mount_bot, 0, 0)
    drawPolygonWithOffset(bar_top_left, 0, 0)
    drawPolygonWithOffset(bar_top_right, 0, 0)
    drawPolygonWithOffset(bar_bot_left, 0, 0)
    drawPolygonWithOffset(bar_bot_right, 0, 0)

    -- =========================================================================
    -- PASE 3: FACETAS INFERIORES METÁLICAS (Shadow Gunmetal Facets)
    -- =========================================================================
    love.graphics.setColor(COLOR_STEEL_SHADOW[1], COLOR_STEEL_SHADOW[2], COLOR_STEEL_SHADOW[3], alpha)
    drawFacetList(s_bot_facets, 0, 0)
    drawFacetList(n_bot_facets, 0, 0)
    drawFacetList(a_bot_facets, 0, 0)
    drawFacetList(k_bot_facets, 0, 0)
    drawFacetList(e_bot_facets, 0, 0)

    -- =========================================================================
    -- PASE 4: FACETAS SUPERIORES METÁLICAS (Platinum Highlight Facets)
    -- =========================================================================
    love.graphics.setColor(COLOR_STEEL_TOP[1], COLOR_STEEL_TOP[2], COLOR_STEEL_TOP[3], alpha)
    drawFacetList(s_top_facets, 0, 0)
    drawFacetList(n_top_facets, 0, 0)
    drawFacetList(a_top_facets, 0, 0)
    drawFacetList(k_top_facets, 0, 0)
    drawFacetList(e_top_facets, 0, 0)

    -- Vaciado interior de la A
    love.graphics.setColor(COLOR_STEEL_DEEP[1], COLOR_STEEL_DEEP[2], COLOR_STEEL_DEEP[3], alpha)
    drawPolygonWithOffset(a_hole, 0, 0)

    -- =========================================================================
    -- PASE 5: LÍNEAS DE CRESTA Y BISEL BRILLANTE (Chiseled Ridge Highlights)
    -- =========================================================================
    love.graphics.setLineWidth(1.5)
    love.graphics.setColor(COLOR_STEEL_HIGHLIGHT[1], COLOR_STEEL_HIGHLIGHT[2], COLOR_STEEL_HIGHLIGHT[3], alpha * 0.9)
    drawRidgeList(s_ridges, 0, 0)
    drawRidgeList(n_ridges, 0, 0)
    drawRidgeList(a_ridges, 0, 0)
    drawRidgeList(k_ridges, 0, 0)
    drawRidgeList(e_ridges, 0, 0)

    -- Biseles de montura y barras de marco en brillo cian
    love.graphics.setColor(COLOR_CYAN_LIGHT[1], COLOR_CYAN_LIGHT[2], COLOR_CYAN_LIGHT[3], alpha * 0.75)
    drawPolygonLineWithOffset(bar_top_left, 0, 0)
    drawPolygonLineWithOffset(bar_top_right, 0, 0)
    drawPolygonLineWithOffset(bar_bot_left, 0, 0)
    drawPolygonLineWithOffset(bar_bot_right, 0, 0)
    drawPolygonLineWithOffset(mount_top, 0, 0)
    drawPolygonLineWithOffset(mount_bot, 0, 0)

    -- =========================================================================
    -- PASE 6: DOBLE GEMA DE DIAMANTE CIAN (Top & Bottom Cyan Jewels)
    -- =========================================================================
    -- Gema Superior
    love.graphics.setColor(COLOR_CYAN_LIGHT[1], COLOR_CYAN_LIGHT[2], COLOR_CYAN_LIGHT[3], alpha)
    drawPolygonWithOffset(jewel_top_tr, 0, 0)
    love.graphics.setColor(COLOR_CYAN_MID[1], COLOR_CYAN_MID[2], COLOR_CYAN_MID[3], alpha)
    drawPolygonWithOffset(jewel_top_tl, 0, 0)
    love.graphics.setColor(COLOR_CYAN_GLOW[1], COLOR_CYAN_GLOW[2], COLOR_CYAN_GLOW[3], alpha)
    drawPolygonWithOffset(jewel_top_br, 0, 0)
    love.graphics.setColor(COLOR_CYAN_DARK[1], COLOR_CYAN_DARK[2], COLOR_CYAN_DARK[3], alpha)
    drawPolygonWithOffset(jewel_top_bl, 0, 0)
    -- Núcleo brillante superior
    love.graphics.setColor(1, 1, 1, alpha * 0.98)
    drawPolygonWithOffset(jewel_top_core, 0, 0)

    -- Gema Inferior
    love.graphics.setColor(COLOR_CYAN_LIGHT[1], COLOR_CYAN_LIGHT[2], COLOR_CYAN_LIGHT[3], alpha)
    drawPolygonWithOffset(jewel_bot_tr, 0, 0)
    love.graphics.setColor(COLOR_CYAN_MID[1], COLOR_CYAN_MID[2], COLOR_CYAN_MID[3], alpha)
    drawPolygonWithOffset(jewel_bot_tl, 0, 0)
    love.graphics.setColor(COLOR_CYAN_GLOW[1], COLOR_CYAN_GLOW[2], COLOR_CYAN_GLOW[3], alpha)
    drawPolygonWithOffset(jewel_bot_br, 0, 0)
    love.graphics.setColor(COLOR_CYAN_DARK[1], COLOR_CYAN_DARK[2], COLOR_CYAN_DARK[3], alpha)
    drawPolygonWithOffset(jewel_bot_bl, 0, 0)
    -- Núcleo brillante inferior
    love.graphics.setColor(1, 1, 1, alpha * 0.98)
    drawPolygonWithOffset(jewel_bot_core, 0, 0)

    -- Contornos exteriores de las gemas con pulso neón
    love.graphics.setLineWidth(2)
    love.graphics.setColor(COLOR_CYAN_GLOW[1], COLOR_CYAN_GLOW[2], COLOR_CYAN_GLOW[3], alpha * pulse)
    drawPolygonLineWithOffset(jewel_top_outer, 0, 0)
    drawPolygonLineWithOffset(jewel_bot_outer, 0, 0)
    love.graphics.setLineWidth(1)

    love.graphics.pop()
end

function titleDraw.drawGlow(x, y, scale, alpha, globalTime, floatOffset)
    scale = scale or 1.0
    alpha = alpha or 1.0
    floatOffset = floatOffset or 0
    local pulse = 0.8 + math.sin((globalTime or 0) * 3.5) * 0.2

    love.graphics.push()
    love.graphics.translate(x, y + floatOffset)
    love.graphics.scale(scale, scale)

    -- Resplandor de gemas para el bloom shader
    love.graphics.setColor(COLOR_CYAN_GLOW[1], COLOR_CYAN_GLOW[2], COLOR_CYAN_GLOW[3], alpha * pulse * 0.95)
    drawPolygonWithOffset(jewel_top_outer, 0, 0)
    drawPolygonWithOffset(jewel_bot_outer, 0, 0)

    love.graphics.setColor(1, 1, 1, alpha * pulse * 0.9)
    drawPolygonWithOffset(jewel_top_core, 0, 0)
    drawPolygonWithOffset(jewel_bot_core, 0, 0)

    -- Líneas de energía en las alas y bordes
    love.graphics.setLineWidth(2)
    love.graphics.setColor(COLOR_CYAN_MID[1], COLOR_CYAN_MID[2], COLOR_CYAN_MID[3], alpha * pulse * 0.6)
    drawPolygonLineWithOffset(jewel_top_outer, 0, 0)
    drawPolygonLineWithOffset(jewel_bot_outer, 0, 0)
    drawPolygonLineWithOffset(bar_top_left, 0, 0)
    drawPolygonLineWithOffset(bar_top_right, 0, 0)
    drawPolygonLineWithOffset(bar_bot_left, 0, 0)
    drawPolygonLineWithOffset(bar_bot_right, 0, 0)
    drawPolygonLineWithOffset(mount_top, 0, 0)
    drawPolygonLineWithOffset(mount_bot, 0, 0)
    love.graphics.setLineWidth(1)

    love.graphics.pop()
end

return titleDraw
