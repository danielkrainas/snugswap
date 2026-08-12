-- Thief
--
-- Melee damage dealer with one extra concern: Treasure Hunter. TH lives on a
-- separate weapon set you swap to deliberately rather than something that
-- swaps itself, so you can tag a mob and then go back to your damage weapons.

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

    -- `gs c set weapon th` to tag, `gs c set weapon $default` to go back.
    -- `gs c cycle weapon` rotates through all of them in this order.
    snugs:default_weaponset({})
    snugs:weaponset("th", {})
    -- snugs:weaponset("sb", {})
    -- snugs:weaponset("procdagger", {})
    -- snugs:weaponset("procclub", {})
    -- snugs:weaponset("procsword", {})

    snugs:default_idle(dt_set)

    snugs:default_engaged(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    }))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Rudra's Storm",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Evisceration",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Savage Blade",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Mandalic Stab",  set_combine(base_ws_set, {}))

    -- Aeolian Edge is magic damage, so it wants magic attack rather than the
    -- usual strength and accuracy pieces.
    -- snugs:weaponskill("Aeolian Edge", set_combine(base_ws_set, {}))

    -- Job abilities. Sneak Attack and Trick Attack take no gear, but a few
    -- others benefit from their own pieces.
    -- snugs:midcast("Steal",        {})
    -- snugs:midcast("Despoil",      {})
    -- snugs:midcast("Feint",        {})
    -- snugs:midcast("Conspirator",  {})

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
