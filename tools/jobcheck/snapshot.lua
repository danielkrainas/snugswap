-- Records what a job lua actually equips, so a later edit shows up as a diff.
--
-- The output is deliberately plain text in a fixed order: the point is that it
-- reads as a description of the file's behaviour, and that `diff` on it is
-- meaningful to a human.

local snapshot = {}

local function slots_of(stub)
    local parts = {}
    for _, slot in ipairs(stub.SLOTS) do
        local item = stub.slot(slot)
        if item then table.insert(parts, slot .. "=" .. item) end
    end
    -- Slot aliases GearSwap accepts that are not in the canonical list.
    for _, alias in ipairs({ "ring1", "ring2", "ear1", "ear2" }) do
        local item = stub.equipped[alias]
        if item then
            table.insert(parts, alias .. "=" .. (type(item) == "table" and item.name or tostring(item)))
        end
    end
    return #parts == 0 and "-" or table.concat(parts, ", ")
end

local function reset_state()
    _G.player.status = "Idle"
    _G.player.hpp = 100
    _G.player.mpp = 100
    _G.player.tp = 0
    _G.pet.isvalid = false
    for k in pairs(_G.buffactive) do _G.buffactive[k] = nil end
    _G.world.weather_element = "None"
    _G.world.day_element = "Fire"
end

--- Build the snapshot text for one job lua.
function snapshot.render(env, path, opts)
    local report = env.load(path, opts)
    local out = {}
    local function line(s) table.insert(out, s) end

    line("# " .. report.name)
    line("# recorded by tools/jobcheck.lua -- regenerate with `make snapshot`")
    line("")

    if not report.ok then
        for _, e in ipairs(report.errors) do line("!! " .. e) end
        return table.concat(out, "\n") .. "\n"
    end

    local snugs = report.snugs

    -- Modes, so a changed default or a renamed value is visible on its own.
    local mode_keys = {}
    for key in pairs(_G.sets.modes or {}) do table.insert(mode_keys, key) end
    table.sort(mode_keys)
    if #mode_keys > 0 then
        line("[modes]")
        for _, key in ipairs(mode_keys) do
            local mode = _G.sets.modes[key]
            local values = mode.cycle_values and table.concat(
                (function()
                    local t = {}
                    for _, v in ipairs(mode.cycle_values) do t[#t + 1] = tostring(v) end
                    return t
                end)(), ", ") or "-"
            line(("  %-16s = %-12s [%s]"):format(key, tostring(mode.v), values))
        end
        line("")
    end

    -- Which keys are registered, per tier. Catches a set silently vanishing.
    line("[registered]")
    for _, tier in ipairs({ "weapons", "idle", "engaged", "fastcast", "precast",
                            "midcast", "weaponskill", "util" }) do
        local keys = {}
        for key in pairs(_G.sets[tier] or {}) do table.insert(keys, key) end
        table.sort(keys)
        line(("  %-12s %s"):format(tier, #keys == 0 and "-" or table.concat(keys, ", ")))
    end
    line("")

    local function record(header, apply)
        reset_state()
        if apply then apply() end
        line("[" .. header .. "]")

        env.stub.clear_equipped()
        pcall(snugs.do_status_change, snugs, _G.player.status, "Idle")
        line(("  %-24s %s"):format("status", slots_of(env.stub)))

        for _, action in ipairs(env.ACTIONS) do
            for _, hook in ipairs({ "do_precast", "do_midcast" }) do
                env.stub.clear_equipped()
                local ok = pcall(snugs[hook], snugs, action)
                local label = (hook == "do_precast" and "precast " or "midcast ") .. action.label
                line(("  %-24s %s"):format(label, ok and slots_of(env.stub) or "!! errored"))
            end
        end
        line("")
    end

    for _, scenario in ipairs(env.SCENARIOS) do
        record("scenario " .. scenario.name, function() env.apply(scenario) end)
    end

    -- Each mode swept independently. The full cross product would explode on a
    -- file with several modes, and per-mode differences are what matter.
    for _, key in ipairs(mode_keys) do
        local mode = _G.sets.modes[key]
        for _, value in ipairs(mode.cycle_values or {}) do
            record(("mode %s=%s"):format(key, tostring(value)), function()
                _G.sets.modes[key].v = value
            end)
        end
        mode.v = (mode.cycle_values or {})[1] or mode.v
    end

    return table.concat(out, "\n") .. "\n"
end

function snapshot.path_for(dir, name)
    return dir .. "/" .. name:gsub("%.lua$", "") .. ".txt"
end

return snapshot
