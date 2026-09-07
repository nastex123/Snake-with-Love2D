-- tests/test_scope_26_shopv2.lua — Tienda v2: puestos mixtos, reroll, tarot comprable (GDD §13)
-- Suite consola-only: config, precios, stock, compra y reroll. Sin love.graphics real.
local harness = require("tests.test_harness")
local constants = require("constants")
local world = require("core.world")
local shop = require("systems.shop")
local tarot = require("systems.tarot")

harness.describe("Scope 26 - Shop v2 config", function()
    harness.it("exposes reroll, stalls and tarot-chance constants", function()
        harness.assert_equal(5, constants.SHOP_REROLL_BASE, "reroll base 5")
        harness.assert_equal(2, constants.SHOP_REROLL_STEP, "reroll step 2")
        harness.assert_equal(3, constants.SHOP_STALLS, "3 stalls")
        harness.assert_equal(0.40, constants.SHOP_TAROT_CHANCE, "40% tarot chance")
    end)

    harness.it("prices every tarot by tier S60/A45/B30/C20", function()
        local expected = {
            mercury = 60, reaper = 60,
            absolute_zero = 45, dragon_blood = 45, eagle_eye = 45,
            iron_spine = 30, magic_circle = 30, astral_mirror = 30, alchemical_digestion = 30,
            shadow_thief = 20, midas_pouch = 20, iron_heart = 20,
        }
        for id, price in pairs(expected) do
            harness.assert_equal(price, tarot.price(id), "price tier " .. id)
        end
        harness.assert_equal(30, tarot.price("no_existe"), "unknown defaults 30")
    end)
end)

harness.describe("Scope 26 - Tarot shop pool and buy", function()
    harness.it("shopPool excludes equipped cards", function()
        tarot.reset()
        harness.assert_equal(12, #tarot.shopPool(), "full pool unequipped")
        tarot.buy("mercury")
        local pool = tarot.shopPool()
        harness.assert_equal(11, #pool, "equipped excluded")
        for _, id in ipairs(pool) do
            harness.assert_true(id ~= "mercury", "mercury not offered twice")
        end
        tarot.reset()
    end)

    harness.it("buy appends without duplicates or cap", function()
        tarot.reset()
        harness.assert_equal("mercury", tarot.buy("mercury"), "buys mercury")
        harness.assert_nil(tarot.buy("mercury"), "duplicate rejected")
        harness.assert_nil(tarot.buy("no_existe"), "unknown rejected")
        harness.assert_true(tarot.has("mercury"), "equipped after buy")
        tarot.reset()
    end)
end)

harness.describe("Scope 26 - Mixed stock and reroll", function()
    harness.it("abrir renew rolls fresh stock, plain abrir keeps it", function()
        shop.reset(false)
        tarot.reset()
        shop.abrir(500, true)
        local first = {}
        for i, o in ipairs(shop.getStock()) do first[i] = o and (o.kind .. ":" .. o.id) or "nil" end
        shop.abrir(500)
        for i, o in ipairs(shop.getStock()) do
            local key = o and (o.kind .. ":" .. o.id) or "nil"
            harness.assert_equal(first[i], key, "stock persists without renew")
        end
        shop.reset(false)
        tarot.reset()
    end)

    harness.it("mixed rolls hit both kinds over many visits", function()
        shop.reset(false)
        tarot.reset()
        local kinds = {}
        for _ = 1, 40 do
            shop.abrir(500, true)
            for _, o in ipairs(shop.getStock()) do
                if o then kinds[o.kind] = true end
            end
        end
        harness.assert_true(kinds.item, "items appear")
        harness.assert_true(kinds.tarot, "tarots appear")
        shop.reset(false)
        tarot.reset()
    end)

    harness.it("buyStall buys tarots with kind flag and marks sold", function()
        shop.reset(false)
        tarot.reset()
        shop.abrir(500, true)
        local found = false
        for i, o in ipairs(shop.getStock()) do
            if o and o.kind == "tarot" then
                local res = shop.buyStall(i, 500)
                harness.assert_not_nil(res, "tarot purchase succeeds")
                harness.assert_equal("tarot", res.kind, "result flags tarot kind")
                harness.assert_equal(o.price, res.costo, "charges tier price")
                harness.assert_true(tarot.has(o.id), "card equipped")
                harness.assert_true(shop.getStock()[i].sold, "stall marked sold")
                harness.assert_nil(shop.buyStall(i, 500), "sold stall rejects")
                found = true
                break
            end
        end
        if not found then
            local pool = tarot.shopPool()
            harness.assert_true(#pool > 0, "pool available when no tarot rolled")
        end
        shop.reset(false)
        tarot.reset()
    end)

    harness.it("buyStall rejects without funds", function()
        shop.reset(false)
        tarot.reset()
        shop.abrir(500, true)
        for i, o in ipairs(shop.getStock()) do
            if o and not o.sold then
                harness.assert_nil(shop.buyStall(i, 0), "no purchase without funds")
                break
            end
        end
        harness.assert_nil(shop.buyStall(99, 500), "invalid stall rejected")
        shop.reset(false)
        tarot.reset()
    end)
end)
