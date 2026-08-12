-- Middleware, lookup keys, spell families and mode transitions.

describe("middleware registration", function()
    it("runs middleware for the matching phase", function(snugs)
        local seen = {}
        snugs:register_middleware("precast", function(ctx)
            table.insert(seen, ctx.phase)
        end, { name = "spy" })

        snugs:do_precast(stub.spell{})
        snugs:do_midcast(stub.spell{})

        assert_list(seen, { "precast" })
    end)

    it("runs 'any' middleware for every phase", function(snugs)
        local seen = {}
        snugs:register_middleware("any", function(ctx)
            table.insert(seen, ctx.phase)
        end, { name = "spy" })

        snugs:do_precast(stub.spell{})
        snugs:do_midcast(stub.spell{})
        snugs:do_aftercast(stub.spell{})

        assert_list(seen, { "precast", "midcast", "aftercast" })
    end)

    it("runs higher priority middleware first", function(snugs)
        local order = {}
        snugs:register_middleware("midcast", function() table.insert(order, "low") end,
            { name = "low", priority = 1 })
        snugs:register_middleware("midcast", function() table.insert(order, "high") end,
            { name = "high", priority = 10 })

        snugs:do_midcast(stub.spell{})
        assert_list(order, { "high", "low" })
    end)

    it("warns for an unknown phase", function(snugs)
        snugs:register_middleware("nonsense", function() end, { name = "spy" })
        assert_true(stub.said("No such context phase"))
    end)

    it("sees the spell name but not yet the type or skill", function(snugs)
        local during
        snugs:register_middleware("midcast", function(ctx)
            during = { ctx:has_lookup("Cure"), ctx:has_lookup("WhiteMagic") }
        end, { name = "spy" })

        snugs:do_midcast(stub.spell{ english = "Cure" })

        assert_true(during[1], "the spell name should already be present")
        assert_false(during[2], "the type should be appended after middleware runs")
    end)
end)

