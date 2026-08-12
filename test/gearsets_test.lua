-- gearset(), and_combine, when/otherwise, gearset_from_mode, selectors.

local function eval(set, phase, spell)
    local ctx = snugs:_new_context(phase or "midcast", spell and { spell = spell } or {})
    return set:eval(ctx)
end

describe("gearset combination", function()
    it("merges overlays onto the base", function()
        local set = gearset({ head = "base", body = "base" }):and_combine({ body = "overlay" })
        local result = eval(set)
        assert_equal(result.head, "base")
        assert_equal(result.body, "overlay")
    end)

    it("applies overlays in order so the last one wins", function()
        local set = gearset({ head = "base" })
            :and_combine({ head = "first" })
            :and_combine({ head = "second" })
        assert_equal(eval(set).head, "second")
    end)

    it("accepts another gearset as an overlay", function()
        local set = gearset({ head = "base" }):and_combine(gearset({ body = "nested" }))
        assert_equal(eval(set).body, "nested")
    end)

    it("accepts a dotted path string as an overlay", function(snugs)
        snugs:util("speed", { feet = "Herald's Gaiters" })
        local set = gearset({ head = "base" }):and_combine(gearset("util.speed"))
        assert_equal(eval(set).feet, "Herald's Gaiters")
    end)

    it("evaluates to an empty set for an unknown path", function()
        assert_equal(next(eval(gearset("util.nope"))), nil)
    end)

    it("mutates the receiver, so a shared base accumulates overlays", function()
        local base = gearset({ head = "base" })
        local a = base:and_combine({ body = "a" })
        local b = base:and_combine({ body = "b" })
        assert_equal(a, b, "and_combine should return the same object it was called on")
        assert_equal(eval(a).body, "b", "both overlays landed on the shared base")
    end)

    it("isolates branches when the base is re-wrapped", function()
        local base = gearset({ head = "base" })
        local a = gearset(base):and_combine({ body = "a" })
        local b = gearset(base):and_combine({ body = "b" })
        assert_equal(eval(a).body, "a")
        assert_equal(eval(b).body, "b")
    end)

    it("ignores a nil overlay", function()
        local set = gearset({ head = "base" }):and_combine(nil)
        assert_equal(eval(set).head, "base")
    end)
end)

describe("conditional gearsets", function()
    it("contributes nothing when the condition fails", function()
        local set = gearset({ head = "buffed" }):when():buff("Impetus")
        assert_equal(next(eval(set)), nil)
    end)

    it("contributes when the condition passes", function()
        buffactive["Impetus"] = true
        local set = gearset({ head = "buffed" }):when():buff("Impetus")
        assert_equal(eval(set).head, "buffed")
    end)

    it("falls back to the otherwise set", function()
        local set = gearset({ head = "with-pet" }):when():has_pet(true):otherwise({ head = "no-pet" })
        assert_equal(eval(set).head, "no-pet")

        pet.isvalid = true
        assert_equal(eval(set).head, "with-pet")
    end)

    it("combines conditions with or_instead", function()
        local set = gearset({ waist = "obi" })
            :when():weather("Fire")
            :or_instead(when():day("Fire"))

        world.weather_element = "Ice"
        world.day_element = "Water"
        assert_equal(next(eval(set)), nil, "neither branch should match")

        world.day_element = "Fire"
        assert_equal(eval(set).waist, "obi", "the day branch should match")
    end)

    it("requires every condition by default", function()
        local set = gearset({ head = "x" }):when():buff("A"):buff("B")
        buffactive["A"] = true
        assert_equal(next(eval(set)), nil, "only one of two conditions held")

        buffactive["B"] = true
        assert_equal(eval(set).head, "x")
    end)

    it("layers a conditional overlay onto an unconditional base", function()
        local set = gearset({ head = "base" })
            :and_combine(gearset({ body = "low-mp" }):when():mpp_less_than(80))

        assert_equal(eval(set).body, nil)

        player.mpp = 50
        assert_equal(eval(set).body, "low-mp")
        assert_equal(eval(set).head, "base")
    end)
end)

