-- Warrior
--
-- A straightforward melee job: pick a fighting set, tune your weapon skills,
-- and let SnugSwap put your weapons back after every action.

include('snugswap')

function get_sets()
    -- Flip between raw damage, accuracy and a defensive set with
    -- `gs c toggle style`.
    snugs:add_mode("style", {
        initial_value = "dd",
        description   = "Playstyle",
        cycle_values  = {"dd", "acc", "dt"},
    })

    local dd_set  = {}
    local acc_set = {}
    local dt_set  = {}

    -- Your weapons. Kept apart from armour so casting never strands you
    -- barehanded. Add proc weapons as extra named sets.
    snugs:default_weaponset({})
    -- snugs:weaponset("greataxe", {})
    -- snugs:weaponset("proc", {})

    snugs:default_idle(dt_set)

    snugs:default_engaged(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    }))

    -- Weapon skills. The default covers anything without its own set.
    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Ukko's Fury",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Upheaval",      set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Resolution",    set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Savage Blade",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("King's Justice", set_combine(base_ws_set, {}))

    -- Job abilities. Most need nothing, but a few want their own pieces.
    -- snugs:midcast("Berserk",   {})
    -- snugs:midcast("Warcry",    {})
    -- snugs:midcast("Aggressor", {})
    -- snugs:midcast("Mighty Strikes", {})

    -- Tomahawk throws a piece of ammo, so it needs that ammo equipped first.
    -- snugs:precast("Tomahawk", { ammo = "Thr. Tomahawk" })

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
