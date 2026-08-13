-- Scholar
--
-- Caster whose gear depends heavily on which job abilities are up. Immanence
-- changes what a nuke is for, and Sublimation is worth wearing gear for while
-- it charges, so both are handled as buff conditions rather than modes.

include('snugswap')

function get_sets()
    -- Magic burst gear, used for one spell then switched back off on its own.
    snugs:add_mode("burst", {
        initial_value = "off",
        description   = "Magic burst",
        cycle_values  = {"off", "on"},
    })

    snugs:register_middleware("aftercast",
        create_once_mode_transition("burst", "off", when():mode_is("burst", "on")))

    snugs:default_weaponset({})

    -- Sublimation stores MP while it charges; this gear makes it store more.
    local sublimation_set = gearset({}):when():buff("Sublimation: Activated")

    local idle_refresh_set = gearset({}):when():mpp_less_than(80)

    snugs:default_idle(gearset({})
        :and_combine(idle_refresh_set)
        :and_combine(sublimation_set))

    snugs:default_engaged({})

    snugs:default_fastcast({})

    -- Immanence turns a nuke into a skillchain opener, where magic accuracy
    -- matters more than raw damage.
    local immanence_set = gearset({}):when():buff("Immanence")

    local burst_set = gearset({}):when():mode_is("burst", "on")

    snugs:midcast("Elemental Magic", gearset({})
        :and_combine(immanence_set)
        :and_combine(burst_set))

    -- Helix spells are elemental magic but scale with duration as well.
    -- snugs:midcast_all({"Geohelix", "Hydrohelix", "Anemohelix", "Pyrohelix",
    --                    "Cryohelix", "Ionohelix", "Noctohelix", "Luminohelix"}, {})

    snugs:midcast("Enhancing Magic", {})

    -- Regen tiers all share one key.
    snugs:midcast("AllRegen", {})

    snugs:midcast("AllCure", {})
    snugs:midcast("AllCuraga", {})
    snugs:midcast("Enfeebling Magic", {})
    snugs:midcast("Dark Magic", {})

    snugs:midcast("Cursna", {})
    snugs:midcast("Stoneskin", {})

    -- Storm spells last longer with duration gear.
    -- snugs:midcast_all({"Firestorm", "Hailstorm", "Windstorm", "Sandstorm",
    --                    "Thunderstorm", "Rainstorm", "Aurorastorm", "Voidstorm"}, {})

    snugs:default_weaponskill({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
