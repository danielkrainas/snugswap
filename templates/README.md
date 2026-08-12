# Templates

Starting points for a new job lua. Every set is left empty — copy the file, fill in your gear, and
delete anything you do not use.

```
templates/
  archetypes/     three broad playstyles, if your job is not listed below
  jobs/           one per job, with the sections that job actually needs
```

## How to use one

1. Copy the file into `Windower/addons/GearSwap/data/` and rename it to match your character and
   job, for example `Mycharacter_WHM.lua`.
2. Put [`snugswap.lua`](../snugswap.lua) in `Windower/addons/GearSwap/libs/`.
3. Fill in the empty `{}` sets with your gear.

Every template ends with `snugs:wire_all()`, which hooks SnugSwap into GearSwap for you. You do not
need to write `precast`, `midcast`, or any of the other GearSwap functions yourself.

## What the sets mean

| Section | When it is worn |
| --- | --- |
| **weapon set** | Your weapons. Re-equipped after every action, so casting cannot strand you barehanded. |
| **idle** | Standing around, not fighting. |
| **engaged** | Fighting with your weapon out. |
| **fast cast** | The moment a spell starts casting — reduces cast time. |
| **precast** | The moment an ability starts. Weapon skills and job abilities use this. |
| **midcast** | While the spell is going off — this is where potency and duration gear goes. |
| **weapon skill** | The instant a weapon skill fires. |
| **utility** | Equipped by hand with `gs c util <name>`, for things like warp rings. |

An empty `{}` is always safe. SnugSwap skips a set with nothing in it, so a half-finished template
still works in game.

## Common commands

```text
//gs c list modes            show every mode and its current value
//gs c toggle style          switch to the next playstyle
//gs c set style tank        jump straight to one
//gs c cycle weapon          rotate through your weapon sets
//gs c set weapon proc       jump straight to one
//gs c util warp             equip a utility set
//gs c set trace true        print exactly what is being equipped, and why
```

`gs c set trace true` is the one to reach for when a swap surprises you.

## Filling in gear

Slot names are `main`, `sub`, `range`, `ammo`, `head`, `body`, `hands`, `legs`, `feet`, `neck`,
`waist`, `left_ear`, `right_ear`, `left_ring`, `right_ring`, `back`.

```lua
snugs:default_idle({
    head = "Nyame Helm",
    body = "Nyame Mail",
    back = { name = "Rosmerta's Cape", augments = {'HP+60','Damage taken-5%'} },
})
```

Fuller examples of conditions, modes and layering live in [docs/RECIPES.md](../docs/RECIPES.md).
