-- A deliberately broken job lua. Every problem here was found in a real file
-- during an audit; test/jobcheck_test.lua asserts the linter still reports each
-- one. A linter that reports nothing is indistinguishable from a broken linter.

require("snugswap")            -- GearSwap provides include(), not require()

function get_sets()
    snugs:add_mode("style", {
        initial_value = "dd",
        description   = "Playstyle",
        cycle_values  = {"dd", "tank"},
    })

    snugs:add_mode("burst", {
        initial_value = "off",
        cycle_values  = {"off", "on"},
    })

    -- Wrong phase: this clears the mode before any set for the action is read.
    snugs:register_middleware("any",
        create_once_mode_transition("burst", "off", when():mode_is("burst", "on")))

    snugs:default_weaponset({ main = "Naegling" })

    -- Undefined name: the branch silently drops out of the mapping.
    snugs:default_idle(gearset_from_mode("style", {
        dd   = never_defined_anywhere,
        tank = { head = "Tank Helm" },
    }))

    -- Missing `local`.
    leaked_engaged_set = gearset({ head = "Engaged Helm" })
    snugs:default_engaged(leaked_engaged_set)

    -- Duplicate slot: the first is discarded.
    snugs:default_weaponskill({
        left_ring = "Epaminondas's Ring",
        head      = "WS Helm",
        left_ring = "Sroda Ring",
    })

    -- Condition attaches to the whole set, not the overlay, so the base is lost
    -- whenever the condition is false.
    snugs:midcast("Healing Magic", gearset({
        body = "Cure Body",
    }):and_combine(gearset({
        head = "Curaga Head",
    })):when():key("AllCuraga"))

    -- Weapon skills resolve against the weaponskill tier, so this never fires.
    snugs:midcast("Savage Blade", { head = "Never Worn" })

    -- Corsair actions arrive as spell.type; action_type is just "Ability".
    snugs:default_midcast(gearset({})
        :and_combine(gearset({ head = "Roll Head" }):when():action_type("CorsairRoll")))

    -- Registered twice: the second is refused.
    snugs:util("speed", { feet = "First" })
    snugs:util("speed", { feet = "Second" })

    -- Built and never used.
    local unused_set = gearset({ head = "Orphan" })
end

snugs:wire_all()
