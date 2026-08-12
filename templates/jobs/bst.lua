-- Beastmaster
--
-- Pet job. Two things are unusual here. First, which jug pet you call is
-- decided by which broth is in your ammo slot, so the pet choice is a mode
-- that maps straight onto a piece of gear. Second, your pet's Ready moves
-- happen while you are standing still, so their gear layers onto idle.

include('snugswap')

function get_sets()
    -- Pick your pet with `gs c set jug tiger`, then use Call Beast. The mode
    -- swaps the broth in your ammo slot for you.
    snugs:add_mode("jug", {
        initial_value = "sheep",
        description   = "Current jug pet",
        gearset_mappings = {
            sheep    = {},  -- e.g. { ammo = "Lyrical Broth" }
            crab     = {},
            diremite = {},
            tiger    = {},
            chapuli  = {},
            leech    = {},
        },
    })

    snugs:add_mode("style", {
        initial_value = "dd",
        description   = "Playstyle",
        cycle_values  = {"dd", "petdmg", "petdt"},
    })

    local dd_set     = {}  -- you are doing the damage
    local pet_dd_set = {}  -- your pet is doing the damage
    local pet_dt_set = {}  -- keeping your pet alive
    local dt_set     = {}

    snugs:default_weaponset(gearset_from_mode("style", {
        dd     = {},
        petdmg = {},
        petdt  = {},
    }))

    -- Ready moves fire while you are idle, so their gear layers on here.
    -- "Monster" is the spell type every Ready move uses.
    local ready_move_set = gearset({}):when():spell_type("Monster")

    snugs:default_idle(gearset(gearset_from_mode("style", {
        dd     = dt_set,
        -- Pet gear only matters while a pet is actually out.
        petdmg = gearset(pet_dd_set):when():has_pet(true):otherwise(dt_set),
        petdt  = gearset(pet_dt_set):when():has_pet(true):otherwise(dt_set),
    })):and_combine(ready_move_set))

    snugs:default_engaged(gearset_from_mode("style", {
        dd     = dd_set,
        petdmg = gearset(pet_dd_set):when():has_pet(true):otherwise(dd_set),
        petdt  = gearset(pet_dt_set):when():has_pet(true):otherwise(dd_set),
    }))

    -- Calling a pet needs the right broth equipped before and during the call,
    -- which is what premidcast_all does: it registers for both stages at once.
    snugs:premidcast_all({"Call Beast", "Bestial Loyalty"},
        gearset({}):and_combine(gearset_from_mode("jug")))

    -- Reward heals your pet, and needs pet food in the ammo slot.
    -- snugs:precast("Reward", { ammo = "Pet Food Theta" })
    -- snugs:midcast("Reward", {})

    -- Specific Ready moves that want their own gear. Physical moves want pet
    -- accuracy and attack; magical ones want pet magic accuracy.
    -- snugs:midcast_all({"Tegmina Buffet", "Wing Slap"}, {})
    -- snugs:midcast_all({"Corrosive Ooze"}, {})

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)
    -- snugs:weaponskill("Decimation",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Mistral Axe", set_combine(base_ws_set, {}))

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
