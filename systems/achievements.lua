-- systems/achievements.lua — Catálogo de logros, disparadores por evento, helpers y encolado
local achievements = {}
local persistence = require('systems.persistence')
local constants = require('constants')
local world = require('core.world')
local ok_ui, uiMod = pcall(require, 'ui.ui')

achievements.registry = {
    first_kill = {
        id = "first_kill",
        title = "Primera Sangre",
        desc = "Mata tu primer enemigo"
    },
    enemy_25 = {
        id = "enemy_25",
        title = "Cazador Novato",
        desc = "Mata 25 enemigos"
    },
    enemy_100 = {
        id = "enemy_100",
        title = "Cazador Experto",
        desc = "Mata 100 enemigos"
    },
    combo_5 = {
        id = "combo_5",
        title = "Racha 5",
        desc = "Consigue una racha de 5"
    },
    combo_10 = {
        id = "combo_10",
        title = "Racha 10",
        desc = "Consigue una racha de 10"
    },
    coins_100 = {
        id = "coins_100",
        title = "Ahorrador",
        desc = "Acumula 100 monedas"
    },
    coins_500 = {
        id = "coins_500",
        title = "Rico",
        desc = "Acumula 500 monedas"
    },
    stage_3 = {
        id = "stage_3",
        title = "Profundidades",
        desc = "Llega a la etapa 3"
    },
    boss_kill = {
        id = "boss_kill",
        title = "Matadragones",
        desc = "Mata a un jefe"
    },
    score_1000 = {
        id = "score_1000",
        title = "Puntuación 1000",
        desc = "Alcanza 1000 puntos en una run"
    },
    score_5000 = {
        id = "score_5000",
        title = "Puntuación 5000",
        desc = "Alcanza 5000 puntos en una run"
    }
}

function achievements.get(id)
    return achievements.registry[id]
end

function achievements.getAll()
    return achievements.registry
end

function achievements.isUnlocked(id, profile)
    local p = profile or persistence.getActiveProfile()
    if not p or not p.achievements then return false end
    local a = p.achievements[id]
    return a ~= nil and a.done == true
end

function achievements.getUnlockedCount(profile)
    local p = profile or persistence.getActiveProfile()
    local count = 0
    local total = 0
    for id, _ in pairs(achievements.registry) do
        total = total + 1
        if achievements.isUnlocked(id, p) then
            count = count + 1
        end
    end
    return count, total
end

function achievements.getProgress(id, profile)
    local p = profile or persistence.getActiveProfile()
    local stats = p and p.stats or {}
    local unlocked = achievements.isUnlocked(id, p)

    if id == "first_kill" then
        local cur = stats.kills or 0
        return math.min(cur, 1), 1, math.min(1, cur / 1), unlocked
    elseif id == "enemy_25" then
        local cur = stats.kills or 0
        return math.min(cur, 25), 25, math.min(1, cur / 25), unlocked
    elseif id == "enemy_100" then
        local cur = stats.kills or 0
        return math.min(cur, 100), 100, math.min(1, cur / 100), unlocked
    elseif id == "combo_5" then
        local cur = stats.highestStreak or (world.get("comboCount") or 0)
        return math.min(cur, 5), 5, math.min(1, cur / 5), unlocked
    elseif id == "combo_10" then
        local cur = stats.highestStreak or (world.get("comboCount") or 0)
        return math.min(cur, 10), 10, math.min(1, cur / 10), unlocked
    elseif id == "coins_100" then
        local cur = stats.totalCoins or (world.get("monedas") or 0)
        return math.min(cur, 100), 100, math.min(1, cur / 100), unlocked
    elseif id == "coins_500" then
        local cur = stats.totalCoins or (world.get("monedas") or 0)
        return math.min(cur, 500), 500, math.min(1, cur / 500), unlocked
    elseif id == "stage_3" then
        local cur = stats.highestStage or 1
        return math.min(cur, 3), 3, math.min(1, cur / 3), unlocked
    elseif id == "boss_kill" then
        local cur = stats.bossesKilled or 0
        return math.min(cur, 1), 1, math.min(1, cur / 1), unlocked
    elseif id == "score_1000" then
        local cur = stats.highestScore or (world.get("puntuacion") or 0)
        return math.min(cur, 1000), 1000, math.min(1, cur / 1000), unlocked
    elseif id == "score_5000" then
        local cur = stats.highestScore or (world.get("puntuacion") or 0)
        return math.min(cur, 5000), 5000, math.min(1, cur / 5000), unlocked
    end
    return 0, 1, 0, unlocked
end

function achievements.reset(profile)
    local p = profile or persistence.getActiveProfile()
    if not p then return false end
    p.achievements = {}
    persistence.saveProfiles()
    return true
end

