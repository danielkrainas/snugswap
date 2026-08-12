-- Built-in predicates, custom predicates, and the comparison helper.

local function holds(predicate, spell, phase)
    local ctx = snugs:_new_context(phase or "midcast", spell and { spell = spell } or {})
    return predicate:eval(ctx) and true or false
end

describe("spell predicates", function()
    it("matches a spell name", function()
        assert_true(holds(when():spell_name("Cure"), stub.spell{ english = "Cure" }))
        assert_false(holds(when():spell_name("Cure"), stub.spell{ english = "Curaga" }))
    end)

    it("matches any of several spell names", function()
        local p = when():spell_name_any({ "Trueflight", "Last Stand" })
        assert_true(holds(p, stub.spell{ english = "Last Stand" }))
        assert_false(holds(p, stub.spell{ english = "Coronach" }))
    end)

    it("matches a spell type", function()
        assert_true(holds(when():spell_type("BardSong"), stub.spell{ type = "BardSong" }))
        assert_false(holds(when():spell_type("BardSong"), stub.spell{ type = "WhiteMagic" }))
    end)

    it("matches any of several spell types", function()
        local p = when():spell_type_any({ "BloodPactRage", "BloodPactWard" })
        assert_true(holds(p, stub.spell{ type = "BloodPactWard" }))
        assert_false(holds(p, stub.spell{ type = "WhiteMagic" }))
    end)

    it("matches an action type", function()
        local p = when():action_type("Ranged Attack")
        assert_true(holds(p, stub.spell{ action_type = "Ranged Attack" }))
        assert_false(holds(p, stub.spell{ action_type = "Magic" }))
    end)

    it("is false when there is no spell in context", function()
        assert_false(holds(when():spell_name("Cure"), nil))
        assert_false(holds(when():spell_type_any({ "WhiteMagic" }), nil))
    end)

    it("matches the current phase", function()
        assert_true(holds(when():phase("precast"), stub.spell{}, "precast"))
        assert_false(holds(when():phase("precast"), stub.spell{}, "midcast"))
    end)
end)

describe("player predicates", function()
    it("matches status", function()
        assert_true(holds(when():status("Idle")))
        player.status = "Engaged"
        assert_true(holds(when():status("Engaged")))
        assert_false(holds(when():status("Idle")))
    end)

    it("matches subjob", function()
        assert_true(holds(when():subjob("RDM")))
        assert_false(holds(when():subjob("WAR")))
    end)

    it("matches an active buff", function()
        assert_false(holds(when():buff("Impetus")))
        buffactive["Impetus"] = true
        assert_true(holds(when():buff("Impetus")))
    end)

    it("matches a pet being out", function()
        assert_false(holds(when():has_pet(true)))
        assert_true(holds(when():has_pet(false)))

        pet.isvalid = true
        assert_true(holds(when():has_pet(true)))
    end)

    it("defaults has_pet to true", function()
        assert_false(holds(when():has_pet()))
        pet.isvalid = true
        assert_true(holds(when():has_pet()))
    end)
end)

describe("threshold predicates", function()
    it("compares hp, mp and tp with the named forms", function()
        player.hpp = 50
        player.mpp = 50
        player.tp = 1000

        assert_true(holds(when():hpp_less_than(60)))
        assert_false(holds(when():hpp_less_than(50)))
        assert_true(holds(when():hpp_less_than_or_equal_to(50)))
        assert_true(holds(when():hpp_greater_than(40)))
        assert_true(holds(when():hpp_greater_than_or_equal_to(50)))
        assert_true(holds(when():hpp_equal_to(50)))

        assert_true(holds(when():mpp_less_than(80)))
        assert_true(holds(when():mpp_equal_to(50)))
        assert_true(holds(when():mpp_greater_than_or_equal_to(50)))

        assert_true(holds(when():tp_greater_than_or_equal_to(1000)))
        assert_true(holds(when():tp_less_than(2000)))
        assert_true(holds(when():tp_equal_to(1000)))
    end)

    it("compares with the operator forms", function()
        player.hpp = 90
        player.mpp = 40
        player.tp = 500

        assert_true(holds(when():hpp("<", 95)))
        assert_false(holds(when():hpp(">", 95)))
        assert_true(holds(when():mpp("<=", 40)))
        assert_true(holds(when():tp(">=", 500)))
    end)
end)

describe("compare_with_op", function()
    it("handles the ordering operators", function()
        assert_true(compare_with_op(1, "<", 2))
        assert_false(compare_with_op(2, "<", 1))
        assert_true(compare_with_op(2, ">", 1))
        assert_true(compare_with_op(2, ">=", 2))
        assert_true(compare_with_op(2, "<=", 2))
    end)

    it("handles equality for non-numbers", function()
        assert_true(compare_with_op("a", "==", "a"))
        assert_false(compare_with_op("a", "==", "b"))
        assert_true(compare_with_op("a", "~=", "b"))
        assert_true(compare_with_op(true, "==", true))
    end)

    it("refuses to compare mismatched types for equality", function()
        assert_false(compare_with_op("1", "==", 1))
        assert_true(stub.said("same type"))
    end)

    it("refuses to order non-numbers", function()
        assert_false(compare_with_op("a", "<", "b"))
        assert_true(stub.said("must be numbers"))
    end)

    it("rejects an unknown operator", function()
        assert_false(compare_with_op(1, "<>", 2))
        assert_true(stub.said("Invalid operator"))
    end)
end)

