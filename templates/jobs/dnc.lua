-- Dancer
--
-- Melee that heals and debuffs with TP instead of MP. Waltzes are treated as
-- cures for gear purposes, and Steps care about accuracy rather than damage.

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

    snugs:default_idle(dt_set)

    snugs:default_engaged(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    }))

    -- Waltzes heal, so they want cure potency and waltz-specific pieces.
    -- They also cost less TP with the right gear, which is worth more than
    -- the healing itself on a long fight.
    snugs:midcast_all({"Curing Waltz", "Curing Waltz II", "Curing Waltz III",
                       "Curing Waltz IV", "Curing Waltz V", "Divine Waltz",
                       "Divine Waltz II"}, {})

    -- Healing Waltz removes a status effect and does not scale with potency.
    -- snugs:midcast("Healing Waltz", {})

    -- Steps need to land, so accuracy is what matters.
    snugs:midcast_all({"Quickstep", "Box Step", "Stutter Step", "Feather Step"}, {})

    -- Flourishes. Violent Flourish needs magic accuracy to land.
    -- snugs:midcast_all({"Violent Flourish"}, {})
    -- snugs:midcast_all({"Animated Flourish"}, {})

    -- Sambas and Jigs generally take no gear beyond duration pieces.
    -- snugs:midcast_all({"Haste Samba", "Drain Samba III"}, {})

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Rudra's Storm",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Pyrrhic Kleos",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Evisceration",   set_combine(base_ws_set, {}))

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
