local shaders = {}
local constants = require("constants")

-- ============================================================
-- CRT: scanlines + vignette + chromatic aberration + grain
-- ============================================================
local SRC_CRT = [[
extern vec2 resolution;
extern float time;
extern float intensity;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float ca = 0.0012 * intensity;
    float r = Texel(tex, vec2(uv.x + ca, uv.y)).r;
    float g = Texel(tex, uv).g;
    float b = Texel(tex, vec2(uv.x - ca, uv.y)).b;
    vec4 col = vec4(r, g, b, Texel(tex, uv).a);

    float scan = sin(uv.y * resolution.y * 1.5) * 0.5 + 0.5;
    col.rgb *= 1.0 - scan * 0.055 * intensity;

    vec2 vc = uv - 0.5;
    float vig = 1.0 - dot(vc, vc) * 2.0 * intensity;
    col.rgb *= clamp(vig, 0.0, 1.0);

    float grain = fract(sin(dot(uv * resolution + time * 80.0,
        vec2(127.1, 311.7))) * 43758.5453);
    col.rgb += (grain - 0.5) * 0.016 * intensity;

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
-- Balatro background: domain warping fluid
-- ============================================================
-- -------------------------------------------------------------
-- Balatro background shader – VORTEX FAN version
-- -------------------------------------------------------------
-- Vortex with "fan blades" (aletas de abanico): the rotation is
-- modulated by a sine that creates N discrete arms, producing
-- separated lobes instead of a smooth continuous swirl.
-- Hard‑coded uniforms: vortexAngle, vortexStrength, numArms.
-- Edit the values in `shaders.drawBalatroBG` to tweak the look.


local SRC_BALATRO_BG = [[
extern vec2 resolution;
extern float time;
extern float comboIntensity;
// Vortex specific uniforms (hard‑coded in Lua)
extern float vortexAngle;
extern float vortexStrength;
extern float numArms;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    // Normalised screen coordinates ([-1,1] range with aspect correction)
    vec2 p = gl_FragCoord.xy / resolution.xy;
    vec2 q = p * 3.0 - 1.5;
    q.x *= resolution.x / resolution.y;
    float ci = comboIntensity;
    float t = time * 0.2 + ci * 1.2;

    // -----------------------------------------------------
    // VORTEX FAN DISTORTION (aletas de abanico)
    // -----------------------------------------------------
    // sin(numArms * angle) creates N discrete lobes.
    // pow(...) sharpens them so blades look separated.
    // vortexAngle rotates the whole pattern over time.
    // vortexStrength controls the pull intensity.
    // numArms = number of fan blades (6 = hexagonal fan).
    vec2 uvc = q;
    float dist = length(uvc);
    float angle = atan(uvc.y, uvc.x);

    float blade = sin(numArms * angle + vortexAngle);
    blade = pow(abs(blade), 0.6) * sign(blade);

    angle += blade * dist * vortexStrength;
    q = vec2(cos(angle), sin(angle)) * dist;
    // -----------------------------------------------------

    // Original fluid‑like perturbations (unchanged)
    for (int i = 0; i < 6; i++) {
        float fi = float(i);
        float amp = 0.8 + ci * 0.2;
        float amp2 = 0.4 + ci * 0.2;
        q = vec2(
            sin(q.x * 1.2 + q.y * 0.8 + t + fi * 0.5) * amp + cos(t * 0.3 + q.y * 0.5) * amp2,
            cos(q.x * 0.7 + q.y * 1.3 + t * 0.7 + fi * 0.3) * amp + sin(t * 0.4 + q.x * 0.6) * amp2
        );
        q = q * 1.1 + p * 1.2 - 0.4;
    }

    float d = length(q);

    vec3 c1 = vec3(0.05, 0.05, 0.08);
    vec3 c2 = vec3(0.8 + ci * 0.2, 0.08 - ci * 0.03, 0.1 - ci * 0.05);
    vec3 c3 = vec3(ci * 0.1, 0.35 + ci * 0.15, 0.7 + ci * 0.3);

    float w1 = sin(d * 2.5 + t) * 0.5 + 0.5;
    float w2 = sin(d * 3.5 - t * 1.5 + 1.2) * 0.5 + 0.5;
    float w3 = sin(d * 1.8 + t * 0.6 + 2.5) * 0.5 + 0.5;

    vec3 col = c1;
    col = mix(col, c2, w1 * (0.6 + ci * 0.2));
    col = mix(col, c3, w2 * (0.4 + ci * 0.2));
    col = mix(col, c1, w3 * 0.25);

    vec3 hot = vec3(1.0, 0.5, 0.05);
    float hotFactor = ci * (sin(d * 6.0 + t * 3.0) * 0.3 + 0.5);
    col = mix(col, hot, hotFactor);

    vec3 glow = vec3(1.0, 0.6, 0.0);
    col += glow * ci * (sin(d * 4.0 + t * 2.0) * 0.3 + 0.3) * 0.15;

    return vec4(col, 1.0);
}
]]

local canvasScene, canvasGlow, canvasBlurH, canvasBlurV, canvasShadow, canvasShadowBlur, canvasFinal
local shCRT, shBlurH, shBlurV, shShadow, shHeat, shBalatro
local W, H

local function tryShader(src)
    local ok, s = pcall(love.graphics.newShader, src)
    if not ok then
        -- print("Shader error: " .. tostring(s))
    end
    return ok and s or nil
end

function shaders.load()
    W = love.graphics.getWidth()
    H = love.graphics.getHeight()

    shCRT    = tryShader(SRC_CRT)
    shBlurH  = tryShader(SRC_BLUR_H_FIXED)
    shBlurV  = tryShader(SRC_BLUR_V_FIXED)
    shShadow = tryShader(SRC_SHADOW)
    shHeat   = tryShader(SRC_HEAT)
    shBalatro = tryShader(SRC_BALATRO_BG)

    local function newC()
        local c = love.graphics.newCanvas(W, H)
        c:setFilter("linear", "linear")
        return c
    end

    canvasScene       = newC()
    canvasGlow        = newC()
    canvasBlurH       = newC()
    canvasBlurV       = newC()
    canvasShadow      = newC()
    canvasShadowBlur  = newC()
    canvasFinal       = newC()
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

function shaders.drawBalatroBG(time, comboIntensity)
    if shBalatro then
        shBalatro:send("resolution", {W, H})
        shBalatro:send("time", time)
        shBalatro:send("comboIntensity", comboIntensity or 0)
        -- Vortex fan uniforms (hard‑coded values). Adjust here to tweak the look.
        local vortexAngle = time * 0.8          -- rotation speed (rad per second)
        local vortexStrength = 0.9               -- pull strength (0‑1)
        local numArms = 6.0                      -- number of fan blades
        shBalatro:send("vortexAngle", vortexAngle)
        shBalatro:send("vortexStrength", vortexStrength)
        shBalatro:send("numArms", numArms)
        love.graphics.setShader(shBalatro)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, W, H)
    love.graphics.setShader()
