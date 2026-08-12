-- Every template must load, register cleanly, and survive being driven through
-- each of its modes. A template that errors in game is worse than no template.

local function template_paths()
    local paths = {}
    for _, dir in ipairs({ "archetypes", "jobs" }) do
        local pipe = io.popen("ls " .. stub.root .. "/templates/" .. dir .. "/*.lua 2>/dev/null")
        for line in pipe:lines() do table.insert(paths, line) end
        pipe:close()
    end
    table.sort(paths)
    return paths
end

local ACTIONS = {
    { english = "Cure IV",       type = "WhiteMagic",    skill = "Healing Magic",    action_type = "Magic" },
    { english = "Fire V",        type = "BlackMagic",    skill = "Elemental Magic",  action_type = "Magic", element = "Fire" },
    { english = "Haste",         type = "WhiteMagic",    skill = "Enhancing Magic",  action_type = "Magic" },
    { english = "Savage Blade",  type = "WeaponSkill",   skill = "Sword",            action_type = "Ability" },
    { english = "Provoke",       type = "JobAbility",    action_type = "Ability" },
    { english = "Utsusemi: Ni",  type = "Ninjutsu",      skill = "Ninjutsu",         action_type = "Magic" },
    { english = "Valor Minuet",  type = "BardSong",      skill = "Singing",          action_type = "Magic" },
    { english = "Chaos Roll",    type = "CorsairRoll",   action_type = "Ability" },
    { english = "Fire Shot",     type = "CorsairShot",   action_type = "Ability" },
    { english = "Shot",          type = "WeaponSkill",   skill = "Archery",          action_type = "Ranged Attack" },
    { english = "Inferno",       type = "BloodPactRage", skill = "Summoning Magic",  action_type = "Ability" },
    { english = "Indi-Haste",    type = "Geomancy",      skill = "Geomancy",         action_type = "Magic" },
    { english = "Wing Slap",     type = "Monster",       action_type = "Ability" },
    { english = "Head Butt",     type = "BlueMagic",     skill = "Blue Magic",       action_type = "Magic" },
}

local function drive(snugs, label)
    for _, spell in ipairs(ACTIONS) do
        for _, hook in ipairs({ "do_precast", "do_midcast", "do_aftercast" }) do
            local ok, err = pcall(snugs[hook], snugs, spell)
            if not ok then
                fail(label .. ": " .. hook .. "(" .. spell.english .. ") -> " .. tostring(err))
            end
        end
    end

    for _, status in ipairs({ "Idle", "Engaged", "Resting" }) do
        player.status = status
        local ok, err = pcall(snugs.do_status_change, snugs, status, "Idle")
        if not ok then fail(label .. ": status_change(" .. status .. ") -> " .. tostring(err)) end
    end
    player.status = "Idle"

    local ok, err = pcall(snugs.do_pet_midcast, snugs,
        { english = "Inferno", type = "BloodPactRage", skill = "Summoning Magic" })
    if not ok then fail(label .. ": pet_midcast -> " .. tostring(err)) end
end

describe("templates", function()
    local paths = template_paths()

    it("finds the template files", function()
        assert_true(#paths >= 20, "expected the templates folder to be populated, found " .. #paths)
    end)

    for _, path in ipairs(paths) do
        local name = path:match("templates/(.*)$")

        it(name .. " loads and registers cleanly", function(snugs)
            _G.include = function() end
            _G.require = function() end

            local chunk, load_err = loadfile(path)
            assert_true(chunk ~= nil, "could not parse: " .. tostring(load_err))

            local ok, err = pcall(chunk)
            assert_true(ok, "error while loading: " .. tostring(err))

            assert_equal(type(_G.get_sets), "function", "template defines no get_sets()")

            local ok2, err2 = pcall(_G.get_sets)
            assert_true(ok2, "error in get_sets(): " .. tostring(err2))

            -- Templates ship empty, so nothing should complain on a clean load.
            for _, line in ipairs(stub.chat) do
                if line:find("error:", 1, true) or line:find("warning:", 1, true) then
                    fail("registration complained: " .. line)
                end
            end
        end)

        it(name .. " survives every action and every mode", function(snugs)
            _G.include = function() end
            _G.require = function() end
            assert(loadfile(path))()
            _G.get_sets()

            drive(snugs, name)

            -- Walk each mode through all of its values, driving actions at each.
            for mode_key, mode in pairs(sets.modes or {}) do
                local steps = mode.cycle_values and #mode.cycle_values or 2
                for _ = 1, steps do
                    local ok, err = pcall(snugs.do_self_command, snugs, "toggle " .. mode_key)
                    if not ok then
                        fail(name .. ": toggle " .. mode_key .. " -> " .. tostring(err))
                    end
                    drive(snugs, name .. " [" .. mode_key .. "=" .. tostring(sets.modes[mode_key].v) .. "]")
                end
            end

            for _, cmd in ipairs({ "cycle weapon", "list modes", "util warp", "warp", "nexus", "speed" }) do
                local ok, err = pcall(snugs.do_self_command, snugs, cmd)
                if not ok then fail(name .. ": gs c " .. cmd .. " -> " .. tostring(err)) end
            end
        end)

        it(name .. " wires the GearSwap hooks", function(snugs)
            _G.include = function() end
            _G.require = function() end
            assert(loadfile(path))()

            for _, hook in ipairs({ "precast", "midcast", "aftercast", "status_change",
                                    "self_command", "pet_change", "pet_midcast", "pet_aftercast" }) do
                assert_equal(type(_G[hook]), "function", hook .. " was not installed")
            end
        end)
    end
end)
