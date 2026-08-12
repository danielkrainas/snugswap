-- Monk
--
-- Hand-to-hand damage dealer. The one thing that makes Monk different from a
-- plain melee job is Impetus: a buff that makes one body piece worth wearing
-- only while it is up, both while fighting and during Victory Smite.

include('snugswap')

function get_sets()
    snugs:add_mode("style", {
        initial_value = "dd",
        description   = "Playstyle",
        cycle_values  = {"dd", "acc", "dt"},
    })

    local dd_set  = {}
    local acc_set = {}
    local dt_set  = {}

    snugs:default_weaponset({})

    -- Gear worn only while Impetus is up. Defined once and layered onto both
    -- the fighting set and Victory Smite below.
    local impetus_set = gearset({}):when():buff("Impetus")

    -- Extra regen gear while you are hurt but not fighting.
    local idle_regen_set = gearset({}):when():hpp_less_than(90)

    snugs:default_idle(gearset(dt_set):and_combine(idle_regen_set))

    snugs:default_engaged(gearset(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    })):and_combine(impetus_set))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- Victory Smite hits harder with the Impetus body on, so it gets the same
    -- conditional piece layered on top of its own set.
    -- snugs:weaponskill("Victory Smite",
    --     gearset(set_combine(base_ws_set, {})):and_combine(impetus_set))

    -- snugs:weaponskill("Shijin Spiral",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Dragon Kick",     set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Ascetic's Fury",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Howling Fist",    set_combine(base_ws_set, {}))

    -- Chakra is an ability rather than a weapon skill, so it uses midcast.
    -- snugs:midcast("Chakra", {})
    -- snugs:midcast("Boost", {})

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
