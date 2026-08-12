-- Red Mage
--
-- Enhancing magic is the interesting part: buffs on yourself want duration
-- gear, the same buffs on other people want potency gear. `target_self` tells
-- the two apart so you do not need separate spell lists.

include('snugswap')

function get_sets()
    snugs:add_mode("lockweapons", {
        initial_value = "off",
        description   = "Lock weapons",
        cycle_values  = {"off", "on"},
    })

    snugs:add_mode("burst", {
        initial_value = "off",
        description   = "Magic burst",
        cycle_values  = {"off", "on"},
    })

    snugs:register_middleware("any",
        create_once_mode_transition("burst", "off", when():mode_is("burst", "on")))

    -- One default plus named sets you switch to by hand.
    snugs:default_weaponset({})
    -- snugs:weaponset("melee", {})
    -- snugs:weaponset("magic", {})

    local idle_refresh_set = gearset({}):when():mpp_less_than(80)
    snugs:default_idle(gearset({}):and_combine(idle_refresh_set))
    snugs:default_engaged({})

    snugs:default_fastcast({})

    -- Buffs on other people: potency matters, duration does not.
    local party_enhancing_set = gearset({}):when():target_self(false)

    -- Buffs on yourself: duration matters most.
    local self_enhancing_set = gearset({}):when():target_self(true)

    snugs:midcast("Enhancing Magic", gearset({})
        :and_combine(party_enhancing_set)
        :and_combine(self_enhancing_set))

    -- Refresh and Haste usually want their own duration pieces.
    -- snugs:midcast_all({"Refresh", "Refresh II", "Refresh III"}, {})
    -- snugs:midcast_all({"Haste", "Haste II"}, {})

    -- Enspells and Temper want maximum enhancing skill instead.
    -- snugs:midcast_all({"Enfire", "Enblizzard", "Enaero", "Enstone",
    --                    "Enthunder", "Enwater", "Temper", "Temper II"}, {})

    local enfeebling_set = gearset({})
    snugs:midcast("Enfeebling Magic", enfeebling_set)

    -- Some enfeebles scale off MND rather than INT.
    -- snugs:midcast_all({"Paralyze", "Paralyze II", "Slow", "Slow II",
    --                    "Addle", "Addle II"}, gearset(enfeebling_set):and_combine({}))

    snugs:midcast("Elemental Magic", gearset({})
        :and_combine(gearset({}):when():mode_is("burst", "on")))

    snugs:midcast("AllCure", {})
    snugs:midcast("Dark Magic", {})

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)
    -- snugs:weaponskill("Savage Blade",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Seraph Blade",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Chant du Cygne", set_combine(base_ws_set, {}))

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
