local Profiles = {}
function Profiles.attach(P, deps)
    local profilesPath = deps.profilesPath
    local SCHEMA_VERSION = deps.SCHEMA_VERSION
    local MAX_NAME_LENGTH = deps.MAX_NAME_LENGTH or 14
    local lua_encode = deps.encode
    local lua_decode = deps.decode
    local atomicWrite = deps.atomicWrite
    local helpers = deps.helpers
    local world = deps.world
    local profileSchema = deps.profileSchema
    local profileSchemaOk = deps.profileSchemaOk
    function P.initProfiles()
        P.profilesData = nil
        local function tryLoad(path)
            if love.filesystem.getInfo(path) then
                local contents = love.filesystem.read(path)
                if contents and #contents > 0 then
                    local decoded = lua_decode(contents)
                    if decoded and type(decoded) == 'table' then return decoded end
                end
            end
            return nil
        end
        local decoded = tryLoad(profilesPath)
        if not decoded then
            decoded = tryLoad(profilesPath .. ".bak")
            if decoded then
                pcall(function()
                    local enc = lua_encode(decoded)
                    if enc then atomicWrite(profilesPath, enc) end
                end)
            end
        end
        if decoded and type(decoded) == 'table' then
            P.profilesData = decoded
            if profileSchemaOk and profileSchema then profileSchema.migrate(P.profilesData, P.profilesData.schema_version) end
            if not P.profilesData.schema_version or P.profilesData.schema_version < SCHEMA_VERSION then P.profilesData.schema_version = SCHEMA_VERSION end
            P.profilesData.version = SCHEMA_VERSION
            if type(P.profilesData.profiles) ~= 'table' then P.profilesData.profiles = {} end
            for k, p in pairs(P.profilesData.profiles) do
                if type(k) ~= 'number' or k < 1 or k > 3 or type(p) ~= 'table' then
                    P.profilesData.profiles[k] = nil
                else
                    if profileSchemaOk and profileSchema then profileSchema.sanitize(p, k)
                    else
                        p.name = (type(p.name) == 'string' and #p.name > 0) and p.name or ("Jugador " .. k)
                        p.monedas = (type(p.monedas) == 'number' and p.monedas >= 0) and p.monedas or 0
                        p.highScore = (type(p.highScore) == 'number' and p.highScore >= 0) and p.highScore or 0
                        p.achievements = type(p.achievements) == 'table' and p.achievements or {}
                        p.unlocks = type(p.unlocks) == 'table' and p.unlocks or {}
                        p.stats = type(p.stats) == 'table' and p.stats or {kills = 0, bossesKilled = 0, highestStage = 1, highestScore = 0, totalCoins = 0, highestStreak = 1.0}
                    end
                end
            end
            local act = P.profilesData.activeProfileIndex
            if act and (type(act) ~= 'number' or act < 1 or act > 3 or not P.profilesData.profiles[act]) then
                P.profilesData.activeProfileIndex = nil
                for i = 1, 3 do if P.profilesData.profiles[i] then P.profilesData.activeProfileIndex = i; break end end
            end
            return
        end
        P.profilesData = {version = SCHEMA_VERSION, schema_version = SCHEMA_VERSION, activeProfileIndex = nil, profiles = {}}
    end
    function P.saveProfiles()
        if not P.profilesData then return true end
        P.profilesData.schema_version = SCHEMA_VERSION
        P.profilesData.version = SCHEMA_VERSION
        local encoded = lua_encode(P.profilesData)
        if type(encoded) ~= 'string' or #encoded == 0 then return false, 'encode failed' end
        local decoded, err = lua_decode(encoded)
        if not decoded or type(decoded) ~= 'table' then return false, 'validation failed: ' .. tostring(err) end
        local ok, werr = atomicWrite(profilesPath, encoded)
        if not ok then
            pcall(function() love.filesystem.createDirectory('config') end)
            ok, werr = atomicWrite(profilesPath, encoded)
            if not ok then return false, werr or 'atomic write failed' end
        end
        return true
    end
    function P.getProfiles()
        if not P.profilesData or type(P.profilesData.profiles) ~= 'table' then return {} end
        return P.profilesData.profiles
    end
    function P.getActiveProfile()
        local idx = P.getActiveProfileIndex()
        if idx and P.profilesData and P.profilesData.profiles then
            local p = P.profilesData.profiles[idx]
            if p then return p end
        end
        return nil
    end
    function P.getActiveProfileIndex()
        if not P.profilesData then return nil end
        local idx = P.profilesData.activeProfileIndex
        if idx and type(idx) == 'number' and idx >= 1 and idx <= 3 then
            if P.profilesData.profiles and P.profilesData.profiles[idx] then return idx end
        end
        return nil
    end
    function P.createProfile(name)
        if not P.profilesData then P.initProfiles() end
        local profiles = P.profilesData.profiles
        for i = 1, 3 do
            if profiles[i] == nil then
                local cleanName = name
                if cleanName then
                    cleanName = tostring(cleanName):gsub("^%s*(.-)%s*$", "%1")
                    if #cleanName > MAX_NAME_LENGTH then cleanName = cleanName:sub(1, MAX_NAME_LENGTH) end
                end
                if not cleanName or #cleanName == 0 then cleanName = "Jugador " .. i end
                if profileSchemaOk and profileSchema then profiles[i] = profileSchema.blankProfile(cleanName, i)
                else profiles[i] = {name = cleanName, createdAt = os.time(), monedas = 0, highScore = 0, achievements = {}, unlocks = {}, stats = {kills = 0, bossesKilled = 0, highestStage = 1, highestScore = 0, totalCoins = 0, highestStreak = 1.0}} end
                P.profilesData.activeProfileIndex = i
                P.saveProfiles()
                return true, nil, i
            end
        end
        return false, "Máximo 3 perfiles alcanzado", nil
    end
    function P.selectProfile(index)
        if not P.profilesData then P.initProfiles() end
        if type(index) ~= 'number' or index < 1 or index > 3 then return false, "Índice inválido" end
        if not P.profilesData.profiles[index] then return false, "Perfil vacío" end
        P.profilesData.activeProfileIndex = index
        P.saveProfiles()
        return true, nil, P.profilesData.profiles[index]
    end
    function P.renameProfile(index, newName)
        if not P.profilesData then P.initProfiles() end
        if type(index) ~= 'number' or index < 1 or index > 3 then return false, "Índice inválido" end
        local profile = P.profilesData.profiles[index]
        if not profile then return false, "Perfil vacío" end
        local cleanName = newName and tostring(newName):gsub("^%s*(.-)%s*$", "%1") or ""
        if #cleanName > MAX_NAME_LENGTH then cleanName = cleanName:sub(1, MAX_NAME_LENGTH) end
        if #cleanName == 0 then cleanName = "Jugador " .. index end
        profile.name = cleanName
        P.saveProfiles()
        return true
    end
    function P.deleteProfile(index)
        if not P.profilesData then P.initProfiles() end
        if type(index) ~= 'number' or index < 1 or index > 3 then return false, "Índice inválido" end
        if not P.profilesData.profiles or not P.profilesData.profiles[index] then return false, "Perfil vacío" end
        P.profilesData.profiles[index] = nil
        if P.profilesData.activeProfileIndex == index then
            local found = false
            for i = 1, 3 do if P.profilesData.profiles[i] ~= nil then P.profilesData.activeProfileIndex = i; found = true; break end end
            if not found then P.profilesData.activeProfileIndex = nil end
        end
        P.saveProfiles()
        return true
    end
    function P.resetProfile(index)
        if not P.profilesData then P.initProfiles() end
        if type(index) ~= 'number' or index < 1 or index > 3 then return false, "Índice inválido" end
        local old = P.profilesData.profiles[index]
        if not old then return false, "Perfil vacío" end
        if profileSchemaOk and profileSchema then
            local fresh = profileSchema.blankProfile(old.name, index)
            fresh.createdAt = os.time()
            P.profilesData.profiles[index] = fresh
        else
            P.profilesData.profiles[index] = {name = old.name, createdAt = os.time(), monedas = 0, highScore = 0, achievements = {}, unlocks = {}, stats = {kills = 0, bossesKilled = 0, highestStage = 1, highestScore = 0, totalCoins = 0, highestStreak = 1.0}}
        end
        P.saveProfiles()
        return true
    end
    function P.syncActiveProfile()
        local profile = P.getActiveProfile()
        if not profile then return false end
        if world and world.get then
            local wMonedas = world.get("monedas")
            if type(wMonedas) == "number" and wMonedas == wMonedas and wMonedas >= 0 then profile.monedas = math.floor(wMonedas) end
            local wHighScore = world.get("highScore")
            if type(wHighScore) == "number" and wHighScore == wHighScore and wHighScore >= 0 then profile.highScore = math.floor(wHighScore) end
            profile.stats = profile.stats or {}
            local curStreak = world.get("highestStreak") or 1.0
            profile.stats.highestStreak = math.max(profile.stats.highestStreak or 1.0, curStreak)
            local curHighScore = world.get("highScore") or profile.highScore or 0
            profile.stats.highestScore = math.max(profile.stats.highestScore or 0, curHighScore)
            profile.stats.totalCoins = math.max(profile.stats.totalCoins or 0, profile.monedas)
        end
        P.saveProfiles()
        return true
    end
    function P.closeRunToShrine()
        local profile = P.getActiveProfile()
        if not profile then return 0 end
        local okCfg, cfg = pcall(require, "core.config")
        local rate = (okCfg and cfg.SHRINE_COIN_RATE) or 0.2
        local earned = math.floor((profile.monedas or 0) * rate)
        if earned > 0 then
            profile.shrineCoins = (profile.shrineCoins or 0) + earned
            profile.monedas = (profile.monedas or 0) - earned
            P.saveProfiles()
        end
        return earned
    end
    function P.addShrineCoins(n)
        local profile = P.getActiveProfile()
        if not profile then return false end
        profile.shrineCoins = math.max(0, (profile.shrineCoins or 0) + math.floor(n or 0))
        P.saveProfiles()
        return true
    end
    function P.syncUnlocks(unlocksTable)
        local profile = P.getActiveProfile()
        if not profile then return false end
        profile.unlocks = helpers.deep_copy(unlocksTable or {})
        P.saveProfiles()
        return true
    end
    function P.syncTalents(talentsTable)
        local profile = P.getActiveProfile()
        if not profile then return false end
        local src = talentsTable or {}
        profile.talents = profile.talents or {}
        if profileSchemaOk and profileSchema then
            for _, id in ipairs(profileSchema.TALENT_IDS) do
                local v = src[id]
                if type(v) == "number" and v >= 0 then profile.talents[id] = math.floor(v) end
            end
            profileSchema.sanitize(profile, P.getActiveProfileIndex() or 1)
        else
            profile.talents = helpers.deep_copy(src)
        end
        P.saveProfiles()
        return true
    end
    function P.syncBounties(history)
        local profile = P.getActiveProfile()
        if not profile then return false end
        profile.bounties = profile.bounties or {active = {}, history = {}}
        if type(history) == "table" then
            profile.bounties.history = helpers.deep_copy(history)
        end
        P.saveProfiles()
        return true
    end
    function P.syncCodex()
        local profile = P.getActiveProfile()
        if not profile then return false end
        P.saveProfiles()
        return true
    end
    function P.syncModeSkin(modo, skin)
        local profile = P.getActiveProfile()
        if not profile then return false end
        if type(modo) == "string" and #modo > 0 then profile.modo = modo end
        if type(skin) == "string" and #skin > 0 then profile.skin = skin end
        P.saveProfiles()
        return true
    end
    function P.syncDailyHistory(entry)
        local profile = P.getActiveProfile()
        if not profile then return false end
        profile.dailyHistory = profile.dailyHistory or {}
        if type(entry) == "table" and entry.date then
            profile.dailyHistory[entry.date] = helpers.deep_copy(entry)
        end
        P.saveProfiles()
        return true
    end
end
return Profiles
