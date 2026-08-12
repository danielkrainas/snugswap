-- Corsair
--
-- Part gunner, part support. Rolls and Quick Draw are the job's own actions
-- and they arrive as a spell *type*, not an action type: the action type for
-- both is just "Ability". Use spell_type("CorsairRoll") and
-- spell_type("CorsairShot") or the gear will never equip.

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

    -- A gun you swap to for rolling, if your rolling gun differs.
    -- snugs:weaponset("rolls", {})

    snugs:default_idle({})

    snugs:default_engaged(gearset_from_mode("style", {
        ranged = {},
        melee  = {},
    }))

    -- Worn as a shot begins: snapshot and rapid shot.
    local preshot_set = gearset({}):when():action_type("Ranged Attack")

    -- Worn as a shot lands: ranged attack and accuracy.
    local midshot_set = gearset({}):when():action_type("Ranged Attack")

    -- Quick Draw. Magic accuracy and magic attack.
    local quickdraw_set = gearset({}):when():spell_type("CorsairShot")

    -- Phantom Rolls. Rolling gear and any lucky-roll pieces.
    -- Double-Up is a separate action name, so it is listed as well.
    local roll_set = gearset({})
        :when():spell_type("CorsairRoll")
        :or_instead(when():spell_name("Double-Up"))

    snugs:default_precast(gearset({}):and_combine(preshot_set))

    snugs:default_midcast(gearset({})
        :and_combine(midshot_set)
        :and_combine(quickdraw_set)
        :and_combine(roll_set))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Last Stand",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Savage Blade", set_combine(base_ws_set, {}))

    -- Leaden Salute and Wildfire are magic damage: magic attack, and an
    -- elemental obi when the day or weather matches.
    -- snugs:weaponskill("Leaden Salute", set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Wildfire",      set_combine(base_ws_set, {}))

    snugs:default_fastcast({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
