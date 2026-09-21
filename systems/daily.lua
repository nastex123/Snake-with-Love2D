local daily = {}
local RNG = require("core.rng")
local world = require("core.world")

function daily.getDateString(dateTbl)
    dateTbl = dateTbl or os.date("*t")
    return string.format("%04d-%02d-%02d", dateTbl.year or 2026, dateTbl.month or 1, dateTbl.day or 1)
end

function daily.hasAttemptedToday(profile, dateTbl)
    if not profile or not profile.dailyHistory then return false end
    local ds = daily.getDateString(dateTbl)
    return profile.dailyHistory[ds] ~= nil
end

function daily.getTodayRecord(profile, dateTbl)
    if not profile or not profile.dailyHistory then return nil end
    local ds = daily.getDateString(dateTbl)
    return profile.dailyHistory[ds]
end

function daily.recordRun(profile, score, stage, roomsCleared, dateTbl)
    if not profile then return false end
    profile.dailyHistory = profile.dailyHistory or {}
    local ds = daily.getDateString(dateTbl)
    local entry = {
        date = ds,
        score = math.max(0, math.floor(score or 0)),
        stage = math.max(1, math.floor(stage or 1)),
        roomsCleared = math.max(0, math.floor(roomsCleared or 0)),
        completedAt = os.time(),
    }
    profile.dailyHistory[ds] = entry
    return entry
end

function daily.getHistoryList(profile, maxEntries)
    local list = {}
    if not profile or not profile.dailyHistory then return list end
    for dateKey, entry in pairs(profile.dailyHistory) do
        if type(entry) == "table" then
            list[#list + 1] = {
                date = entry.date or dateKey,
                score = entry.score or 0,
                stage = entry.stage or 1,
                roomsCleared = entry.roomsCleared or 0,
                completedAt = entry.completedAt or 0,
            }
        end
    end
    table.sort(list, function(a, b)
        return (a.date or "") > (b.date or "")
    end)
    if maxEntries and #list > maxEntries then
        local trimmed = {}
        for i = 1, maxEntries do trimmed[i] = list[i] end
        return trimmed
    end
    return list
end

function daily.isDailyActive()
    local st = world.state
    return st and (st.modo == "daily" or st.dailySeed ~= nil)
end

return daily
