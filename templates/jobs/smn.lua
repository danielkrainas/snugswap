-- Summoner
--
-- Pet job. Your avatar's blood pacts are what actually do the work, and they
-- arrive as pet actions rather than your own, so their gear goes in midcast
-- and SnugSwap applies it for both you and the avatar.
--
-- Blood pacts come in two kinds: "rage" (damage) and "ward" (buffs and
-- debuffs). Registering those two type names covers every pact you have.

include('snugswap')

function get_sets()
    -- Movement speed gear while idling, without giving up your idle set.
    snugs:add_mode("speed", {
        initial_value = "off",
        description   = "Keep movement gear on while idle",
        cycle_values  = {"off", "on"},
    })

    snugs:default_weaponset({})

    local idle_set        = {}  -- no avatar out
    local avatar_set      = {}  -- avatar out: perpetuation cost down
    local idle_refresh_set = {} -- low MP

    -- Only one of these applies at a time, so choose_from is used rather than
    -- layering: avatar out wins, then low MP, then the plain idle set.
    snugs:default_idle(gearset(choose_from(
        use(avatar_set, when():has_pet(true)):priority(30),
        use(idle_refresh_set, when():mpp_less_than(75)):priority(20),
        use(idle_set):priority(10)
    )):and_combine(gearset({}):when():mode_is("speed", "on")))

    snugs:default_engaged({})

    snugs:default_fastcast({})

    -- Blood pact ability delay reduction, worn as the pact starts.
    snugs:default_precast(gearset({})
        :and_combine(gearset({}):when():spell_type_any({"BloodPactRage", "BloodPactWard"})))

    -- Every damage pact. Pet magic attack, pet accuracy and blood pact damage.
    snugs:midcast("BloodPactRage", {})

    -- Every buff or debuff pact. Summoning magic skill matters most.
    snugs:midcast("BloodPactWard", {})

    -- Magical pacts want different gear from physical ones. List the magical
    -- ones here to override the general BloodPactRage set above.
    -- snugs:midcast_all({"Inferno", "Diamond Dust", "Aerial Blast", "Earthen Fury",
    --                    "Judgment Bolt", "Tidal Wave", "Searing Light", "Howling Moon",
    --                    "Meteor Strike", "Heavenly Strike", "Wind Blade", "Geocrush",
    --                    "Thunderstorm", "Grand Fall"}, {})

    -- Flaming Crush is part physical and part magical, so it often wants a
    -- set of its own.
    -- snugs:midcast("Flaming Crush", {})

    -- Summoning the avatar itself, and non-pact summoning magic.
    snugs:midcast("Summoning Magic", {})

    snugs:midcast("AllCure", {})

    snugs:default_weaponskill({})

    -- Blood pact sets you can force by hand before a pact, with
    -- `gs c util magicalbp` and so on.
    -- snugs:util("magicalbp",  {})
    -- snugs:util("physicalbp", {})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
