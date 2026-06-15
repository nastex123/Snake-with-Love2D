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

local function isSeamless(name)
    return name == "comboLoop"
end

local function makeSrc()
    local s = love.audio.newSource(ambientFile, "stream")
    s:setLooping(false)
    s:setVolume(sound.baseVolume)
    return s
end

local function startSegment(name)
    local seg = sound.fragments[name]
    if not seg then return end
    if activeSource then activeSource:stop() end
    activeSource = makeSrc()
    activeSource:play()
    activeSource:seek(seg.start)
    currentSegment = name
    segmentEnd = seg.finish
    if nextLoopSource then nextLoopSource:stop(); nextLoopSource = nil end
    nextLoopReady = false
end

function sound:playSegment(name)
    if sound.fading then
        if oldSource then
            oldSource:stop()
            oldSource = nil
        end
        sound.fading = false
        sound.fadeTimer = 0
        fadeSource = nil
        targetSegment = nil
    end
    if currentSegment == name then return end
    startSegment(name)
end

function sound:crossfadeTo(name)
    local seg = sound.fragments[name]
    if not seg then return end
    if currentSegment == name and not sound.fading then return end

    if activeSource and activeSource:isPlaying() then
        oldSource = activeSource
    else
        oldSource = nil
    end

    fadeSource = makeSrc()
    fadeSource:setVolume(0)
    fadeSource:play()
    fadeSource:seek(seg.start)

    targetSegment = name
    sound.fading = true
    sound.fadeTimer = 0

    activeSource = fadeSource
    currentSegment = name
    segmentEnd = seg.finish
    if nextLoopSource then nextLoopSource:stop(); nextLoopSource = nil end
    nextLoopReady = false
end

function sound:stop()
    if activeSource then
        activeSource:stop()
        activeSource = nil
    end
    if oldSource then
        oldSource:stop()
        oldSource = nil
    end
    if nextLoopSource then
        nextLoopSource:stop()
        nextLoopSource = nil
    end
    currentSegment = nil
    segmentEnd = nil
    sound.fading = false
    sound.fadeTimer = 0
    fadeSource = nil
    targetSegment = nil
    nextLoopReady = false
end

function sound:update(dt)
    if not currentSegment then return end
    if not activeSource then return end

    -- ==== CROSSFADE ====
    if sound.fading then
        sound.fadeTimer = sound.fadeTimer + dt
        local prog = math.min(1, sound.fadeTimer / sound.fadeDuration)
        local base = sound.baseVolume

        if oldSource and oldSource:isPlaying() then
            oldSource:setVolume((1 - prog) * base)
        end
        activeSource:setVolume(prog * base)

        if prog >= 1 then
            if oldSource then
                oldSource:stop()
                oldSource = nil
            end
            sound.fading = false
            sound.fadeTimer = 0
            fadeSource = nil
            targetSegment = nil
            activeSource:setVolume(base)
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
            nextLoopSource:setVolume(0)
            nextLoopSource:play()
            nextLoopSource:seek(seg.start)
            nextLoopReady = true
        end

        if nextLoopReady and nextLoopSource and pos >= loopZone then
            local fadeProg = math.min(1, (pos - loopZone) / overlapTime)
            activeSource:setVolume((1 - fadeProg) * sound.baseVolume)
            nextLoopSource:setVolume(fadeProg * sound.baseVolume)
        end

        if pos >= segmentEnd then
            if nextLoopReady and nextLoopSource then
                activeSource:stop()
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

    -- ==== SEGMENTOS NO-SEAMLESS ====
    if not activeSource:isPlaying() then
        return
    end

    local pos = activeSource:tell()

    if pos >= segmentEnd then
        if currentSegment == "comboEnter" then
            startSegment("comboLoop")
        else
            local seg = sound.fragments[currentSegment]
            if seg then
                activeSource:seek(seg.start)
            end
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

-- ==================================================================
--  Efectos de sonido (SFX) – generacion procedural
-- ==================================================================
local SAMPLE_RATE = 44100
local sources = {}

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

function sound.load()
    math.randomseed(os.time())

    sources.eat = love.audio.newSource(makeSweep(600, 900, 0.08, 0.3), "static")
    sources.death = love.audio.newSource(makeSweep(200, 40, 0.3, 0.4), "static")
    sources.buy = love.audio.newSource(makeSine(550, 0.12, 0.25), "static")
    sources.shieldBreak = love.audio.newSource(makeNoise(0.05, 0.2), "static")
    sources.highScore = love.audio.newSource(makeSweep(440, 880, 0.3, 0.3), "static")
    sources.enemyKill = love.audio.newSource(makeSweep(800, 400, 0.1, 0.25), "static")
end

function sound.play(name)
    if sources[name] then
        sources[name]:stop()
        sources[name]:play()
    end
end

-- Control de volumen y toggles expuestos para settings
function sound.setMasterVolume(v)
    sound.baseVolume = math.max(0, math.min(1, v))
    if activeSource then activeSource:setVolume(sound.baseVolume) end
    if nextLoopSource then nextLoopSource:setVolume(sound.baseVolume) end
end

function sound.enableMusic(flag)
    -- Si desactivamos la música paramos las fuentes; si activamos, arrancamos el segmento intro
    if not flag then
        sound:stop()
    else
        if not sound:isPlaying() then sound:playSegment('intro') end
    end
end

function sound.enableSfx(flag)
    -- Implementación simple: habilitar/deshabilitar reproducción de SFX en sound.play
    sound.sfxEnabled = not not flag
end

return sound
