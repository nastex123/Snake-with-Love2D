local RNG = {}
local function makeLCG(seed)
    local s = (tonumber(seed) or 1) % 2147483647
    if s <= 0 then s = s + 2147483646 end
    return function(a, b)
        s = (s * 16807) % 2147483647
        local r = s / 2147483647
        if a == nil then return r end
        if b == nil then return 1 + math.floor(r * a) end
        return a + math.floor(r * (b - a + 1))
    end
end
function RNG.new(seed)
    local gen = nil
    if love and love.math and love.math.newRandomGenerator then
        local ok, g = pcall(love.math.newRandomGenerator, seed or 1)
        if ok and g then gen = g end
    end
    local lcg = makeLCG(seed or 1)
    local self = {seed = seed or 1, _gen = gen, _lcg = lcg}
    function self.next(a, b)
        if self._gen then return self._gen:random(a, b) end
        return self._lcg(a, b)
    end
    function self.float()
        if self._gen then return self._gen:random() end
        return self._lcg()
    end
    function self.choice(t)
        if type(t) ~= "table" or #t == 0 then return nil end
        return t[self.next(1, #t)]
    end
    function self.shuffle(t)
        if type(t) ~= "table" then return t end
        for i = #t, 2, -1 do
            local j = self.next(1, i)
            t[i], t[j] = t[j], t[i]
        end
        return t
    end
    return self
end
function RNG.dailySeed(year, month, day, salt)
    local y = tonumber(year) or 2026
    local m = tonumber(month) or 1
    local d = tonumber(day) or 1
    local s = tonumber(salt) or 7919
    return (y * 10000 + m * 100 + d) * 31 + (s % 100000)
end
return RNG
