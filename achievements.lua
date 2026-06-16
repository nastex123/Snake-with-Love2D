local achievements = {}
local persistence = require('persistence')
local constants = require('constants')

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
        title = "Puntuaci\u{F3}n 1000",
        desc = "Alcanza 1000 puntos en una run"
    },
    score_5000 = {
        id = "score_5000",
        title = "Puntuaci\u{F3}n 5000",
        desc = "Alcanza 5000 puntos en una run"
    }
}

function achievements.check(event, params)
    local profile = persistence.getActiveProfile()
    if not profile then return end
    profile.stats = profile.stats or {}
    profile.achievements = profile.achievements or {}

    local changed = false

    if event == "enemyKilled" then
        profile.stats.kills = (profile.stats.kills or 0) + 1
        if not profile.achievements.first_kill and profile.stats.kills >= 1 then
            profile.achievements.first_kill = {done = true, at = os.time()}
            changed = true
        end
        if not profile.achievements.enemy_25 and profile.stats.kills >= 25 then
            profile.achievements.enemy_25 = {done = true, at = os.time()}
            changed = true
        end
        if not profile.achievements.enemy_100 and profile.stats.kills >= 100 then
            profile.achievements.enemy_100 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "comboAchieved" and params and params.count then
        if not profile.achievements.combo_5 and params.count >= 5 then
            profile.achievements.combo_5 = {done = true, at = os.time()}
            changed = true
        end
        if not profile.achievements.combo_10 and params.count >= 10 then
            profile.achievements.combo_10 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "bossDefeated" then
        profile.stats.bossesKilled = (profile.stats.bossesKilled or 0) + 1
        if not profile.achievements.boss_kill then
            profile.achievements.boss_kill = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "stageChanged" and params and params.stage then
        profile.stats.highestStage = math.max(profile.stats.highestStage or 0, params.stage)
        if not profile.achievements.stage_3 and profile.stats.highestStage >= 3 then
            profile.achievements.stage_3 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "scoreReached" and params and params.score then
        profile.stats.highestScore = math.max(profile.stats.highestScore or 0, params.score)
        if not profile.achievements.score_1000 and profile.stats.highestScore >= 1000 then
            profile.achievements.score_1000 = {done = true, at = os.time()}
            changed = true
        end
        if not profile.achievements.score_5000 and profile.stats.highestScore >= 5000 then
            profile.achievements.score_5000 = {done = true, at = os.time()}
            changed = true
        end
    end

    if event == "coinsChanged" then
        if params and params.totalCoins then
            profile.stats.totalCoins = params.totalCoins
        else
            profile.stats.totalCoins = monedas
        end
        if not profile.achievements.coins_100 and profile.stats.totalCoins >= 100 then
            profile.achievements.coins_100 = {done = true, at = os.time()}
            changed = true
        end
        if not profile.achievements.coins_500 and profile.stats.totalCoins >= 500 then
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
                if pendingAchievements then
                    local exists = false
                    for _, x in ipairs(pendingAchievements) do if x == aid then exists = true break end end
                    if not exists then table.insert(pendingAchievements, aid) end
                else
                    if ui and ui.showToast then
                        local reg = achievements.registry[aid]
                        if reg then ui.showToast({id=aid, title=reg.title, subtitle=reg.desc}) end
                    end
                end
                -- schedule delayed toast (overlay-aware)
                local sreg = achievements.registry[aid]
                if sreg and scheduledToasts and not scheduledIndex[aid] then
                    scheduledIndex[aid] = true
                    table.insert(scheduledToasts, {
                        id = aid,
                        showAt = (time or 0) + constants.TOAST_SCHEDULE_DELAY,
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

return achievements