describe("context lookups", function()
    it("appends a key after the spell name but before type and skill", function(snugs)
        snugs:register_middleware("midcast", function(ctx) ctx:add_lookup("Custom") end,
            { name = "spy" })

        local ctx = snugs:_new_context("midcast", { spell = stub.spell{ english = "Cure" } })
        assert_list(ctx.lookups, { "Cure", "AllCure", "Custom", "WhiteMagic", "Healing Magic" })
    end)

    it("promotes a prepended key to the front", function(snugs)
        snugs:register_middleware("midcast", function(ctx) ctx:prepend_lookup("Custom") end,
            { name = "spy" })

        local ctx = snugs:_new_context("midcast", { spell = stub.spell{ english = "Cure" } })
        assert_equal(ctx.lookups[1], "Custom")
    end)

    it("ignores a duplicate key", function(snugs)
        local ctx = SnugContext:new("midcast", {})
        ctx:add_lookup("A")
        ctx:add_lookup("A")
        ctx:prepend_lookup("A")

        assert_list(ctx.lookups, { "A" })
    end)

    it("warns on a nil key", function()
        local ctx = SnugContext:new("midcast", {})
        ctx:add_lookup(nil)
        ctx:prepend_lookup(nil)

        assert_equal(#ctx.lookups, 0)
        assert_true(stub.said("nil key"))
    end)

    it("carries arbitrary metadata", function()
        local ctx = SnugContext:new("midcast", {})
        assert_nil(ctx:get_meta("count"))

        ctx:set_meta("count", 3)
        assert_equal(ctx:get_meta("count"), 3)
    end)

    it("resolves the first matching key", function()
        local ctx = SnugContext:new("midcast", {})
        ctx:add_lookup("first")
        ctx:add_lookup("second")

        local found = ctx:resolve_set_from_keys({ second = { head = "b" }, first = { head = "a" } })
        assert_equal(found.head, "a")
        assert_nil(ctx:resolve_set_from_keys({ third = { head = "c" } }))
    end)
end)

describe("spell families", function()
    local function family_for(snugs, english, spell_type)
        local ctx = snugs:_new_context("midcast", {
            spell = stub.spell{ english = english, type = spell_type or "WhiteMagic" },
        })
        for _, key in ipairs(ctx.lookups) do
            if key:sub(1, 3) == "All" then return key end
        end
        return nil
    end

    it("strips a roman numeral tier", function(snugs)
        assert_equal(family_for(snugs, "Cure IV"), "AllCure")
        assert_equal(family_for(snugs, "Cure VI"), "AllCure")
        assert_equal(family_for(snugs, "Curaga V"), "AllCuraga")
        assert_equal(family_for(snugs, "Banish II"), "AllBanish")
        assert_equal(family_for(snugs, "Valor Minuet IV", "BardSong"), "AllValor Minuet")
    end)

    it("covers the untiered base spell too", function(snugs)
        assert_equal(family_for(snugs, "Cure"), "AllCure")
        assert_equal(family_for(snugs, "Curaga"), "AllCuraga")
        assert_equal(family_for(snugs, "Regen"), "AllRegen")
    end)

    it("strips a ninjutsu tier", function(snugs)
        assert_equal(family_for(snugs, "Katon: Ichi", "Ninjutsu"), "AllKaton")
        assert_equal(family_for(snugs, "Katon: San", "Ninjutsu"), "AllKaton")
        assert_equal(family_for(snugs, "Utsusemi: Ni", "Ninjutsu"), "AllUtsusemi")
    end)

    it("leaves names that merely look tiered alone", function(snugs)
        assert_equal(family_for(snugs, "Magic Fruit", "BlueMagic"), "AllMagic Fruit")
        assert_equal(family_for(snugs, "Sheep Song", "BlueMagic"), "AllSheep Song")
        assert_equal(family_for(snugs, "MP Drainkiss", "BlueMagic"), "AllMP Drainkiss")
        assert_equal(family_for(snugs, "Absorb-STR", "DarkMagic"), "AllAbsorb-STR")
        assert_equal(family_for(snugs, "1000 Needles", "BlueMagic"), "All1000 Needles")
    end)

    it("registers one set for a whole family", function(snugs)
        snugs:midcast("AllCure", { body = "cure" })

        for _, name in ipairs({ "Cure", "Cure III", "Cure VI" }) do
            stub.clear_equipped()
            snugs:do_midcast(stub.spell{ english = name })
            assert_slot("body", "cure")
        end
    end)
end)

describe("ninjutsu helpers", function()
    it("adds a category key for elemental ninjutsu", function(snugs)
        snugs:midcast("ElementalNinjutsu", { body = "nuke" })
        snugs:do_midcast(stub.spell{ english = "Katon: San", type = "Ninjutsu", skill = "Ninjutsu" })
        assert_slot("body", "nuke")
    end)

    it("adds a category key for utility and debuff ninjutsu", function(snugs)
        snugs:midcast("UtilityNinjutsu", { body = "utility" })
        snugs:midcast("DebuffNinjutsu", { body = "debuff" })

        snugs:do_midcast(stub.spell{ english = "Monomi: Ichi", type = "Ninjutsu", skill = "Ninjutsu" })
        assert_slot("body", "utility")

        stub.clear_equipped()
        snugs:do_midcast(stub.spell{ english = "Hojo: Ni", type = "Ninjutsu", skill = "Ninjutsu" })
        assert_slot("body", "debuff")
    end)

    it("leaves non-ninjutsu alone", function(snugs)
        snugs:midcast("ElementalNinjutsu", { body = "nuke" })
        snugs:do_midcast(stub.spell{ english = "Fire IV", type = "BlackMagic", skill = "Elemental Magic" })
        assert_slot("body", nil)
    end)
end)

describe("create_once_mode_transition", function()
    it("resets the mode once the condition holds", function(snugs)
        snugs:add_mode("burst", { initial_value = "off", cycle_values = { "off", "Single" } })
        snugs:register_middleware("aftercast",
            create_once_mode_transition("burst", "off", when():mode_is("burst", "Single")))

        sets.modes.burst.v = "Single"
        snugs:do_aftercast(stub.spell{})
        assert_equal(sets.modes.burst.v, "off")
    end)

    it("leaves the mode alone while the condition fails", function(snugs)
        snugs:add_mode("burst", { initial_value = "off", cycle_values = { "off", "Single" } })
        snugs:register_middleware("aftercast",
            create_once_mode_transition("burst", "off", when():mode_is("burst", "Single")))

        snugs:do_aftercast(stub.spell{})
        assert_equal(sets.modes.burst.v, "off")

        sets.modes.burst.v = "Double"
        snugs:do_aftercast(stub.spell{})
        assert_equal(sets.modes.burst.v, "Double")
    end)

    it("errors for a mode that does not exist", function(snugs)
        local fn = create_once_mode_transition("nope", "off", when())
        assert_nil(fn)
        assert_true(stub.said("No such mode to create once transition"))
    end)

    it("errors when the condition is not a predicate", function(snugs)
        snugs:add_mode("burst", { initial_value = "off", cycle_values = { "off" } })
        local fn = create_once_mode_transition("burst", "off", "not a predicate")
        assert_nil(fn)
        assert_true(stub.said("must be a Predicate"))
    end)

    it("still applies the burst set on the action that consumes it", function(snugs)
        snugs:add_mode("burst", { initial_value = "off", cycle_values = { "off", "Single" } })
        snugs:register_middleware("aftercast",
            create_once_mode_transition("burst", "off", when():mode_is("burst", "Single")))

        snugs:midcast("Elemental Magic", gearset({ body = "nuke" })
            :and_combine(gearset({ left_ring = "Mujin Band" }):when():mode_is("burst", "Single")))

        sets.modes.burst.v = "Single"

        snugs:do_midcast(stub.spell{ english = "Fire IV", type = "BlackMagic", skill = "Elemental Magic" })
        assert_slot("left_ring", "Mujin Band")

        snugs:do_aftercast(stub.spell{ english = "Fire IV", type = "BlackMagic", skill = "Elemental Magic" })
        assert_equal(sets.modes.burst.v, "off")

        stub.clear_equipped()
        snugs:do_midcast(stub.spell{ english = "Fire IV", type = "BlackMagic", skill = "Elemental Magic" })
        assert_slot("left_ring", nil)
    end)
end)
