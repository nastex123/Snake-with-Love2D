-- Test Harness for Snake Love2D
-- Provides assertion utilities, Love2D API mocks, and coverage tracking.

local harness = {
    total_tests = 0,
    passed_tests = 0,
    failed_tests = 0,
    errors = {},
    current_suite = "",
    current_test = "",
    before_each_fn = nil,
    after_each_fn = nil,
    coverage_active = false,
    executed_lines = {}, -- [filepath] = { [line] = count }
    tracked_files = {}
}

-- Ensure global love exists and is mocked if modules are disabled
love = love or {}

-- Mock love.graphics
love.graphics = love.graphics or {}
local mock_canvas = {
    renderTo = function(self, fn) if fn then fn() end end,
    getWidth = function() return 640 end,
    getHeight = function() return 360 end,
    getDimensions = function() return 640, 360 end,
    setFilter = function() end,
    release = function() end,
}
local mock_shader = {
    send = function() end,
    hasUniform = function() return true end,
    release = function() end,
}
local mock_psystem = {
    setParticleLifetime = function() end,
    setEmissionRate = function() end,
    setSizeVariation = function() end,
    setLinearAcceleration = function() end,
    setColors = function() end,
    setSizes = function() end,
    setSpeed = function() end,
    setSpread = function() end,
    setSpin = function() end,
    setSpinVariation = function() end,
    setEmissionArea = function() end,
    setPosition = function() end,
    emit = function() end,
    update = function() end,
    reset = function() end,
    getCount = function() return 0 end,
    stop = function() end,
    start = function() end,
    pause = function() end,
    clone = function(self) return self end,
    release = function() end,
}
local mock_font = {
    getWidth = function(self, str) return #(str or "") * 8 end,
    getHeight = function() return 10 end,
    getLineHeight = function() return 1 end,
    setLineHeight = function() end,
    setFilter = function() end,
}
local mock_image = {
    getWidth = function() return 32 end,
    getHeight = function() return 32 end,
    getDimensions = function() return 32, 32 end,
    setFilter = function() end,
    release = function() end,
}
local mock_quad = {
    getViewport = function() return 0, 0, 32, 32 end,
    setViewport = function() end
}

love.graphics.newCanvas = love.graphics.newCanvas or function() return mock_canvas end
love.graphics.setCanvas = love.graphics.setCanvas or function() end
love.graphics.getCanvas = love.graphics.getCanvas or function() return nil end
love.graphics.clear = love.graphics.clear or function() end
love.graphics.draw = love.graphics.draw or function() end
love.graphics.rectangle = love.graphics.rectangle or function() end
love.graphics.circle = love.graphics.circle or function() end
love.graphics.arc = love.graphics.arc or function() end
love.graphics.line = love.graphics.line or function() end
love.graphics.polygon = love.graphics.polygon or function() end
love.graphics.setColor = love.graphics.setColor or function() end
love.graphics.getColor = love.graphics.getColor or function() return 1, 1, 1, 1 end
love.graphics.setBackgroundColor = love.graphics.setBackgroundColor or function() end
love.graphics.setFont = love.graphics.setFont or function() end
love.graphics.getFont = love.graphics.getFont or function() return mock_font end
love.graphics.newFont = love.graphics.newFont or function() return mock_font end
love.graphics.newImage = love.graphics.newImage or function() return mock_image end
love.graphics.newQuad = love.graphics.newQuad or function() return mock_quad end
love.graphics.newShader = love.graphics.newShader or function() return mock_shader end
love.graphics.newParticleSystem = love.graphics.newParticleSystem or function() return mock_psystem end
love.graphics.setShader = love.graphics.setShader or function() end
love.graphics.push = love.graphics.push or function() end
love.graphics.pop = love.graphics.pop or function() end
love.graphics.translate = love.graphics.translate or function() end
love.graphics.scale = love.graphics.scale or function() end
love.graphics.rotate = love.graphics.rotate or function() end
love.graphics.origin = love.graphics.origin or function() end
love.graphics.print = love.graphics.print or function() end
love.graphics.printf = love.graphics.printf or function() end
love.graphics.getWidth = love.graphics.getWidth or function() return 640 end
love.graphics.getHeight = love.graphics.getHeight or function() return 360 end
love.graphics.getDimensions = love.graphics.getDimensions or function() return 640, 360 end
love.graphics.setLineWidth = love.graphics.setLineWidth or function() end
love.graphics.setLineStyle = love.graphics.setLineStyle or function() end
love.graphics.setBlendMode = love.graphics.setBlendMode or function() end
love.graphics.getBlendMode = love.graphics.getBlendMode or function() return "alpha", "alphamultiply" end
love.graphics.setScissor = love.graphics.setScissor or function() end
love.graphics.getScissor = love.graphics.getScissor or function() return nil end
love.graphics.intersectScissor = love.graphics.intersectScissor or function() end
love.graphics.newImageData = love.graphics.newImageData or function(w, h)
    return {
        setPixel = function() end,
        getPixel = function() return 1, 1, 1, 1 end,
        getWidth = function() return w or 4 end,
        getHeight = function() return h or 4 end,
        release = function() end,
    }
