-- Black Mage
--
-- Nuking job. Two ideas dominate the file: an elemental obi that only helps
-- when the day or weather matches, and a magic burst mode that switches itself
-- back off after one spell so you never leave burst gear on by accident.

include('snugswap')

function get_sets()
    snugs:add_mode("lockweapons", {
        initial_value = "off",
        description   = "Lock weapons",
        cycle_values  = {"off", "on"},
    })

    -- Turn on just before you burst. It resets to "off" on its own.
    snugs:add_mode("burst", {
        initial_value = "off",
        description   = "Magic burst",
        cycle_values  = {"off", "on"},
    })

    snugs:register_middleware("any",
        create_once_mode_transition("burst", "off", when():mode_is("burst", "on")))

    snugs:default_weaponset({})

    local idle_refresh_set = gearset({}):when():mpp_less_than(80)
    snugs:default_idle(gearset({}):and_combine(idle_refresh_set))
    snugs:default_engaged({})

    snugs:default_fastcast({})

    -- One obi overlay per element. Only the matching one contributes, so
    -- stacking all of them is harmless.
    local obi = {}  -- e.g. { waist = "Hachirin-no-Obi" }

    local fire_obi      = gearset(obi):when():weather("Fire"):or_instead(when():day("Fire")):or_instead(when():buff("Firestorm"))
    local ice_obi       = gearset(obi):when():weather("Ice"):or_instead(when():day("Ice")):or_instead(when():buff("Hailstorm"))
    local wind_obi      = gearset(obi):when():weather("Wind"):or_instead(when():day("Wind")):or_instead(when():buff("Windstorm"))
    local earth_obi     = gearset(obi):when():weather("Earth"):or_instead(when():day("Earth")):or_instead(when():buff("Sandstorm"))
    local lightning_obi = gearset(obi):when():weather("Lightning"):or_instead(when():day("Lightning")):or_instead(when():buff("Thunderstorm"))
    local water_obi     = gearset(obi):when():weather("Water"):or_instead(when():day("Water")):or_instead(when():buff("Rainstorm"))

    -- Worn only while the burst mode is on.
    local burst_set = gearset({}):when():mode_is("burst", "on")

    snugs:midcast("Elemental Magic", gearset({})
        :and_combine(fire_obi)
        :and_combine(ice_obi)
        :and_combine(wind_obi)
        :and_combine(earth_obi)
        :and_combine(lightning_obi)
        :and_combine(water_obi)
        :and_combine(burst_set))

    snugs:midcast("Enfeebling Magic", {})
    snugs:midcast("Dark Magic", {})
    snugs:midcast("Enhancing Magic", {})
    snugs:midcast("AllCure", {})

    -- Drain and Aspir want different gear from the rest of dark magic.
    -- snugs:midcast_all({"Drain", "Aspir", "Aspir II", "Aspir III"}, {})

    -- snugs:midcast("Death", {})
    -- snugs:midcast("Stoneskin", {})

    snugs:default_weaponskill({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
