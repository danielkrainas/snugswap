-- A tiny describe/it test harness with no external dependencies, so `make test`
-- works against a stock Lua install with nothing to fetch first.

local stub = dofile((debug.getinfo(1, "S").source:sub(2):match("^(.*)/harness%.lua$")) .. "/gearswap_stub.lua")

local harness = {}

harness.stub = stub

local groups = {}
local current = nil

local results = { passed = 0, failed = 0, failures = {} }

--- Declare a group of tests. Each `it` inside gets a fresh library instance.
function harness.describe(name, fn)
    current = { name = name, tests = {} }
    table.insert(groups, current)
    fn()
    current = nil
end

--- Declare a single test. `fn` receives the fresh `snugs` instance and the stub.
function harness.it(name, fn)
    assert(current, "it() must be called inside describe()")
    table.insert(current.tests, { name = name, fn = fn })
end

-- ---------------------------------------------------------------- assertions

local function fail(msg, level)
    error({ __test_failure = true, message = msg }, (level or 2) + 1)
end

harness.fail = function(msg) fail(msg, 2) end

local function render(v)
    if type(v) == "table" then
        if v.name then return "<item " .. tostring(v.name) .. ">" end
        local parts = {}
        for k, item in pairs(v) do
            table.insert(parts, tostring(k) .. "=" .. (type(item) == "table" and tostring(item.name) or tostring(item)))
        end
        table.sort(parts)
        return "{" .. table.concat(parts, ", ") .. "}"
    end
    if type(v) == "string" then return string.format("%q", v) end
    return tostring(v)
end

harness.render = render

function harness.assert_equal(actual, expected, context)
    if actual ~= expected then
        fail(string.format("%sexpected %s, got %s",
            context and (context .. ": ") or "", render(expected), render(actual)))
    end
end

function harness.assert_true(value, context)
    if not value then
        fail(string.format("%sexpected a truthy value, got %s",
            context and (context .. ": ") or "", render(value)))
    end
end

function harness.assert_false(value, context)
    if value then
        fail(string.format("%sexpected a falsey value, got %s",
            context and (context .. ": ") or "", render(value)))
    end
end

function harness.assert_nil(value, context)
    if value ~= nil then
        fail(string.format("%sexpected nil, got %s",
            context and (context .. ": ") or "", render(value)))
    end
end

-- Marker for "this slot should be empty". A Lua table constructor drops `key = nil`
-- entirely, so `assert_slots{head = nil}` would assert nothing at all — use EMPTY.
harness.EMPTY = setmetatable({}, { __tostring = function() return "<empty>" end })

--- Assert the item currently equipped in `slot`. Pass nil or EMPTY for an empty slot.
function harness.assert_slot(slot, expected)
    if expected == harness.EMPTY then expected = nil end

    local actual = stub.slot(slot)
    if actual ~= expected then
        fail(string.format("slot %s: expected %s, got %s (equipped: %s)",
            slot, expected == nil and "<empty>" or render(expected),
            actual == nil and "<empty>" or render(actual), stub.summary()))
    end
end

--- Assert several slots at once: {head = "X", body = EMPTY}.
function harness.assert_slots(expectations)
    for slot, expected in pairs(expectations) do
        harness.assert_slot(slot, expected)
    end
end

--- Assert an ordered list matches exactly.
function harness.assert_list(actual, expected, context)
    local prefix = context and (context .. ": ") or ""
    if #actual ~= #expected then
        fail(string.format("%sexpected %d entries, got %d (%s)",
            prefix, #expected, #actual, table.concat(actual, " > ")))
    end
    for i = 1, #expected do
        if actual[i] ~= expected[i] then
            fail(string.format("%sposition %d: expected %s, got %s (full: %s)",
                prefix, i, render(expected[i]), render(actual[i]), table.concat(actual, " > ")))
        end
    end
end

-- ------------------------------------------------------------------- running

local RED, GREEN, DIM, BOLD, RESET = "\27[31m", "\27[32m", "\27[2m", "\27[1m", "\27[0m"

if os.getenv("NO_COLOR") then
    RED, GREEN, DIM, BOLD, RESET = "", "", "", "", ""
end

--- Run every declared group. Returns the number of failures.
function harness.run(filter)
    for _, group in ipairs(groups) do
        local shown = false
        for _, test in ipairs(group.tests) do
            local label = group.name .. " " .. test.name
            if not filter or label:lower():find(filter:lower(), 1, true) then
                if not shown then
                    print(BOLD .. group.name .. RESET)
                    shown = true
                end

                local snugs = stub.reset()
                local ok, err = pcall(test.fn, snugs, stub)

                if ok then
                    results.passed = results.passed + 1
                    print("  " .. GREEN .. "ok" .. RESET .. "   " .. test.name)
                else
                    results.failed = results.failed + 1
                    local message
                    if type(err) == "table" and err.__test_failure then
                        message = err.message
                    else
                        message = tostring(err)
                    end
                    table.insert(results.failures, { label = label, message = message })
                    print("  " .. RED .. "FAIL" .. RESET .. " " .. test.name)
                    print("       " .. DIM .. message:gsub("\n", "\n       ") .. RESET)
                end
            end
        end
        if shown then print() end
    end

    return results
end

function harness.report(results)
    local total = results.passed + results.failed

    if results.failed > 0 then
        print(BOLD .. "Failures:" .. RESET)
        for i, failure in ipairs(results.failures) do
            print(string.format("  %d) %s", i, failure.label))
            print("     " .. DIM .. failure.message:gsub("\n", "\n     ") .. RESET)
        end
        print()
        print(string.format("%s%d of %d failed%s", RED, results.failed, total, RESET))
    else
        print(string.format("%s%d passed%s", GREEN, results.passed, RESET))
    end

    return results.failed
end

--- Expose describe/it/assertions as globals so test files read cleanly.
function harness.install()
    for _, name in ipairs({"describe", "it", "assert_equal", "assert_true", "assert_false",
                           "assert_nil", "assert_slot", "assert_slots", "assert_list", "fail"}) do
        _G[name] = harness[name]
    end
    _G.stub = stub
    _G.EMPTY = harness.EMPTY
end

return harness
