-- systems/skinRegistry.lua - Catalogo maestro de skins de la serpiente (Zero-GC)
local skinRegistry = {}
local world = require("core.world")

skinRegistry.LIST = {"neon", "cyber", "volcanic", "void"}

skinRegistry.DEFS = {
    neon = {
        id = "neon",
        name = "Neón Arcade",
        desc = "Aspecto prismático estándar",
        achievement = nil,
        colorHead = {0.0, 0.94, 1.0},
        colorBody = {0.0, 0.6, 0.9}
    },
    cyber = {
        id = "cyber",
        name = "Cobalto Cibernético",
        desc = "Blindaje de cobalto táctico (Logro: 100 Bajas)",
        achievement = "enemy_100",
        colorHead = {0.1, 0.75, 1.0},
        colorBody = {0.05, 0.35, 0.8}
    },
    volcanic = {
        id = "volcanic",
        name = "Sierpe Magmática",
        desc = "Escamas ígneas ardientes (Logro: Superar Etapa 3)",
        achievement = "stage_3",
        colorHead = {1.0, 0.4, 0.05},
        colorBody = {0.8, 0.15, 0.02}
    },
    void = {
        id = "void",
        name = "Espectro del Vacío",
        desc = "Manto etéreo cósmico (Logro: Vencer al Boss)",
        achievement = "boss_kill",
        colorHead = {0.8, 0.25, 1.0},
        colorBody = {0.45, 0.08, 0.7}
    }
}

function skinRegistry.list()
    return skinRegistry.LIST
end

function skinRegistry.getDef(id)
    return skinRegistry.DEFS[id] or skinRegistry.DEFS.neon
end

function skinRegistry.isValid(id)
    return id == "classic" or skinRegistry.DEFS[id] ~= nil
end

function skinRegistry.isUnlocked(skinId, profile)
    if not skinId or skinId == "neon" or skinId == "classic" then return true end
    local def = skinRegistry.DEFS[skinId]
    if not def then return false end
    if not def.achievement then return true end
    if not profile or not profile.achievements then return false end
    return profile.achievements[def.achievement] == true
end

function skinRegistry.getActiveSkin(profile)
    local s = world.get("skin")
    if s and skinRegistry.isValid(s) then
        return (s == "classic") and "neon" or s
    end
    if profile and profile.skin and skinRegistry.isValid(profile.skin) then
        return (profile.skin == "classic") and "neon" or profile.skin
    end
    return "neon"
end

function skinRegistry.computeBaseColor(skinId, i, numSegments, now, t, defaultR, defaultG, defaultB)
    if skinId == "cyber" then
        local pulse = math.sin(now * 4 + i * 0.4) * 0.08
        local r = 0.05 + 0.15 * (1 - t)
        local g = math.max(0, math.min(1, 0.70 - 0.25 * t + pulse))
        local b = 1.0
        return r, g, b
    elseif skinId == "volcanic" then
        local pulse = math.sin(now * 5 + i * 0.5) * 0.1
        local r = 1.0
        local g = math.max(0, math.min(1, 0.20 + 0.45 * (1 - t) + pulse))
        local b = 0.05 + 0.1 * t
        return r, g, b
    elseif skinId == "void" then
        local pulse = math.sin(now * 3 + i * 0.35) * 0.12
        local r = math.max(0, math.min(1, 0.65 + pulse))
        local g = 0.12 + 0.18 * (1 - t)
        local b = math.max(0, math.min(1, 0.95 - 0.25 * t))
        return r, g, b
    end
    return defaultR, defaultG, defaultB
end

return skinRegistry