end

function shaders.composite(time, crtIntensity, isMenu)
    -- 1. Bloom H
    love.graphics.setCanvas(canvasBlurH)
    love.graphics.clear(0, 0, 0, 0)
    if shBlurH then
        shBlurH:send("resolution", {W, H})
        shBlurH:send("radius", 3.0)
        love.graphics.setShader(shBlurH)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvasGlow, 0, 0)
    love.graphics.setShader()

    -- 2. Bloom V
    love.graphics.setCanvas(canvasBlurV)
    love.graphics.clear(0, 0, 0, 0)
    if shBlurV then
        shBlurV:send("resolution", {W, H})
        shBlurV:send("radius", 3.0)
        love.graphics.setShader(shBlurV)
    end
    love.graphics.draw(canvasBlurH, 0, 0)
    love.graphics.setShader()

    -- 3. Shadow blur
    love.graphics.setCanvas(canvasShadowBlur)
    love.graphics.clear(0, 0, 0, 0)
    if shShadow then
        shShadow:send("resolution", {W, H})
        shShadow:send("softness", 4.5)
        love.graphics.setShader(shShadow)
    end
    love.graphics.draw(canvasShadow, 0, 0)
    love.graphics.setShader()

    -- 4. Componer en canvasFinal
    love.graphics.setCanvas(canvasFinal)
    love.graphics.clear(0, 0, 0, 1)

    -- 4a. Escena base (con heat distortion opcional)
    if isMenu and shHeat then
        shHeat:send("time", time)
        shHeat:send("strength", 1.0)
        love.graphics.setShader(shHeat)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvasScene, 0, 0)
    love.graphics.setShader()

    -- 4b. Sombra con offset
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvasShadowBlur, 5, 7)

    -- 4c. Bloom additive
    love.graphics.setBlendMode("add")
    love.graphics.setColor(1, 1, 1, 0.6)
    love.graphics.draw(canvasBlurV, 0, 0)
    love.graphics.setBlendMode("alpha")

    love.graphics.setCanvas()

    -- 5. CRT sobre canvasFinal → backbuffer
    if shCRT then
        shCRT:send("resolution", {W, H})
        shCRT:send("time", time)
        shCRT:send("intensity", crtIntensity or 0.75)
        love.graphics.setShader(shCRT)
    end
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvasFinal, 0, 0)
    love.graphics.setShader()
end

return shaders
