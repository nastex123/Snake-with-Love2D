-- =============================================================================
-- MÓDULO: enemyMiniBoss.lua
-- Mini-Jefes temáticos de Sala 3 (GDD §5): 5 encuentros élite, uno por etapa.
-- A diferencia del Boss final, son VULNERABLES al daño directo (escudo, armadura,
-- bomba, fuego) o a recolectar su objetivo de comidas en la sala.
-- Diseño data-driven: MINIBOSS_DEFS + máquina de estados idle/telegraph/execute/cooldown.
-- El estado vive en World.state.enemies.miniboss (sin globals).
-- =============================================================================
local miniBoss = {}
local constants = require("constants")
local world = require("core.world")

miniBoss.DEFS = {
    [1] = {
        id = "wall_crusher", name = "TRITURADOR", color = {0.6, 0.6, 0.7},
        hp = 3, foodTarget = 6, coins = 15, streakBonus = 0.2,
        attacks = {"charge"}, telegraphTime = 1.2, cooldown = 4.0,
        moveInterval = nil, reward = "shield",
    },
    [2] = {
        id = "frost_golem", name = "GOLEM ESCARCHA", color = {0.2, 0.8, 1.0},
        hp = 4, foodTarget = 7, coins = 20, streakBonus = 0.2,
        attacks = {"breath"}, telegraphTime = 0.6, cooldown = 5.0,
        moveInterval = nil, reward = "freeze",
    },
    [3] = {
        id = "magma_wyrm", name = "SIERPE MAGMA", color = {1.0, 0.3, 0.0},
        hp = 6, foodTarget = 8, coins = 25, streakBonus = 0.2,
        attacks = {}, telegraphTime = 0, cooldown = 0,
        moveInterval = 0.45, reward = "fire",
    },
    [4] = {
        id = "brood_queen", name = "REINA LARVA", color = {0.7, 0.1, 0.8},
        hp = 5, foodTarget = 9, coins = 30, streakBonus = 0.2,
        attacks = {"swarm", "web"}, telegraphTime = 0.8, cooldown = 6.0,
        moveInterval = nil, reward = "constrictor",
    },
    [5] = {
        id = "void_phantom", name = "ESPECTRO VACIO", color = {0.1, 0.0, 0.3},
        hp = 6, foodTarget = 10, coins = 40, streakBonus = 0.3,
        attacks = {"singularity", "teleport"}, telegraphTime = 1.0, cooldown = 5.0,
        moveInterval = 0.5, reward = "streak",
    },
}

function miniBoss.getDef(etapa)
    local e = math.max(1, math.min(5, etapa or 1))
    return miniBoss.DEFS[e]
end

function miniBoss.get()
    return world.get("enemies.miniboss")
end

function miniBoss.clear()
    world.set("enemies.miniboss", nil)
end

function miniBoss.spawn(etapa, gx, gy)
    local def = miniBoss.getDef(etapa)
    local mb = {
        defId = def.id, name = def.name, color = def.color,
        etapa = math.max(1, math.min(5, etapa or 1)),
        x = gx, y = gy, hp = def.hp, maxHp = def.hp,
        foodCollected = 0, foodTarget = def.foodTarget,
        alive = true, state = "idle", stateTimer = 0,
        attackCooldown = 2.0, attackCount = 0,
        moveTimer = 0, dirX = 1, dirY = 0,
        telegraphCells = {}, flash = 0,
        trail = {}, singu = nil, singuPull = 0,
        wpIndex = 1, slammed = false, pendingHit = false,
        justTeleported = false,
    }
    world.set("enemies.miniboss", mb)
    return mb
end

local function lootOf(mb)
    local tam = constants.TAMANIO_BLOQUE
    return {
        px = mb.x * tam + tam / 2,
        py = mb.y * tam + tam / 2,
        gx = mb.x, gy = mb.y,
        coins = miniBoss.getDef(mb.etapa).coins,
        type = "miniboss", id = mb.defId,
    }
end

function miniBoss.defeat(mb)
    if not mb or not mb.alive then return nil end
    mb.alive = false
    world.set("enemies.miniboss", nil)
    return lootOf(mb)
end