describe("gearset_from_mode", function()
    it("selects the branch matching the current mode value", function(snugs)
        snugs:add_mode("style", { initial_value = "dd", cycle_values = { "dd", "tank" } })
        local set = gearset_from_mode("style", {
            dd = { main = "Naegling" },
            tank = { main = "Nixxer" },
        })

        assert_equal(eval(set).main, "Naegling")

        sets.modes.style.v = "tank"
        assert_equal(eval(set).main, "Nixxer")
    end)

    it("evaluates a branch that is itself a gearset", function(snugs)
        snugs:add_mode("style", { initial_value = "dd", cycle_values = { "dd" } })
        local set = gearset_from_mode("style", {
            dd = gearset({ main = "Naegling" }):and_combine({ sub = "Thibron" }),
        })
        assert_equal(eval(set).sub, "Thibron")
    end)

    it("nests one mode inside another", function(snugs)
        snugs:add_mode("style", { initial_value = "melee", cycle_values = { "melee" } })
        snugs:add_mode("buffed", { initial_value = "off", cycle_values = { "off", "on" } })

        local set = gearset_from_mode("style", {
            melee = gearset_from_mode("buffed", {
                on = { sub = "Ternion Dagger +1" },
                off = { sub = "Gleti's Knife" },
            }),
        })

        assert_equal(eval(set).sub, "Gleti's Knife")

        sets.modes.buffed.v = "on"
        assert_equal(eval(set).sub, "Ternion Dagger +1")
    end)

    it("uses the mode's own gearset_mappings when none are supplied", function(snugs)
        snugs:add_mode("jug", {
            initial_value = "sheep",
            gearset_mappings = {
                sheep = { ammo = "Lyrical Broth" },
                tiger = { ammo = "Meaty Broth" },
            },
        })

        local set = gearset_from_mode("jug")
        assert_equal(eval(set).ammo, "Lyrical Broth")

        sets.modes.jug.v = "tiger"
        assert_equal(eval(set).ammo, "Meaty Broth")
    end)

    it("evaluates to empty for an unknown mode", function()
        assert_equal(next(eval(gearset_from_mode("nope", { a = { head = "x" } }))), nil)
    end)

    it("evaluates to empty when the current value has no mapping", function(snugs)
        snugs:add_mode("style", { initial_value = "dd", cycle_values = { "dd", "tank" } })
        local set = gearset_from_mode("style", { tank = { main = "Nixxer" } })
        assert_equal(next(eval(set)), nil)
    end)
end)

describe("selectors", function()
    it("picks the first selector whose condition passes", function()
        local set = choose_from(
            use({ head = "burst" }, when():buff("Immanence")),
            use({ head = "plain" }))

        assert_equal(eval(set).head, "plain")

        buffactive["Immanence"] = true
        assert_equal(eval(set).head, "burst")
    end)

    it("honours priority over declaration order", function()
        buffactive["A"] = true
        buffactive["B"] = true

        local set = choose_from(
            use({ head = "low" }, when():buff("A")):priority(1),
            use({ head = "high" }, when():buff("B")):priority(10))

        assert_equal(eval(set).head, "high")
    end)

    it("skips a selector that evaluates to an empty set", function()
        local set = choose_from(
            use({}, when():buff("Immanence")),
            use({ head = "fallback" }))

        buffactive["Immanence"] = true
        assert_equal(eval(set).head, "fallback")
    end)

    it("merges every matching selector with choose_all", function()
        buffactive["A"] = true
        buffactive["B"] = true

        local set = choose_all(
            use({ head = "one" }, when():buff("A")),
            use({ body = "two" }, when():buff("B")),
            use({ legs = "three" }, when():buff("C")))

        local result = eval(set)
        assert_equal(result.head, "one")
        assert_equal(result.body, "two")
        assert_equal(result.legs, nil)
    end)

    it("evaluates a gearset held by a selector", function()
        local set = choose_from(use(gearset({ head = "base" }):and_combine({ body = "extra" })))
        assert_equal(eval(set).body, "extra")
    end)
end)

describe("set identification", function()
    it("recognises a gearset", function()
        assert_true(is_gearset(gearset({})))
        assert_true(is_gearset(choose_from(use({ head = "x" }))))
        assert_false(is_gearset({ head = "x" }))
        assert_false(is_gearset("util.speed"))
    end)

    it("recognises a predicate", function()
        assert_true(is_predicate(when()))
        assert_true(is_predicate(where(function() return true end)))
        assert_false(is_predicate(gearset({})))
    end)
end)

describe("get_set_from_path", function()
    it("returns a table unchanged", function()
        local t = { head = "x" }
        assert_equal(get_set_from_path(t), t)
    end)

    it("walks a dotted path into sets", function(snugs)
        snugs:weaponset("th", { main = "Twashtar" })
        assert_equal(get_set_from_path("weapons.th").main, "Twashtar")
    end)

    it("returns an empty table for a missing path or a non-path value", function()
        assert_equal(next(get_set_from_path("weapons.missing")), nil)
        assert_equal(next(get_set_from_path(42)), nil)
        assert_equal(next(get_set_from_path(nil)), nil)
    end)
end)