describe("world predicates", function()
    it("matches weather and day", function()
        world.weather_element = "Fire"
        world.day_element = "Ice"

        assert_true(holds(when():weather("Fire")))
        assert_false(holds(when():weather("Ice")))
        assert_true(holds(when():day("Ice")))
        assert_false(holds(when():day("Fire")))
    end)
end)

describe("mode predicates", function()
    it("matches a mode value with mode_is", function(snugs)
        snugs:add_mode("style", { initial_value = "dd", cycle_values = { "dd", "tank" } })
        assert_true(holds(when():mode_is("style", "dd")))
        assert_false(holds(when():mode_is("style", "tank")))
    end)

    it("is false for a mode that does not exist", function()
        assert_false(holds(when():mode_is("nope", "dd")))
        assert_false(holds(when():mode("nope")))
    end)

    it("reads a mode's truthiness with no operator", function(snugs)
        snugs:add_mode("flag", {})
        assert_true(holds(when():mode("flag")))

        sets.modes.flag.v = false
        assert_false(holds(when():mode("flag")))
    end)

    it("compares a mode value with an operator", function(snugs)
        snugs:add_mode("level", { initial_value = 3, cycle_values = { 1, 2, 3 } })
        assert_true(holds(when():mode("level", ">=", 3)))
        assert_false(holds(when():mode("level", ">", 3)))
    end)
end)

describe("lookup key predicates", function()
    it("matches a key present on the context", function()
        assert_true(holds(when():key("AllCure"), stub.spell{ english = "Cure IV" }))
        assert_true(holds(when():key("Healing Magic"), stub.spell{ english = "Cure IV" }))
        assert_false(holds(when():key("AllCuraga"), stub.spell{ english = "Cure IV" }))
    end)

    it("matches any key from a list", function()
        local p = when():any_key({ "Poisona", "Paralyna", "Blindna" })
        assert_true(holds(p, stub.spell{ english = "Paralyna" }))
        assert_false(holds(p, stub.spell{ english = "Cure" }))
    end)

    it("fails closed when given a non-table", function()
        assert_false(holds(when():any_key("Poisona"), stub.spell{ english = "Poisona" }))
        assert_true(stub.said("any_key requires a table"))
    end)
end)

describe("target_self", function()
    it("matches a spell cast on yourself", function()
        local spell = stub.spell{ target = { id = player.id } }
        assert_true(holds(when():target_self(true), spell))
        assert_false(holds(when():target_self(false), spell))
    end)

    it("does not match a spell cast on someone else", function()
        local spell = stub.spell{ target = { id = player.id + 1 } }
        assert_false(holds(when():target_self(true), spell))
        assert_true(holds(when():target_self(false), spell))
    end)

    it("treats a spell with no target as not self", function()
        assert_false(holds(when():target_self(true), stub.spell{}))
        assert_true(holds(when():target_self(false), stub.spell{}))
    end)
end)

describe("predicate composition", function()
    it("requires all tests by default", function()
        buffactive["A"] = true
        assert_false(holds(when():buff("A"):buff("B")))
        buffactive["B"] = true
        assert_true(holds(when():buff("A"):buff("B")))
    end)

    it("requires only one test after any()", function()
        buffactive["A"] = true
        assert_true(holds(when():any():buff("A"):buff("B")))
    end)

    it("ands another predicate with and_also", function()
        buffactive["A"] = true
        assert_false(holds(when():buff("A"):and_also(when():buff("B"))))
        buffactive["B"] = true
        assert_true(holds(when():buff("A"):and_also(when():buff("B"))))
    end)

    it("ors another predicate with or_instead", function()
        buffactive["B"] = true
        assert_true(holds(when():buff("A"):or_instead(when():buff("B"))))
    end)

    it("ignores a non-predicate passed to and_also or or_instead", function()
        buffactive["A"] = true
        assert_true(holds(when():buff("A"):and_also("nope")))
        assert_true(holds(when():buff("A"):or_instead(nil)))
    end)

    it("takes a raw function with where", function()
        local p = where(function(ctx) return ctx.spell and ctx.spell.element == "Dark" end)
        assert_true(holds(p, stub.spell{ element = "Dark" }))
        assert_false(holds(p, stub.spell{ element = "Fire" }))
    end)

    it("ignores a non-function passed to where", function()
        assert_true(holds(when():where("nope")))
    end)

    it("is true when it has no tests at all", function()
        assert_true(holds(when()))
    end)
end)

