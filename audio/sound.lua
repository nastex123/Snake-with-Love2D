local sound = {}
local constants = require("constants")

-- ==================================================================
--  Ambient music – controlado por segmentos
-- ==================================================================
-- Un solo archivo de audio dividido en segmentos con tiempos absolutos.
-- Cada source se maneja con tell() absoluto contra el archivo.
-- El bucle y los cambios de segmento los gestionamos nosotros.

local ambientFile = "Hashiras, Assemble! (from Demon Slayer).ogg"

local activeSource = nil

sound.baseVolume = 0.5
sound.fadeDuration = 0.5
sound.fading = false
sound.fadeTimer = 0
sound.musicEnabled = true
sound.sfxEnabled = true

local oldSource = nil
local fadeSource = nil
local targetSegment = nil

local currentSegment = nil
local segmentEnd = nil

local nextLoopSource = nil
local nextLoopReady = false

sound.fragments = {
    intro      = { start = 1,  finish = 9  },
    comboEnter = { start = 10, finish = 17 },
    comboLoop  = { start = 13, finish = 17 },
    boss       = { start = 18, finish = 24 }
}

local function releaseSrc(src)
    if src then
        pcall(function() src:stop() end)
        if src.release then
            pcall(function() src:release() end)
        end
    end
end

local function isSeamless(name)
    return name == "comboLoop"
end

local function makeSrc()
    local ok, s = pcall(love.audio.newSource, ambientFile, "stream")
    if ok and s then
        s:setLooping(false)
        s:setVolume(sound.baseVolume)
        return s
    end
    return nil
end

local function startSegment(name)
    if not sound.musicEnabled then return end
    local seg = sound.fragments[name]
    if not seg then return end
    if activeSource then
        releaseSrc(activeSource)
        activeSource = nil
    end
    activeSource = makeSrc()
    if activeSource then
        activeSource:seek(seg.start)
        activeSource:play()
    end
    currentSegment = name
    segmentEnd = seg.finish
    if nextLoopSource then
        releaseSrc(nextLoopSource)
        nextLoopSource = nil
    end
    nextLoopReady = false
end

function sound:playSegment(name)
    if not sound.musicEnabled then return end
    if sound.fading then
        if oldSource then
            releaseSrc(oldSource)
            oldSource = nil
        end
        if fadeSource and fadeSource ~= activeSource then
            releaseSrc(fadeSource)
            fadeSource = nil
        end
        sound.fading = false
        sound.fadeTimer = 0
        targetSegment = nil
    end
    if currentSegment == name and activeSource and activeSource:isPlaying() then return end
    startSegment(name)
end

function sound:crossfadeTo(name)
    if not sound.musicEnabled then return end
    local seg = sound.fragments[name]
    if not seg then return end
    if currentSegment == name and not sound.fading and activeSource and activeSource:isPlaying() then return end

    -- Cancel previous crossfade cleanly if already in progress
    if sound.fading then
        if oldSource then
            releaseSrc(oldSource)
            oldSource = nil
        end
        if fadeSource then
            releaseSrc(fadeSource)
            fadeSource = nil
        end
        sound.fading = false
        sound.fadeTimer = 0
    end

    if activeSource and activeSource:isPlaying() then
        oldSource = activeSource
    else
        if activeSource then
            releaseSrc(activeSource)
        end
        oldSource = nil
    end

    fadeSource = makeSrc()
    if not fadeSource then
        return
    end
    fadeSource:setVolume(0)
    fadeSource:seek(seg.start)
    fadeSource:play()

    targetSegment = name
    sound.fading = true
    sound.fadeTimer = 0

    activeSource = fadeSource
    currentSegment = name
    segmentEnd = seg.finish
    if nextLoopSource then
        releaseSrc(nextLoopSource)
        nextLoopSource = nil
    end
    nextLoopReady = false
end

function sound:stop()
    if activeSource then
        releaseSrc(activeSource)
        activeSource = nil
    end
    if oldSource then
        releaseSrc(oldSource)
        oldSource = nil
    end
    if fadeSource then
        releaseSrc(fadeSource)
        fadeSource = nil
    end
    if nextLoopSource then
        releaseSrc(nextLoopSource)
        nextLoopSource = nil
    end
    currentSegment = nil
    segmentEnd = nil
    sound.fading = false
    sound.fadeTimer = 0
    targetSegment = nil
    nextLoopReady = false
end

function sound:update(dt)
    if not sound.musicEnabled then
        if activeSource and activeSource:isPlaying() then
            sound:stop()
        end
        return
    end

    if not currentSegment then return end

    -- Auto-reiniciar el segmento si se detuvo el stream
    if not activeSource or not activeSource:isPlaying() then
        if not sound.fading then
            startSegment(currentSegment)
        end
        return
    end

    -- ==== CROSSFADE ====
    if sound.fading then
        sound.fadeTimer = sound.fadeTimer + dt
        local prog = math.min(1, sound.fadeTimer / sound.fadeDuration)
        local base = sound.baseVolume

        if oldSource and oldSource:isPlaying() then
            oldSource:setVolume((1 - prog) * base)
        end
        if activeSource then
            activeSource:setVolume(prog * base)
        end

        if prog >= 1 then
            if oldSource then
                releaseSrc(oldSource)
                oldSource = nil
            end
            sound.fading = false
            sound.fadeTimer = 0
            fadeSource = nil
            targetSegment = nil
            if activeSource then
                activeSource:setVolume(base)
            end
        end
        return
    end

    -- ==== SEAMLESS LOOP (comboLoop) ====
    if isSeamless(currentSegment) then
        if not activeSource:isPlaying() then
            startSegment(currentSegment)
            return
        end

        local pos = activeSource:tell()
        local seg = sound.fragments[currentSegment]
        local overlapTime = 0.3
        local loopZone = segmentEnd - overlapTime

        if pos >= loopZone and not nextLoopReady then
            nextLoopSource = makeSrc()
            if nextLoopSource then
                nextLoopSource:setVolume(0)
                nextLoopSource:seek(seg.start)
                nextLoopSource:play()
                nextLoopReady = true
            end
        end

        if nextLoopReady and nextLoopSource and pos >= loopZone then
            local fadeProg = math.min(1, (pos - loopZone) / overlapTime)
            activeSource:setVolume((1 - fadeProg) * sound.baseVolume)
            nextLoopSource:setVolume(fadeProg * sound.baseVolume)
        end

        if pos >= segmentEnd then
            if nextLoopReady and nextLoopSource then
                releaseSrc(activeSource)
                activeSource = nextLoopSource
                activeSource:setVolume(sound.baseVolume)
                nextLoopSource = nil
                nextLoopReady = false
            else
                startSegment(currentSegment)
            end
        end
        return
    end

    -- ==== SEGMENTOS NO-SEAMLESS (intro, boss, comboEnter) ====
    local pos = activeSource:tell()

    if pos >= segmentEnd then
        if currentSegment == "comboEnter" then
            startSegment("comboLoop")
        else
            startSegment(currentSegment)
        end
    end
