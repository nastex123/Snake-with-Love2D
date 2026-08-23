local shaders = {}
local constants = require("constants")
local Log = require("core.logger")

-- ============================================================
-- Corrección daltonica (Protanopia / Deuteranopia / Tritanopia)
-- ============================================================
local SRC_COLORBLIND = [[
extern mat3 colorMatrix;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 texColor = Texel(tex, uv);
    vec3 corrected = colorMatrix * texColor.rgb;
    corrected = clamp(corrected, 0.0, 1.0);
    return vec4(corrected, texColor.a) * color;
}
]]

-- Matrices de corrección daltonica (Daltonization para protanopia, deuteranopia, tritanopia)
-- Matriz 3x3 para GLSL (column-major en Love2D)
local COLORBLIND_MATRICES = {
    protanopia = {
        1.0, 0.3033, 0.3033,
        0.0, 0.6967, -0.3033,
        0.0, 0.0, 1.0,
    },
    deuteranopia = {
        0.6967, 0.0, -0.3033,
        0.3033, 1.0, 0.3033,
        0.0, 0.0, 1.0,
    },
    tritanopia = {
        1.0, 0.0, 0.0,
        -0.3033, 0.6967, 0.0,
        0.3033, 0.3033, 1.0,
    },
}

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

-- ============================================================
-- Bloom: separable gaussian, pasada H
-- ============================================================
local SRC_BLUR_H = [[
extern vec2 resolution;
extern float radius;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float w[9];
    w[0]=0.054; w[1]=0.122; w[2]=0.194; w[3]=0.230; w[4]=0.230;
    w[5]=0.194; w[6]=0.122; w[7]=0.054; w[8]=0.054;
    vec4 sum = vec4(0.0);
    float step = radius / resolution.x;
    for (int i = -4; i <= 4; i++) {
        sum += Texel(tex, uv + vec2(float(i) * step, 0.0)) * w[i + 4];
    }
    return sum * color;
}
]]

-- ============================================================
-- Bloom: pasada V
-- ============================================================
local SRC_BLUR_V = [[
extern vec2 resolution;
extern float radius;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float w[9];
    w[0]=0.054; w[1]=0.122; w[2]=0.194; w[3]=0.230; w[4]=0.230;
    w[5]=0.194; w[6]=0.122; w[7]=0.054; w[8]=0.054;
    vec4 sum = vec4(0.0);
    float step = radius / resolution.y;
    for (int i = -4; i <= 4; i++) {
        sum += Texel(tex, uv + vec2(0.0, float(i) * step)) * weights[i + 4];
    }
    return sum * color;
}
]]

-- Corregido: variable name consistency
local SRC_BLUR_V_FIXED = [[
extern vec2 resolution;
extern float radius;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float w0=0.054, w1=0.122, w2=0.194, w3=0.230, w4=0.230;
    float w5=0.194, w6=0.122, w7=0.054, w8=0.054;
    float step = radius / resolution.y;
    vec4 s = vec4(0.0);
    s += Texel(tex, uv + vec2(0.0, -4.0*step)) * w0;
    s += Texel(tex, uv + vec2(0.0, -3.0*step)) * w1;
    s += Texel(tex, uv + vec2(0.0, -2.0*step)) * w2;
    s += Texel(tex, uv + vec2(0.0, -1.0*step)) * w3;
    s += Texel(tex, uv + vec2(0.0,  0.0      )) * w4;
    s += Texel(tex, uv + vec2(0.0,  1.0*step)) * w5;
    s += Texel(tex, uv + vec2(0.0,  2.0*step)) * w6;
    s += Texel(tex, uv + vec2(0.0,  3.0*step)) * w7;
    s += Texel(tex, uv + vec2(0.0,  4.0*step)) * w8;
    return s * color;
}
]]