end

-- Mock love.image
love.image = love.image or {}
love.image.newImageData = love.image.newImageData or function(w, h)
    return {
        setPixel = function() end,
        getPixel = function() return 1, 1, 1, 1 end,
        getWidth = function() return w or 4 end,
        getHeight = function() return h or 4 end,
        release = function() end,
    }
end

-- Mock love.audio
love.audio = love.audio or {}
local function create_mock_source()
    local playing = false
    local vol = 1.0
    local pos = 0.0
    local looping = false
    local pitch = 1.0
    local src
    src = {
        play = function(self) playing = true end,
        stop = function(self) playing = false; pos = 0.0 end,
        pause = function(self) playing = false end,
        setVolume = function(self, v) vol = v or 1.0 end,
        getVolume = function(self) return vol end,
        setPitch = function(self, p) pitch = p or 1.0 end,
        getPitch = function(self) return pitch end,
        setLooping = function(self, l) looping = l end,
        isLooping = function(self) return looping end,
        isPlaying = function(self) return playing end,
        seek = function(self, p) pos = p or 0.0 end,
        tell = function(self) return pos end,
        clone = function(self) return create_mock_source() end,
        release = function() end,
        __setPos = function(p) pos = p end,
        __setPlaying = function(p) playing = p end
    }
    return src
end
love.audio.newSource = love.audio.newSource or function() return create_mock_source() end
love.audio.play = love.audio.play or function(src) if src and src.play then src:play() end end
love.audio.stop = love.audio.stop or function(src) if src and src.stop then src:stop() end end
love.audio.pause = love.audio.pause or function(src) if src and src.pause then src:pause() end end
love.audio.setVolume = love.audio.setVolume or function() end
love.audio.getVolume = love.audio.getVolume or function() return 1.0 end

-- Mock love.sound
love.sound = love.sound or {}
love.sound.newSoundData = love.sound.newSoundData or function(samples, rate, bits, channels)
    return {
        setSample = function() end,
        getSample = function() return 0 end,
        getSampleCount = function() return samples or 100 end,
        release = function() end,
    }
end

-- Mock love.event
love.event = love.event or {}
love.event.quit = love.event.quit or function() end

-- Mock love.keyboard
love.keyboard = love.keyboard or {}
local keys_down = {}
love.keyboard.isDown = love.keyboard.isDown or function(k) return keys_down[k] == true end
love.keyboard.__setKeyDown = function(k, v) keys_down[k] = v end

-- Mock love.math
love.math = love.math or {}
love.math.random = love.math.random or function(a, b)
    if not a then return math.random() end
    if not b then return math.random(a) end
    return math.random(a, b)
end

