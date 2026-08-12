-- Blue Mage
--
-- Blue Mage has hundreds of spells and each one behaves like a physical
-- attack, a nuke, a debuff, a heal or a buff. Rather than writing a set per
-- spell, group the spell names into categories once at the top of the file and
-- then register one set per category. Adding a new spell later is a one-line
-- edit to a list.

include('snugswap')

-- ----------------------------------------------------------------------
-- Which spells belong to which category.
--
-- Add spell names to whichever list matches how the spell does its damage.
-- The loop underneath turns these into plain lists for registration.
-- ----------------------------------------------------------------------
local blue_magic_maps = {}

blue_magic_maps.physical = {
    -- ['Vertical Cleave'] = true,
    -- ['Sinker Drill'] = true,
}

blue_magic_maps.magical = {
    -- ['Subduction'] = true,
    -- ['Leafstorm'] = true,
}

blue_magic_maps.magical_acc = {   -- debuffs: magic accuracy over damage
    -- ['Blank Gaze'] = true,
    -- ['Sheep Song'] = true,
}

blue_magic_maps.breath = {
    -- ['Bad Breath'] = true,
}

blue_magic_maps.healing = {
    -- ['Magic Fruit'] = true,
    -- ['Wild Carrot'] = true,
}

blue_magic_maps.buff = {          -- self buffs, want blue magic skill
    -- ['Cocoon'] = true,
    -- ['Occultation'] = true,
}

blue_magic_maps.stun = {
    -- ['Head Butt'] = true,
}

-- Turns each category above into an ordered list SnugSwap can register.
local blue_spell_lists = {}
for category, spells in pairs(blue_magic_maps) do
    local list = {}
    blue_spell_lists[category] = list
    for spell in pairs(spells) do
        table.insert(list, spell)
    end
end

function get_sets()
    snugs:add_mode("style", {
        initial_value = "dd",
        description   = "Playstyle",
        cycle_values  = {"dd", "magic", "tank"},
    })

    snugs:default_weaponset({})

    snugs:default_idle({})
    snugs:default_engaged({})

    local fast_cast_set = gearset({})
    snugs:default_fastcast(fast_cast_set)
    snugs:fastcast("Blue Magic", gearset(fast_cast_set):and_combine({}))

    -- Gear worn only while a job buff is up.
    local diffusion_set = gearset({}):when():buff("Diffusion")
    local efflux_set    = gearset({}):when():buff("Efflux")

    -- Spell interruption gear, only while something is hitting you.
    local sird_set = gearset({}):when():status("Engaged")

    -- The base every blue magic spell shares.
    local blue_magic_set = gearset({})
        :and_combine(diffusion_set)
        :and_combine(efflux_set)
        :and_combine(sird_set)

    -- "Blue Magic" is the skill name, so this catches anything without a more
    -- specific set below.
    snugs:midcast("Blue Magic", blue_magic_set)

    -- One registration per category. Wrap the shared base in gearset(...) each
    -- time so the categories do not blend into one another.
    snugs:midcast_all(blue_spell_lists.physical,    gearset(blue_magic_set):and_combine({}))
    snugs:midcast_all(blue_spell_lists.magical,     gearset(blue_magic_set):and_combine({}))
    snugs:midcast_all(blue_spell_lists.magical_acc, gearset(blue_magic_set):and_combine({}))
    snugs:midcast_all(blue_spell_lists.breath,      gearset(blue_magic_set):and_combine({}))
    snugs:midcast_all(blue_spell_lists.healing,     gearset(blue_magic_set):and_combine({}))
    snugs:midcast_all(blue_spell_lists.buff,        gearset(blue_magic_set):and_combine({}))
    snugs:midcast_all(blue_spell_lists.stun,        gearset(blue_magic_set):and_combine({}))

    snugs:midcast("AllCure", {})

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)
    -- snugs:weaponskill("Savage Blade", set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Chant du Cygne", set_combine(base_ws_set, {}))

    -- Maximum blue magic skill, for learning new spells. `gs c util learning`.
    snugs:util("learning", {})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
