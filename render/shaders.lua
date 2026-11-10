local shaders = {}
local constants = require("constants")
local Log = require("core.logger")

local uiMod = nil
local function getUI()
    if not uiMod then
        local ok, m = pcall(require, "ui.ui")
        if ok and m then uiMod = m end
    end
    return uiMod
end

local Sources = require("render.shaderSources")
local SRC_COLORBLIND = Sources.SRC_COLORBLIND
local COLORBLIND_MATRICES = Sources.COLORBLIND_MATRICES

-- ============================================================
-- CRT: curvatura + scanlines + vignette + chromatic aberration
--      + grain + damage flash + screen shake
-- ============================================================
local SRC_CRT = [[
extern vec2 resolution;
extern float time;
extern float intensity;
extern float damageFlash;
extern float shake;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec2 base_uv = uv;

    // Curvatura CRT
    vec2 dc = base_uv - 0.5;
    float r2 = dot(dc, dc);
    vec2 curved_uv = base_uv + dc * r2 * (0.16 * intensity);

    // Bordes negros si se sale de la pantalla
    if (curved_uv.x < 0.0 || curved_uv.x > 1.0 || curved_uv.y < 0.0 || curved_uv.y > 1.0) {
        return vec4(0.0, 0.0, 0.0, 1.0) * color;
    }

    // Screen shake
    float shake_amp = shake * 0.0045;
    vec2 shake_offset = vec2(
        sin(time * 63.0) + sin(time * 17.0) * 0.5,
        cos(time * 49.0) + cos(time * 23.0) * 0.5
    ) * shake_amp;

    vec2 suv = curved_uv + shake_offset;
    suv = clamp(suv, 0.0, 1.0);

    // Aberración cromática
    float ca = 0.0012 * intensity;
    float r = Texel(tex, vec2(suv.x + ca, suv.y)).r;
    float g = Texel(tex, suv).g;
    float b = Texel(tex, vec2(suv.x - ca, suv.y)).b;
    vec4 col = vec4(r, g, b, Texel(tex, suv).a);

    // Scanlines
    float scan = sin(suv.y * resolution.y * 1.5) * 0.5 + 0.5;
    col.rgb *= 1.0 - scan * 0.055 * intensity;

    // Vignette
    vec2 vc = suv - 0.5;
    float vig = 1.0 - dot(vc, vc) * 2.0 * intensity;
    col.rgb *= clamp(vig, 0.0, 1.0);

    // Grain
    float grain = fract(sin(dot(suv * resolution + time * 80.0,
        vec2(127.1, 311.7))) * 43758.5453);
    col.rgb += (grain - 0.5) * 0.016 * intensity;

    // Damage flash
    float flash = clamp(damageFlash, 0.0, 1.0);
    col.rgb = mix(col.rgb, vec3(1.0, 0.10, 0.12), flash * 0.55);

    return col * color;
}
]]

local SRC_BLUR_V_FIXED = Sources.SRC_BLUR_V_FIXED
local SRC_BLUR_H_FIXED = Sources.SRC_BLUR_H_FIXED

local SRC_SHADOW = Sources.SRC_SHADOW
local SRC_HEAT = Sources.SRC_HEAT

local SRC_VORONOI = Sources.SRC_VORONOI

-- ============================================================
-- Balatro background: domain warping + spiral (original style)
-- ============================================================

local SRC_BALATRO_BG = Sources.SRC_BALATRO_BG

local canvasScene, canvasGlow, canvasGlowLow, canvasBlurH, canvasBlurV, canvasShadow, canvasShadowBlur, canvasFinal, canvasPost, canvasReflection
local shCRT, shBlurH, shBlurV, shShadow, shHeat, shBalatro, shColorblind, shVoronoi
local W, H, BW, BH, RW, RH

local FxMod = require("render.shaderFx")
local fx = FxMod.state
function shaders.triggerDamage(amount, shakeAmount) return FxMod.trigger(amount, shakeAmount) end
function shaders.update(dt) return FxMod.update(dt) end
function shaders.getFX() return FxMod.get() end

local function releaseCanvas(c)
    if c and (type(c) == "userdata" or type(c) == "table") then
        if c.release then
            pcall(function() c:release() end)
        end
    end
end

