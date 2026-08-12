-- Samurai
--
-- Great katana damage dealer. Almost everything is about building TP quickly
-- and spending it well, so the fighting set and the weapon skill sets are
-- where nearly all the tuning happens.

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
    -- snugs:weaponset("polearm", {})
    -- snugs:weaponset("proc", {})

    snugs:default_idle(dt_set)

    snugs:default_engaged(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    }))

    -- Third Eye and Seigan are defensive; you may want a different set while
    -- Seigan is up. Uncomment and fill in if you use it.
    -- local seigan_set = gearset({}):when():buff("Seigan")
    -- snugs:default_engaged(gearset(dd_set):and_combine(seigan_set))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Tachi: Fudo",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Tachi: Shoha",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Tachi: Kasha",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Tachi: Rana",   set_combine(base_ws_set, {}))

    -- Job abilities. Meditate builds TP and benefits from its own pieces.
    -- snugs:midcast("Meditate", {})
    -- snugs:midcast("Hasso",    {})
    -- snugs:midcast("Seigan",   {})
    -- snugs:midcast("Third Eye", {})

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
