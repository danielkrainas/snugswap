-- Generic tank template (PLD / RUN / NIN / DRK when tanking ...)
--
-- A tank swaps between staying alive and holding hate. The "style" mode below
-- is the main dial: flip it and your weapons, idle set and fighting set all
-- change together.
--
-- Copy this file, rename it Yourname_JOB.lua, and fill in the empty {} sets.

include('snugswap')

function get_sets()
    -- ------------------------------------------------------------------
    -- Modes
    -- ------------------------------------------------------------------

    -- One switch that drives weapons, idle and engaged at the same time.
    -- `gs c toggle style` moves to the next value.
    snugs:add_mode("style", {
        initial_value = "tank",
        description   = "Playstyle",
        cycle_values  = {"tank", "hybrid", "dd"},
    })

    -- ------------------------------------------------------------------
    -- Gear building blocks
    --
    -- Plain tables, defined once and reused below. Nothing is worn until it
    -- is handed to a snugs:... call.
    -- ------------------------------------------------------------------
    local tank_set   = {}  -- maximum survivability
    local hybrid_set = {}  -- a bit of both
    local dd_set     = {}  -- damage, when something else is tanking

    -- ------------------------------------------------------------------
    -- Weapons
    --
    -- One entry per style value. Extra named sets can be added with
    -- snugs:weaponset("name", {...}) and reached with `gs c set weapon name`.
    -- ------------------------------------------------------------------
    snugs:default_weaponset(gearset_from_mode("style", {
        tank   = {},
        hybrid = {},
        dd     = {},
    }))

    -- ------------------------------------------------------------------
    -- Idle and engaged
    --
    -- Both follow the style mode, so one toggle changes everything.
    -- ------------------------------------------------------------------
    snugs:default_idle(gearset_from_mode("style", {
        tank   = tank_set,
        hybrid = tank_set,
        dd     = tank_set,
    }))

    snugs:default_engaged(gearset_from_mode("style", {
        tank   = tank_set,
        hybrid = hybrid_set,
        dd     = dd_set,
    }))

    -- ------------------------------------------------------------------
    -- Conditional extras
    -- ------------------------------------------------------------------

    -- Enmity gear, for anything whose job is to grab attention.
    local enmity_set = gearset({})

    -- Spell interruption gear, only while something is hitting you. Casting
    -- through damage is most of a tank's job.
    local sird_set = gearset({}):when():status("Engaged")

    -- ------------------------------------------------------------------
    -- Casting
    -- ------------------------------------------------------------------
    snugs:default_fastcast({})

    -- Provoke, Flash, Sentinel and friends all want enmity gear.
    snugs:midcast_all({"Provoke", "Flash", "Sentinel", "Rampart", "Cover", "Palisade"},
        gearset(enmity_set))

    -- Cures on yourself, worn through incoming damage.
    snugs:midcast("AllCure", gearset({}):and_combine(sird_set))

    snugs:midcast("Divine Magic", gearset({}):and_combine(sird_set))
    snugs:midcast("Enhancing Magic", gearset({}):and_combine(sird_set))

    -- Phalanx usually wants its own augmented pieces.
    snugs:midcast("Phalanx", gearset({}):and_combine(sird_set))

    -- ------------------------------------------------------------------
    -- Weapon skills
    -- ------------------------------------------------------------------
    snugs:default_weaponskill({})

    -- Hate-generating weapon skills want enmity rather than damage.
    -- snugs:weaponskill("Atonement", gearset(enmity_set))

    -- ------------------------------------------------------------------
    -- Utility sets
    -- ------------------------------------------------------------------
    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

-- Hooks SnugSwap into GearSwap. Leave this at the bottom.
snugs:wire_all()
