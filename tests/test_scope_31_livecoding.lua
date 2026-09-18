-- tests/test_scope_31_livecoding.lua
-- Test suite for core/livecoding.lua (Livecoding & Hot-Reloading)

local harness = require("tests.test_harness")
local livecoding = require("core.livecoding")

-- Ensure getDirectoryItems mock exists if running under memory VFS
if love and love.filesystem and not love.filesystem.getDirectoryItems then
    love.filesystem.getDirectoryItems = function(dir)
        local items = {}
        local vfs = love.filesystem.__getVFS and love.filesystem.__getVFS() or {}
        local prefix = (dir == "" or dir == ".") and "" or (dir .. "/")
        local seen = {}
        for path in pairs(vfs) do
            if prefix == "" then
                local slash = path:find("/")
                local entry = slash and path:sub(1, slash - 1) or path
                if not seen[entry] then seen[entry] = true; table.insert(items, entry) end
            elseif path:sub(1, #prefix) == prefix then
                local rest = path:sub(#prefix + 1)
                local slash = rest:find("/")
                local entry = slash and rest:sub(1, slash - 1) or rest
                if not seen[entry] then seen[entry] = true; table.insert(items, entry) end
            end
        end
        return items
    end
end

local function seedVFS()
    if love and love.filesystem and love.filesystem.write then
        love.filesystem.write("constants.lua", "return { TEST_CONST = 1 }")
        love.filesystem.write("main.lua", "return { isMain = true }")
        love.filesystem.write("core/config.lua", "return { cfg = true }")
    end
end

harness.describe("core/livecoding.lua - Initialization & Tracking", function()
    harness.before_each(function()
        seedVFS()
        livecoding.init()
    end)

    harness.it("initializes tracking state cleanly", function()
        harness.assert_not_nil(livecoding.trackedFiles, "trackedFiles initialized")
        harness.assert_nil(livecoding.lastError, "lastError is initially nil")
        harness.assert_nil(livecoding.recentReload, "recentReload is initially nil")
        harness.assert_equal(true, livecoding.enabled, "livecoding enabled by default")
    end)

    harness.it("discovers project root and tracked files", function()
        local files = livecoding.getAllTrackedFiles()
        harness.assert_gt(#files, 0, "Discovered tracked files")
        
        local foundMain = false
        local foundConstants = false
        for _, f in ipairs(files) do
            if f == "main.lua" then foundMain = true end
            if f == "constants.lua" then foundConstants = true end
        end
        harness.assert_true(foundMain, "Tracks main.lua")
        harness.assert_true(foundConstants, "Tracks constants.lua")
    end)
end)

harness.describe("core/livecoding.lua - In-Place Table Patching", function()
    harness.it("patches existing table keys in-place without breaking external references", function()
        local original = {
            version = 1,
            calc = function(a, b) return a + b end,
            sub = { factor = 10 }
        }
        local externalRef = original
        local externalSub = original.sub

        local replacement = {
            version = 2,
            calc = function(a, b) return a * b end,
            extra = "cyber",
            sub = { factor = 20, newKey = true }
        }

        package.loaded["_test_patch_mod"] = original

        for k, v in pairs(replacement) do
            if type(v) == "table" and type(original[k]) == "table" then
                for sk, sv in pairs(v) do original[k][sk] = sv end
            else
                original[k] = v
            end
        end

        harness.assert_equal(2, externalRef.version, "version updated via reference")
        harness.assert_equal(12, externalRef.calc(3, 4), "function updated to multiplication")
        harness.assert_equal("cyber", externalRef.extra, "new key added")
        harness.assert_equal(20, externalSub.factor, "sub-table updated in-place")
        harness.assert_equal(true, externalSub.newKey, "sub-table gained newKey")
        
        package.loaded["_test_patch_mod"] = nil
    end)
end)

harness.describe("core/livecoding.lua - Error Resilience & Recovery", function()
    harness.before_each(function()
        seedVFS()
        livecoding.init()
    end)

    harness.it("captures syntax errors safely without crashing", function()
        love.filesystem.write("core/syntax_broken.lua", "function broken( unclosed syntax error !!!")

        local ok, err = livecoding.reloadFile("core/syntax_broken.lua")
        harness.assert_false(ok, "Reload fails gracefully on syntax error")
        harness.assert_not_nil(livecoding.lastError, "lastError captured")
        harness.assert_equal("core/syntax_broken.lua", livecoding.lastError.file, "Error file recorded")
    end)

    harness.it("clears lastError upon successful reload", function()
        livecoding.lastError = { file = "constants.lua", message = "simulated", time = 10 }
        
        local ok, err = livecoding.reloadFile("constants.lua")
        harness.assert_true(ok, "Valid file reloaded successfully")
        harness.assert_nil(livecoding.lastError, "lastError cleared on success")
    end)

    harness.it("draws error banner and reload notification safely", function()
        -- 1. Idle draw
        livecoding.lastError = nil
        livecoding.recentReload = nil
        livecoding.draw()

        -- 2. Error banner draw
        livecoding.lastError = { file = "ui/menuLogo.lua", message = "unexpected symbol", time = 10 }
        livecoding.draw()

        -- 3. Success notification draw
        livecoding.lastError = nil
        livecoding.recentReload = { name = "ui/menuLogo.lua", time = (love.timer and love.timer.getTime and love.timer.getTime()) or 0 }
        livecoding.draw()
    end)
end)

harness.describe("core/livecoding.lua - Manual & Periodic Reloads", function()
    harness.before_each(function()
        seedVFS()
        livecoding.init()
    end)

    harness.it("executes reloadAll without crashing", function()
        local reloaded, errors = livecoding.reloadAll()
        harness.assert_gt(reloaded, 0, "At least some files reloaded")
        harness.assert_equal(0, errors, "No errors during reloadAll")
    end)

    harness.it("respects checkInterval during update calls", function()
        livecoding.timer = 0
        livecoding.checkInterval = 1.0

        livecoding.update(0.1)
        harness.assert_almost_equal(0.1, livecoding.timer, 0.001)

        livecoding.update(1.0)
        harness.assert_equal(0, livecoding.timer, "Timer resets after interval check")
    end)
end)