describe("misconfigured predicates", function()
    -- A factory that rejects its arguments builds no test. Such a predicate must
    -- never pass, or the gear behind it would apply on every single action.
    it("fails closed for every built-in that validates its arguments", function()
        local cases = {
            { "any_key", function() return when():any_key("not a table") end },
            { "spell_name", function() return when():spell_name(nil) end },
            { "spell_name_any", function() return when():spell_name_any("not a table") end },
            { "spell_type", function() return when():spell_type(nil) end },
            { "spell_type_any", function() return when():spell_type_any(nil) end },
            { "action_type", function() return when():action_type(nil) end },
            { "buff", function() return when():buff(nil) end },
            { "status", function() return when():status(nil) end },
            { "subjob", function() return when():subjob(nil) end },
            { "phase", function() return when():phase(nil) end },
            { "weather", function() return when():weather(nil) end },
            { "day", function() return when():day(nil) end },
            { "mode", function() return when():mode(nil) end },
            { "mode_is", function() return when():mode_is(nil, "x") end },
            { "hpp_less_than", function() return when():hpp_less_than(nil) end },
            { "mpp_greater_than", function() return when():mpp_greater_than(nil) end },
            { "tp_equal_to", function() return when():tp_equal_to(nil) end },
            { "hpp", function() return when():hpp("<") end },
            { "mpp", function() return when():mpp(nil, 50) end },
            { "tp", function() return when():tp("<") end },
        }

        for _, case in ipairs(cases) do
            local name, build = case[1], case[2]
            assert_false(holds(build(), stub.spell{}), name .. " should fail closed")
        end
    end)

    it("fails closed even when another clause would have passed", function()
        buffactive["Impetus"] = true
        assert_false(holds(when():buff("Impetus"):spell_name(nil)))
    end)

    it("fails closed under any() logic too", function()
        buffactive["Impetus"] = true
        assert_false(holds(when():any():buff("Impetus"):spell_name(nil)))
    end)

    it("does not apply the gear behind a misconfigured condition", function(snugs)
        snugs:midcast("Healing Magic", gearset({ body = "base" })
            :and_combine(gearset({ head = "conditional" }):when():buff(nil)))

        snugs:do_midcast(stub.spell{ english = "Cure" })
        assert_slots{ body = "base", head = EMPTY }
    end)

    it("falls back to the otherwise set", function()
        local set = gearset({ head = "yes" }):when():buff(nil):otherwise({ head = "no" })
        local ctx = snugs:_new_context("midcast", { spell = stub.spell{} })
        assert_equal(set:eval(ctx).head, "no")
    end)

    it("leaves a correctly built predicate unaffected", function()
        buffactive["Impetus"] = true
        assert_true(holds(when():buff("Impetus")))
    end)
end)

describe("custom predicates", function()
    it("registers a predicate usable from when()", function(snugs)
        snugs:extend_predicate("element_is", function(element)
            return function(ctx) return ctx.spell and ctx.spell.element == element end
        end)

        assert_true(holds(when():element_is("Light"), stub.spell{ element = "Light" }))
        assert_false(holds(when():element_is("Dark"), stub.spell{ element = "Light" }))
    end)

    it("makes the predicate usable directly on a gearset", function(snugs)
        snugs:extend_predicate("element_is", function(element)
            return function(ctx) return ctx.spell and ctx.spell.element == element end
        end)

        snugs:midcast("Elemental Magic", gearset({ body = "base" })
            :and_combine(gearset({ right_ring = "Archon Ring" }):when():element_is("Dark")))

        snugs:do_midcast(stub.spell{ english = "Comet", type = "BlackMagic",
                                     skill = "Elemental Magic", element = "Dark" })
        assert_slot("right_ring", "Archon Ring")

        stub.clear_equipped()
        snugs:do_midcast(stub.spell{ english = "Fire V", type = "BlackMagic",
                                     skill = "Elemental Magic", element = "Fire" })
        assert_slot("right_ring", nil)
    end)

    it("accepts a factory that returns another predicate", function(snugs)
        snugs:extend_predicate("engaged_with", function(buff)
            return when():status("Engaged"):buff(buff)
        end)

        player.status = "Engaged"
        buffactive["Impetus"] = true
        assert_true(holds(when():engaged_with("Impetus")))

        buffactive["Impetus"] = nil
        assert_false(holds(when():engaged_with("Impetus")))
    end)

    it("refuses to shadow a built-in Predicate method", function(snugs)
        snugs:extend_predicate("eval", function() return function() return true end end)
        assert_true(stub.said("reserved predicate method name"))
    end)

    it("wraps an existing predicate when asked", function(snugs)
        snugs:extend_predicate("always", function() return function() return true end end)
        snugs:extend_predicate("always", function(old)
            return function()
                local inner = old()
                return function(ctx) return not inner(ctx) end
            end
        end, { wrap = true })

        assert_false(holds(when():always()))
    end)
end)
