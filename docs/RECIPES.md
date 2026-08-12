# Recipes

A collection of quick-reference "recipes" for common GearSwap situations, written the SnugSwap way.
Each one is a self-contained snippet you can drop into `get_sets()` and adapt.

Gear names throughout are illustrative — swap in your own.

- [Playstyle modes](#playstyle-modes)
- [Keeping weapons out of your sets](#keeping-weapons-out-of-your-sets)
- [Named weapon sets you switch to directly](#named-weapon-sets-you-switch-to-directly)
- [Self-resetting magic burst mode](#self-resetting-magic-burst-mode)
- [Layering conditional pieces onto a base set](#layering-conditional-pieces-onto-a-base-set)
- [Refresh gear only when MP is low](#refresh-gear-only-when-mp-is-low)
- [Buff-conditional gear](#buff-conditional-gear)
- [Different gear for self-targeted spells](#different-gear-for-self-targeted-spells)
- [Pet-aware idle and engaged sets](#pet-aware-idle-and-engaged-sets)
- [Elemental obi on day, weather, or storm](#elemental-obi-on-day-weather-or-storm)
- [Fast cast layers](#fast-cast-layers)
- [Preshot and midshot for ranged jobs](#preshot-and-midshot-for-ranged-jobs)
- [One set for a whole group of spells](#one-set-for-a-whole-group-of-spells)
- [Big spell-to-category tables](#big-spell-to-category-tables)
- [Weapon skills](#weapon-skills)
- [Utility sets you trigger by hand](#utility-sets-you-trigger-by-hand)
- [Jug pets and other ammo-driven modes](#jug-pets-and-other-ammo-driven-modes)
- [Instrument swapping for BRD](#instrument-swapping-for-brd)
- [Engaged-only spell interruption gear](#engaged-only-spell-interruption-gear)
- [Picking exactly one set from a list](#picking-exactly-one-set-from-a-list)
- [Adding your own predicate](#adding-your-own-predicate)
- [Spell family keys](#spell-family-keys)
- [Custom lookup keys with middleware](#custom-lookup-keys-with-middleware)
- [Wiring hooks by hand](#wiring-hooks-by-hand)
- [In-game commands](#in-game-commands)
- [Gotchas](#gotchas)

---

## Playstyle modes

The single most useful pattern: one `style` mode that drives weapons, idle, and engaged together.
`gearset_from_mode` picks a branch based on the mode's current value.

```lua
snugs:add_mode("style", {
    initial_value = "hybrid",
    description   = "Playstyle",
    cycle_values  = {"dd", "tank", "hybrid"},
})

snugs:default_weaponset(gearset_from_mode("style", {
    dd     = {main="Naegling", sub="Blurred Shield +1"},
    tank   = {main="Nixxer",   sub="Aegis"},
    hybrid = {main="Naegling", sub="Srivatsa"},
}))

snugs:default_idle(gearset_from_mode("style", {
    dd     = tank_set,       -- idle defensively even in DD mode
    tank   = tank_set,
    hybrid = layered_set,
}))

snugs:default_engaged(gearset_from_mode("style", {
    dd     = dd_set,
    tank   = tank_set,
    hybrid = hybrid_set,
}))
```

Cycle it in game with `gs c toggle style`, or jump straight to a value with `gs c set style tank`.

Give the mode a `shortcut` and SnugSwap binds the key for you on load:

```lua
snugs:add_mode("style", {
    initial_value = "hybrid",
    cycle_values  = {"dd", "tank", "hybrid"},
    shortcut      = "^f1",   -- ctrl+F1 -> gs c toggle style
})
```

Branches can be plain tables, `gearset(...)` values, or nested `gearset_from_mode` calls — so a
second mode can refine the first:

```lua
snugs:default_weaponset(gearset_from_mode("style", {
    melee = gearset_from_mode("highbuff", {
        on  = {main="Naegling", sub="Ternion Dagger +1"},
        off = {main="Naegling", sub="Gleti's Knife"},
    }),
    ranged = {main="Perun +1", sub="Nusku Shield", range="Annihilator"},
}))
```

## Keeping weapons out of your sets

Casting sets that specify `main`/`sub` will happily yank your weapon mid-fight. Gate every
weapon-bearing overlay behind a `lockweapons` mode so you can freeze your current weapons with a
single toggle.

```lua
snugs:add_mode("lockweapons", {
    initial_value = "off",
    cycle_values  = {"off", "on"},
    description   = "Lock weapons",
})

local nuke_set = gearset({
    head="Ea Hat +1",
    body="Ea Houppe. +1",
}):and_combine(gearset({
    main="Bunzi's Rod",
    sub="Ammurapi Shield",
    ammo="Ghastly Tathlum +1",
}):when():mode_is("lockweapons", "off"))

snugs:midcast("Elemental Magic", nuke_set)
```

With `lockweapons` on, the weapon overlay evaluates to nothing and the rest of the set still swaps.

## Named weapon sets you switch to directly

Beyond the default weapon set, register any number of named ones — proc weapons, a savage-blade
club, a treasure hunter offhand — and jump to them by name.

```lua
snugs:default_weaponset({main="Twashtar", sub="Centovente"})

snugs:weaponset("th",         {main="Twashtar", sub="Gandring"})
snugs:weaponset("sb",         {main="Naegling", sub="Centovente"})
snugs:weaponset("procdagger", {main="Brass Dagger", sub="Sapara"})
snugs:weaponset("procclub",   {main="Ash Club", sub="Brass Dagger"})
snugs:weaponset("procgk",     {main="Mutsunokami", sub="Utu Grip"})
```

`gs c set weapon procclub` switches to that set and keeps it through subsequent idle and engaged
swaps until you pick another. `gs c cycle weapon` walks the list in registration order, default
first — handy on a bound key when you are cycling proc weapons in a fight.

## Self-resetting magic burst mode

Mimics `AutoMagicBurstMode = 'once'`: burst gear applies to exactly one spell, then the mode
falls back on its own.

```lua
snugs:add_mode("MagicBurstMode", {
    initial_value = "off",
    cycle_values  = {"off", "Single"},
    description   = "Elemental Magic Burst Mode.",
})

-- reset MagicBurstMode back to "off" as soon as it has been used once
snugs:register_middleware("any",
    create_once_mode_transition("MagicBurstMode", "off",
        when():mode_is("MagicBurstMode", "Single")))

snugs:midcast("Elemental Magic", gearset(nuke_set):and_combine(gearset({
    neck="Mizukage-no-Kubikazari",
    left_ring="Mujin Band",
    right_ring="Locus Ring",
}):when():mode_is("MagicBurstMode", "Single")))
```

Register on `"any"` and the reset fires on the first phase of the next action, so the burst set is
still live for the cast that consumed it. Register on `"aftercast"` instead if you want the mode to
survive until the spell finishes resolving.

## Layering conditional pieces onto a base set

`and_combine` stacks overlays onto a base; `when()` decides whether each overlay contributes.
Overlays apply in order, so later ones win on shared slots.

```lua
local sird_set     = gearset({ammo="Staunch Tathlum +1"}):when():status("Engaged")
local diffusion    = gearset({feet="Luhlaza Charuqs +3"}):when():buff("Diffusion")
local efflux       = gearset({legs="Hashishin Tayt +2"}):when():buff("Efflux")

local blue_magic_set = gearset({
    ammo="Mavi Tathlum",
    head="Hashishin Kavuk +2",
    body="Assim. Jubbah +3",
})
    :and_combine(sird_set)
    :and_combine(diffusion)
    :and_combine(efflux)

snugs:midcast("Blue Magic", blue_magic_set)
```

`"Blue Magic"` here is the spell's *skill*, so this covers every blue magic spell without a more
specific set. The same works for `"Elemental Magic"`, `"Enhancing Magic"`, `"Geomancy"`, and so on.

## Refresh gear only when MP is low

```lua
local idle_refresh = gearset({
    left_ring="Stikini Ring +1",
    right_ring="Stikini Ring +1",
    legs="Assid. Pants +1",
}):when():mpp_less_than(80):and_combine(gearset({
    waist="Fucho-no-Obi",
}):when():mpp_less_than(50))

snugs:default_idle(gearset({
    head="Nyame Helm",
    body="Jhakri Robe +2",
    neck="Loricate Torque +1",
}):and_combine(idle_refresh))
```

Two thresholds, two overlays — under 50% MP you get both. The comparison predicates come in named
form (`mpp_less_than`, `hpp_greater_than_or_equal_to`, `tp_equal_to`, …) and operator form:

```lua
gearset({body="Hizamaru Haramaki +2"}):when():hpp("<", 90)
gearset({body="Jhakri Robe +2"}):when():mpp("<", 80)
```

## Buff-conditional gear

```lua
local impetus_set = gearset({body="Bhikku Cyclas +2"}):when():buff("Impetus")

snugs:default_engaged(gearset(engaged_set):and_combine(impetus_set))
snugs:weaponskill("Victory Smite", gearset(vs_set):and_combine(impetus_set))
```

Buff names are matched against `buffactive`, so multi-word buffs work as written:

```lua
gearset({
    body="Peda. Gown +3",
    waist="Embla Sash",
}):when():buff("Sublimation: Activated")
```

## Different gear for self-targeted spells

Enhancing magic usually wants duration gear on yourself and potency gear on everyone else.
`target_self` splits the two without separate spell registrations.

```lua
local self_enhancing  = gearset({
    head="Telchine Cap",
    legs={name="Telchine Braconi", augments={'Enh. Mag. eff. dur. +10',}},
    waist="Embla Sash",
}):when():target_self(true)

local party_enhancing = gearset({
    head="Leth. Chappel +2",
    body="Lethargy Sayon +2",
    feet="Leth. Houseaux +2",
}):when():target_self(false)

snugs:midcast("Enhancing Magic", gearset({})
    :and_combine(party_enhancing)
    :and_combine(self_enhancing))
```

It compares the spell target's id against your own, so it is accurate for spells you cast on
yourself by name as well as with `<me>`.

## Pet-aware idle and engaged sets

`has_pet` plus `otherwise` gives you a clean two-branch set: pet gear when a pet is out,
something else when it is not.

```lua
snugs:idle(gearset_from_mode("style", {
    dd     = dt_set,
    petdt  = gearset(pet_dt_set):when():has_pet(true):otherwise(base_set),
    petdmg = gearset(pet_dmg_set):when():has_pet(true):otherwise(base_set),
}))
```

Or as a plain overlay on a shared base:

```lua
local pet_idle = gearset({
    head="Azimuth Hood +2",
    body="Azimuth Coat +2",
    back={name="Nantosuelta's Cape", augments={'Pet: "Regen"+10',}},
}):when():has_pet(true)

snugs:default_idle(gearset(base_idle):and_combine(pet_idle))
```

For BST ready moves and other pet actions, overlay on the *idle* set — pet moves fire while you are
not casting anything yourself:

```lua
snugs:idle(gearset(idle_set)
    :and_combine(gearset(physical_ready_move):when():spell_type("Monster")))
```

## Elemental obi on day, weather, or storm

Build the obi overlay once per element and hang it off the relevant midcast set.

```lua
local obi = {waist="Hachirin-no-Obi"}

local fire_obi  = gearset(obi):when():weather("Fire"):or_instead(when():day("Fire")):or_instead(when():buff("Firestorm"))
local ice_obi   = gearset(obi):when():weather("Ice"):or_instead(when():day("Ice")):or_instead(when():buff("Hailstorm"))
local light_obi = gearset(obi):when():weather("Light"):or_instead(when():day("Light")):or_instead(when():buff("Aurorastorm"))

snugs:midcast("Elemental Magic", gearset(nuke_set)
    :and_combine(fire_obi)
    :and_combine(ice_obi))

snugs:midcast_all(cure_spells, gearset(cure_set):and_combine(light_obi))
```

Only the matching element's overlay evaluates to anything, so stacking all six is harmless.

## Fast cast layers

Fast cast has its own tier that runs when no specific precast set matched. Register a default plus
per-skill or per-spell refinements.

```lua
local fc_set = gearset({
    head="Carmine Mask +1",
    body="Pinga Tunic +1",
    waist="Witful Belt",
    left_ring="Kishar Ring",
})

snugs:default_fastcast(fc_set)

-- extra fast cast for one skill
snugs:fastcast("Elemental Magic", gearset(fc_set):and_combine({hands="Bagua Mitaines +3"}))

-- and for a specific spell
snugs:fastcast("Cure IV", gearset(fc_set):and_combine({legs="Doyen Pants"}))
```

For a whole list of spells, use `fastcast_all`:

```lua
local cure_spells = {"Cure", "Cure II", "Cure III", "Cure IV"}
snugs:fastcast_all(cure_spells, gearset(fc_set):and_combine({legs="Doyen Pants"}))
```

## Preshot and midshot for ranged jobs

Ranged attacks are not magic, so they never reach the fast cast tier. Put preshot in
`default_precast` (which always runs) and gate it on `action_type`.

```lua
local preshot = gearset({
    head="Arcadian Beret +3",
    hands="Carmine Fin. Ga. +1",
    legs="Orion Braccae +4",
}):when():action_type("Ranged Attack")

local midshot = gearset({
    head="Arcadian Beret +3",
    body="Ikenga's Vest",
    hands="Ikenga's Gloves",
}):when():action_type("Ranged Attack")

snugs:default_precast(gearset({}):and_combine(preshot))
snugs:default_midcast(gearset({}):and_combine(midshot))
```

COR stacks quick draw and rolls on the same midcast tier:

```lua
snugs:default_midcast(gearset({})
    :and_combine(gearset(midshot_set)
        :when():action_type("Ranged Attack")
        :or_instead(when():action_type("CorsairShot")))
    :and_combine(gearset({head="Ikenga's Hat"})
        :when():action_type("CorsairShot"))
    :and_combine(gearset({main="Rostam", head="Lanun Tricorne +3"})
        :when():action_type("CorsairRoll")
        :or_instead(when():spell_name("Double-Up"))))
```

Guarding your weapon-skill ammo from ordinary shots is the same idea in reverse:

```lua
local ws_ammo_spells = {"Trueflight", "Empyreal Arrow", "Last Stand", "Namas Arrow"}

local keep_ws_ammo = gearset({ammo="Eminent Arrow"})
    :when():action_type("Ranged Attack")
    :or_instead(when():spell_name_any(ws_ammo_spells))

snugs:default_precast(gearset({}):and_combine(preshot):and_combine(keep_ws_ammo))
```

## One set for a whole group of spells

`midcast_all`, `precast_all`, `premidcast_all`, and `weaponskill_all` take a list of keys and
register the same set for each. Naming the list makes the intent obvious.

```lua
local cure_spells   = {"Cure", "Cure II", "Cure III", "Cure IV", "Cure V", "Cure VI"}
local march_spells  = {"Honor March", "Victory March", "Advancing March"}
local barspells     = {"Barfira", "Barblizzara", "Baraera", "Barstonra"}
local enmity_spells = {"Provoke", "Flash", "Sentinel", "Rampart", "Cover", "Palisade"}

snugs:midcast_all(cure_spells,   cure_set)
snugs:midcast_all(march_spells,  set_combine(song_set, {hands="Fili Manchettes +2"}))
snugs:midcast_all(barspells,     barspell_set)
snugs:midcast_all(enmity_spells, enmity_set)
```

`premidcast_all` registers the same set on both precast and midcast — handy for abilities that need
the gear on both sides:

```lua
snugs:premidcast_all({"Call Beast", "Bestial Loyalty"}, gearset({
    feet="Gleti's Boots",
    hands="Ankusa Gloves +3",
}))
```

## Big spell-to-category tables

For jobs with hundreds of spells (BLU especially), keep a category table and flatten it into lists
once, then register per category. This keeps the "which spell is which" data separate from the gear.

```lua
local blue_magic_maps = {}

blue_magic_maps.physical_str = {
    ['Vertical Cleave'] = true,
    ['Quadrastrike']    = true,
    ['Sinker Drill']    = true,
}

blue_magic_maps.magical = {
    ['Subduction']    = true,
    ['Leafstorm']     = true,
    ['Anvil Lightning'] = true,
}

-- flatten the lookup tables into ordered lists for midcast_all
local blue_spell_lists = {}
for category, spells in pairs(blue_magic_maps) do
    local list = {}
    blue_spell_lists[category] = list
    for spell in pairs(spells) do
        table.insert(list, spell)
    end
end

snugs:midcast_all(blue_spell_lists.physical_str, physical_set)
snugs:midcast_all(blue_spell_lists.magical,      magical_set)
```

Editing a set-membership table is much less error-prone than editing a long inline list, and you can
comment individual entries with the reason they are categorised the way they are.

## Weapon skills

Weapon skills resolve against the weapon skill sets only — a `midcast` registration for a WS name is
never consulted. Always register them with `weaponskill`.

```lua
snugs:default_weaponskill(base_ws_set)

snugs:weaponskill("Savage Blade", gearset(base_ws_set):and_combine({
    neck="Anu Torque",
    waist="Sailfi Belt +1",
    right_ring="Gere Ring",
}))

snugs:weaponskill_all({"Mistral Axe", "Decimation"}, gearset(base_ws_set):and_combine({
    waist="Saifi Belt +1",
    right_ring="Sroda Ring",
}))
```

Magical weapon skills take the same conditional overlays as spells:

```lua
snugs:weaponskill("Leaden Salute", gearset(magic_ws_set):and_combine(
    gearset({waist="Hachirin-no-Obi"})
        :when():weather("Darkness")
        :or_instead(when():day("Darkness"))
        :or_instead(when():buff("Voidstorm"))))
```

## Utility sets you trigger by hand

`snugs:util(name, set)` registers a set you equip on demand with `gs c util <name>`. `warp`,
`nexus`, and `speed` also have dedicated shorthand commands.

```lua
snugs:util("speed",  {feet="Herald's Gaiters"})      -- gs c speed  (or gs c util speed)
snugs:util("warp",   {left_ring="Warp Ring"})        -- gs c warp
snugs:util("nexus",  {back="Nexus Cape"})            -- gs c nexus

-- max blue magic skill for spell learning
snugs:util("learning", gearset(max_blue_skill_set):and_combine({
    hands="Assim. Bazu. +3",
}))                                                   -- gs c util learning
```

SMN players often park their blood pact sets here too, so they can force a set before a pact:

```lua
snugs:util("magicalbp",  bp_rage_magic_set)
snugs:util("physicalbp", bp_rage_set)
snugs:util("hybridbp",   flaming_crush_set)
```

## Jug pets and other ammo-driven modes

A mode's `gearset_mappings` maps each value to a set directly — no `cycle_values` needed, they are
derived from the mapping keys. `gearset_from_mode(name)` with no table pulls the mode's own mapping.

```lua
snugs:add_mode("jug", {
    initial_value = "sheep",
    description   = "Current Jug Pet",
    gearset_mappings = {
        crab     = {ammo="Ferm. Broth"},
        sheep    = {ammo="Lyrical Broth"},
        diremite = {ammo="Crackling Broth"},
        tiger    = {ammo="Meaty Broth"},
    },
})

snugs:premidcast_all({"Call Beast", "Bestial Loyalty"}, gearset({
    feet="Gleti's Boots",
    hands="Ankusa Gloves +3",
}):and_combine(gearset_from_mode("jug")))
```

`gs c set jug tiger` now changes which broth you call with.

## Instrument swapping for BRD

Same shape as jug pets, applied to the `range` slot, plus fixed instruments you can pin to specific
songs.

```lua
local instrument_dummy  = {range="Daurdabla"}
local instrument_aeonic = {range="Marsyas"}
local instrument_relic  = {range="Gjallarhorn"}

snugs:add_mode("instrument", {
    initial_value = "relic",
    description   = "Instrument",
    gearset_mappings = {
        relic  = instrument_relic,
        aeonic = instrument_aeonic,
        dummy  = instrument_dummy,
    },
})

local active_instrument = gearset_from_mode("instrument")
local song_precast      = gearset(song_set):and_combine(active_instrument)

snugs:default_precast(gearset({}):and_combine(
    gearset(song_precast):when():spell_type("BardSong")))

-- dummy songs always want the extra-slot instrument
snugs:midcast_all({"Scop's Operetta", "Goblin's Gavotte"},
    gearset(song_precast):and_combine(instrument_dummy))

-- and Honor March always wants the aeonic
snugs:precast("Honor March", gearset(song_precast):and_combine(instrument_aeonic))
```

Songs are not magic as far as the precast tier is concerned, so song gear belongs in
`default_precast`, not `default_fastcast`.

## Engaged-only spell interruption gear

Interruption resistance matters when you are being hit, and costs you elsewhere. Gate it on status.

```lua
local sird_set = gearset({
    head="Souv. Schaller +1",
    ammo="Staunch Tathlum +1",
    neck="Moonlight Necklace",
    legs="Founder's Hose",
}):when():status("Engaged")

snugs:midcast("Divine Magic",    gearset(divine_set):and_combine(sird_set))
snugs:midcast("Enhancing Magic", gearset(enhancing_set):and_combine(sird_set))
snugs:midcast_all(cure_spells,   gearset(cure_set):and_combine(sird_set))
```

The reverse — gear you only want while idle — is `:when():status("Idle")`:

```lua
snugs:midcast_all({"Enlight", "Enlight II"}, gearset(divine_set)
    :and_combine(gearset({main="Brilliance"}):when():status("Idle")))
```

## Picking exactly one set from a list

`and_combine` merges everything that qualifies. When you want *one* winner instead, use
`choose_from` with `use(set, condition)` and optional priorities. The highest-priority selector whose
condition passes and whose set is non-empty wins.

```lua
snugs:midcast("Elemental Magic", choose_from(
    use(burst_set,     when():mode_is("MagicBurstMode", "Single")):priority(20),
    use(immanence_set, when():buff("Immanence")):priority(10),
    use(nuke_set)))
```

`choose_all` is the merging counterpart when you want every matching selector combined instead.

## Adding your own predicate

`extend_predicate` registers a new condition usable anywhere `when()` is. The factory receives the
arguments from the call site and returns a `function(ctx) -> boolean`. Every built-in predicate is
registered exactly this way, so anything they can do, yours can too.

The elemental obi check above is a good candidate — it is the same three-way test repeated per
element, so collapse it into one predicate:

```lua
local storms = {
    Fire = "Firestorm", Ice = "Hailstorm", Wind = "Windstorm", Earth = "Sandstorm",
    Lightning = "Thunderstorm", Water = "Rainstorm", Light = "Aurorastorm", Dark = "Voidstorm",
}

snugs:extend_predicate("element_active", function(element)
    if not element then
        return function() return false end
    end

    local storm = storms[element]
    return function()
        return world.weather_element == element
            or world.day_element == element
            or (storm and buffactive[storm]) and true or false
    end
end)

local obi = {waist="Hachirin-no-Obi"}

snugs:midcast("Elemental Magic", gearset(nuke_set)
    :and_combine(gearset(obi):when():element_active("Fire"))
    :and_combine(gearset(obi):when():element_active("Ice")))
```

For one-off conditions that do not deserve a name, `where` takes a raw function:

```lua
gearset({neck="Warder's Charm +1"}):when():where(function(ctx)
    return ctx.spell and ctx.spell.element == "Dark"
end)
```

## Spell family keys

SnugSwap adds an `All<BaseName>` lookup key to every action, with any tier suffix stripped. One
registration therefore covers a whole spell family — no lists to maintain as new tiers unlock.

```lua
-- covers Cure, Cure II ... Cure VI
snugs:midcast("AllCure", cure_set)

-- covers Curaga through Curaga V
snugs:midcast("AllCuraga", gearset(cure_set):and_combine({body="Theo. Bliaut +3"}))

-- Ninjutsu strips ": Ichi/Ni/San" instead, so this covers all three Utsusemi
snugs:midcast("AllUtsusemi", {feet="Ninja Feet"})
```

Spells with no tier suffix get the key too, so `AllCure` really does include plain `Cure`. Spells
whose names simply do not end in a tier get a harmless key of their own (`Magic Fruit` becomes
`AllMagic Fruit`).

Family keys sit between the spell's own name and its type and skill in the resolution order, so they
layer the way you would expect — register all three and each spell takes the most specific match:

```lua
snugs:midcast("Healing Magic", healing_set)   -- every healing spell
snugs:midcast("AllCure",       cure_set)      -- ...except cures
snugs:midcast("Cure VI",       cure_vi_set)   -- ...except Cure VI specifically
```

If you would rather layer than replace, a `key` predicate combines the family gear onto the skill
set instead of overriding it:

```lua
snugs:midcast("Healing Magic", gearset(healing_set):and_combine(
    gearset(cure_set):when():key("AllCure")))
```

## Custom lookup keys with middleware

Middleware runs before set resolution and can add lookup keys of your own, for groupings the
built-in families do not cover.

```lua
-- one key for every spell that shares an element
snugs:register_middleware("any", function(ctx)
    if ctx.spell and ctx.spell.element then
        ctx:add_lookup("Element:" .. ctx.spell.element)
    end
end, { name = "element_keys", priority = 10 })

snugs:midcast("Element:Dark", gearset(nuke_set):and_combine({right_ring="Archon Ring"}))
```

Keys you add this way rank alongside the built-in family keys — above the spell's type and skill,
below its exact name — so `Element:Dark` beats a plain `midcast("Elemental Magic", ...)`.

Keys can also be tested directly with the `key` predicate:

```lua
snugs:default_fastcast(gearset(fc_set):and_combine(
    gearset({
        head="Kaykaus Mitra +1",
        feet="Kaykaus Boots +1",
    }):when():key("AllCuraga")))
```

`any_key` is the list form — it matches if *any* of the given keys is in the context. Since spell
names, types, and skills are all lookup keys, it doubles as a compact "one of these spells" test:

```lua
local na_spells = {"Poisona", "Paralyna", "Blindna", "Silena", "Stona", "Viruna", "Cursna"}

snugs:midcast("Healing Magic", gearset(healing_set):and_combine(
    gearset({hands="Fanatic Gloves"}):when():any_key(na_spells)))
```

Lookup keys are checked in order, so `prepend_lookup` inside middleware lets a category key win over
the spell's own name:

```lua
snugs:register_middleware("midcast", function(ctx)
    if ctx.spell and ctx.spell.english:find("^Utsusemi") then
        ctx:prepend_lookup("ShadowNinjutsu")
    end
end, { name = "shadows_first" })

snugs:midcast("ShadowNinjutsu", shadow_set)   -- beats a midcast("Utsusemi: Ni", ...) registration
```

Only the spell's own name is in the list when middleware runs; the type and skill keys are appended
afterwards. Prepending a key that would otherwise land at the bottom therefore promotes it all the
way to the top — `prepend_lookup("Ninjutsu")` makes the type key outrank every individual spell
name, since `add_lookup` skips keys that are already present.

## Wiring hooks by hand

`snugs:wire_all()` installs every GearSwap hook that you have not already defined yourself. If you
want explicit control — or need to run your own code alongside SnugSwap — declare them directly:

```lua
function precast(spell)        snugs:do_precast(spell)        end
function midcast(spell)        snugs:do_midcast(spell)        end
function aftercast(spell)      snugs:do_aftercast(spell)      end
function status_change(new, old) snugs:do_status_change(new, old) end
function self_command(command) snugs:do_self_command(command) end
function pet_change(pet, gain) snugs:do_pet_change(pet, gain) end
function pet_midcast(spell)    snugs:do_pet_midcast(spell)    end
function pet_aftercast(spell)  snugs:do_pet_aftercast(spell)  end
```

Mixing works too — define the one hook you want to own, then call `snugs:wire_all()` for the rest:

```lua
function aftercast(spell)
    snugs:do_aftercast(spell)
    if my_auto_follow_up then check_party_hp() end
end

snugs:wire_all()   -- installs everything except aftercast
```

## In-game commands

| Command | Effect |
| --- | --- |
| `gs c toggle <mode>` | Advance a cycle mode to its next value, or flip a boolean mode |
| `gs c set <mode> <value>` | Set a mode to a specific value |
| `gs c list modes` | Print every mode, its value, description, and cycle values |
| `gs c cycle weapon` | Advance through the registered weapon sets |
| `gs c set weapon <name>` | Jump straight to a named weapon set |
| `gs c util <name>` | Equip a utility set registered with `snugs:util` |
| `gs c warp` / `gs c nexus` / `gs c speed` | Shorthand for the like-named utility sets |
| `gs c set debug true` | Turn on debug output |
| `gs c set trace true` | Log every middleware run and the final set for each equip |

`gs c set trace true` is the fastest way to answer "why did it equip *that*" — it prints the fully
resolved slot list on every swap.

## Gotchas

**Registrations resolve most-specific-first.** For any action, SnugSwap tries these keys in order
and equips the first one that has a set registered:

1. the exact spell or ability name — `"Cure IV"`
2. keys added by middleware — the `All<Base>` family key, plus anything you add yourself
3. the type — `"WhiteMagic"`, `"BardSong"`, `"WeaponSkill"`
4. the skill — `"Healing Magic"`, `"Blue Magic"`, `"Geomancy"`

Only one of them wins. To *combine* tiers rather than override, register the broad set and layer the
narrow gear onto it with a `key` predicate.

**Sets are write-once.** Registering the same key twice warns and keeps the first registration:

```lua
snugs:default_idle(a_set)
snugs:default_idle(b_set)   -- warns, b_set is ignored
```

Build the full set with `and_combine` instead of registering repeatedly.

**`and_combine` mutates the gearset it is called on.** Reusing a named gearset as a base will
accumulate overlays across all its users:

```lua
local lullaby = gearset(song_set)
snugs:midcast("Horde's Lullaby", lullaby:and_combine(instrument_dummy))
snugs:midcast("Foe Lullaby",     lullaby:and_combine(instrument_relic))
-- both now carry BOTH instruments; the relic wins everywhere
```

Wrap the base in a fresh `gearset(...)` each time you branch off it:

```lua
snugs:midcast("Horde's Lullaby", gearset(lullaby):and_combine(instrument_dummy))
snugs:midcast("Foe Lullaby",     gearset(lullaby):and_combine(instrument_relic))
```

**A matching precast set short-circuits fast cast.** If a spell has its own precast registration,
the fast cast tier is skipped entirely — fold your fast cast pieces into that set:

```lua
snugs:precast("Stun", gearset(fc_set):and_combine({neck="Stun Neck"}))
```

**Weapon skills never consult midcast sets.** `snugs:midcast("Victory Smite", ...)` is dead code;
use `snugs:weaponskill("Victory Smite", ...)`.

**Boolean modes want string cycle values.** A mode declared with `initial_value = false` comes up
`true`, so express on/off modes as `cycle_values = {"off", "on"}` and test them with
`mode_is("name", "on")`.
