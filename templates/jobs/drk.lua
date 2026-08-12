-- Dark Knight
--
-- Heavy damage dealer that also casts. Absorb spells and Drain/Aspir want dark
-- magic gear rather than melee gear, so they get their own midcast sets.

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

    -- Great sword and scythe usually want different weapon skills, so keep
    -- them as separate named sets and switch with `gs c set weapon scythe`.
    snugs:default_weaponset({})
    -- snugs:weaponset("scythe", {})
    -- snugs:weaponset("greatsword", {})

    snugs:default_idle(dt_set)

    snugs:default_engaged(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    }))

    snugs:default_fastcast({})

    -- Dark magic. Absorb spells and Drain/Aspir want magic accuracy and
    -- potency, not melee stats.
    local dark_magic_set = gearset({})
    snugs:midcast("Dark Magic", dark_magic_set)

    -- snugs:midcast_all({"Drain", "Drain II", "Drain III",
    --                    "Aspir", "Aspir II", "Aspir III"},
    --     gearset(dark_magic_set):and_combine({}))

    -- snugs:midcast_all({"Absorb-STR", "Absorb-DEX", "Absorb-VIT", "Absorb-AGI",
    --                    "Absorb-INT", "Absorb-MND", "Absorb-CHR", "Absorb-ACC",
    --                    "Absorb-TP", "Absorb-Attri"},
    --     gearset(dark_magic_set):and_combine({}))

    -- Stun wants fast cast and magic accuracy above all else.
    -- snugs:midcast("Stun", gearset(dark_magic_set):and_combine({}))

    -- Enmity gear, if you are the one holding hate.
    -- snugs:midcast_all({"Provoke", "Souleater", "Last Resort"}, {})

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Torcleaver",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Resolution",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Entropy",      set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Insurgency",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Cross Reaper", set_combine(base_ws_set, {}))

    -- Catastrophe and Quietus are magic damage, so they want magic attack.
    -- snugs:weaponskill("Catastrophe", set_combine(base_ws_set, {}))

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
