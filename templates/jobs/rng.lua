-- Ranger
--
-- Shooting has two stages, the same way casting does. "Preshot" is worn as you
-- start the shot and controls how fast it goes off; "midshot" is worn as it
-- lands and controls damage. Both are told apart by action type rather than
-- spell name, so one rule covers every shot.

include('snugswap')

function get_sets()
    snugs:add_mode("style", {
        initial_value = "ranged",
        description   = "Playstyle",
        cycle_values  = {"ranged", "melee"},
    })

    snugs:default_weaponset(gearset_from_mode("style", {
        ranged = {},
        melee  = {},
    }))

    snugs:default_idle({})

    snugs:default_engaged(gearset_from_mode("style", {
        ranged = {},
        melee  = {},
    }))

    -- Worn as the shot begins. Snapshot and rapid shot go here.
    local preshot_set = gearset({}):when():action_type("Ranged Attack")

    -- Worn as the shot lands. Ranged attack and ranged accuracy go here.
    local midshot_set = gearset({}):when():action_type("Ranged Attack")

    -- default_precast always applies, which is what you want for shots: they
    -- never reach the fast cast stage the way spells do.
    snugs:default_precast(gearset({}):and_combine(preshot_set))
    snugs:default_midcast(gearset({}):and_combine(midshot_set))

    -- Weapon skills that use special ammo are worth protecting: this keeps
    -- cheap ammo equipped for ordinary shots so you do not burn the good
    -- stuff, while letting the listed weapon skills use it.
    -- local ws_ammo_spells = {"Trueflight", "Last Stand", "Empyreal Arrow",
    --                         "Jishnu's Radiance", "Wildfire"}
    -- local keep_ws_ammo = gearset({})
    --     :when():action_type("Ranged Attack")
    --     :or_instead(when():spell_name_any(ws_ammo_spells))
    -- snugs:default_precast(gearset({}):and_combine(preshot_set):and_combine(keep_ws_ammo))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Last Stand",        set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Jishnu's Radiance", set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Empyreal Arrow",    set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Coronach",          set_combine(base_ws_set, {}))

    -- Trueflight and Wildfire are magic damage, so they want magic attack
    -- and an elemental obi rather than the usual ranged stats.
    -- snugs:weaponskill("Trueflight", set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Wildfire",   set_combine(base_ws_set, {}))

    -- Job abilities.
    -- snugs:midcast("Barrage",    {})
    -- snugs:midcast("Sharpshot",  {})
    -- snugs:midcast("Velocity Shot", {})

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
