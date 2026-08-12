-- Dragoon
--
-- Polearm damage dealer with a wyvern. Jumps are job abilities rather than
-- weapon skills, so they use the midcast section, and a few pieces only help
-- while your wyvern is out.

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

    -- Gear that only helps while the wyvern is out.
    local wyvern_set = gearset({}):when():has_pet(true)

    snugs:default_idle(gearset(dt_set):and_combine(wyvern_set))

    snugs:default_engaged(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    }))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Stardiver",          set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Camlann's Torment",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Drakesbane",         set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Impulse Drive",      set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Geirskogul",         set_combine(base_ws_set, {}))

    -- Jumps are abilities, so they go through midcast. They benefit from
    -- attack and jump-specific pieces rather than weapon skill damage.
    -- snugs:midcast_all({"Jump", "High Jump", "Soul Jump", "Spirit Jump"}, {})

    -- Wyvern abilities.
    -- snugs:midcast("Spirit Link", {})
    -- snugs:midcast("Call Wyvern", {})

    -- Angon throws a piece of ammo, so that ammo must be equipped first.
    -- snugs:precast("Angon", { ammo = "Angon" })

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
