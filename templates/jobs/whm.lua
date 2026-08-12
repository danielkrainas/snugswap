-- White Mage
--
-- Healing job. Most of the work is getting cures off fast and making them
-- land for as much as possible, so there is gear in both the fast cast and
-- the midcast sections for the same spells.

include('snugswap')

function get_sets()
    -- Stops casting sets from swapping your weapons mid-fight.
    snugs:add_mode("lockweapons", {
        initial_value = "off",
        description   = "Lock weapons",
        cycle_values  = {"off", "on"},
    })

    snugs:default_weaponset({})

    -- Extra refresh gear once you drop below 80% MP.
    local idle_refresh_set = gearset({}):when():mpp_less_than(80)

    snugs:default_idle(gearset({}):and_combine(idle_refresh_set))
    snugs:default_engaged({})

    -- Fast cast is worn the instant a spell starts.
    --
    -- Each name can only be registered once, so build the whole thing in one
    -- call. "AllCuraga" covers Curaga through Curaga V without listing tiers.
    snugs:default_fastcast(gearset({})
        :and_combine(gearset({}):when():key("AllCuraga")))

    -- Spell interruption gear, only while something is hitting you.
    local sird_set = gearset({}):when():status("Engaged")

    -- A light-elemental obi helps cures on a Lightsday, in Light weather, or
    -- under your own Aurorastorm.
    local light_obi_set = gearset({})
        :when():weather("Light")
        :or_instead(when():day("Light"))
        :or_instead(when():buff("Aurorastorm"))

    -- Midcast is where cure potency lives.
    local cure_set = gearset({})

    snugs:midcast("AllCure", gearset(cure_set)
        :and_combine(light_obi_set)
        :and_combine(sird_set))

    snugs:midcast("AllCuraga", gearset(cure_set)
        :and_combine({})
        :and_combine(light_obi_set)
        :and_combine(sird_set))

    -- Whole-skill sets, used by anything without a more specific set above.
    snugs:midcast("Healing Magic", {})
    snugs:midcast("Enhancing Magic", {})
    snugs:midcast("Enfeebling Magic", {})
    snugs:midcast("Divine Magic", {})

    -- Individual spells that want their own gear.
    snugs:midcast("Cursna", {})
    snugs:midcast("Stoneskin", {})
    snugs:midcast("Devotion", {})

    -- Barspells share one set. Add the rest of the list as you need them.
    -- snugs:midcast_all({"Barfira", "Barblizzara", "Baraera", "Barstonra",
    --                    "Barthundera", "Barwatera"}, {})

    snugs:default_weaponskill({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