-- Daño directo (escudo, armadura, bomba, fuego). Retorna loot si muere.
function miniBoss.hit(mb, dmg, ctx)
    if not mb or not mb.alive then return nil end
    mb.hp = (mb.hp or 1) - (dmg or 1)
    mb.flash = 0.3
    -- Nova de Hielo reactiva del golem: esquirlas en 4 diagonales
    if mb.defId == "frost_golem" and mb.hp > 0 and ctx and ctx.enemies then
        local dirs = {{1, 1}, {1, -1}, {-1, 1}, {-1, -1}}
        for _, d in ipairs(dirs) do
            ctx.enemies.addProjectile(mb.x, mb.y, d[1] * 20, d[2] * 20, 2.0, 1)
        end
    end
    if mb.hp <= 0 then
        return miniBoss.defeat(mb)
    end
    return nil
end

function miniBoss.addFood(mb)
    if not mb or not mb.alive then return nil end
    mb.foodCollected = (mb.foodCollected or 0) + 1
    if mb.foodCollected >= (mb.foodTarget or 6) then
        return miniBoss.defeat(mb)
    end
    return nil
end

local function inBounds(x, y, w, h)
    return x >= 0 and x < w and y >= 0 and y < h
end

local function markTelegraph(ctx, cells, timer, attackType)
    for _, c in ipairs(cells) do
        ctx.attackRegistry.addTelegraph(c.x, c.y, timer, attackType or "miniboss")
    end
end