local SRC_BLUR_H_FIXED = [[
extern vec2 resolution;
extern float radius;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float w0=0.054, w1=0.122, w2=0.194, w3=0.230, w4=0.230;
    float w5=0.194, w6=0.122, w7=0.054, w8=0.054;
    float step = radius / resolution.x;
    vec4 s = vec4(0.0);
    s += Texel(tex, uv + vec2(-4.0*step, 0.0)) * w0;
    s += Texel(tex, uv + vec2(-3.0*step, 0.0)) * w1;
    s += Texel(tex, uv + vec2(-2.0*step, 0.0)) * w2;
    s += Texel(tex, uv + vec2(-1.0*step, 0.0)) * w3;
    s += Texel(tex, uv + vec2( 0.0,      0.0)) * w4;
    s += Texel(tex, uv + vec2( 1.0*step, 0.0)) * w5;
    s += Texel(tex, uv + vec2( 2.0*step, 0.0)) * w6;
    s += Texel(tex, uv + vec2( 3.0*step, 0.0)) * w7;
    s += Texel(tex, uv + vec2( 4.0*step, 0.0)) * w8;
    return s * color;
}
]]

-- ============================================================
-- Sombra difusa bajo la serpiente
-- ============================================================
local SRC_SHADOW = [[
extern vec2 resolution;
extern float softness;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float alpha = 0.0;
    float total = 0.0;
    float s = softness;
    for (int x = -3; x <= 3; x++) {
        for (int y = 0; y <= 4; y++) {
            vec2 off = vec2(float(x), float(y)) * s / resolution;
            float dist = float(x*x + y*y);
            float w = 1.0 / (1.0 + dist * 0.4);
            alpha += Texel(tex, uv + off).a * w;
            total += w;
        }
    }
    alpha /= total;
    return vec4(0.0, 0.0, 0.0, alpha * 0.5) * color;
}
]]

-- ============================================================
-- Distorsión de calor (menú)
-- ============================================================
local SRC_HEAT = [[
extern float time;
extern float strength;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float nx = sin(uv.y * 18.0 + time * 2.3) * 0.0009 * strength;
    float ny = cos(uv.x * 14.0 + time * 1.7) * 0.0006 * strength;
    return Texel(tex, vec2(uv.x + nx, uv.y + ny)) * color;
}
]]

-- ============================================================
-- Balatro background: domain warping + spiral (original style)
-- ============================================================

local SRC_BALATRO_BG = [[
extern float time;
extern float spin_time;
extern vec4 colour_1;
extern vec4 colour_2;
extern vec4 colour_3;
extern float contrast;
extern float spin_amount;

#define PIXEL_SIZE_FAC 700.
#define SPIN_EASE 0.5

vec4 effect( vec4 colour, Image texture, vec2 texture_coords, vec2 screen_coords )
{
    float pixel_size = length(love_ScreenSize.xy)/PIXEL_SIZE_FAC;
    vec2 uv = (floor(screen_coords.xy*(1./pixel_size))*pixel_size - 0.5*love_ScreenSize.xy)/length(love_ScreenSize.xy);
    float uv_len = length(uv);

    float speed = (spin_time*SPIN_EASE*0.2) + 302.2;
    float new_pixel_angle = (atan(uv.y, uv.x)) + speed - SPIN_EASE*20.*(1.*spin_amount*uv_len + (1. - 1.*spin_amount));
    vec2 mid = (love_ScreenSize.xy/length(love_ScreenSize.xy))/2.;
    uv = (vec2((uv_len * cos(new_pixel_angle) + mid.x), (uv_len * sin(new_pixel_angle) + mid.y)) - mid);

    uv *= 30.;
    speed = time*(2.);
    vec2 uv2 = vec2(uv.x+uv.y);

    for(int i=0; i < 5; i++) {
        uv2 += sin(max(uv.x, uv.y)) + uv;
        uv  += 0.5*vec2(cos(5.1123314 + 0.353*uv2.y + speed*0.131121), sin(uv2.x - 0.113*speed));
        uv  -= 1.0*cos(uv.x + uv.y) - 1.0*sin(uv.x*0.711 - uv.y);
    }

    float contrast_mod = (0.25*contrast + 0.5*spin_amount + 1.2);
    float paint_res = min(2., max(0., length(uv)*(0.035)*contrast_mod));
    float c1p = max(0.,1. - contrast_mod*abs(1.-paint_res));
    float c2p = max(0.,1. - contrast_mod*abs(paint_res));
    float c3p = 1. - min(1., c1p + c2p);

    vec4 ret_col = (0.3/contrast)*colour_1 + (1. - 0.3/contrast)*(colour_1*c1p + colour_2*c2p + vec4(c3p*colour_3.rgb, c3p*colour_1.a));

    return ret_col;
}
]]