function shaders.releaseCanvases()
    releaseCanvas(canvasScene)
    releaseCanvas(canvasGlow)
    releaseCanvas(canvasGlowLow)
    releaseCanvas(canvasBlurH)
    releaseCanvas(canvasBlurV)
    releaseCanvas(canvasShadow)
    releaseCanvas(canvasShadowBlur)
    releaseCanvas(canvasFinal)
    releaseCanvas(canvasPost)
    releaseCanvas(canvasReflection)
    canvasScene, canvasGlow, canvasGlowLow = nil, nil, nil
    canvasBlurH, canvasBlurV = nil, nil
    canvasShadow, canvasShadowBlur = nil, nil
    canvasFinal, canvasPost = nil, nil
    canvasReflection = nil
end

function shaders.getCanvases()
    return {
        scene = canvasScene,
        glow = canvasGlow,
        glowLow = canvasGlowLow,
        blurH = canvasBlurH,
        blurV = canvasBlurV,
        shadow = canvasShadow,
        shadowBlur = canvasShadowBlur,
        final = canvasFinal,
        post = canvasPost,
        reflection = canvasReflection
    }
end

function shaders.getShaders()
    return {
        crt = shCRT,
        blurH = shBlurH,
        blurV = shBlurV,
        shadow = shShadow,
        heat = shHeat,
        balatro = shBalatro,
        colorblind = shColorblind,
        voronoi = shVoronoi
    }
end

local function tryShader(src)
    local ok, s = pcall(love.graphics.newShader, src)
    if not ok then
        Log.warn("shaders.tryShader failed: " .. tostring(s))
    end
    return ok and s or nil
end

function shaders.load()
    shaders.releaseCanvases()

    local ps = tonumber(shaders.pixelScale) or 1
    if ps < 1 then ps = 1 end
    local realW = love.graphics.getWidth()
    local realH = love.graphics.getHeight()
    W = math.max(1, math.floor(realW / ps))
    H = math.max(1, math.floor(realH / ps))
    BW = math.max(1, math.floor(W / 2))
    BH = math.max(1, math.floor(H / 2))
    local refScale = constants.REFLECTION_SCALE or 0.5
    RW = math.max(1, math.floor(W * refScale))
    RH = math.max(1, math.floor(H * refScale))

    shCRT    = tryShader(SRC_CRT)
    shBlurH  = tryShader(SRC_BLUR_H_FIXED)
    shBlurV  = tryShader(SRC_BLUR_V_FIXED)
    shShadow = tryShader(SRC_SHADOW)
    shHeat   = tryShader(SRC_HEAT)
    shBalatro = tryShader(SRC_BALATRO_BG)
    shColorblind = tryShader(SRC_COLORBLIND)
    shVoronoi = (constants.ENABLE_VORONOI and tryShader(SRC_VORONOI)) or nil

    local function newC()
        local c = love.graphics.newCanvas(W, H)
        c:setFilter("linear", "linear")
        return c
    end

    -- Bloom a media resolución: blur más barato y visualmente equivalente.
    -- Filtro linear siempre (el bloom es luz difusa; nearest lo rompería).
    local function newCLow()
        local c = love.graphics.newCanvas(BW, BH)
        c:setFilter("linear", "linear")
        return c
    end

    local function newCRef()
        local c = love.graphics.newCanvas(RW, RH)
        c:setFilter("linear", "linear")
        return c
    end

    canvasScene       = newC()
    canvasGlow        = newC()
    canvasGlowLow     = newCLow()
    canvasBlurH       = newCLow()
    canvasBlurV       = newCLow()
    canvasShadow      = newC()
    canvasShadowBlur  = newC()
    canvasFinal       = newC()
    canvasPost        = newC()
    canvasReflection  = newCRef()
end

shaders.currentFilter = 'linear'

function shaders.getFilter()
    return shaders.currentFilter or 'linear'
end

function shaders.setFilter(filter)
    local f = (filter == 'nearest' or filter == 'linear') and filter or 'linear'
    shaders.currentFilter = f
    if canvasScene and canvasScene.setFilter then pcall(function() canvasScene:setFilter(f, f) end) end
    if canvasGlow and canvasGlow.setFilter then pcall(function() canvasGlow:setFilter(f, f) end) end
    -- Bloom / blur canvases must strictly remain linear for smooth lighting diffusion
    if canvasGlowLow and canvasGlowLow.setFilter then pcall(function() canvasGlowLow:setFilter("linear", "linear") end) end
    if canvasBlurH and canvasBlurH.setFilter then pcall(function() canvasBlurH:setFilter("linear", "linear") end) end
    if canvasBlurV and canvasBlurV.setFilter then pcall(function() canvasBlurV:setFilter("linear", "linear") end) end
    if canvasShadow and canvasShadow.setFilter then pcall(function() canvasShadow:setFilter(f, f) end) end
    if canvasShadowBlur and canvasShadowBlur.setFilter then pcall(function() canvasShadowBlur:setFilter("linear", "linear") end) end
    if canvasFinal and canvasFinal.setFilter then pcall(function() canvasFinal:setFilter(f, f) end) end
    if canvasPost and canvasPost.setFilter then pcall(function() canvasPost:setFilter(f, f) end) end
    if canvasReflection and canvasReflection.setFilter then pcall(function() canvasReflection:setFilter("linear", "linear") end) end
