local easings = {}
easings.linear = function(t) return t end
easings.quadIn = function(t) return t * t end
easings.quadOut = function(t) return t * (2 - t) end
easings.quadInOut = function(t)
    if t < 0.5 then return 2 * t * t
    else return -1 + (4 - 2 * t) * t end
end
easings.cubicIn = function(t) return t * t * t end
easings.cubicOut = function(t)
    local p = t - 1
    return p * p * p + 1
end
easings.cubicInOut = function(t)
    if t < 0.5 then return 4 * t * t * t
    else
        local p = 2 * t - 2
        return 0.5 * p * p * p + 1
    end
end
easings.quartIn = function(t) return t * t * t * t end
easings.quartOut = function(t)
    local p = t - 1
    return 1 - p * p * p * p
end
easings.quartInOut = function(t)
    if t < 0.5 then return 8 * t * t * t * t
    else
        local p = t - 1
        return 1 - 8 * p * p * p * p
    end
end
easings.quintIn = function(t) return t * t * t * t * t end
easings.quintOut = function(t)
    local p = t - 1
    return p * p * p * p * p + 1
end
easings.quintInOut = function(t)
    if t < 0.5 then return 16 * t * t * t * t * t
    else
        local p = 2 * t - 2
        return 0.5 * p * p * p * p * p + 1
    end
end
easings.sineIn = function(t) return 1 - math.cos(t * math.pi * 0.5) end
easings.sineOut = function(t) return math.sin(t * math.pi * 0.5) end
easings.sineInOut = function(t) return -0.5 * (math.cos(math.pi * t) - 1) end
easings.expoIn = function(t) return t == 0 and 0 or (2 ^ (10 * (t - 1))) end
easings.expoOut = function(t) return t == 1 and 1 or (1 - 2 ^ (-10 * t)) end
easings.expoInOut = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    if t < 0.5 then return 0.5 * (2 ^ (20 * t - 10))
    else return 1 - 0.5 * (2 ^ (-20 * t + 10)) end
end
easings.circIn = function(t) return 1 - math.sqrt(math.max(0, 1 - t * t)) end
easings.circOut = function(t)
    local p = t - 1
    return math.sqrt(math.max(0, 1 - p * p))
end
easings.circInOut = function(t)
    local p = t * 2
    if p < 1 then return -0.5 * (math.sqrt(math.max(0, 1 - p * p)) - 1)
    else
        p = p - 2
        return 0.5 * (math.sqrt(math.max(0, 1 - p * p)) + 1)
    end
end
easings.backIn = function(t)
    local s = 1.70158
    return t * t * ((s + 1) * t - s)
end
easings.backOut = function(t)
    local s = 1.70158
    local p = t - 1
    return p * p * ((s + 1) * p + s) + 1
end
easings.backInOut = function(t)
    local s = 1.70158 * 1.525
    local p = t * 2
    if p < 1 then return 0.5 * (p * p * ((s + 1) * p - s))
    else
        p = p - 2
        return 0.5 * (p * p * ((s + 1) * p + s) + 2)
    end
end
local function bounceOut(t)
    if t < 1 / 2.75 then return 7.5625 * t * t
    elseif t < 2 / 2.75 then
        local p = t - 1.5 / 2.75
        return 7.5625 * p * p + 0.75
    elseif t < 2.5 / 2.75 then
        local p = t - 2.25 / 2.75
        return 7.5625 * p * p + 0.9375
    else
        local p = t - 2.625 / 2.75
        return 7.5625 * p * p + 0.984375
    end
end
easings.bounceOut = bounceOut
easings.bounceIn = function(t) return 1 - bounceOut(1 - t) end
easings.bounceInOut = function(t)
    if t < 0.5 then return (1 - bounceOut(1 - 2 * t)) * 0.5
    else return bounceOut(2 * t - 1) * 0.5 + 0.5 end
end
easings.elasticIn = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    local p = 0.3
    local s = p / 4
    local t1 = t - 1
    return -(2 ^ (10 * t1) * math.sin((t1 - s) * (2 * math.pi) / p))
end
easings.elasticOut = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    local p = 0.3
    local s = p / 4
    return 2 ^ (-10 * t) * math.sin((t - s) * (2 * math.pi) / p) + 1
end
easings.elasticInOut = function(t)
    if t == 0 then return 0 end
    if t == 1 then return 1 end
    local p = 0.3 * 1.5
    local s = p / 4
    local t1 = t * 2 - 1
    if t1 < 0 then return -0.5 * (2 ^ (10 * t1) * math.sin((t1 - s) * (2 * math.pi) / p))
    else return 0.5 * (2 ^ (-10 * t1) * math.sin((t1 - s) * (2 * math.pi) / p)) + 1 end
end
return easings
