-- How SnugSwap picks which registered set to equip for a given action.

describe("lookup order", function()
    local function lookups_for(snugs, spell)
        return snugs:_new_context("midcast", { spell = spell }).lookups
    end

    it("ranks spell name, then family key, then type, then skill", function(snugs)
        assert_list(
            lookups_for(snugs, stub.spell{ english = "Cure IV" }),
            { "Cure IV", "AllCure", "WhiteMagic", "Healing Magic" })
    end)

    it("collapses type and skill when they are the same string", function(snugs)
        assert_list(
            lookups_for(snugs, stub.spell{ english = "Utsusemi: Ni", type = "Ninjutsu", skill = "Ninjutsu" }),
            { "Utsusemi: Ni", "AllUtsusemi", "Ninjutsu" })
    end)

    it("omits the skill key when the action has no skill", function(snugs)
        assert_list(
            lookups_for(snugs, { english = "Provoke", type = "JobAbility" }),
            { "Provoke", "AllProvoke", "JobAbility" })
    end)
end)

describe("midcast resolution", function()
    local function register_ladder(snugs)
        snugs:midcast("Healing Magic", { body = "skill" })
        snugs:midcast("WhiteMagic", { body = "type" })
        snugs:midcast("AllCure", { body = "family" })
        snugs:midcast("Cure VI", { body = "exact" })
    end

    it("prefers an exact spell name over everything else", function(snugs)
        register_ladder(snugs)
        snugs:do_midcast(stub.spell{ english = "Cure VI" })
        assert_slot("body", "exact")
    end)

    it("prefers a family key over the type and skill", function(snugs)
        register_ladder(snugs)
        snugs:do_midcast(stub.spell{ english = "Cure IV" })
        assert_slot("body", "family")
    end)

    it("prefers the type over the skill", function(snugs)
        register_ladder(snugs)
        snugs:do_midcast(stub.spell{ english = "Cursna" })
        assert_slot("body", "type")
    end)

    it("falls back to the skill when nothing narrower matches", function(snugs)
        snugs:midcast("Healing Magic", { body = "skill" })
        snugs:do_midcast(stub.spell{ english = "Cursna" })
        assert_slot("body", "skill")
    end)

    it("equips the default midcast set before the resolved one", function(snugs)
        snugs:default_midcast({ head = "default", body = "default" })
        snugs:midcast("Cure", { body = "specific" })
        snugs:do_midcast(stub.spell{ english = "Cure" })
        assert_slots{ head = "default", body = "specific" }
    end)

    it("equips nothing extra when no set matches", function(snugs)
        snugs:midcast("Elemental Magic", { body = "nuke" })
        snugs:do_midcast(stub.spell{ english = "Cure" })
        assert_equal(stub.summary(), "")
    end)
end)

describe("precast resolution", function()
    it("always equips the default precast set", function(snugs)
        snugs:default_precast({ head = "preshot" })
        snugs:do_precast(stub.spell{ english = "Shot", type = "WeaponSkill",
                                     skill = "Archery", action_type = "Ranged Attack" })
        assert_slot("head", "preshot")
    end)

    it("falls through to fast cast for magic", function(snugs)
        snugs:default_fastcast({ head = "fc" })
        snugs:do_precast(stub.spell{ english = "Cure" })
        assert_slot("head", "fc")
    end)

    it("prefers a fast cast set matching the skill over the default", function(snugs)
        snugs:default_fastcast({ head = "fc", body = "fc" })
        snugs:fastcast("Healing Magic", { body = "fc-healing" })
        snugs:do_precast(stub.spell{ english = "Cure" })
        assert_slots{ head = "fc", body = "fc-healing" }
    end)

    it("registers a fast cast set for every name given to fastcast_all", function(snugs)
        snugs:fastcast_all({ "Cure", "Cure II", "Cure III" }, { legs = "doyen" })
        for _, name in ipairs({ "Cure", "Cure II", "Cure III" }) do
            stub.clear_equipped()
            snugs:do_precast(stub.spell{ english = name })
            assert_slot("legs", "doyen")
        end
    end)

    it("skips fast cast entirely when a precast set matched", function(snugs)
        snugs:default_fastcast({ head = "fc" })
        snugs:precast("Stun", { neck = "stun" })
        snugs:do_precast(stub.spell{ english = "Stun", type = "BlackMagic", skill = "Dark Magic" })
        assert_slots{ neck = "stun", head = EMPTY }
    end)

    it("does not reach fast cast for non-magic actions", function(snugs)
        snugs:default_fastcast({ head = "fc" })
        snugs:do_precast(stub.spell{ english = "Berserk", type = "JobAbility",
                                     skill = nil, action_type = "Ability" })
        assert_slot("head", nil)
    end)
end)

