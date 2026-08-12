-- Bard
--
-- Songs are grouped by family, and each family usually wants one different
-- piece on top of a shared song set.
--
-- One thing to know: songs do NOT go through the fast cast set. Only spells
-- whose type contains "Magic" reach that stage, and a song's type is
-- "BardSong". Song gear belongs in default_precast, which always applies.

include('snugswap')

function get_sets()
    snugs:add_mode("style", {
        initial_value = "song",
        description   = "Playstyle",
        cycle_values  = {"song", "dw", "dd"},
    })

    -- Which instrument to hold. Daurdabla gives extra song slots, the relic
    -- and aeonic horns give potency. `gs c toggle instrument` cycles them.
    local instrument_dummy  = {}  -- e.g. { range = "Daurdabla" }
    local instrument_relic  = {}  -- e.g. { range = "Gjallarhorn" }
    local instrument_aeonic = {}  -- e.g. { range = "Marsyas" }

    snugs:add_mode("instrument", {
        initial_value = "relic",
        description   = "Instrument",
        cycle_values  = {"relic", "aeonic", "dummy"},
        gearset_mappings = {
            relic  = instrument_relic,
            aeonic = instrument_aeonic,
            dummy  = instrument_dummy,
        },
    })

    local active_instrument_set = gearset_from_mode("instrument")

    local active_weapon_set = gearset_from_mode("style", {
        song = {},
        dw   = {},
        dd   = {},
    })

    -- The gear every song shares.
    local song_set = {}

    -- Extra magic accuracy, for songs that have to land on an enemy.
    local song_accuracy_set = gearset({})

    -- What you wear while the song is starting: cast time plus your instrument.
    local precast_song_set = gearset(set_combine(song_set, {}))
        :and_combine(active_instrument_set)

    snugs:idle(gearset({})
        :and_combine(active_weapon_set)
        :and_combine(active_instrument_set))

    snugs:engaged(gearset({}):and_combine(active_weapon_set))

    -- Fast cast still applies to actual magic, like cures.
    snugs:default_fastcast(gearset({}))

    -- Song precast goes here, not in fast cast. See the note at the top.
    snugs:default_precast(gearset({})
        :and_combine(gearset(precast_song_set):when():spell_type("BardSong")))

    snugs:default_midcast(gearset({}):and_combine(song_accuracy_set))

    -- Dummy songs exist to be overwritten, so they want the extra-slot
    -- instrument regardless of which one you have selected.
    local dummy_spells = {"Scop's Operetta", "Goblin's Gavotte"}
    snugs:midcast_all(dummy_spells, gearset(precast_song_set):and_combine(instrument_dummy))

    -- Each family below gets the shared song set plus one different piece.
    -- Wrap the shared base in gearset(...) each time: and_combine changes the
    -- set it is called on, so reusing it directly would mix the families.
    local lullaby_set = gearset(song_set):and_combine(song_accuracy_set)
    snugs:midcast_all({"Horde's Lullaby", "Horde's Lullaby II"},
        gearset(lullaby_set):and_combine(instrument_dummy))
    snugs:midcast_all({"Foe Lullaby", "Foe Lullaby II"},
        gearset(lullaby_set):and_combine(instrument_relic))

    snugs:midcast_all({"Honor March", "Victory March", "Advancing March"},
        set_combine(song_set, {}))

    snugs:midcast_all({"Valor Minuet", "Valor Minuet II", "Valor Minuet III",
                       "Valor Minuet IV", "Valor Minuet V"}, set_combine(song_set, {}))

    snugs:midcast_all({"Mage's Ballad", "Mage's Ballad II", "Mage's Ballad III"},
        set_combine(song_set, {}))

    snugs:midcast_all({"Knight's Minne", "Knight's Minne II", "Knight's Minne III",
                       "Knight's Minne IV", "Knight's Minne V"}, set_combine(song_set, {}))

    snugs:midcast_all({"Blade Madrigal", "Sword Madrigal"}, set_combine(song_set, {}))
    snugs:midcast_all({"Battlefield Elegy", "Carnage Elegy"}, set_combine(song_set, {}))
    snugs:midcast_all({"Sentinel's Scherzo"}, set_combine(song_set, {}))
    snugs:midcast_all({"Sheepfoe Mambo", "Dragonfoe Mambo"}, set_combine(song_set, {}))

    -- Honor March is best cast with the aeonic horn specifically.
    -- snugs:precast("Honor March", gearset(precast_song_set):and_combine(instrument_aeonic))

    snugs:midcast("AllCure", {})

    snugs:default_weaponskill({})

    snugs:util("warp", {})
    snugs:util("nexus", {})
    snugs:util("speed", {})
end

snugs:wire_all()