-- Elige eje de embestida por la fila/columna de la cabeza y marca la línea
local function planCharge(mb, ctx)
    local head = ctx.head or {x = mb.x, y = mb.y}
    local w, h = ctx.anchoGrilla, ctx.altoGrilla
    local horizontal = math.abs(head.x - mb.x) >= math.abs(head.y - mb.y)
    local cells = {}
    if horizontal then
        for x = 0, w - 1 do cells[#cells + 1] = {x = x, y = mb.y} end
    else
        for y = 0, h - 1 do cells[#cells + 1] = {x = mb.x, y = y} end
    end
    return cells, horizontal
end

local function destroyAt(obstacles, x, y)
    if not obstacles or not obstacles.pos then return false end
    for i = #obstacles.pos, 1, -1 do
        local o = obstacles.pos[i]
        if o.x == x and o.y == y then
            table.remove(obstacles.pos, i)
            return true
        end
    end
    return false
end

local function stepToward(mb, tx, ty, w, h)
    local dx = (tx or mb.x) - mb.x
    local dy = (ty or mb.y) - mb.y
    if math.abs(dx) >= math.abs(dy) and dx ~= 0 then
        mb.x = mb.x + (dx > 0 and 1 or -1)
    elseif dy ~= 0 then
        mb.y = mb.y + (dy > 0 and 1 or -1)
    end
    mb.x = math.max(0, math.min(w - 2, mb.x))
    mb.y = math.max(0, math.min(h - 2, mb.y))
end

function miniBoss.update(dt, mb, ctx)
    if not mb or not mb.alive then return end
    ctx = ctx or {}
    local w = ctx.anchoGrilla or constants.MAX_GRID_COLS or 32
    local h = ctx.altoGrilla or constants.MAX_GRID_ROWS or 18
    local def = miniBoss.getDef(mb.etapa)

    if mb.flash and mb.flash > 0 then
        mb.flash = math.max(0, mb.flash - dt)
    end

    -- Estela de lava de la sierpe: expira a los 4s
    if mb.trail and #mb.trail > 0 and ctx.obstacles then
        for i = #mb.trail, 1, -1 do
            local t = mb.trail[i]
            t.timer = t.timer - dt
            if t.timer <= 0 then
                destroyAt(ctx.obstacles, t.x, t.y)
                table.remove(mb.trail, i)
            end
        end
    end

    -- Movimiento por defecto según arquetipo
    mb.moveTimer = (mb.moveTimer or 0) + dt
    local interval = def.moveInterval
    if interval and mb.moveTimer >= interval and mb.state == "idle" then
        mb.moveTimer = 0
        if mb.defId == "magma_wyrm" then
            -- Bucle por el perímetro interior de la sala
            local m = 2
            local corners = {{x = m, y = m}, {x = w - 3 - m, y = m}, {x = w - 3 - m, y = h - 3 - m}, {x = m, y = h - 3 - m}}
            mb.wpIndex = (mb.wpIndex or 1) % #corners + 1
            local wp = corners[mb.wpIndex]
            stepToward(mb, wp.x, wp.y, w, h)
            -- Rastro de ceniza: lava 4s (máx 10 celdas vivas)
            if ctx.obstacles and ctx.obstacles.spawnAt then
                ctx.obstacles.spawnAt(mb.x, mb.y, "lava")
                mb.trail[#mb.trail + 1] = {x = mb.x, y = mb.y, timer = 4.0}
                while #mb.trail > 10 do
                    local old = table.remove(mb.trail, 1)
                    destroyAt(ctx.obstacles, old.x, old.y)
                end
            end
        elseif mb.defId == "void_phantom" and ctx.head then
            stepToward(mb, ctx.head.x, ctx.head.y, w, h)
        end
    end

    -- Singularidad activa: atrae enemigos y detona al final
    if mb.singu then
        mb.singu.timer = mb.singu.timer - dt
        mb.singuPull = (mb.singuPull or 0) - dt
        if mb.singuPull <= 0 then
            mb.singuPull = 0.5
            for _, e in ipairs(ctx.enemies and ctx.enemies.list or {}) do
                if e.alive and math.abs(e.x - mb.singu.cx) + math.abs(e.y - mb.singu.cy) <= 6 then
                    if e.x ~= mb.singu.cx then e.x = e.x + (mb.singu.cx > e.x and 1 or -1) end
                    if e.y ~= mb.singu.cy then e.y = e.y + (mb.singu.cy > e.y and 1 or -1) end
                end
            end
        end
        if mb.singu.timer <= 0 then
            local head = ctx.head
            if head and math.max(math.abs(head.x - mb.singu.cx), math.abs(head.y - mb.singu.cy)) <= 2 then
                mb.pendingHit = true
            end
            mb.singu = nil
        end
    end

    -- Máquina de estados de ataque
    if mb.state == "idle" then
        mb.attackCooldown = (mb.attackCooldown or 3.0) - dt
        if mb.attackCooldown <= 0 and #(def.attacks or {}) > 0 then
            mb.attackCount = (mb.attackCount or 0) + 1
            local atk = def.attacks[((mb.attackCount - 1) % #def.attacks) + 1]
            mb.currentAttack = atk
            mb.telegraphCells = {}
            if atk == "charge" then
                local cells = planCharge(mb, ctx)
                mb.telegraphCells = cells
                markTelegraph(ctx, cells, def.telegraphTime, "miniboss_charge")
            elseif atk == "breath" then
                local head = ctx.head or {x = mb.x + 1, y = mb.y}
                local dx = (head.x or mb.x) - mb.x
                local dy = (head.y or mb.y) - mb.y
                local sx = dx ~= 0 and (dx > 0 and 1 or -1) or 0
                local sy = (dx == 0 and dy ~= 0) and (dy > 0 and 1 or -1) or 0
                if sx == 0 and sy == 0 then sx = 1 end
                for d = 1, 3 do
                    local cx, cy = mb.x + sx * d, mb.y + sy * d
                    if inBounds(cx, cy, w, h) then
                        mb.telegraphCells[#mb.telegraphCells + 1] = {x = cx, y = cy}
                    end
                end
                markTelegraph(ctx, mb.telegraphCells, def.telegraphTime, "miniboss_breath")
            elseif atk == "swarm" or atk == "web" then
                markTelegraph(ctx, {{x = mb.x, y = mb.y}}, def.telegraphTime, "miniboss_" .. atk)
                mb.telegraphCells = {{x = mb.x, y = mb.y}}
            elseif atk == "singularity" then
                local cx0 = math.floor(w / 2)
                local cy0 = math.floor(h / 2)
                for dx = -1, 1 do
                    for dy = -1, 1 do
                        mb.telegraphCells[#mb.telegraphCells + 1] = {x = cx0 + dx, y = cy0 + dy}
                    end
                end
                markTelegraph(ctx, mb.telegraphCells, def.telegraphTime, "miniboss_singularity")
            elseif atk == "teleport" then
                markTelegraph(ctx, {{x = mb.x, y = mb.y}}, 0.5, "miniboss_teleport")
                mb.telegraphCells = {{x = mb.x, y = mb.y}}
            end
            mb.state = "telegraph"
            mb.stateTimer = def.telegraphTime or 0.8
        end
    elseif mb.state == "telegraph" then
        mb.stateTimer = mb.stateTimer - dt
        if mb.stateTimer <= 0 then
            miniBoss.execute(mb, ctx)
            mb.state = "cooldown"
            mb.stateTimer = def.cooldown or 5.0
        end
    elseif mb.state == "cooldown" then
        mb.stateTimer = mb.stateTimer - dt
        if mb.stateTimer <= 0 then
            mb.state = "idle"
            mb.attackCooldown = 1.0
        end
    end
end

function miniBoss.execute(mb, ctx)
    if not mb or not mb.alive then return end
    ctx = ctx or {}
    local w = ctx.anchoGrilla or constants.MAX_GRID_COLS or 32
    local h = ctx.altoGrilla or constants.MAX_GRID_ROWS or 18
    local atk = mb.currentAttack
    local enemiesMod = ctx.enemies
    local obstacles = ctx.obstacles

    if atk == "charge" then
        -- Embestida sísmica: cruza hasta el borde destruyendo obstáculos
        local cells, horizontal = planCharge(mb, ctx)
        local step = 0
        if horizontal then
            step = (ctx.head and ctx.head.x or mb.x) >= mb.x and 1 or -1
            local x = mb.x
            while inBounds(x + step, mb.y, w, h) do
                x = x + step
                destroyAt(obstacles, x, mb.y)
            end
            mb.x = math.max(0, math.min(w - 2, x))
        else
            step = (ctx.head and ctx.head.y or mb.y) >= mb.y and 1 or -1
            local y = mb.y
            while inBounds(mb.x, y + step, w, h) do
                y = y + step
                destroyAt(obstacles, mb.x, y)
            end
            mb.y = math.max(0, math.min(h - 2, y))
        end
        mb.slammed = true
    elseif atk == "breath" then
        -- Aliento gélido: cono de 3 proyectiles + losetas de hielo al frente
        local head = ctx.head or {x = mb.x + 1, y = mb.y}
        local ang = math.atan2((head.y or mb.y) - mb.y, (head.x or mb.x) - mb.x)
        if enemiesMod then
            for _, off in ipairs({-0.3, 0, 0.3}) do
                local a = ang + off
                enemiesMod.addProjectile(mb.x, mb.y, math.cos(a) * 25, math.sin(a) * 25, 3.0, 1)
            end
        end
        if obstacles and obstacles.spawnAt then
            local sx = (head.x or 0) >= mb.x and 1 or -1
            for d = 2, 3 do
                local cx, cy = mb.x + sx * d, mb.y
                if inBounds(cx, cy, w, h) then
                    obstacles.spawnAt(cx, cy, "ice")
                end
            end
        end
    elseif atk == "swarm" then
        -- Enjambre: hasta 3 larvas suicidas con mecha de 2s que dejan baba
        if enemiesMod and enemiesMod.spawnAt then
            local larvae = 0
            for _, e in ipairs(enemiesMod.list or {}) do
                if e.alive and e.larva then larvae = larvae + 1 end
            end
            local dirs = {{1, 0}, {-1, 0}, {0, 1}, {0, -1}}
            for _, d in ipairs(dirs) do
                if larvae >= 3 then break end
                local nx, ny = mb.x + d[1], mb.y + d[2]
                if inBounds(nx, ny, w, h) then
                    local e = enemiesMod.spawnAt("chaser", nx, ny, {moveInterval = 0.2, dropCoins = 0})
                    if e then
                        e.larva = true
                        e.fuse = 2.0
                        e.fuseSlime = true
                        larvae = larvae + 1
                    end
                end
            end
        end
    elseif atk == "web" then
        -- Red pegajosa: 3x3 de baba sobre la cabeza (zona lenta)
        local head = ctx.head or {x = mb.x, y = mb.y}
        if obstacles and obstacles.spawnAt then
            for dx = -1, 1 do
                for dy = -1, 1 do
                    local cx, cy = (head.x or mb.x) + dx, (head.y or mb.y) + dy
                    if inBounds(cx, cy, w, h) then
                        obstacles.spawnAt(cx, cy, "slime")
                    end
                end
            end
        end
    elseif atk == "singularity" then
        mb.singu = {cx = math.floor(w / 2), cy = math.floor(h / 2), timer = 3.0}
        mb.singuPull = 0
    elseif atk == "teleport" then
        -- Desfase cuántico: reaparece tras la cola
        local tail = ctx.tail or {x = mb.x, y = mb.y}
        local head = ctx.head or {x = mb.x, y = mb.y}
        local dx = (tail.x or 0) - (head.x or 0)
        local dy = (tail.y or 0) - (head.y or 0)
        local nx = (tail.x or 0) + (dx ~= 0 and (dx > 0 and 2 or -2) or 0)
        local ny = (tail.y or 0) + (dy ~= 0 and (dy > 0 and 2 or -2) or 0)
        mb.x = math.max(0, math.min(w - 2, nx))
        mb.y = math.max(0, math.min(h - 2, ny))
        mb.flash = 0.5
        mb.justTeleported = true
    end
end

return miniBoss