end

function shaders.needsRecreate(oldG, newG)
    if not oldG or not newG then return true end
    if oldG.pixelScale ~= newG.pixelScale then return true end
    if oldG.fullscreen ~= newG.fullscreen then return true end
    if oldG.vsync ~= newG.vsync then return true end
    local ra, rb = oldG.resolution, newG.resolution
    local resEq = false
    if ra == rb then resEq = true
    elseif ra == nil and rb == nil then resEq = true
    elseif ra == nil or rb == nil then resEq = false
    elseif ra.width == rb.width and ra.height == rb.height then resEq = true end
    if not resEq then return true end
    if oldG.filter ~= newG.filter then return false end
    return false
end

shaders.pixelScale = 1

function shaders.getPixelScale()
    return shaders.pixelScale or 1
end

-- Recreate canvases (respeta filter param; evita recreate si solo cambia filter via setFilter)
function shaders.recreateCanvases(pixelScale, filter)
    local f = (filter == 'nearest' or filter == 'linear') and filter or (shaders.currentFilter or 'linear')
    shaders.releaseCanvases()

    local ps = tonumber(pixelScale) or tonumber(shaders.pixelScale) or 1
    if ps < 1 then ps = 1 end
    shaders.pixelScale = ps

    local realW = love.graphics.getWidth()
    local realH = love.graphics.getHeight()
    W = math.max(1, math.floor(realW / ps))
    H = math.max(1, math.floor(realH / ps))
    BW = math.max(1, math.floor(W / 2))
    BH = math.max(1, math.floor(H / 2))
    local refScale = constants.REFLECTION_SCALE or 0.5
    RW = math.max(1, math.floor(W * refScale))
    RH = math.max(1, math.floor(H * refScale))
    local function newC()
        local c = love.graphics.newCanvas(W, H)
        c:setFilter(f, f)
        return c
    end
    local function newCLow()
        local c = love.graphics.newCanvas(BW, BH)
        c:setFilter("linear", "linear")
        return c
    end
    local function newCRef()
        local c = love.graphics.newCanvas(RW, RH)
        c:setFilter("linear", "linear")
        return c
    end
    canvasScene       = newC()
    canvasGlow        = newC()
    canvasGlowLow     = newCLow()
    canvasBlurH       = newCLow()
    canvasBlurV       = newCLow()
    canvasShadow      = newC()
    canvasShadowBlur  = newC()
    canvasFinal       = newC()
    canvasPost        = newC()
    canvasReflection  = newCRef()
    if shVoronoi == nil and constants.ENABLE_VORONOI then
        shVoronoi = tryShader(SRC_VORONOI)
    end
end

function shaders.beginScene(br, bg, bb)
    love.graphics.setCanvas(canvasScene)
    love.graphics.clear(
        br or constants.COLOR_BG[1],
        bg or constants.COLOR_BG[2],
        bb or constants.COLOR_BG[3],
        1
    )
end

function shaders.beginGlow()
    love.graphics.setCanvas(canvasGlow)
    love.graphics.clear(0, 0, 0, 0)
end

function shaders.beginShadow()
    love.graphics.setCanvas(canvasShadow)
    love.graphics.clear(0, 0, 0, 0)
end

function shaders.drawBalatroBG(time, intensity)
    if shBalatro then
        shBalatro:send("time", time)
        shBalatro:send("spin_time", time)

        local i = intensity or 0
        shBalatro:send("colour_1", {0.07, 0.07, 0.12, 1})

        local c2_r = 0.0 + i * 0.8
        local c2_g = 0.85 - i * 0.55
        local c2_b = 1.0 - i * 0.9
        shBalatro:send("colour_2", {c2_r, c2_g, c2_b, 1})

        local c3_r = 0.9 - i * 0.8
        local c3_g = 0.2 + i * 0.6
        local c3_b = 0.2 + i * 0.8
        shBalatro:send("colour_3", {c3_r, c3_g, c3_b, 1})

        local ui = getUI()
        local isHighContrast = ui and ui.highContrast
        local bgContrast = isHighContrast and 1.6 or 1.2
        shBalatro:send("contrast", bgContrast)
        shBalatro:send("spin_amount", i)
        love.graphics.setShader(shBalatro)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setShader()
