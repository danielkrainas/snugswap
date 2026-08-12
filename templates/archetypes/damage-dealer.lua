-- Generic melee damage dealer template (WAR / MNK / THF / SAM / DRG / DRK ...)
--
-- Most of the work here is weapon skills and the sets you fight in. The "style"
-- mode lets you move between raw damage, accuracy, and a safer defensive set
-- without editing the file.
--
-- Copy this file, rename it Yourname_JOB.lua, and fill in the empty {} sets.

include('snugswap')

function get_sets()
    -- ------------------------------------------------------------------
    -- Modes
    -- ------------------------------------------------------------------
    snugs:add_mode("style", {
        initial_value = "dd",
        description   = "Playstyle",
        cycle_values  = {"dd", "acc", "dt"},
    })

    -- ------------------------------------------------------------------
    -- Gear building blocks
    -- ------------------------------------------------------------------
    local dd_set  = {}  -- maximum damage
    local acc_set = {}  -- accuracy, for things you miss
    local dt_set  = {}  -- damage taken down, for things that hit hard

    -- ------------------------------------------------------------------
    -- Weapons
    --
    -- The default set is what you fight with. Named sets are for anything you
    -- swap to deliberately: a different weapon skill, or proc weapons.
    -- `gs c cycle weapon` rotates through them, `gs c set weapon proc` jumps.
    -- ------------------------------------------------------------------
    snugs:default_weaponset({})

    -- snugs:weaponset("proc", {})
    -- snugs:weaponset("club", {})

    -- ------------------------------------------------------------------
    -- Idle and engaged
    -- ------------------------------------------------------------------

    -- Standing around. Usually your defensive set — you are not gaining
    -- anything from damage gear while nothing is happening.
    snugs:default_idle(dt_set)

    snugs:default_engaged(gearset_from_mode("style", {
        dd  = dd_set,
        acc = acc_set,
        dt  = dt_set,
    }))

    -- ------------------------------------------------------------------
    -- Conditional extras
    --
    -- Layered on top of a set only while their condition holds.
    -- ------------------------------------------------------------------

    -- Gear that is only worth wearing while a job buff is up. Replace the
    -- buff name with whatever your job actually uses.
    -- local buff_set = gearset({}):when():buff("Impetus")

    -- Extra defence when your health gets low.
    -- local low_hp_set = gearset({}):when():hpp_less_than(50)

    -- ------------------------------------------------------------------
    -- Weapon skills
    --
    -- The default is used for any weapon skill without its own set. Add the
    -- ones you actually use — they are usually worth tuning individually.
    -- ------------------------------------------------------------------
    local base_ws_set = {}

    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Savage Blade", set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Ukko's Fury",  set_combine(base_ws_set, {}))

    -- Several weapon skills that share one set.
    -- snugs:weaponskill_all({"Mistral Axe", "Decimation"}, set_combine(base_ws_set, {}))

    -- ------------------------------------------------------------------
    -- Job abilities and casting
    --
    -- Most melee jobs need very little here, but sub-job spells and abilities
    -- that consume ammo or want their own gear go in this section.
    -- ------------------------------------------------------------------
    snugs:default_fastcast({})

    -- snugs:precast("Tomahawk", { ammo = "Thr. Tomahawk" })

    -- ------------------------------------------------------------------
    -- Utility sets
    -- ------------------------------------------------------------------
    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

-- Hooks SnugSwap into GearSwap. Leave this at the bottom.
snugs:wire_all()