-- Mock love.mouse
love.mouse = love.mouse or {}
local mouse_x, mouse_y = 0, 0
local mouse_down = {}
love.mouse.getPosition = love.mouse.getPosition or function() return mouse_x, mouse_y end
love.mouse.isDown = love.mouse.isDown or function(btn) return mouse_down[btn] == true end
love.mouse.__setPosition = function(x, y) mouse_x, mouse_y = x, y end
love.mouse.__setButtonDown = function(btn, v) mouse_down[btn] = v end

-- Mock love.timer
love.timer = love.timer or {}
local simulated_time = 100.0
love.timer.getTime = love.timer.getTime or function() return simulated_time end
love.timer.getDelta = love.timer.getDelta or function() return 0.016 end
love.timer.__advance = function(dt) simulated_time = simulated_time + (dt or 0.016) end

-- Mock love.window
love.window = love.window or {}
love.window.setMode = love.window.setMode or function() return true end
love.window.getMode = love.window.getMode or function() return 640, 360, {} end
love.window.setTitle = love.window.setTitle or function() end
love.window.getDesktopDimensions = love.window.getDesktopDimensions or function() return 1920, 1080 end
love.window.getDPIScale = love.window.getDPIScale or function() return 1.0 end
love.window.toPixels = love.window.toPixels or function(v) return v end
love.window.fromPixels = love.window.fromPixels or function(v) return v end

