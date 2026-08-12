-- Rune Fencer
--
-- Tank that leans on magic defence. Runes and the abilities that use them
-- (Vallation, Valiance, Pflug) are job abilities, so they go through midcast,
-- and enhancing magic matters more here than on most tanks.

include('snugswap')

function get_sets()
    snugs:add_mode("style", {
        initial_value = "tank",
        description   = "Playstyle",
        cycle_values  = {"tank", "hybrid", "dd"},
    })

    local tank_set   = {}
    local hybrid_set = {}
    local dd_set     = {}

    snugs:default_weaponset(gearset_from_mode("style", {
        tank   = {},
        hybrid = {},
        dd     = {},
    }))

    local idle_refresh_set = gearset({}):when():mpp_less_than(80)

    snugs:default_idle(gearset(tank_set):and_combine(idle_refresh_set))

    snugs:default_engaged(gearset_from_mode("style", {
        tank   = tank_set,
        hybrid = hybrid_set,
        dd     = dd_set,
    }))

    -- Enmity gear, for anything that grabs attention.
    local enmity_set = gearset({})

    -- Spell interruption gear, only while something is hitting you.
    local sird_set = gearset({}):when():status("Engaged")

    snugs:default_fastcast({})

    -- Everything hate-related shares one set.
    snugs:midcast_all({"Provoke", "Flash", "Foil", "Swipe", "Lunge"},
        gearset(enmity_set))

    -- Rune abilities. Vallation and Valiance scale with magic defence bonus
    -- gear worn at the moment you use them.
    -- snugs:midcast_all({"Vallation", "Valiance", "Pflug", "Battuta"}, {})

    -- Embolden doubles the next enhancing spell, so Embolden itself and the
    -- spell that follows both want enhancing gear.
    -- snugs:midcast("Embolden", {})

    snugs:midcast("Enhancing Magic", gearset({}):and_combine(sird_set))
    snugs:midcast("Phalanx",         gearset({}):and_combine(sird_set))
    snugs:midcast("AllRegen",        gearset({}):and_combine(sird_set))
    snugs:midcast("AllCure",         gearset(enmity_set):and_combine(sird_set))

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Resolution",  set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Dimidiation", set_combine(base_ws_set, {}))

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
