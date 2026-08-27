-- Test suite for core/logger.lua
-- Covers log levels, message formatting, nil handling, table serialization,
-- circular references, string formatting fallback, and custom writers.

local harness = require("tests.test_harness")
local Log = require("core.logger")

harness.describe("core/logger.lua - Log Levels and Configuration", function()
    harness.before_each(function()
        Log.setLevel(Log.LEVEL_INFO)
        Log.resetWriter()
    end)

    harness.it("defines valid level constants in ascending order", function()
        harness.assert_equal(1, Log.LEVEL_DEBUG, "LEVEL_DEBUG constant")
        harness.assert_equal(2, Log.LEVEL_INFO,  "LEVEL_INFO constant")
        harness.assert_equal(3, Log.LEVEL_WARN,  "LEVEL_WARN constant")
        harness.assert_equal(4, Log.LEVEL_ERROR, "LEVEL_ERROR constant")
        harness.assert_equal(5, Log.LEVEL_OFF,   "LEVEL_OFF constant")
    end)

    harness.it("gets and sets numeric levels correctly", function()
        Log.setLevel(Log.LEVEL_DEBUG)
        harness.assert_equal(Log.LEVEL_DEBUG, Log.getLevel(), "level set to DEBUG")

        Log.setLevel(Log.LEVEL_ERROR)
        harness.assert_equal(Log.LEVEL_ERROR, Log.getLevel(), "level set to ERROR")

        Log.setLevel(Log.LEVEL_OFF)
        harness.assert_equal(Log.LEVEL_OFF, Log.getLevel(), "level set to OFF")
    end)

    harness.it("sets levels using case-insensitive string names", function()
        Log.setLevel("debug")
        harness.assert_equal(Log.LEVEL_DEBUG, Log.getLevel(), "string 'debug'")

        Log.setLevel("INFO")
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "string 'INFO'")

        Log.setLevel("warn")
        harness.assert_equal(Log.LEVEL_WARN, Log.getLevel(), "string 'warn'")

        Log.setLevel("warning")
        harness.assert_equal(Log.LEVEL_WARN, Log.getLevel(), "string 'warning'")

        Log.setLevel("Error")
        harness.assert_equal(Log.LEVEL_ERROR, Log.getLevel(), "string 'Error'")

        Log.setLevel("off")
        harness.assert_equal(Log.LEVEL_OFF, Log.getLevel(), "string 'off'")

        Log.setLevel("silent")
        harness.assert_equal(Log.LEVEL_OFF, Log.getLevel(), "string 'silent'")

        Log.setLevel("none")
        harness.assert_equal(Log.LEVEL_OFF, Log.getLevel(), "string 'none'")
    end)

    harness.it("ignores invalid level arguments safely without modifying active level", function()
        Log.setLevel(Log.LEVEL_INFO)

        Log.setLevel(0)
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "ignore 0")

        Log.setLevel(99)
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "ignore 99")

        Log.setLevel(-1)
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "ignore -1")

        Log.setLevel("invalid_level_name")
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "ignore invalid string")

        Log.setLevel(nil)
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "ignore nil")

        Log.setLevel(true)
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "ignore boolean")

        Log.setLevel({})
        harness.assert_equal(Log.LEVEL_INFO, Log.getLevel(), "ignore table")
    end)

    harness.it("retrieves level names correctly", function()
        harness.assert_equal("DEBUG", Log.getLevelName(Log.LEVEL_DEBUG), "DEBUG name")
        harness.assert_equal("INFO",  Log.getLevelName(Log.LEVEL_INFO),  "INFO name")
        harness.assert_equal("WARN",  Log.getLevelName(Log.LEVEL_WARN),  "WARN name")
        harness.assert_equal("ERROR", Log.getLevelName(Log.LEVEL_ERROR), "ERROR name")
        harness.assert_equal("OFF",   Log.getLevelName(Log.LEVEL_OFF),   "OFF name")
        harness.assert_equal("UNKNOWN", Log.getLevelName(999), "unknown level name")

        Log.setLevel(Log.LEVEL_WARN)
        harness.assert_equal("WARN", Log.getLevelName(), "current level name")
    end)

    harness.it("evaluates level enablement predicates accurately", function()
        Log.setLevel(Log.LEVEL_WARN)

        harness.assert_false(Log.isDebugEnabled(), "debug disabled when level is WARN")
        harness.assert_false(Log.isInfoEnabled(),  "info disabled when level is WARN")
        harness.assert_true(Log.isWarnEnabled(),   "warn enabled when level is WARN")
        harness.assert_true(Log.isErrorEnabled(),  "error enabled when level is WARN")

        Log.setLevel(Log.LEVEL_OFF)
        harness.assert_false(Log.isDebugEnabled(), "debug disabled when OFF")
        harness.assert_false(Log.isInfoEnabled(),  "info disabled when OFF")
        harness.assert_false(Log.isWarnEnabled(),  "warn disabled when OFF")
        harness.assert_false(Log.isErrorEnabled(), "error disabled when OFF")
    end)
