-- Puppetmaster
--
-- Pet job. Your automaton's build decides what gear helps it, so the styles
-- below are named after what the puppet is doing rather than what you are.

include('snugswap')

function get_sets()
    snugs:add_mode("style", {
        initial_value = "masterdd",
        description   = "Playstyle",
        cycle_values  = {"masterdd", "autoranged", "autobruiser", "autoturtle"},
    })

    snugs:default_weaponset(gearset_from_mode("style", {
        -- Every entry needs the animator in the ranged slot and oil in ammo,
        -- otherwise you cannot control the automaton.
        masterdd    = {},
        autoranged  = {},
        autobruiser = {},
        autoturtle  = {},
    }))

    local master_dt_set   = {}  -- you are the one being hit
    local pet_ranged_set  = {}  -- puppet is shooting
    local pet_bruiser_set = {}  -- puppet is meleeing
    local pet_turtle_set  = {}  -- puppet is tanking or healing

    snugs:default_idle(gearset_from_mode("style", {
        masterdd    = master_dt_set,
        autoranged  = pet_ranged_set,
        autobruiser = pet_bruiser_set,
        autoturtle  = pet_turtle_set,
    }))

    snugs:default_engaged(gearset_from_mode("style", {
        masterdd    = {},
        autoranged  = pet_ranged_set,
        autobruiser = pet_bruiser_set,
        autoturtle  = pet_turtle_set,
    }))

    -- Maneuvers are job abilities. Pet regen and maneuver-related pieces here.
    -- snugs:midcast_all({"Fire Maneuver", "Ice Maneuver", "Wind Maneuver",
    --                    "Earth Maneuver", "Thunder Maneuver", "Water Maneuver",
    --                    "Light Maneuver", "Dark Maneuver"}, {})

    -- Repairing the automaton wants automaton repair gear plus the right oil.
    -- snugs:premidcast("Repair", { ammo = "Automat. Oil +3" })

    -- Activate and Deus Ex Automata bring the puppet out.
    -- snugs:midcast_all({"Activate", "Deus Ex Automata"}, {})

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Shijin Spiral",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Victory Smite",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Stringing Pummel", set_combine(base_ws_set, {}))

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
