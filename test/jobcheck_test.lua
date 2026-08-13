-- The job linter has to keep catching what it was built to catch. Each case
-- below corresponds to a bug found in a real job lua; test/fixtures/broken_job.lua
-- plants all of them in one file.

local root = stub.root
local env = dofile(root .. "/tools/jobcheck/env.lua")
local lint = dofile(root .. "/tools/jobcheck/lint.lua")
local snapshot = dofile(root .. "/tools/jobcheck/snapshot.lua")

local FIXTURE = root .. "/test/fixtures/broken_job.lua"

local function findings_for(path)
    local out = lint.run(env, path)
    local joined = {}
    for _, f in ipairs(out) do
        table.insert(joined, f.level .. " " .. f.message .. " " .. (f.detail or ""))
    end
    return table.concat(joined, "\n"), out
end

describe("job linter", function()
    local EXPECTED = {
        { "require() instead of include()",        "require%(%) where GearSwap provides include" },
        { "once-transition on the wrong phase",    'create_once_mode_transition on the "any" phase' },
        { "condition after and_combine closes",    "condition chained after and_combine" },
        { "action_type for a Corsair action",      'action_type%("CorsairRoll"%) never matches' },
        { "duplicate slot in one set",             'slot "left_ring" is set twice' },
        { "weapon skill in the midcast tier",      'snugs:midcast%("Savage Blade"%) never fires' },
        { "duplicate registration",                "already exists" },
        { "undefined global",                      '"never_defined_anywhere" is read but never defined' },
        { "accidental global",                     '"leaked_engaged_set" is a global' },
        { "unused local",                          'local "unused_set" is built but never used' },
        { "a set that resolves to nothing",        "set evaluates to nothing" },
    }

    for _, case in ipairs(EXPECTED) do
        local label, pattern = case[1], case[2]
        it("reports " .. label, function()
            local text = findings_for(FIXTURE)
            assert_true(text:find(pattern) ~= nil,
                "no finding matched " .. pattern .. "\n--- findings were:\n" .. text)
        end)
    end

    it("reports nothing alarming for a healthy file", function()
        local _, out = findings_for(root .. "/templates/jobs/war.lua")
        for _, f in ipairs(out) do
            assert_false(f.level == "ERROR", "unexpected error: " .. f.message)
            assert_false(f.level == "WARN", "unexpected warning: " .. f.message)
        end
    end)

    it("collapses the empty-set note for an unfilled template", function()
        local text = findings_for(root .. "/templates/jobs/whm.lua")
        assert_true(text:find("looks like an unfilled template") ~= nil)
    end)

    it("does not choke on a file that fails to load", function()
        local report = env.load(root .. "/test/fixtures/does_not_exist.lua")
        assert_false(report.ok)
        assert_true(#report.errors > 0)
    end)
end)

describe("job snapshots", function()
    it("renders deterministically", function()
        local a = snapshot.render(env, root .. "/templates/jobs/smn.lua")
        local b = snapshot.render(env, root .. "/templates/jobs/smn.lua")
        assert_equal(a, b, "two renders of the same file differed")
    end)

    it("records modes, registrations and every scenario", function()
        local text = snapshot.render(env, root .. "/templates/jobs/geo.lua")
        assert_true(text:find("[modes]", 1, true) ~= nil)
        assert_true(text:find("[registered]", 1, true) ~= nil)
        for _, scenario in ipairs(env.SCENARIOS) do
            assert_true(text:find("[scenario " .. scenario.name .. "]", 1, true) ~= nil,
                "missing scenario " .. scenario.name)
        end
        assert_true(text:find("[mode style=", 1, true) ~= nil, "modes were not swept")
    end)

    it("changes when the gear changes", function()
        local before = snapshot.render(env, root .. "/templates/jobs/war.lua")
        local after = snapshot.render(env, FIXTURE)
        assert_false(before == after)
    end)

    it("names a failed load rather than rendering an empty file", function()
        local text = snapshot.render(env, root .. "/test/fixtures/does_not_exist.lua")
        assert_true(text:find("!!", 1, true) ~= nil)
    end)
end)