end)

harness.describe("core/logger.lua - Message Formatting and Varargs", function()
    local captured = {}

    harness.before_each(function()
        captured = {}
        Log.setLevel(Log.LEVEL_DEBUG)
        Log.setWriter(function(msg, level)
            captured[#captured + 1] = { msg = msg, level = level }
        end)
    end)

    harness.after_each(function()
        Log.resetWriter()
    end)

    harness.it("formats messages with valid timestamp and level tags", function()
        Log.info("Test message")
        harness.assert_equal(1, #captured, "one message captured")
        harness.assert_true(captured[1].msg:match("^%[%d%d:%d%d:%d%d%] %[INFO%] Test message$") ~= nil, "message format match")
    end)

    harness.it("handles empty arguments gracefully", function()
        Log.warn()
        harness.assert_equal(1, #captured, "one message captured")
        harness.assert_true(captured[1].msg:match("^%[%d%d:%d%d:%d%d%] %[WARN%]$") ~= nil, "empty message format match")
    end)

    harness.it("formats multiple scalar arguments separated by spaces", function()
        Log.info("Score:", 100, "Lives:", 3, "Active:", true)
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1].msg:find("Score: 100 Lives: 3 Active: true") ~= nil, "scalars concatenated")
    end)

    harness.it("supports printf style string formatting when format specifiers match", function()
        Log.info("Player %s has %d coins (%.2f multiplier)", "Snake", 50, 1.5)
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1].msg:find("Player Snake has 50 coins %(1.50 multiplier%)") ~= nil, "printf format matched")
    end)

    harness.it("gracefully falls back to vararg stringification if printf formatting fails", function()
        Log.info("100% discount", "now", "available")
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1].msg:find("100%% discount now available") ~= nil, "fallback stringification")
    end)

    harness.it("returns formatted message string on dispatch", function()
        local res = Log.error("Critical failure")
        harness.assert_type(res, "string", "write returns string")
        harness.assert_true(res:find("%[ERROR%] Critical failure") ~= nil, "contains error message")
    end)
end)

harness.describe("core/logger.lua - Nil Value Safety", function()
    local captured = {}

    harness.before_each(function()
        captured = {}
        Log.setLevel(Log.LEVEL_DEBUG)
        Log.setWriter(function(msg, level)
            captured[#captured + 1] = msg
        end)
    end)

    harness.after_each(function()
        Log.resetWriter()
    end)

    harness.it("handles single nil argument without error", function()
        Log.info(nil)
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1]:find("%[INFO%] nil") ~= nil, "single nil printed as string")
    end)

    harness.it("handles nil at the beginning of arguments", function()
        Log.info(nil, "foo", "bar")
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1]:find("nil foo bar") ~= nil, "nil at start handled")
    end)

    harness.it("handles nil in the middle of arguments", function()
        Log.info("foo", nil, "bar")
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1]:find("foo nil bar") ~= nil, "nil in middle handled")
    end)

    harness.it("handles nil at the end of arguments", function()
        Log.info("foo", "bar", nil)
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1]:find("foo bar nil") ~= nil, "nil at end handled")
    end)

    harness.it("handles multiple consecutive nils", function()
        Log.info(nil, nil, nil)
        harness.assert_equal(1, #captured, "message logged")
        harness.assert_true(captured[1]:find("nil nil nil") ~= nil, "multiple nils handled")
    end)
end)