function achievements.check(event, params)
    local profile = persistence.getActiveProfile()
    if not profile then return end
    profile.stats = profile.stats or {}
    profile.achievements = profile.achievements or {}

    local changed = false

    if event == "enemyKilled" then
        profile.stats.kills = (profile.stats.kills or 0) + 1
        if (not profile.achievements.first_kill or not profile.achievements.first_kill.done) and profile.stats.kills >= 1 then
            profile.achievements.first_kill = {done = true, at = os.time()}
            changed = true
        end
        if (not profile.achievements.enemy_25 or not profile.achievements.enemy_25.done) and profile.stats.kills >= 25 then
            profile.achievements.enemy_25 = {done = true, at = os.time()}
            changed = true
        end
        if (not profile.achievements.enemy_100 or not profile.achievements.enemy_100.done) and profile.stats.kills >= 100 then
            profile.achievements.enemy_100 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "comboAchieved" then
        local count = (params and params.count) or ((world.get("comboCount") or 0) + 1)
        if (not profile.achievements.combo_5 or not profile.achievements.combo_5.done) and count >= 5 then
            profile.achievements.combo_5 = {done = true, at = os.time()}
            changed = true
        end
        if (not profile.achievements.combo_10 or not profile.achievements.combo_10.done) and count >= 10 then
            profile.achievements.combo_10 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "bossDefeated" then
        profile.stats.bossesKilled = (profile.stats.bossesKilled or 0) + 1
        if not profile.achievements.boss_kill or not profile.achievements.boss_kill.done then
            profile.achievements.boss_kill = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "stageChanged" then
        local worldModRef = package.loaded["world.world"]
        local stage = (params and params.stage) or (worldModRef and worldModRef.etapa) or world.get("etapa") or 1
        profile.stats.highestStage = math.max(profile.stats.highestStage or 1, stage)
        if (not profile.achievements.stage_3 or not profile.achievements.stage_3.done) and profile.stats.highestStage >= 3 then
            profile.achievements.stage_3 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "scoreReached" then
        local score = (params and params.score) or world.get("puntuacion") or world.get("highScore") or profile.highScore or 0
        profile.stats.highestScore = math.max(profile.stats.highestScore or 0, score)
        if (not profile.achievements.score_1000 or not profile.achievements.score_1000.done) and profile.stats.highestScore >= 1000 then
            profile.achievements.score_1000 = {done = true, at = os.time()}
            changed = true
        end
        if (not profile.achievements.score_5000 or not profile.achievements.score_5000.done) and profile.stats.highestScore >= 5000 then
            profile.achievements.score_5000 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "coinsChanged" then
        local coins = (params and params.totalCoins) or world.get("monedas") or 0
        profile.stats.totalCoins = math.max(profile.stats.totalCoins or 0, coins)
        if (not profile.achievements.coins_100 or not profile.achievements.coins_100.done) and profile.stats.totalCoins >= 100 then
            profile.achievements.coins_100 = {done = true, at = os.time()}
            changed = true
        end
        if (not profile.achievements.coins_500 or not profile.achievements.coins_500.done) and profile.stats.totalCoins >= 500 then
            profile.achievements.coins_500 = {done = true, at = os.time()}
            changed = true
        end
    end

    if changed then
        persistence.saveProfiles()
        -- Enqueue visual notification for later (pending in current sala)
        -- pendingAchievements is a global queue defined in main.lua; if absent, show immediately via ui
        -- When marking a new achievement we set a temporary flag `queued` on the achievement entry
        for aid, v in pairs(profile.achievements) do
            if v.done and (v.queued ~= true) then
                v.queued = true
                local pendingAch = world.get("pendingAchievements")
                if pendingAch then
                    local exists = false
                    for _, x in ipairs(pendingAch) do if x == aid then exists = true break end end
                    if not exists then table.insert(pendingAch, aid) end
                else
                    if ok_ui and uiMod and uiMod.showToast then
                        local reg = achievements.registry[aid]
                        if reg then uiMod.showToast({id=aid, title=reg.title, subtitle=reg.desc}) end
                    end
                end
                -- schedule delayed toast (overlay-aware)
                local sreg = achievements.registry[aid]
                local schedToasts = world.get("scheduledToasts")
                local schedIndex = world.get("scheduledIndex")
                if sreg and schedToasts and schedIndex and not schedIndex[aid] then
                    schedIndex[aid] = true
                    table.insert(schedToasts, {
                        id = aid,
                        showAt = (world.get("time") or 0) + (constants.TOAST_SCHEDULE_DELAY or 0.5),
                        payload = {
                            id = aid,
                            title = sreg.title,
                            subtitle = sreg.desc,
                            reward = sreg.reward
                        }
                    })
                end
            end
        end
    end
end

-- P06 Event Bus wiring (sin circular: Events no requiere achievements)
local okEvents, Events = pcall(require, "core.events")
if okEvents and Events and Events.on then
    Events.on("enemyKilled", function(payload) achievements.check("enemyKilled", payload) end)
    Events.on("bossDefeated", function(payload) achievements.check("bossDefeated", payload) end)
    Events.on("comboAchieved", function(payload) achievements.check("comboAchieved", payload) end)
    Events.on("stageChanged", function(payload) achievements.check("stageChanged", payload) end)
    Events.on("scoreReached", function(payload) achievements.check("scoreReached", payload) end)
    Events.on("coinsChanged", function(payload) achievements.check("coinsChanged", payload) end)
end

return achievements
