-- Ninja
--
-- Dual wielder that also casts. Ninjutsu comes in tiers named Ichi, Ni and San
-- rather than I, II and III, and SnugSwap groups those for you: registering
-- "AllUtsusemi" covers Utsusemi: Ichi, Ni and San in one go.

include('snugswap')

function get_sets()
    snugs:add_mode("style", {
        initial_value = "dd",
        description   = "Playstyle",
        cycle_values  = {"dd", "acc", "tank"},
    })

    local dd_set   = {}
    local acc_set  = {}
    local tank_set = {}

    snugs:default_weaponset({})

    snugs:default_idle(tank_set)

    snugs:default_engaged(gearset_from_mode("style", {
        dd   = dd_set,
        acc  = acc_set,
        tank = tank_set,
    }))

    -- Ninjutsu cast time. Shadows are worth recasting quickly.
    snugs:default_fastcast({})
    snugs:fastcast("Ninjutsu", {})

    -- Shadows. One registration covers all three tiers.
    snugs:midcast("AllUtsusemi", {})

    -- Elemental ninjutsu wants magic attack and magic accuracy. SnugSwap adds
    -- an "ElementalNinjutsu" key to these automatically.
    snugs:midcast("ElementalNinjutsu", {})

    -- Debuff ninjutsu (Kurayami, Hojo, Dokumori) wants magic accuracy only.
    snugs:midcast("DebuffNinjutsu", {})

    -- Utility ninjutsu (Monomi, Tonko) needs nothing in particular.
    snugs:midcast("UtilityNinjutsu", {})

    -- Anything not covered above.
    snugs:midcast("Ninjutsu", {})

    local base_ws_set = {}
    snugs:default_weaponskill(base_ws_set)

    -- snugs:weaponskill("Blade: Shun", set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Blade: Hi",   set_combine(base_ws_set, {}))
    -- snugs:weaponskill("Blade: Ten",  set_combine(base_ws_set, {}))

    -- Blade: Yu and Blade: Chi are magic damage and want magic attack.
    -- snugs:weaponskill("Blade: Yu", set_combine(base_ws_set, {}))

    -- Job abilities.
    -- snugs:midcast("Innin", {})
    -- snugs:midcast("Yonin", {})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