harness.describe("core/logger.lua - Table Serialization and Deep Inspection", function()
    harness.it("serializes empty tables as {}", function()
        local str = Log.serialize({})
        harness.assert_equal("{}", str, "empty table")
    end)

    harness.it("serializes sequential array tables with values", function()
        local str = Log.serialize({10, 20, 30})
        harness.assert_equal("{10, 20, 30}", str, "integer array")

        local strStr = Log.serialize({"apple", "banana"})
        harness.assert_equal('{"apple", "banana"}', strStr, "string array")
    end)

    harness.it("serializes key-value maps with deterministic key ordering", function()
        local data = { b = 2, a = 1, c = 3 }
        local str = Log.serialize(data)
        harness.assert_equal("{a = 1, b = 2, c = 3}", str, "sorted map keys")
    end)

    harness.it("serializes nested table hierarchies", function()
        local nested = {
            hero = {
                hp = 100,
                pos = { x = 5, y = 10 }
            }
        }
        local str = Log.serialize(nested)
        harness.assert_equal("{hero = {hp = 100, pos = {x = 5, y = 10}}}", str, "nested tables")
    end)

    harness.it("truncates at max recursion depth limit", function()
        local deep = { l1 = { l2 = { l3 = { l4 = { l5 = "bottom" } } } } }
        local str = Log.serialize(deep, 2)
        harness.assert_equal("{l1 = {l2 = {...}}}", str, "depth limit reached")
    end)

    harness.it("respects custom __tostring in metatable", function()
        local obj = { id = 42 }
        setmetatable(obj, {
            __tostring = function(self)
                return "Entity#" .. tostring(self.id)
            end
        })
        local str = Log.serialize(obj)
        harness.assert_equal("Entity#42", str, "custom tostring honored")
    end)

    harness.it("handles failing __tostring metamethod safely", function()
        local brokenObj = { id = 99 }
        setmetatable(brokenObj, {
            __tostring = function()
                error("Broken metamethod")
            end
        })
        -- Should not throw an unhandled error
        local ok, str = pcall(Log.serialize, brokenObj)
        harness.assert_true(ok, "safe fallback on broken metamethod")
        harness.assert_not_nil(str, "string returned")
    end)
end)

harness.describe("core/logger.lua - Circular Reference Protection", function()
    harness.it("detects and avoids crash on self-referential tables", function()
        local t = { name = "root" }
        t.self = t

        local ok, str = pcall(Log.serialize, t)
        harness.assert_true(ok, "serialization does not crash")
        harness.assert_equal('{name = "root", self = <circular>}', str, "circular reference labeled")
    end)

    harness.it("detects and avoids crash on mutually circular tables", function()
        local a = { name = "A" }
        local b = { name = "B" }
        a.partner = b
        b.partner = a

        local ok, str = pcall(Log.serialize, a)
        harness.assert_true(ok, "mutual cycle does not crash")
        harness.assert_equal('{name = "A", partner = {name = "B", partner = <circular>}}', str, "mutual cycle resolved")
    end)

    harness.it("handles shared non-cyclic references (DAG) correctly", function()
        local sharedChild = { val = 42 }
        local root = {
            first = sharedChild,
            second = sharedChild
        }

        local ok, str = pcall(Log.serialize, root)
        harness.assert_true(ok, "DAG serialization succeeds")
        harness.assert_equal("{first = {val = 42}, second = {val = 42}}", str, "shared tables serialized in DAG")
    end)
end)

harness.describe("core/logger.lua - Level Filtering and Writer Control", function()
    local logs = {}

    harness.before_each(function()
        logs = {}
        Log.setWriter(function(msg, level)
            logs[#logs + 1] = { msg = msg, level = level }
        end)
    end)

    harness.after_each(function()
        Log.resetWriter()
    end)

    harness.it("filters log levels below active threshold", function()
        Log.setLevel(Log.LEVEL_WARN)

        Log.debug("Debug msg")
        Log.info("Info msg")
        Log.warn("Warn msg")
        Log.error("Error msg")

        harness.assert_equal(2, #logs, "only warn and error captured")
        harness.assert_equal(Log.LEVEL_WARN,  logs[1].level, "first captured is warn")
        harness.assert_equal(Log.LEVEL_ERROR, logs[2].level, "second captured is error")
    end)

    harness.it("suppresses all outputs when level is LEVEL_OFF", function()
        Log.setLevel(Log.LEVEL_OFF)

        Log.debug("Debug msg")
        Log.info("Info msg")
        Log.warn("Warn msg")
        Log.error("Error msg")

        harness.assert_equal(0, #logs, "no logs when LEVEL_OFF")
    end)

    harness.it("allows all messages when level is LEVEL_DEBUG", function()
        Log.setLevel(Log.LEVEL_DEBUG)

        Log.debug("Debug msg")
        Log.info("Info msg")
        Log.warn("Warn msg")
        Log.error("Error msg")

        harness.assert_equal(4, #logs, "all 4 levels captured")
    end)

    harness.it("resets writer to default via resetWriter()", function()
        Log.resetWriter()
        harness.assert_nil(Log.writer, "Log.writer is nil after reset")
    end)

    harness.it("handles error inside custom writer function gracefully without crashing", function()
        Log.setWriter(function()
            error("Simulated writer failure")
        end)
        Log.setLevel(Log.LEVEL_INFO)

        local ok = pcall(function()
            Log.info("This should not raise uncaught error")
        end)
        harness.assert_true(ok, "writer exception handled safely")
    end)
end)
