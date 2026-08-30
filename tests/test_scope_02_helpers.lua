-- Test Scope 02: Core Helpers Module
-- Exhaustive unit tests for all helper functions and edge cases.

local harness = require("tests.test_harness")
local helpers = require("core.helpers")

harness.describe("core.helpers - deep_copy", function()
    harness.it("handles primitive non-table values", function()
        harness.assert_equal(42, helpers.deep_copy(42), "number copy")
        harness.assert_equal("hello", helpers.deep_copy("hello"), "string copy")
        harness.assert_equal(true, helpers.deep_copy(true), "boolean true copy")
        harness.assert_equal(false, helpers.deep_copy(false), "boolean false copy")
        harness.assert_nil(helpers.deep_copy(nil), "nil copy")
        local dummy_fn = function() return 1 end
        harness.assert_equal(dummy_fn, helpers.deep_copy(dummy_fn), "function reference preserved")
    end)

    harness.it("copies flat tables and prevents mutation of original", function()
        local orig = { a = 1, b = "two", c = true }
        local copy = helpers.deep_copy(orig)
        harness.assert_equal(orig.a, copy.a, "property a match")
        harness.assert_equal(orig.b, copy.b, "property b match")
        harness.assert_equal(orig.c, copy.c, "property c match")
        copy.a = 99
        harness.assert_equal(1, orig.a, "mutation isolated from orig")
    end)

    harness.it("copies deeply nested tables recursively", function()
        local orig = {
            level1 = {
                level2 = {
                    level3 = { value = "deep_secret" }
                }
            }
        }
        local copy = helpers.deep_copy(orig)
        harness.assert_equal("deep_secret", copy.level1.level2.level3.value, "deep value matches")
        copy.level1.level2.level3.value = "modified"
        harness.assert_equal("deep_secret", orig.level1.level2.level3.value, "deep mutation isolated")
    end)

    harness.it("copies array tables properly", function()
        local orig = { 10, 20, 30, 40 }
        local copy = helpers.deep_copy(orig)
        harness.assert_equal(#orig, #copy, "array length matches")
        for i = 1, #orig do
            harness.assert_equal(orig[i], copy[i], "element " .. i .. " matches")
        end
        copy[2] = 999
        harness.assert_equal(20, orig[2], "array mutation isolated")
    end)

    harness.it("handles empty tables", function()
        local orig = {}
        local copy = helpers.deep_copy(orig)
        harness.assert_not_nil(copy, "copy is table")
        harness.assert_nil(next(copy), "copy is empty")
    end)

    harness.it("handles tables with self-referential circular cycles without stack overflow", function()
        local t = { name = "cycle_test" }
        t.self = t
        local copy = helpers.deep_copy(t)
        harness.assert_not_nil(copy, "circular table copy created")
        harness.assert_equal("cycle_test", copy.name, "field preserved")
        harness.assert_equal(copy, copy.self, "copy.self points to copy, not orig")
        harness.assert_not_equal(t, copy, "copy is a distinct table instance")
    end)

    harness.it("handles mutually recursive circular tables", function()
        local nodeA = { name = "A" }
        local nodeB = { name = "B" }
        nodeA.neighbor = nodeB
        nodeB.neighbor = nodeA
        local copyA = helpers.deep_copy(nodeA)
        harness.assert_equal("A", copyA.name, "nodeA name")
        harness.assert_equal("B", copyA.neighbor.name, "nodeB name")
        harness.assert_equal(copyA, copyA.neighbor.neighbor, "nodeB's neighbor points back to copyA")
    end)

    harness.it("copies tables with table keys correctly", function()
        local keyTable = { keyName = "complexKey" }
        local orig = {}
        orig[keyTable] = "complexValue"
        local copy = helpers.deep_copy(orig)
        local foundKey, foundVal = next(copy)
        harness.assert_not_nil(foundKey, "table key exists in copy")
        harness.assert_equal("complexKey", foundKey.keyName, "table key contents copied")
        harness.assert_not_equal(keyTable, foundKey, "key is a new table clone")
        harness.assert_equal("complexValue", foundVal, "value matches")
    end)

    harness.it("preserves metatables on copied tables", function()
        local mt = {
            __add = function(a, b) return a.val + b.val end
        }
        local orig = setmetatable({ val = 10 }, mt)
        local copy = helpers.deep_copy(orig)
        harness.assert_equal(10, copy.val, "val preserved")
        local copy2 = helpers.deep_copy(orig)
        copy2.val = 20
        harness.assert_equal(30, copy + copy2, "metatable __add operator works on copies")
    end)

    harness.it("supports deepCopy alias", function()
        harness.assert_equal(helpers.deep_copy, helpers.deepCopy, "deepCopy alias exists")
    end)
end)

harness.describe("core.helpers - clamp", function()
    harness.it("returns val if within [min, max]", function()
        harness.assert_equal(5, helpers.clamp(5, 0, 10), "inside integer range")
        harness.assert_almost_equal(0.55, helpers.clamp(0.55, 0.1, 0.9), 0.0001, "inside float range")
    end)

    harness.it("clamps to min if val < min", function()
        harness.assert_equal(0, helpers.clamp(-5, 0, 10), "clamp to min integer")
        harness.assert_almost_equal(0.1, helpers.clamp(0.05, 0.1, 0.9), 0.0001, "clamp to min float")
    end)

    harness.it("clamps to max if val > max", function()
        harness.assert_equal(10, helpers.clamp(15, 0, 10), "clamp to max integer")
        harness.assert_almost_equal(0.9, helpers.clamp(1.5, 0.1, 0.9), 0.0001, "clamp to max float")
    end)

    harness.it("handles inverted bounds where min > max gracefully", function()
        harness.assert_equal(5, helpers.clamp(5, 10, 0), "inside inverted range")
        harness.assert_equal(0, helpers.clamp(-5, 10, 0), "below inverted min")
        harness.assert_equal(10, helpers.clamp(15, 10, 0), "above inverted max")
    end)

    harness.it("handles equal bounds min == max", function()
        harness.assert_equal(7, helpers.clamp(2, 7, 7), "below equal bound")
        harness.assert_equal(7, helpers.clamp(7, 7, 7), "at equal bound")
        harness.assert_equal(7, helpers.clamp(12, 7, 7), "above equal bound")
    end)

    harness.it("handles negative ranges", function()
        harness.assert_equal(-15, helpers.clamp(-15, -20, -10), "inside negative range")
        harness.assert_equal(-20, helpers.clamp(-25, -20, -10), "below negative min")
        harness.assert_equal(-10, helpers.clamp(-5, -20, -10), "above negative max")
    end)
end)

harness.describe("core.helpers - distance and distance_sq", function()
    harness.it("calculates euclidean distance with 4 scalar arguments", function()
        harness.assert_almost_equal(0, helpers.distance(0, 0, 0, 0), 0.0001, "zero distance")
        harness.assert_almost_equal(5, helpers.distance(0, 0, 3, 4), 0.0001, "3-4-5 triangle")
        harness.assert_almost_equal(5, helpers.distance(3, 4, 0, 0), 0.0001, "reverse points")
    end)

    harness.it("calculates distance with negative coordinates", function()
        harness.assert_almost_equal(5, helpers.distance(-3, -4, 0, 0), 0.0001, "negative to origin")
        harness.assert_almost_equal(5, helpers.distance(-2, -5, -5, -9), 0.0001, "negative to negative")
    end)

    harness.it("calculates distance with table points {x, y}", function()
        local p1 = { x = 0, y = 0 }
        local p2 = { x = 3, y = 4 }
        harness.assert_almost_equal(5, helpers.distance(p1, p2), 0.0001, "named table points")
    end)

    harness.it("calculates distance with array table points {x, y}", function()
        local p1 = { 0, 0 }
        local p2 = { 3, 4 }
        harness.assert_almost_equal(5, helpers.distance(p1, p2), 0.0001, "indexed table points")
    end)

    harness.it("handles nil coordinates defaulting to 0", function()
        harness.assert_almost_equal(5, helpers.distance(nil, nil, 3, 4), 0.0001, "nil p1 defaults to 0,0")
    end)

    harness.it("calculates distance_sq accurately without square root", function()
        harness.assert_equal(25, helpers.distance_sq(0, 0, 3, 4), "scalar distance_sq")
        harness.assert_equal(25, helpers.distance_sq({ x = 0, y = 0 }, { x = 3, y = 4 }), "table distance_sq")
        harness.assert_equal(helpers.distance_sq, helpers.distanceSq, "distanceSq alias exists")
    end)
end)

harness.describe("core.helpers - manhattan", function()
    harness.it("calculates manhattan distance with scalars", function()
        harness.assert_equal(0, helpers.manhattan(0, 0, 0, 0), "zero distance")
        harness.assert_equal(7, helpers.manhattan(1, 2, 4, 6), "manhattan distance dx=3, dy=4")
    end)

    harness.it("calculates manhattan distance with negative coordinates", function()
        harness.assert_equal(30, helpers.manhattan(-5, -10, 5, 10), "negative to positive delta")
    end)

    harness.it("calculates manhattan distance with table arguments", function()
        harness.assert_equal(7, helpers.manhattan({ x = 1, y = 2 }, { x = 4, y = 6 }), "named table manhattan")
        harness.assert_equal(7, helpers.manhattan({ 1, 2 }, { 4, 6 }), "array table manhattan")
    end)
end)

harness.describe("core.helpers - lerp and lerp_clamped", function()
    harness.it("calculates exact endpoints and midpoints", function()
        harness.assert_almost_equal(10, helpers.lerp(10, 20, 0), 0.0001, "lerp t=0")
        harness.assert_almost_equal(20, helpers.lerp(10, 20, 1), 0.0001, "lerp t=1")
        harness.assert_almost_equal(15, helpers.lerp(10, 20, 0.5), 0.0001, "lerp t=0.5")
    end)

    harness.it("extrapolates beyond [0, 1] when using standard lerp", function()
        harness.assert_almost_equal(30, helpers.lerp(10, 20, 2.0), 0.0001, "lerp t=2.0")
        harness.assert_almost_equal(0, helpers.lerp(10, 20, -1.0), 0.0001, "lerp t=-1.0")
    end)

    harness.it("handles negative ranges", function()
        harness.assert_almost_equal(0, helpers.lerp(-10, 10, 0.5), 0.0001, "midpoint of negative to positive")
        harness.assert_almost_equal(-20, helpers.lerp(-20, -10, 0), 0.0001, "negative start")
    end)

    harness.it("clamps factor t to [0, 1] in lerp_clamped", function()
        harness.assert_almost_equal(20, helpers.lerp_clamped(10, 20, 2.0), 0.0001, "lerp_clamped t=2.0")
        harness.assert_almost_equal(10, helpers.lerp_clamped(10, 20, -1.0), 0.0001, "lerp_clamped t=-1.0")
        harness.assert_almost_equal(15, helpers.lerp_clamped(10, 20, 0.5), 0.0001, "lerp_clamped t=0.5")
        harness.assert_equal(helpers.lerp_clamped, helpers.lerpClamped, "lerpClamped alias exists")
    end)
end)

harness.describe("core.helpers - sign", function()
    harness.it("returns 1 for positive numbers", function()
        harness.assert_equal(1, helpers.sign(10), "sign of 10")
        harness.assert_equal(1, helpers.sign(0.0001), "sign of 0.0001")
    end)

    harness.it("returns -1 for negative numbers", function()
        harness.assert_equal(-1, helpers.sign(-5), "sign of -5")
        harness.assert_equal(-1, helpers.sign(-0.0001), "sign of -0.0001")
    end)

    harness.it("returns 0 for zero", function()
        harness.assert_equal(0, helpers.sign(0), "sign of 0")
        harness.assert_equal(0, helpers.sign(-0), "sign of -0")
    end)
end)

harness.describe("core.helpers - round", function()
    harness.it("rounds positive floats to nearest integer", function()
        harness.assert_equal(3, helpers.round(3.2), "round 3.2")
        harness.assert_equal(4, helpers.round(3.7), "round 3.7")
        harness.assert_equal(4, helpers.round(3.5), "round 3.5")
    end)

    harness.it("rounds negative floats to nearest integer", function()
        harness.assert_equal(-3, helpers.round(-3.2), "round -3.2")
        harness.assert_equal(-4, helpers.round(-3.7), "round -3.7")
        harness.assert_equal(-4, helpers.round(-3.5), "round -3.5")
    end)

    harness.it("rounds to specified decimal places", function()
        harness.assert_almost_equal(3.14, helpers.round(3.14159, 2), 0.0001, "round 2 decimals")
        harness.assert_almost_equal(3.1416, helpers.round(3.14159, 4), 0.0001, "round 4 decimals")
        harness.assert_almost_equal(-2.56, helpers.round(-2.556, 2), 0.0001, "round negative decimals")
    end)
end)

harness.describe("core.helpers - map_range", function()
    harness.it("maps values linearly between ranges", function()
        harness.assert_almost_equal(50, helpers.map_range(5, 0, 10, 0, 100), 0.0001, "midpoint mapping")
        harness.assert_almost_equal(100, helpers.map_range(10, 0, 10, 0, 100), 0.0001, "upper bound mapping")
        harness.assert_almost_equal(0, helpers.map_range(0, 0, 10, 0, 100), 0.0001, "lower bound mapping")
    end)

    harness.it("maps inverted ranges properly", function()
        harness.assert_almost_equal(50, helpers.map_range(5, 0, 10, 100, 0), 0.0001, "inverted target range")
    end)

    harness.it("guards against division by zero when in_min == in_max", function()
        harness.assert_equal(50, helpers.map_range(5, 10, 10, 50, 100), "division by zero returns out_min")
    end)

    harness.it("supports mapRange alias", function()
        harness.assert_equal(helpers.map_range, helpers.mapRange, "mapRange alias exists")
    end)
end)

harness.describe("core.helpers - rect_overlap", function()
    harness.it("detects overlapping rectangles (8 scalars)", function()
        harness.assert_true(helpers.rect_overlap(0, 0, 10, 10, 5, 5, 10, 10), "overlapping rects")
        harness.assert_true(helpers.rect_overlap(0, 0, 20, 20, 5, 5, 5, 5), "nested rect")
    end)

    harness.it("detects disjoint rectangles (8 scalars)", function()
        harness.assert_false(helpers.rect_overlap(0, 0, 10, 10, 20, 20, 10, 10), "disjoint rects")
    end)

    harness.it("returns false for touching boundaries (strict overlap)", function()
        harness.assert_false(helpers.rect_overlap(0, 0, 10, 10, 10, 0, 10, 10), "touching x boundary")
        harness.assert_false(helpers.rect_overlap(0, 0, 10, 10, 0, 10, 10, 10), "touching y boundary")
    end)

    harness.it("handles negative coordinates", function()
        harness.assert_true(helpers.rect_overlap(-10, -10, 10, 10, -5, -5, 10, 10), "negative coord overlap")
    end)

    harness.it("normalizes negative width and height", function()
        harness.assert_true(helpers.rect_overlap(10, 10, -10, -10, 5, 5, 10, 10), "negative dimensions normalized")
    end)

    harness.it("returns false for zero or negative area rectangles", function()
        harness.assert_false(helpers.rect_overlap(0, 0, 0, 10, 0, 0, 10, 10), "zero width rect")
        harness.assert_false(helpers.rect_overlap(0, 0, 10, 0, 0, 0, 10, 10), "zero height rect")
    end)

    harness.it("supports table formats {x, y, w, h}", function()
        local r1 = { x = 0, y = 0, w = 10, h = 10 }
        local r2 = { x = 5, y = 5, width = 10, height = 10 }
        harness.assert_true(helpers.rect_overlap(r1, r2), "table rect overlap")
        harness.assert_equal(helpers.rect_overlap, helpers.rectsOverlap, "rectsOverlap alias exists")
    end)

    harness.it("supports array table formats {x, y, w, h}", function()
        local r1 = { 0, 0, 10, 10 }
        local r2 = { 5, 5, 10, 10 }
        harness.assert_true(helpers.rect_overlap(r1, r2), "array table rect overlap")
    end)
end)

harness.describe("core.helpers - point_in_rect", function()
    harness.it("detects points inside rect with scalars", function()
        harness.assert_true(helpers.point_in_rect(5, 5, 0, 0, 10, 10), "point strictly inside")
    end)

    harness.it("detects points outside rect with scalars", function()
        harness.assert_false(helpers.point_in_rect(15, 5, 0, 0, 10, 10), "point to right")
        harness.assert_false(helpers.point_in_rect(-5, 5, 0, 0, 10, 10), "point to left")
        harness.assert_false(helpers.point_in_rect(5, 15, 0, 0, 10, 10), "point below")
        harness.assert_false(helpers.point_in_rect(5, -5, 0, 0, 10, 10), "point above")
    end)

    harness.it("is inclusive on edges and corners", function()
        harness.assert_true(helpers.point_in_rect(0, 0, 0, 0, 10, 10), "top-left corner")
        harness.assert_true(helpers.point_in_rect(10, 10, 0, 0, 10, 10), "bottom-right corner")
        harness.assert_true(helpers.point_in_rect(5, 0, 0, 0, 10, 10), "top edge")
        harness.assert_true(helpers.point_in_rect(10, 5, 0, 0, 10, 10), "right edge")
    end)

    harness.it("handles negative coordinates and dimensions", function()
        harness.assert_true(helpers.point_in_rect(-5, -5, -10, -10, 10, 10), "negative coord point inside")
        harness.assert_true(helpers.point_in_rect(5, 5, 10, 10, -10, -10), "negative rect dimensions inside")
    end)

    harness.it("supports table point and rect formats", function()
        local p = { x = 5, y = 5 }
        local r = { x = 0, y = 0, w = 10, h = 10 }
        harness.assert_true(helpers.point_in_rect(p, r), "table point and rect")
        harness.assert_true(helpers.point_in_rect(5, 5, r), "scalar point and table rect")
        harness.assert_equal(helpers.point_in_rect, helpers.rectContains, "rectContains alias exists")
    end)
end)

harness.describe("core.helpers - rect_center", function()
    harness.it("computes center from scalars", function()
        local cx, cy = helpers.rect_center(0, 0, 10, 20)
        harness.assert_equal(5, cx, "center x")
        harness.assert_equal(10, cy, "center y")
    end)

    harness.it("computes center from table", function()
        local cx, cy = helpers.rect_center({ x = 10, y = 20, w = 30, h = 40 })
        harness.assert_equal(25, cx, "table center x")
        harness.assert_equal(40, cy, "table center y")
        harness.assert_equal(helpers.rect_center, helpers.rectCenter, "rectCenter alias exists")
    end)

    harness.it("computes center with negative coordinates", function()
        local cx, cy = helpers.rect_center(-10, -20, 10, 20)
        harness.assert_equal(-5, cx, "negative center x")
        harness.assert_equal(-10, cy, "negative center y")
    end)
end)

harness.describe("core.helpers - shuffle", function()
    harness.it("handles empty arrays", function()
        local list = {}
        local res = helpers.shuffle(list)
        harness.assert_equal(0, #res, "empty array length")
    end)

    harness.it("handles single-element arrays", function()
        local list = { 42 }
        local res = helpers.shuffle(list)
        harness.assert_equal(1, #res, "single element length")
        harness.assert_equal(42, res[1], "single element preserved")
    end)

    harness.it("shuffles arrays while preserving all elements", function()
        local orig = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
        local to_shuffle = { 1, 2, 3, 4, 5, 6, 7, 8, 9, 10 }
        local res = helpers.shuffle(to_shuffle)
        harness.assert_equal(#orig, #res, "length preserved")
        local counts = {}
        for _, v in ipairs(res) do
            counts[v] = (counts[v] or 0) + 1
        end
        for i = 1, 10 do
            harness.assert_equal(1, counts[i], "element " .. i .. " present exactly once")
        end
    end)

    harness.it("accepts custom deterministic RNG function", function()
        local list = { "a", "b", "c", "d" }
        -- Deterministic RNG that always returns 1
        local custom_rng = function(max) return 1 end
        local res = helpers.shuffle(list, custom_rng)
        harness.assert_equal(4, #res, "shuffled length")
    end)

    harness.it("handles non-table arguments safely", function()
        harness.assert_nil(helpers.shuffle(nil), "nil input")
        harness.assert_equal(123, helpers.shuffle(123), "number input")
    end)
end)

harness.describe("core.helpers - angle_diff and normalize_angle", function()
    harness.it("calculates 0 diff for identical angles", function()
        harness.assert_almost_equal(0, helpers.angle_diff(0, 0), 0.0001, "0 to 0")
        harness.assert_almost_equal(0, helpers.angle_diff(1.5, 1.5), 0.0001, "same angle")
    end)

    harness.it("calculates positive angle delta clockwise", function()
        local diff = helpers.angle_diff(0, math.pi / 2)
        harness.assert_almost_equal(math.pi / 2, diff, 0.0001, "0 to pi/2")
    end)

    harness.it("calculates negative angle delta counter-clockwise", function()
        local diff = helpers.angle_diff(math.pi / 2, 0)
        harness.assert_almost_equal(-math.pi / 2, diff, 0.0001, "pi/2 to 0")
    end)

    harness.it("handles wrap-around across 0 / 2*pi boundary", function()
        local a = math.rad(350)
        local b = math.rad(10)
        local diff = helpers.angle_diff(a, b)
        harness.assert_almost_equal(math.rad(20), diff, 0.0001, "350 deg to 10 deg is +20 deg")

        local diff_rev = helpers.angle_diff(b, a)
        harness.assert_almost_equal(-math.rad(20), diff_rev, 0.0001, "10 deg to 350 deg is -20 deg")
    end)

    harness.it("handles multiple full revolutions", function()
        harness.assert_almost_equal(0, helpers.angle_diff(0, math.pi * 4), 0.0001, "4*pi diff is 0")
    end)

    harness.it("supports angleDiff alias", function()
        harness.assert_equal(helpers.angle_diff, helpers.angleDiff, "angleDiff alias exists")
    end)

    harness.it("normalizes angles into [0, 2*pi)", function()
        harness.assert_almost_equal(0, helpers.normalize_angle(0), 0.0001, "normalize 0")
        harness.assert_almost_equal(3 * math.pi / 2, helpers.normalize_angle(-math.pi / 2), 0.0001, "normalize -pi/2")
        harness.assert_almost_equal(math.pi, helpers.normalize_angle(3 * math.pi), 0.0001, "normalize 3*pi")
        harness.assert_equal(helpers.normalize_angle, helpers.normalizeAngle, "normalizeAngle alias exists")
    end)
end)

harness.describe("core.helpers - choice", function()
    harness.it("returns nil on empty table or non-table", function()
        harness.assert_nil(helpers.choice({}), "empty table returns nil")
        harness.assert_nil(helpers.choice(nil), "nil returns nil")
        harness.assert_nil(helpers.choice(123), "number returns nil")
    end)

    harness.it("returns the only element on single-element array", function()
        harness.assert_equal("item", helpers.choice({ "item" }), "single item")
    end)

    harness.it("picks elements from array with custom RNG", function()
        local list = { "apple", "banana", "cherry" }
        local pick_first = helpers.choice(list, function(n) return 1 end)
        local pick_last = helpers.choice(list, function(n) return n end)
        harness.assert_equal("apple", pick_first, "custom rng pick 1")
        harness.assert_equal("cherry", pick_last, "custom rng pick last")
    end)
end)

harness.describe("core.helpers - table utilities (keys, values, filter, map)", function()
    harness.it("keys returns array of keys", function()
        local tbl = { alpha = 1, beta = 2 }
        local k = helpers.keys(tbl)
        harness.assert_equal(2, #k, "2 keys")
        local found = {}
        for _, name in ipairs(k) do found[name] = true end
        harness.assert_true(found.alpha and found.beta, "keys alpha and beta present")
        harness.assert_equal(helpers.keys, helpers.table_keys, "table_keys alias exists")
    end)

    harness.it("values returns array of values", function()
        local tbl = { alpha = 100, beta = 200 }
        local v = helpers.values(tbl)
        harness.assert_equal(2, #v, "2 values")
        local found = {}
        for _, val in ipairs(v) do found[val] = true end
        harness.assert_true(found[100] and found[200], "values 100 and 200 present")
        harness.assert_equal(helpers.values, helpers.table_values, "table_values alias exists")
    end)

    harness.it("filter filters items based on predicate", function()
        local list = { 1, 2, 3, 4, 5, 6 }
        local evens = helpers.filter(list, function(v) return v % 2 == 0 end)
        harness.assert_equal(3, #evens, "3 evens")
        harness.assert_equal(2, evens[1], "first even")
        harness.assert_equal(4, evens[2], "second even")
        harness.assert_equal(6, evens[3], "third even")
    end)

    harness.it("map transforms items using function", function()
        local list = { 1, 2, 3 }
        local doubled = helpers.map(list, function(v) return v * 2 end)
        harness.assert_equal(3, #doubled, "length 3")
        harness.assert_equal(2, doubled[1], "mapped item 1")
        harness.assert_equal(4, doubled[2], "mapped item 2")
        harness.assert_equal(6, doubled[3], "mapped item 3")
    end)

    harness.it("handles non-table arguments for table utils gracefully", function()
        harness.assert_table_equal({}, helpers.keys(nil), "keys(nil) returns empty table")
        harness.assert_table_equal({}, helpers.values(nil), "values(nil) returns empty table")
        harness.assert_table_equal({}, helpers.filter(nil, function() return true end), "filter(nil) returns empty table")
        harness.assert_table_equal({}, helpers.map(nil, function(v) return v end), "map(nil) returns empty table")
    end)
end)
