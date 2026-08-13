-- Generic caster template (BLM / WHM / RDM / SCH / GEO / SMN / BLU ...)
--
-- The shape of a casting job: get the spell off quickly (fast cast), then swap
-- into gear that makes it land harder or last longer (midcast), then go back to
-- standing around safely (idle).
--
-- Copy this file, rename it Yourname_JOB.lua, and fill in the empty {} sets.

include('snugswap')

function get_sets()
    -- ------------------------------------------------------------------
    -- Modes
    --
    -- A mode is a switch you flip in game. `gs c toggle <name>` moves to the
    -- next value, `gs c set <name> <value>` jumps straight to one, and
    -- `gs c list modes` shows them all.
    -- ------------------------------------------------------------------

    -- Stops casting sets from swapping your weapons. Handy when you are holding
    -- something you do not want to let go of mid-fight.
    snugs:add_mode("lockweapons", {
        initial_value = "off",
        description   = "Lock weapons",
        cycle_values  = {"off", "on"},
    })

    -- Magic burst gear, used for exactly one spell and then switched back off.
    snugs:add_mode("burst", {
        initial_value = "off",
        description   = "Magic burst",
        cycle_values  = {"off", "on"},
    })

    -- This is what makes "burst" reset itself after one spell.
    snugs:register_middleware("aftercast",
        create_once_mode_transition("burst", "off", when():mode_is("burst", "on")))

    -- ------------------------------------------------------------------
    -- Weapons
    --
    -- Kept separate from your armour so that SnugSwap can put them back after
    -- every action. Add more with snugs:weaponset("name", {...}) and switch
    -- with `gs c set weapon name`.
    -- ------------------------------------------------------------------
    snugs:default_weaponset({})

    -- ------------------------------------------------------------------
    -- Idle and engaged
    -- ------------------------------------------------------------------

    -- Extra refresh gear, worn only when you are low on MP. Change the number
    -- to whatever percentage you want the swap to happen at.
    local idle_refresh_set = gearset({}):when():mpp_less_than(80)

    snugs:default_idle(gearset({}):and_combine(idle_refresh_set))

    -- Worn while meleeing. Many casters just reuse their idle set here.
    snugs:default_engaged({})

    -- ------------------------------------------------------------------
    -- Fast cast
    --
    -- Worn the instant a spell begins. The default applies to everything;
    -- add per-skill or per-spell sets for anything that needs more.
    -- ------------------------------------------------------------------
    local fast_cast_set = gearset({})

    snugs:default_fastcast(fast_cast_set)

    -- Extra fast cast for one skill, layered on top of the default.
    snugs:fastcast("Healing Magic", gearset(fast_cast_set):and_combine({}))

    -- Or for a whole list of spells at once.
    snugs:fastcast_all({"Cure", "Cure II", "Cure III"},
        gearset(fast_cast_set):and_combine({}))

    -- ------------------------------------------------------------------
    -- Midcast
    --
    -- SnugSwap picks the most specific set you registered: the exact spell
    -- name first, then the spell family (AllCure covers every Cure tier),
    -- then the spell type, then the skill. Only one of them is used.
    -- ------------------------------------------------------------------

    -- Whole-skill sets. These catch anything without a more specific set.
    --
    -- Register each name once. A second registration for the same name is
    -- refused with a warning, so build the whole set in one call rather than
    -- adding to it later. Elemental Magic is registered further down, with its
    -- conditions attached.
    snugs:midcast("Healing Magic", {})
    snugs:midcast("Enhancing Magic", {})
    snugs:midcast("Enfeebling Magic", {})
    snugs:midcast("Dark Magic", {})
    snugs:midcast("Divine Magic", {})

    -- Spell families. AllCure covers Cure through Cure VI without listing them.
    snugs:midcast("AllCure", {})
    snugs:midcast("AllCuraga", {})

    -- A single spell, which beats everything above for that one spell.
    snugs:midcast("Stoneskin", {})

    -- ------------------------------------------------------------------
    -- Conditional extras
    --
    -- These layer on top of a set only when their condition is true.
    -- ------------------------------------------------------------------

    -- Spell interruption gear, only while something is hitting you.
    local sird_set = gearset({}):when():status("Engaged")

    -- An elemental obi belongs on only when the day, the weather, or your own
    -- storm spell matches the element you are casting.
    local fire_obi_set = gearset({})
        :when():weather("Fire")
        :or_instead(when():day("Fire"))
        :or_instead(when():buff("Firestorm"))

    -- Magic burst gear, on only while the burst mode is on.
    local burst_set = gearset({}):when():mode_is("burst", "on")

    snugs:midcast("Elemental Magic", gearset({})
        :and_combine(fire_obi_set)
        :and_combine(burst_set)
        :and_combine(sird_set))

    -- ------------------------------------------------------------------
    -- Weapon skills
    -- ------------------------------------------------------------------
    snugs:default_weaponskill({})

    -- ------------------------------------------------------------------
    -- Utility sets
    --
    -- Never worn automatically. Equip them by hand with `gs c util <name>`.
    -- warp, nexus and speed also answer to `gs c warp` and friends.
    -- ------------------------------------------------------------------
    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

-- Hooks SnugSwap into GearSwap. Leave this at the bottom.
snugs:wire_all()
