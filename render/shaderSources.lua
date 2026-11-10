local Sources = {}
Sources.SRC_COLORBLIND = [[
extern mat3 colorMatrix;

vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    vec4 texColor = Texel(tex, uv);
    vec3 corrected = colorMatrix * texColor.rgb;
    corrected = clamp(corrected, 0.0, 1.0);
    return vec4(corrected, texColor.a) * color;
}
]]
Sources.COLORBLIND_MATRICES = {
    protanopia = {1.0, 0.3033, 0.3033, 0.0, 0.6967, -0.3033, 0.0, 0.0, 1.0},
    deuteranopia = {0.6967, 0.0, -0.3033, 0.3033, 1.0, 0.3033, 0.0, 0.0, 1.0},
    tritanopia = {1.0, 0.0, 0.0, -0.3033, 0.6967, 0.0, 0.3033, 0.3033, 1.0},
}
Sources.SRC_BLUR_V_FIXED = [[
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
Sources.SRC_BLUR_H_FIXED = [[
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
Sources.SRC_SHADOW = [[
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
Sources.SRC_HEAT = [[
extern float time;
extern float strength;
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    float nx = sin(uv.y * 18.0 + time * 2.3) * 0.0009 * strength;
    float ny = cos(uv.x * 14.0 + time * 1.7) * 0.0006 * strength;
    return Texel(tex, vec2(uv.x + nx, uv.y + ny)) * color;
}
]]
Sources.SRC_VORONOI = [[
extern vec2 resolution;
extern float time;
extern float scale;
extern float progress;
vec2 hash2(vec2 p) {
    p = vec2(dot(p, vec2(127.1, 311.7)), dot(p, vec2(269.5, 183.3)));
    return -1.0 + 2.0 * fract(sin(p) * 43758.5453123);
}
float voronoi(vec2 x) {
    vec2 n = floor(x);
    vec2 f = fract(x);
    float minDist = 8.0;
    for (int j = -1; j <= 1; j++) {
        for (int i = -1; i <= 1; i++) {
            vec2 g = vec2(float(i), float(j));
            vec2 o = hash2(n + g);
            vec2 r = g + o - f;
            float d = dot(r, r);
            minDist = min(minDist, d);
        }
    }
    return sqrt(minDist);
}
vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
    if (progress <= 0.01) return Texel(tex, uv) * color;
    float v = voronoi(uv * scale);
    float crack = smoothstep(0.0, 0.15, v) * progress;
    vec4 base = Texel(tex, uv);
    vec3 tint = mix(vec3(1.0), vec3(0.9, 0.2, 0.3), crack * 0.4);
    return vec4(base.rgb * tint, base.a) * color;
}
]]
Sources.SRC_BALATRO_BG = [[
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
return Sources
