-- Mode declaration, cycling, and key binding.

describe("add_mode", function()
    it("stores the declared options", function(snugs)
        snugs:add_mode("style", {
            initial_value = "dd",
            description = "Playstyle",
            cycle_values = { "dd", "tank" },
            shortcut = "^f1",
        })

        local mode = sets.modes.style
        assert_equal(mode.v, "dd")
        assert_equal(mode.description, "Playstyle")
        assert_equal(mode.shortcut, "^f1")
        assert_list(mode.cycle_values, { "dd", "tank" })
    end)

    it("derives cycle values from gearset mappings", function(snugs)
        snugs:add_mode("jug", {
            initial_value = "sheep",
            gearset_mappings = {
                sheep = { ammo = "Lyrical Broth" },
                tiger = { ammo = "Meaty Broth" },
            },
        })

        local values = sets.modes.jug.cycle_values
        assert_equal(#values, 2)

        table.sort(values)
        assert_list(values, { "sheep", "tiger" })
    end)

    it("defaults to a boolean-ish true with no options", function(snugs)
        snugs:add_mode("flag", {})
        assert_equal(sets.modes.flag.v, true)
        assert_equal(sets.modes.flag.description, "")
        assert_equal(sets.modes.flag.cycle_values, nil)
    end)

    it("cannot express an initial value of false", function(snugs)
        -- `options.initial_value or true` turns a false initial value into true,
        -- which is why on/off modes are written as string cycle values.
        snugs:add_mode("flag", { initial_value = false })
        assert_equal(sets.modes.flag.v, true)
    end)
end)

describe("toggling modes", function()
    it("advances a cycle mode and wraps around", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a", "b", "c" } })

        snugs:do_self_command("toggle style")
        assert_equal(sets.modes.style.v, "b")

        snugs:do_self_command("toggle style")
        assert_equal(sets.modes.style.v, "c")

        snugs:do_self_command("toggle style")
        assert_equal(sets.modes.style.v, "a")
    end)

    it("flips a boolean mode", function(snugs)
        snugs:add_mode("flag", {})

        snugs:do_self_command("toggle flag")
        assert_equal(sets.modes.flag.v, false)

        snugs:do_self_command("toggle flag")
        assert_equal(sets.modes.flag.v, true)
    end)

    it("recovers when the current value is not in the cycle list", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a", "b" } })
        sets.modes.style.v = "off-list"

        snugs:do_self_command("toggle style")
        assert_equal(sets.modes.style.v, "a")
    end)

    it("re-equips the status set after toggling", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a", "b" } })
        snugs:default_idle({ head = "idle" })

        snugs:do_self_command("toggle style")
        assert_slot("head", "idle")
    end)

    it("errors for an unknown mode", function(snugs)
        snugs:do_self_command("toggle nope")
        assert_true(stub.said("No such mode to toggle"))
    end)
end)

describe("setting modes", function()
    it("sets a cycle mode to a listed value", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a", "b" } })
        snugs:do_self_command("set style b")
        assert_equal(sets.modes.style.v, "b")
    end)

    it("warns for a value outside the cycle list", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a", "b" } })
        snugs:do_self_command("set style z")
        assert_equal(sets.modes.style.v, "a")
        assert_true(stub.said("invalid value for mode"))
    end)

    it("matches a non-string cycle value by its string form", function(snugs)
        snugs:add_mode("level", { initial_value = 1, cycle_values = { 1, 2, 3 } })
        snugs:do_self_command("set level 3")
        assert_equal(sets.modes.level.v, 3)
    end)

    it("warns when no value is given for a cycle mode", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a", "b" } })
        snugs:do_self_command("set style")
        assert_true(stub.said("no value provided"))
    end)

    it("sets a boolean mode from true and false", function(snugs)
        snugs:add_mode("flag", {})

        snugs:do_self_command("set flag false")
        assert_equal(sets.modes.flag.v, false)

        snugs:do_self_command("set flag true")
        assert_equal(sets.modes.flag.v, true)
    end)

    it("rejects a non-boolean value for a boolean mode", function(snugs)
        snugs:add_mode("flag", {})
        snugs:do_self_command("set flag maybe")
        assert_true(stub.said("Invalid value for boolean mode"))
    end)

    it("errors for an unknown mode", function(snugs)
        snugs:do_self_command("set nope value")
        assert_true(stub.said("No such mode to set"))
    end)
end)

describe("debug and trace switches", function()
    it("toggles debug", function(snugs)
        assert_false(snugs:is_debugging())

        snugs:do_self_command("set debug true")
        assert_true(snugs:is_debugging())

        snugs:do_self_command("set debug false")
        assert_false(snugs:is_debugging())
    end)

    it("toggles trace", function(snugs)
        assert_false(snugs:is_tracing())

        snugs:do_self_command("set trace true")
        assert_true(snugs:is_tracing())

        snugs:do_self_command("set trace false")
        assert_false(snugs:is_tracing())
    end)

    it("warns on an unrecognised value", function(snugs)
        snugs:do_self_command("set trace maybe")
        assert_false(snugs:is_tracing())
        assert_true(stub.said("invalid value for trace"))
    end)

    it("ignores a non-boolean argument to trace()", function(snugs)
        snugs:trace("yes")
        assert_false(snugs:is_tracing())

        snugs:trace(true)
        assert_true(snugs:is_tracing())
    end)

    it("logs the resolved set while tracing", function(snugs)
        snugs:trace(true)
        snugs:util("test", { head = "Nyame Helm" })
        snugs:do_self_command("util test")
        assert_true(stub.said("Final set to equip"))
        assert_true(stub.said("Nyame Helm"))
    end)
end)

describe("listing modes", function()
    it("prints each mode with its value, description and cycle values", function(snugs)
        snugs:add_mode("style", {
            initial_value = "dd",
            description = "Playstyle",
            cycle_values = { "dd", "tank" },
        })

        snugs:do_self_command("list modes")
        assert_true(stub.said("style: dd"))
        assert_true(stub.said("(Playstyle)"))
        assert_true(stub.said("cycle values: dd, tank"))
    end)
end)

describe("key bindings", function()
    it("binds a toggle command for every mode with a shortcut", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a" }, shortcut = "^f1" })
        snugs:add_mode("quiet", { initial_value = "a", cycle_values = { "a" } })

        snugs:bind_modes()

        assert_list(stub.commands, { "bind ^f1 gs c toggle style" })
    end)

    it("binds on get_sets when wired", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a" }, shortcut = "^f1" })
        snugs:wire_all()

        get_sets()
        assert_list(stub.commands, { "bind ^f1 gs c toggle style" })
    end)
end)

describe("wire_all", function()
    it("installs the hooks that are not already defined", function(snugs)
        snugs:wire_all()

        for _, hook in ipairs({ "precast", "midcast", "aftercast", "status_change",
                                "self_command", "pet_midcast", "pet_aftercast", "pet_change" }) do
            assert_equal(type(_G[hook]), "function", hook .. " should be installed")
        end
    end)

    it("leaves a hook the job lua already defined", function(snugs)
        local called = false
        _G.precast = function() called = true end

        snugs:wire_all()
        precast(stub.spell{})

        assert_true(called, "the job lua's own precast should still be in place")
    end)

    it("routes an installed hook into the library", function(snugs)
        snugs:default_idle({ head = "idle" })
        snugs:wire_all()

        aftercast(stub.spell{ english = "Cure" })
        assert_slot("head", "idle")
    end)
end)