end

function shaders.composite(time, crtIntensity, isMenu)
    -- 1. Downsample del glow a media resolución
    love.graphics.setCanvas(canvasGlowLow)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvasGlow, 0, 0, 0, BW / W, BH / H)

    -- 2. Bloom H (media resolución)
    love.graphics.setCanvas(canvasBlurH)
    love.graphics.clear(0, 0, 0, 0)
    if shBlurH then
        shBlurH:send("resolution", {BW, BH})
        shBlurH:send("radius", 2.0)
        love.graphics.setShader(shBlurH)
    end
    love.graphics.draw(canvasGlowLow, 0, 0)
    love.graphics.setShader()

    -- 3. Bloom V (media resolución)
    love.graphics.setCanvas(canvasBlurV)
    love.graphics.clear(0, 0, 0, 0)
    if shBlurV then
        shBlurV:send("resolution", {BW, BH})
        shBlurV:send("radius", 2.0)
        love.graphics.setShader(shBlurV)
    end
    love.graphics.draw(canvasBlurH, 0, 0)
    love.graphics.setShader()

    -- 4. Shadow blur (full resolution)
    love.graphics.setCanvas(canvasShadowBlur)
    love.graphics.clear(0, 0, 0, 0)
    if shShadow then
        shShadow:send("resolution", {W, H})
        shShadow:send("softness", 4.5)
        love.graphics.setShader(shShadow)
    end
    love.graphics.draw(canvasShadow, 0, 0)
    love.graphics.setShader()

    -- 5. Componer en canvasFinal
    love.graphics.setCanvas(canvasFinal)
    love.graphics.clear(0, 0, 0, 1)

    -- 5a. Escena base (con heat distortion opcional)
    if isMenu and shHeat then
        shHeat:send("time", time)
        shHeat:send("strength", 1.0)
        love.graphics.setShader(shHeat)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvasScene, 0, 0)
    love.graphics.setShader()

    -- 5b. Sombra con offset
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvasShadowBlur, 5, 7)

    -- 5c. Bloom additive (escalado de vuelta a resolución completa)
    local ui = getUI()
    local isHighContrast = ui and ui.highContrast
    local bloomAlpha = isHighContrast and 0.15 or 0.6
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, bloomAlpha)
    love.graphics.draw(canvasBlurV, 0, 0, 0, W / BW, H / BH)
    love.graphics.setBlendMode("alpha")

    love.graphics.setCanvas()

    -- 6. CRT y Corrección Daltoniana sobre canvasFinal → backbuffer
    local finalCrt = crtIntensity or 0.75
    if isHighContrast then
        finalCrt = math.min(1.0, finalCrt * 1.25)
    end

    local colorblindMode = ui and ui.colorblind
    local cbMatrix = (colorblindMode and colorblindMode ~= "off") and COLORBLIND_MATRICES[colorblindMode] or nil
    local applyCB = cbMatrix and shColorblind and canvasPost

    local ps = tonumber(shaders.pixelScale) or 1
    if ps < 1 then ps = 1 end

    local realW, realH = love.graphics.getWidth(), love.graphics.getHeight()

    if applyCB then
        -- 6a. CRT sobre canvasFinal → canvasPost
        love.graphics.setCanvas(canvasPost)
        love.graphics.clear(0, 0, 0, 1)
        if shCRT then
            shCRT:send("resolution", {realW, realH})
            shCRT:send("time", time)
            shCRT:send("intensity", finalCrt)
            shCRT:send("damageFlash", fx.damage or 0)
            shCRT:send("shake", fx.shake or 0)
            love.graphics.setShader(shCRT)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvasFinal, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()

        -- 6b. Colorblind pass sobre canvasPost → backbuffer
        shColorblind:send("colorMatrix", cbMatrix)
        love.graphics.setShader(shColorblind)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvasPost, 0, 0, 0, ps, ps)
        love.graphics.setShader()
    else
        -- 6. CRT sobre canvasFinal → backbuffer directo (escalado por pixelScale)
        love.graphics.setCanvas()
        if shCRT then
            shCRT:send("resolution", {realW, realH})
            shCRT:send("time", time)
            shCRT:send("intensity", finalCrt)
            shCRT:send("damageFlash", fx.damage or 0)
            shCRT:send("shake", fx.shake or 0)
            love.graphics.setShader(shCRT)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvasFinal, 0, 0, 0, ps, ps)
        love.graphics.setShader()
    end
end

return shaders