describe("weapon skills", function()
    it("uses a weapon skill set matching the name", function(snugs)
        snugs:default_weaponskill({ head = "ws-default" })
        snugs:weaponskill("Savage Blade", { head = "savage" })
        snugs:do_midcast(stub.spell{ english = "Savage Blade", type = "WeaponSkill", skill = "Sword" })
        assert_slot("head", "savage")
    end)

    it("falls back to the default weapon skill set", function(snugs)
        snugs:default_weaponskill({ head = "ws-default" })
        snugs:do_midcast(stub.spell{ english = "Requiescat", type = "WeaponSkill", skill = "Sword" })
        assert_slot("head", "ws-default")
    end)

    it("registers every name given to weaponskill_all", function(snugs)
        snugs:weaponskill_all({ "Mistral Axe", "Decimation" }, { head = "axe" })
        for _, name in ipairs({ "Mistral Axe", "Decimation" }) do
            stub.clear_equipped()
            snugs:do_midcast(stub.spell{ english = name, type = "WeaponSkill", skill = "Axe" })
            assert_slot("head", "axe")
        end
    end)

    it("ignores a midcast registration for a weapon skill name", function(snugs)
        snugs:default_weaponskill({ head = "ws-default" })
        snugs:midcast("Victory Smite", { head = "wrong-tier" })
        snugs:do_midcast(stub.spell{ english = "Victory Smite", type = "WeaponSkill",
                                     skill = "Hand-to-Hand" })
        assert_slot("head", "ws-default")
    end)
end)

describe("status sets", function()
    it("equips the idle set when idle", function(snugs)
        snugs:default_idle({ head = "idle" })
        snugs:default_engaged({ head = "engaged" })
        snugs:do_status_change("Idle", "Engaged")
        assert_slot("head", "idle")
    end)

    it("equips the engaged set when engaged", function(snugs)
        player.status = "Engaged"
        snugs:default_idle({ head = "idle" })
        snugs:default_engaged({ head = "engaged" })
        snugs:do_status_change("Engaged", "Idle")
        assert_slot("head", "engaged")
    end)

    it("prefers an explicit sets.status entry over the lowercased fallback", function(snugs)
        snugs:default_idle({ head = "idle" })
        sets.status.Idle = { head = "explicit" }
        snugs:do_status_change("Idle", "Engaged")
        assert_slot("head", "explicit")
    end)

    it("layers the weapon set on top of the status set", function(snugs)
        snugs:default_idle({ head = "idle" })
        snugs:default_weaponset({ main = "Naegling", sub = "Blurred Shield +1" })
        snugs:do_status_change("Idle", "Engaged")
        assert_slots{ head = "idle", main = "Naegling", sub = "Blurred Shield +1" }
    end)

    it("returns to the status set after a spell", function(snugs)
        snugs:default_idle({ head = "idle" })
        snugs:do_aftercast(stub.spell{ english = "Cure" })
        assert_slot("head", "idle")
    end)
end)

describe("pet actions", function()
    it("uses the midcast tier for pet midcast", function(snugs)
        snugs:midcast("Flaming Crush", { body = "bp" })
        snugs:do_pet_midcast(stub.spell{ english = "Flaming Crush", type = "BloodPactRage",
                                         skill = "Summoning Magic" })
        assert_slot("body", "bp")
    end)

    it("falls back to the status set when no pet midcast set matches", function(snugs)
        snugs:default_idle({ head = "idle" })
        snugs:do_pet_midcast(stub.spell{ english = "Mewing Lullaby", type = "BloodPactWard",
                                         skill = "Summoning Magic" })
        assert_slot("head", "idle")
    end)

    it("returns to the status set on pet change", function(snugs)
        snugs:default_idle({ head = "idle" })
        snugs:do_pet_change({ isvalid = true }, true)
        assert_slot("head", "idle")
    end)
end)

describe("set registration", function()
    it("keeps the first registration and warns on a duplicate", function(snugs)
        snugs:default_idle({ head = "first" })
        snugs:default_idle({ head = "second" })
        snugs:do_status_change("Idle", "Engaged")
        assert_slot("head", "first")
        assert_true(stub.said("already exists"), "expected a duplicate-set warning")
    end)

    it("rejects an empty set name", function(snugs)
        assert_false(snugs:add(sets.midcast, "", { head = "x" }))
        assert_true(stub.said("Set name must be provided"))
    end)

    it("stores an empty table when no set is given", function(snugs)
        assert_true(snugs:add(sets.midcast, "Cure", nil))
        assert_equal(type(sets.midcast["Cure"]), "table")
    end)
end)

describe("equip normalization", function()
    it("converts plain string slots into item tables", function(snugs)
        snugs:util("test", { head = "Nyame Helm" })
        snugs:do_self_command("util test")
        assert_equal(type(stub.equipped.head), "table")
        assert_equal(stub.equipped.head.name, "Nyame Helm")
    end)

    it("leaves the registered set untouched", function(snugs)
        local literal = { head = "Nyame Helm" }
        snugs:util("test", literal)
        snugs:do_self_command("util test")
        assert_equal(type(literal.head), "string", "the source literal was mutated")
        assert_equal(literal.head, "Nyame Helm")
    end)

    it("passes item tables through unchanged", function(snugs)
        local augmented = { name = "Nyame Helm", augments = { "Path: B" } }
        snugs:util("test", { head = augmented })
        snugs:do_self_command("util test")
        assert_equal(stub.equipped.head, augmented)
    end)

    it("leaves empty-string slots alone", function(snugs)
        snugs:util("test", { range = "" })
        snugs:do_self_command("util test")
        assert_equal(stub.equipped.range, "")
    end)
end)