local canvasScene, canvasGlow, canvasGlowLow, canvasBlurH, canvasBlurV, canvasShadow, canvasShadowBlur, canvasFinal, canvasPost
local shCRT, shBlurH, shBlurV, shShadow, shHeat, shBalatro, shColorblind
local W, H, BW, BH

-- Estado de efectos (feedback de daño): decae en shaders.update(dt)
local fx = {
    damage = 0,
    shake = 0,
}

function shaders.triggerDamage(amount, shakeAmount)
    fx.damage = math.max(fx.damage, amount or 0.7)
    fx.shake = math.max(fx.shake, shakeAmount or 0.6)
end

function shaders.update(dt)
    fx.damage = math.max(0, fx.damage - dt * 2.2)
    fx.shake = math.max(0, fx.shake - dt * 3.0)
end

function shaders.getFX()
    return fx
end

local function tryShader(src)
    local ok, s = pcall(love.graphics.newShader, src)
    if not ok then
        Log.warn("shaders.tryShader failed: " .. tostring(s))
    end
    return ok and s or nil
end

function shaders.load()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    BW = math.max(1, math.floor(W / 2))
    BH = math.max(1, math.floor(H / 2))

    shCRT    = tryShader(SRC_CRT)
    shBlurH  = tryShader(SRC_BLUR_H_FIXED)
    shBlurV  = tryShader(SRC_BLUR_V_FIXED)
    shShadow = tryShader(SRC_SHADOW)
    shHeat   = tryShader(SRC_HEAT)
    shBalatro = tryShader(SRC_BALATRO_BG)
    shColorblind = tryShader(SRC_COLORBLIND)

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

    canvasScene       = newC()
    canvasGlow        = newC()
    canvasGlowLow     = newCLow()
    canvasBlurH       = newCLow()
    canvasBlurV       = newCLow()
    canvasShadow      = newC()
    canvasShadowBlur  = newC()
    canvasFinal       = newC()
    canvasPost        = newC()
end

-- Recreate canvases and apply filter settings (filter: 'nearest' | 'linear')
function shaders.recreateCanvases(pixelScale, filter)
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()
    BW = math.max(1, math.floor(W / 2))
    BH = math.max(1, math.floor(H / 2))
    local function newC()
        local c = love.graphics.newCanvas(W, H)
        local f = filter == 'nearest' and 'nearest' or 'linear'
        c:setFilter(f, f)
        return c
    end
    local function newCLow()
        local c = love.graphics.newCanvas(BW, BH)
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

    if applyCB then
        -- 6a. CRT sobre canvasFinal → canvasPost
        love.graphics.setCanvas(canvasPost)
        love.graphics.clear(0, 0, 0, 1)
        if shCRT then
            shCRT:send("resolution", {W, H})
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
        love.graphics.draw(canvasPost, 0, 0)
        love.graphics.setShader()
    else
        -- 6. CRT sobre canvasFinal → backbuffer directo
        love.graphics.setCanvas()
        if shCRT then
            shCRT:send("resolution", {W, H})
            shCRT:send("time", time)
            shCRT:send("intensity", finalCrt)
            shCRT:send("damageFlash", fx.damage or 0)
            shCRT:send("shake", fx.shake or 0)
            love.graphics.setShader(shCRT)
        end
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(canvasFinal, 0, 0)
        love.graphics.setShader()
    end
end

return shaders
