-- Geomancer
--
-- Caster with a luopan pet. Geomancy spells come in two shapes: Indi- spells
-- go on you, Geo- spells create the luopan. Both use the "Geomancy" skill, so
-- one set covers them, and the pet only exists for the Geo- kind.

include('snugswap')

function get_sets()
    -- Stops casting sets from swapping your weapons, which matters more here
    -- than most jobs: your bell in the ranged slot drives geomancy potency.
    snugs:add_mode("lockweapons", {
        initial_value = "off",
        description   = "Lock weapons",
        cycle_values  = {"off", "on"},
    })

    snugs:add_mode("style", {
        initial_value = "support",
        description   = "Playstyle",
        cycle_values  = {"support", "dd", "hybrid"},
    })

    snugs:add_mode("burst", {
        initial_value = "off",
        description   = "Magic burst",
        cycle_values  = {"off", "on"},
    })

    snugs:register_middleware("any",
        create_once_mode_transition("burst", "off", when():mode_is("burst", "on")))

    snugs:default_weaponset(gearset_from_mode("style", {
        support = {},
        dd      = {},
        hybrid  = {},
    }))

    local idle_set    = {}
    local engaged_set = {}

    -- Pet regen and pet damage taken gear, only while the luopan is out.
    local luopan_set = gearset({}):when():has_pet(true)

    local idle_refresh_set = gearset({}):when():mpp_less_than(80)

    snugs:default_idle(gearset(idle_set)
        :and_combine(idle_refresh_set)
        :and_combine(luopan_set))

    snugs:default_engaged(gearset_from_mode("style", {
        support = idle_set,
        dd      = engaged_set,
        hybrid  = gearset(idle_set):and_combine(engaged_set),
    }))

    snugs:default_fastcast({})

    -- Geomancy skill and handbell pieces. Covers both Indi- and Geo- spells.
    local geomancy_set = gearset({})

    -- Entrust puts an Indi- spell on someone else and wants its own weapon.
    -- snugs:midcast("Geomancy", gearset(geomancy_set)
    --     :and_combine(gearset({}):when():buff("Entrust")))

    snugs:midcast("Geomancy", geomancy_set)

    local burst_set = gearset({}):when():mode_is("burst", "on")

    snugs:midcast("Elemental Magic", gearset({}):and_combine(burst_set))

    snugs:midcast("Enfeebling Magic", {})
    snugs:midcast("Enhancing Magic", {})
    snugs:midcast("Dark Magic", {})
    snugs:midcast("AllCure", {})

    -- snugs:midcast_all({"Drain", "Aspir", "Aspir II", "Aspir III"}, {})

    snugs:default_weaponskill({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
