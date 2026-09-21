local ProfileSchema = {}
local helpers = require("core.helpers")
ProfileSchema.VERSION = 3
ProfileSchema.TALENT_IDS = {
    "heritage_pouch",
    "residual_magnet",
    "dragon_stomach",
    "thick_potions",
    "sixth_sense",
    "mercy_pact",
    "iron_body",
    "hunter_focus",
}
function ProfileSchema.defaultTalents()
    local t = {}
    for _, id in ipairs(ProfileSchema.TALENT_IDS) do t[id] = 0 end
    return t
end
function ProfileSchema.defaultStats()
    return {kills = 0, bossesKilled = 0, highestStage = 1, highestScore = 0, totalCoins = 0, highestStreak = 1.0}
end
function ProfileSchema.defaultCodex()
    return {enemiesSeen = {}, miniBossesSeen = {}, synergies = {}}
end
function ProfileSchema.defaultBounties()
    return {active = {}, history = {}}
end
function ProfileSchema.blankProfile(name, index)
    return {
        name = name or ("Jugador " .. tostring(index or 1)),
        createdAt = os.time(),
        monedas = 0,
        shrineCoins = 0,
        highScore = 0,
        achievements = {},
        unlocks = {},
        stats = ProfileSchema.defaultStats(),
        talents = ProfileSchema.defaultTalents(),
        codex = ProfileSchema.defaultCodex(),
        bounties = ProfileSchema.defaultBounties(),
        dailyHistory = {},
        modo = "estandar",
        skin = "classic",
    }
end
function ProfileSchema.sanitize(p, index)
    if type(p) ~= "table" then return ProfileSchema.blankProfile("Jugador " .. tostring(index or 1), index) end
    p.name = (type(p.name) == "string" and #p.name > 0) and p.name or ("Jugador " .. tostring(index or 1))
    p.monedas = (type(p.monedas) == "number" and p.monedas >= 0) and p.monedas or 0
    p.shrineCoins = (type(p.shrineCoins) == "number" and p.shrineCoins >= 0) and math.floor(p.shrineCoins) or 0
    p.highScore = (type(p.highScore) == "number" and p.highScore >= 0) and p.highScore or 0
    p.achievements = type(p.achievements) == "table" and p.achievements or {}
    p.unlocks = type(p.unlocks) == "table" and p.unlocks or {}
    p.stats = type(p.stats) == "table" and p.stats or ProfileSchema.defaultStats()
    local ds = ProfileSchema.defaultStats()
    for k, v in pairs(ds) do if type(p.stats[k]) ~= type(v) then p.stats[k] = v end end
    if type(p.talents) ~= "table" then p.talents = ProfileSchema.defaultTalents() end
    for _, id in ipairs(ProfileSchema.TALENT_IDS) do
        if type(p.talents[id]) ~= "number" or p.talents[id] < 0 then p.talents[id] = 0 end
    end
    if type(p.codex) ~= "table" then p.codex = ProfileSchema.defaultCodex() end
    p.codex.enemiesSeen = type(p.codex.enemiesSeen) == "table" and p.codex.enemiesSeen or {}
    p.codex.miniBossesSeen = type(p.codex.miniBossesSeen) == "table" and p.codex.miniBossesSeen or {}
    p.codex.synergies = type(p.codex.synergies) == "table" and p.codex.synergies or {}
    if type(p.bounties) ~= "table" then p.bounties = ProfileSchema.defaultBounties() end
    p.bounties.active = type(p.bounties.active) == "table" and p.bounties.active or {}
    p.bounties.history = type(p.bounties.history) == "table" and p.bounties.history or {}
    p.dailyHistory = type(p.dailyHistory) == "table" and p.dailyHistory or {}
    p.modo = (type(p.modo) == "string" and #p.modo > 0) and p.modo or "estandar"
    p.skin = (type(p.skin) == "string" and #p.skin > 0) and p.skin or "classic"
    return p
end
function ProfileSchema.migrate(data, fromVersion)
    if type(data) ~= "table" then return data end
    if type(data.profiles) ~= "table" then data.profiles = {} end
    for k, p in pairs(data.profiles) do
        if type(k) == "number" and k >= 1 and k <= 3 and type(p) == "table" then
            ProfileSchema.sanitize(p, k)
        end
    end
    data.schema_version = ProfileSchema.VERSION
    data.version = ProfileSchema.VERSION
    return data
end
return ProfileSchema