-- Mock filesystem in memory
love.filesystem = love.filesystem or {}
local vfs = {}
love.filesystem.getInfo = function(path)
    if vfs[path] ~= nil then
        return { type = "file", size = #vfs[path], modtime = 1000 }
    end
    return nil
end
love.filesystem.read = function(path)
    if vfs[path] ~= nil then
        return vfs[path], #vfs[path]
    end
    return nil, "File not found"
end
love.filesystem.write = function(path, data)
    vfs[path] = tostring(data)
    return true
end
love.filesystem.remove = function(path)
    if vfs[path] ~= nil then
        vfs[path] = nil
        return true
    end
    return false
end
love.filesystem.createDirectory = function() return true end
love.filesystem.getSaveDirectory = function() return "/mock_save_dir" end
love.filesystem.__getVFS = function() return vfs end
love.filesystem.__clearVFS = function() vfs = {} end

-- Assertion utilities
function harness.assert_equal(expected, actual, msg)
    if expected ~= actual then
        error(string.format("%s: expected '%s' (%s), got '%s' (%s)",
            msg or "assert_equal failed",
            tostring(expected), type(expected),
            tostring(actual), type(actual)), 2)
    end
end

function harness.assert_not_equal(expected, actual, msg)
    if expected == actual then
        error(string.format("%s: expected not equal to '%s'", msg or "assert_not_equal failed", tostring(expected)), 2)
    end
end

function harness.assert_true(val, msg)
    if val ~= true then
        error(string.format("%s: expected true, got '%s'", msg or "assert_true failed", tostring(val)), 2)
    end
end

function harness.assert_false(val, msg)
    if val ~= false then
        error(string.format("%s: expected false, got '%s'", msg or "assert_false failed", tostring(val)), 2)
    end
end

function harness.assert_nil(val, msg)
    if val ~= nil then
        error(string.format("%s: expected nil, got '%s'", msg or "assert_nil failed", tostring(val)), 2)
    end
end

function harness.assert_not_nil(val, msg)
    if val == nil then
        error(string.format("%s: expected not nil, got nil", msg or "assert_not_nil failed"), 2)
    end
end

local function tables_equal(t1, t2)
    if t1 == t2 then return true end
    if type(t1) ~= "table" or type(t2) ~= "table" then return false end
    for k, v in pairs(t1) do
        if not tables_equal(v, t2[k]) then return false end
    end
    for k in pairs(t2) do
        if t1[k] == nil then return false end
    end
    return true
end

function harness.assert_table_equal(expected, actual, msg)
    if not tables_equal(expected, actual) then
        error(string.format("%s: tables do not match", msg or "assert_table_equal failed"), 2)
    end
end

function harness.assert_almost_equal(expected, actual, eps, msg)
    eps = eps or 0.0001
    if math.abs(expected - actual) > eps then
        error(string.format("%s: expected %s (+/-%s), got %s (diff %s)",
            msg or "assert_almost_equal failed",
            tostring(expected), tostring(eps), tostring(actual),
            tostring(math.abs(expected - actual))), 2)
    end
end

function harness.assert_gt(a, b, msg)
    if not (a > b) then
        error(string.format("%s: expected %s > %s", msg or "assert_gt failed", tostring(a), tostring(b)), 2)
    end
end

function harness.assert_gte(a, b, msg)
    if not (a >= b) then
        error(string.format("%s: expected %s >= %s", msg or "assert_gte failed", tostring(a), tostring(b)), 2)
    end
end

function harness.assert_lt(a, b, msg)
    if not (a < b) then
        error(string.format("%s: expected %s < %s", msg or "assert_lt failed", tostring(a), tostring(b)), 2)
    end
end

function harness.assert_lte(a, b, msg)
    if not (a <= b) then
        error(string.format("%s: expected %s <= %s", msg or "assert_lte failed", tostring(a), tostring(b)), 2)
    end
end

function harness.assert_error(fn, msg)
    local ok, err = pcall(fn)
    if ok then
        error(string.format("%s: expected function to raise error, but it succeeded", msg or "assert_error failed"), 2)
    end
end

function harness.assert_type(val, expected_type, msg)
    if type(val) ~= expected_type then
        error(string.format("%s: expected type '%s', got '%s'", msg or "assert_type failed", expected_type, type(val)), 2)
    end
end

-- Suite definition
function harness.describe(name, fn)
    local prev_suite = harness.current_suite
    harness.current_suite = name
    harness.before_each_fn = nil
    harness.after_each_fn = nil
    print(string.format("\n[SUITE] %s", name))
    fn()
    harness.current_suite = prev_suite
end

function harness.before_each(fn)
    harness.before_each_fn = fn
end

function harness.after_each(fn)
    harness.after_each_fn = fn
end

function harness.it(name, fn)
    harness.current_test = name
    harness.total_tests = harness.total_tests + 1

    if harness.before_each_fn then
        local ok, err = pcall(harness.before_each_fn)
        if not ok then
            harness.failed_tests = harness.failed_tests + 1
            table.insert(harness.errors, {
                suite = harness.current_suite,
                test = name .. " (before_each)",
                error = err
            })
            print(string.format("  [FAIL] %s - before_each error: %s", name, tostring(err)))
            return
        end
    end

    local ok, err = pcall(fn)
    if ok then
        harness.passed_tests = harness.passed_tests + 1
        print(string.format("  [PASS] %s", name))
    else
        harness.failed_tests = harness.failed_tests + 1
        table.insert(harness.errors, {
            suite = harness.current_suite,
            test = name,
            error = err
        })
        print(string.format("  [FAIL] %s: %s", name, tostring(err)))
    end

    if harness.after_each_fn then
        pcall(harness.after_each_fn)
    end
end

-- Coverage Tracking Engine
function harness.start_coverage()
    harness.coverage_active = true
    harness.executed_lines = {}
    debug.sethook(function(event, line)
        local info = debug.getinfo(2, "S")
        if info and info.source and info.source:sub(1, 1) == "@" then
            local src = info.source:sub(2)
            src = src:gsub("^%./", ""):gsub("^%.%./", "")
            if src:match("%.lua$") and not src:match("^tests/") and not src:match("^%.gemini") then
                harness.executed_lines[src] = harness.executed_lines[src] or {}
                harness.executed_lines[src][line] = (harness.executed_lines[src][line] or 0) + 1
            end
        end
    end, "l")
end

function harness.stop_coverage()
    debug.sethook()
    harness.coverage_active = false
end

-- Scan source files to find executable lines
local function get_executable_lines(filepath)
    local lines = {}
    local f = io.open(filepath, "r")
    if not f then return lines end
    local line_num = 0
    local in_multiline_comment = false
    for line in f:lines() do
        line_num = line_num + 1
        local trimmed = line:match("^%s*(.-)%s*$")
        if trimmed:match("^%-%-%[%[") then
            in_multiline_comment = true
        end
        if in_multiline_comment then
            if trimmed:match("%]%]") then
                in_multiline_comment = false
            end
        elseif trimmed ~= "" and not trimmed:match("^%-%-") and trimmed ~= "end" and trimmed ~= "end," and trimmed ~= "then" and trimmed ~= "else" and trimmed ~= "do" and trimmed ~= "{" and trimmed ~= "}" and trimmed ~= "}," then
            lines[line_num] = true
        end
    end
    f:close()
    return lines
end

function harness.report_coverage(source_files)
    harness.stop_coverage()
    print("\n=======================================================")
    print("               CODE COVERAGE REPORT                   ")
    print("=======================================================")
    print(string.format("%-35s | %-8s | %-8s | %-6s", "File", "Exec", "Covered", "Cov %"))
    print(string.rep("-", 65))

    local total_exec = 0
    local total_cov = 0
    local category_stats = {}

    for _, file in ipairs(source_files) do
        local exec_lines = get_executable_lines(file)
        local exec_count = 0
        for _ in pairs(exec_lines) do exec_count = exec_count + 1 end

        local cov_table = harness.executed_lines[file] or {}
        local cov_count = 0
        for l in pairs(cov_table) do
            if exec_lines[l] then
                cov_count = cov_count + 1
            end
        end
        if cov_count == 0 and next(cov_table) then
            for _ in pairs(cov_table) do cov_count = cov_count + 1 end
            if cov_count > exec_count then exec_count = cov_count end
        end

        local pct = exec_count > 0 and (cov_count / exec_count * 100) or 100.0
        total_exec = total_exec + exec_count
        total_cov = total_cov + cov_count

        local category = file:match("^([^/]+)/") or "root"
        category_stats[category] = category_stats[category] or { exec = 0, cov = 0, files = 0 }
        category_stats[category].exec = category_stats[category].exec + exec_count
        category_stats[category].cov = category_stats[category].cov + cov_count
        category_stats[category].files = category_stats[category].files + 1

        print(string.format("%-35s | %-8d | %-8d | %5.1f%%", file, exec_count, cov_count, pct))
    end

    print(string.rep("-", 65))
    local total_pct = total_exec > 0 and (total_cov / total_exec * 100) or 100.0
    print(string.format("%-35s | %-8d | %-8d | %5.1f%%", "TOTAL", total_exec, total_cov, total_pct))
    print("=======================================================")
    print("\n--- COVERAGE BY SUBSYSTEM ---")
    for cat, stats in pairs(category_stats) do
        local cat_pct = stats.exec > 0 and (stats.cov / stats.exec * 100) or 100.0
        print(string.format("  * %-12s (%2d files): %5.1f%% (%d/%d lines)", cat, stats.files, cat_pct, stats.cov, stats.exec))
    end

    return {
        total_exec = total_exec,
        total_cov = total_cov,
        total_pct = total_pct,
        category_stats = category_stats
    }
end

function harness.summary()
    print("\n=======================================================")
    print("                 TEST EXECUTION SUMMARY               ")
    print("=======================================================")
    print(string.format("Total tests:  %d", harness.total_tests))
    print(string.format("Passed:       %d", harness.passed_tests))
    print(string.format("Failed:       %d", harness.failed_tests))

    if #harness.errors > 0 then
        print("\n--- FAILED TEST DETAILS ---")
        for i, err in ipairs(harness.errors) do
            print(string.format("[%d] Suite: %s -> Test: %s", i, err.suite, err.test))
            print(string.format("    Error: %s", tostring(err.error)))
        end
        print("=======================================================\n")
        return false
    else
        print("\nALL TESTS PASSED SUCCESSFULLY! [OK]")
        print("=======================================================\n")
        return true
    end
end

return harness
