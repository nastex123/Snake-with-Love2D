-- =============================================================================
-- MÓDULO: entities/snake/collisions.lua
-- Parte de P02 — Split de entities/snake.lua (922 → 4 submódulos + fachada)
-- Gestiona colisiones contra enemigos, slice quirúrgico y lazo constrictor.
-- Extraído de entities/snake.lua sin cambios de semántica (incluye fix fromIndex 2026-08-31).
-- =============================================================================
local collisions = {}
local constants = require("constants")
local shop = require("systems.shop")
local enemies = require("entities.enemies")
local world = require("core.world")

local function immune()
    return world.get("debugImmune") or false
end

local function hasWrap()
    local wf = package.loaded["world.world"]
    if not wf then
        local ok, res = pcall(require, "world.world")
        if ok then wf = res end
    end
    if wf and wf.hasWallWrap then
        return wf.hasWallWrap()
    end
    return true
end

function collisions.checkEnemyCollisions(s, enemiesList)
    if not s or not s.body or #s.body == 0 or not enemiesList then
        return nil
    end
    if s.ghost or immune() or (s.sliceGraceTimer and s.sliceGraceTimer > 0) then
        return nil
    end

    local head = s.body[1]
    for idx, e in ipairs(enemiesList) do
        if e.alive then
            if head and e.x == head.x and e.y == head.y then
                if shop.shieldActive then
                    shop.shieldActive = false
                    local res = enemies.killEnemy(idx)
                    return {type = "shield_block", result = res}
                elseif s.armor and s.armor > 0 then
                    s.armor = s.armor - 1
                    local res = enemies.killEnemy(idx)
                    return {type = "armor_block", result = res}
                else
                    return {type = "death"}
                end
            end

            for segIdx = 2, #s.body do
                local seg = s.body[segIdx]
                if seg and seg.x == e.x and seg.y == e.y then
                    local minSliceLen = constants.PATROLLER_SLICE_MIN_LEN or 5
                    if e.type ~= "patroller" or segIdx < 4 or #s.body < minSliceLen then
                        if shop.shieldActive then
                            shop.shieldActive = false
                            local res = enemies.killEnemy(idx)
                            return {type = "shield_block", result = res}
                        elseif s.armor and s.armor > 0 then
                            s.armor = s.armor - 1
                            local res = enemies.killEnemy(idx)
                            return {type = "armor_block", result = res}
                        else
                            return {type = "death"}
                        end
                    else
                        local removed = #s.body - segIdx + 1
                        local fromIdx = segIdx
                        while #s.body >= segIdx do
                            table.remove(s.body)
                        end
                        s.prevBody = {}
                        for i, b in ipairs(s.body) do
                            s.prevBody[i] = {x = b.x, y = b.y}
                        end
                        s.sliceGraceTimer = constants.PATROLLER_SLICE_GRACE_TIME or 1.0
                        return {
                            type = "slice",
                            gx = seg.x,
                            gy = seg.y,
                            fromIndex = fromIdx,
                            removedCount = removed
                        }
                    end
                end
            end
        end
    end
    return nil
end

function collisions.checkPatrollerSlice(s, enemiesList)
    local col = collisions.checkEnemyCollisions(s, enemiesList)
    if col and col.type == "slice" then
        return col
    end
    return nil
end

local function pointInPolygon(px, py, poly)
    local inside = false
    local n = #poly
    if n < 4 then return false end
    local j = n
    for i = 1, n do
        local xi, yi = poly[i].x + 0.5, poly[i].y + 0.5
        local xj, yj = poly[j].x + 0.5, poly[j].y + 0.5
        if ((yi > py) ~= (yj > py)) and (px < (xj - xi) * (py - yi) / ((yj - yi) + 1e-9) + xi) then
            inside = not inside
        end
        j = i
    end
    return inside
end

function collisions.checkConstrictorLoop(s, enemiesList)
    if not s or not s.body or #s.body < 8 or not enemiesList then return nil end
    local killed = {}
    for i = #enemiesList, 1, -1 do
        local e = enemiesList[i]
        if e.alive then
            local onBody = false
            for _, seg in ipairs(s.body) do
                if seg.x == e.x and seg.y == e.y then
                    onBody = true
                    break
                end
            end
            if not onBody and pointInPolygon(e.x + 0.5, e.y + 0.5, s.body) then
                table.insert(killed, {
                    index = i,
                    enemy = e,
                    x = e.x,
                    y = e.y,
                    type = e.type,
                    coins = (e.dropCoins or 1) * 2
                })
            end
        end
    end
    if #killed > 0 then
        s.constrictorBuffTimer = constants.CONSTRICTOR_BUFF_DURATION or 5.0
        return killed
    end
    return nil
end

return collisions