end

function sound:isPlaying()
    if activeSource then
        return activeSource:isPlaying()
    end
    return false
end

function sound:getCurrentSegment()
    return currentSegment
end

function sound.getActiveSource()
    return activeSource
end

function sound.getOldSource()
    return oldSource
end

function sound.getFadeSource()
    return fadeSource
end

function sound.getNextLoopSource()
    return nextLoopSource
end

-- ==================================================================
--  Efectos de sonido (SFX) – generacion procedural
-- ==================================================================
local SAMPLE_RATE = 44100
local sources = {}

function sound.getSources()
    return sources
end

local function makeSine(freq, duration, amp)
    local samples = math.floor(SAMPLE_RATE * duration)
    local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
    for i = 0, samples - 1 do
        local t = i / SAMPLE_RATE
        local envelope = math.min(t / 0.005, 1) * math.min((duration - t) / 0.005, 1)
        local val = math.sin(2 * math.pi * freq * t) * amp * envelope
        sd:setSample(i, val)
    end
    return sd
end

local function makeSweep(freqStart, freqEnd, duration, amp)
    local samples = math.floor(SAMPLE_RATE * duration)
    local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
    for i = 0, samples - 1 do
        local t = i / SAMPLE_RATE
        local frac = t / duration
        local freq = freqStart + (freqEnd - freqStart) * frac
        local envelope = math.min(t / 0.005, 1) * math.min((duration - t) / 0.005, 1)
        local val = math.sin(2 * math.pi * freq * t) * amp * envelope
        sd:setSample(i, val)
    end
    return sd
end

local function makeNoise(duration, amp)
    local samples = math.floor(SAMPLE_RATE * duration)
    local sd = love.sound.newSoundData(samples, SAMPLE_RATE, 16, 1)
    for i = 0, samples - 1 do
        local t = i / SAMPLE_RATE
        local envelope = math.min(t / 0.005, 1) * math.min((duration - t) / 0.005, 1)
        local val = (math.random() * 2 - 1) * amp * envelope
        sd:setSample(i, val)
    end
    return sd
end

function sound.getMakeSine() return makeSine end
function sound.getMakeSweep() return makeSweep end
function sound.getMakeNoise() return makeNoise end

function sound.load()
    -- no reseed global math.random (dungeonGen/persistence usan love.math)

    for k, src in pairs(sources) do
        releaseSrc(src)
    end
    sources = {}

    local function createStatic(sd)
        if not sd then return nil end
        local ok, src = pcall(love.audio.newSource, sd, "static")
        if sd.release then
            pcall(function() sd:release() end)
        end
        return ok and src or nil
    end

    sources.eat = createStatic(makeSweep(600, 900, 0.08, 0.3))
    sources.death = createStatic(makeSweep(200, 40, 0.3, 0.4))
    sources.buy = createStatic(makeSine(550, 0.12, 0.25))
    sources.shieldBreak = createStatic(makeNoise(0.05, 0.2))
    sources.highScore = createStatic(makeSweep(440, 880, 0.3, 0.3))
    sources.enemyKill = createStatic(makeSweep(800, 400, 0.1, 0.25))
    sources.boss_food_tick = createStatic(makeSine(880, 0.08, 0.2))
    sources.boss_defeated = createStatic(makeSweep(440, 1320, 0.4, 0.3))
    sources.buttonHover = createStatic(makeSine(660, 0.04, 0.15))
    sources.buttonClick = createStatic(makeSweep(440, 880, 0.08, 0.25))
end

function sound.play(name)
    if sound.sfxEnabled == false then return end
    if sources[name] then
        sources[name]:stop()
        sources[name]:play()
    end
end

-- Control de volumen y toggles expuestos para settings
function sound.setMasterVolume(v)
    sound.baseVolume = math.max(0, math.min(1, v or 0.5))
    pcall(function() love.audio.setVolume(sound.baseVolume) end)
    if activeSource then activeSource:setVolume(sound.baseVolume) end
    if nextLoopSource then nextLoopSource:setVolume(sound.baseVolume) end
    if fadeSource and not sound.fading then fadeSource:setVolume(sound.baseVolume) end
end

function sound.enableMusic(flag)
    sound.musicEnabled = not not flag
    if not sound.musicEnabled then
        sound:stop()
    else
        if not sound:isPlaying() then sound:playSegment('intro') end
    end
end

function sound.enableSfx(flag)
    sound.sfxEnabled = not not flag
end

return sound
