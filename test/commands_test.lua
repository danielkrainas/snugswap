-- Weapon sets and the `gs c ...` self commands.

describe("weapon sets", function()
    it("equips the default weapon set with the status set", function(snugs)
        snugs:default_weaponset({ main = "Naegling", sub = "Blurred Shield +1" })
        snugs:default_idle({ head = "idle" })

        snugs:do_status_change("Idle", "Engaged")
        assert_slots{ main = "Naegling", sub = "Blurred Shield +1", head = "idle" }
    end)

    it("switches to a named set and keeps it", function(snugs)
        snugs:default_weaponset({ main = "Twashtar" })
        snugs:weaponset("proc", { main = "Brass Dagger", sub = "Sapara" })
        snugs:default_idle({ head = "idle" })

        snugs:do_self_command("set weapon proc")
        assert_slot("main", "Brass Dagger")

        stub.clear_equipped()
        snugs:do_status_change("Idle", "Engaged")
        assert_slots{ main = "Brass Dagger", sub = "Sapara" }
    end)

    it("warns for an unknown weapon set", function(snugs)
        snugs:default_weaponset({ main = "Twashtar" })
        snugs:do_self_command("set weapon nope")
        assert_true(stub.said("no such weapon set"))
    end)

    it("warns when set weapon is given no value", function(snugs)
        snugs:default_weaponset({ main = "Twashtar" })
        snugs:do_self_command("set weapon")
        assert_true(stub.said("no value provided to set weapon set"))
    end)

    it("cycles through the registered sets in registration order", function(snugs)
        snugs:default_weaponset({ main = "default" })
        snugs:weaponset("a", { main = "a" })
        snugs:weaponset("b", { main = "b" })

        snugs:do_self_command("cycle weapon")
        assert_slot("main", "a")

        stub.clear_equipped()
        snugs:do_self_command("cycle weapon")
        assert_slot("main", "b")

        stub.clear_equipped()
        snugs:do_self_command("cycle weapon")
        assert_slot("main", "default")
    end)

    it("warns when there is nothing to cycle", function(snugs)
        snugs:do_self_command("cycle weapon")
        assert_true(stub.said("no weapon sets defined"))
    end)

    it("errors for an unknown cycle target", function(snugs)
        snugs:do_self_command("cycle hat")
        assert_true(stub.said("unknown cycle target"))
    end)

    it("does not add a duplicate name to the cycle list", function(snugs)
        snugs:weaponset("a", { main = "first" })
        snugs:weaponset("a", { main = "second" })
        assert_equal(#snugs.weaponset_cycle_list, 1)
    end)
end)

describe("utility sets", function()
    it("equips a named utility set", function(snugs)
        snugs:util("learning", { hands = "Assim. Bazu. +3" })
        snugs:do_self_command("util learning")
        assert_slot("hands", "Assim. Bazu. +3")
    end)

    it("warns for an unknown utility set", function(snugs)
        snugs:do_self_command("util nope")
        assert_true(stub.said("no such utility set"))
    end)

    it("supports the warp, nexus and speed shorthands", function(snugs)
        snugs:util("warp", { left_ring = "Warp Ring" })
        snugs:util("nexus", { back = "Nexus Cape" })
        snugs:util("speed", { feet = "Herald's Gaiters" })

        snugs:do_self_command("warp")
        assert_slot("left_ring", "Warp Ring")

        stub.clear_equipped()
        snugs:do_self_command("nexus")
        assert_slot("back", "Nexus Cape")

        stub.clear_equipped()
        snugs:do_self_command("speed")
        assert_slot("feet", "Herald's Gaiters")
    end)

    it("warns when a shorthand set is not defined", function(snugs)
        snugs:do_self_command("warp")
        assert_true(stub.said("no warp utility set defined"))

        snugs:do_self_command("nexus")
        assert_true(stub.said("no nexus utility set defined"))

        snugs:do_self_command("speed")
        assert_true(stub.said("no speed utility set defined"))
    end)

    it("evaluates a gearset stored as a utility set", function(snugs)
        buffactive["Diffusion"] = true
        snugs:util("blu", gearset({ head = "base" })
            :and_combine(gearset({ feet = "diffusion" }):when():buff("Diffusion")))

        snugs:do_self_command("util blu")
        assert_slots{ head = "base", feet = "diffusion" }
    end)
end)

describe("unknown commands", function()
    it("reports the command back", function(snugs)
        snugs:do_self_command("frobnicate the thing")
        assert_true(stub.said("unknown command: frobnicate the thing"))
    end)

    it("splits arguments on whitespace", function(snugs)
        snugs:add_mode("style", { initial_value = "a", cycle_values = { "a", "b" } })
        snugs:do_self_command("   set    style    b   ")
        assert_equal(sets.modes.style.v, "b")
    end)
end)

describe("warning deduplication", function()
    it("reports a repeated warning only once", function(snugs)
        snugs:do_self_command("util nope")
        snugs:do_self_command("util nope")

        local count = 0
        for _, line in ipairs(stub.chat) do
            if line:find("no such utility set", 1, true) then count = count + 1 end
        end

        assert_equal(count, 1)
    end)

    it("repeats warnings while tracing", function(snugs)
        snugs:trace(true)
        snugs:do_self_command("util nope")
        snugs:do_self_command("util nope")

        local count = 0
        for _, line in ipairs(stub.chat) do
            if line:find("no such utility set", 1, true) then count = count + 1 end
        end

        assert_equal(count, 2)
    end)
end)
