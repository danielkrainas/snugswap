-- Paladin
--
-- Tank. Two things matter beyond staying alive: holding hate (enmity gear on
-- everything that grabs attention) and casting through damage without being
-- interrupted (spell interruption rate down, but only while you are engaged).

include('snugswap')

function get_sets()
    -- One switch for weapons, idle and engaged together.
    snugs:add_mode("style", {
        initial_value = "hybrid",
        description   = "Playstyle",
        cycle_values  = {"tank", "hybrid", "dd", "magic"},
    })

    local tank_set   = {}  -- maximum survivability
    local hybrid_set = {}  -- some damage, still safe
    local dd_set     = {}  -- when something else is tanking
    local magic_set  = {}  -- magic defence, for casters

    snugs:default_weaponset(gearset_from_mode("style", {
        tank   = {},
        hybrid = {},
        dd     = {},
        magic  = {},
    }))

    snugs:default_idle(gearset_from_mode("style", {
        tank   = tank_set,
        hybrid = tank_set,
        dd     = tank_set,
        magic  = magic_set,
    }))

    snugs:default_engaged(gearset_from_mode("style", {
        tank   = tank_set,
        hybrid = hybrid_set,
        dd     = dd_set,
        magic  = magic_set,
    }))

    -- Enmity gear, for anything whose job is to grab attention.
    local enmity_set = gearset({})

    -- Spell interruption gear, worn only while you are being hit.
    local sird_set = gearset({}):when():status("Engaged")

    snugs:default_fastcast({})

    -- Everything that generates hate shares the enmity set.
    snugs:midcast_all({"Provoke", "Flash", "Sentinel", "Rampart", "Cover",
                       "Palisade", "Fealty", "Holy Circle", "Intervene",
                       "Defender", "Shield Bash"}, gearset(enmity_set))

    -- Cures on yourself, cast through incoming damage.
    snugs:midcast("AllCure", gearset({}):and_combine(enmity_set):and_combine(sird_set))

    snugs:midcast("Divine Magic",    gearset({}):and_combine(sird_set))
    snugs:midcast("Enhancing Magic", gearset({}):and_combine(sird_set))
    snugs:midcast("Phalanx",         gearset({}):and_combine(sird_set))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- Atonement scales with hate, so it wants enmity rather than damage gear.
    -- snugs:weaponskill("Atonement", gearset(enmity_set))
    -- snugs:weaponskill("Savage Blade",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Chant du Cygne", set_combine(base_ws_set, {}))

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
