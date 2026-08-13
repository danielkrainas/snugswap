-- Structural checks that need no knowledge of what a job lua is trying to do.
--
-- Every check here corresponds to a bug found in a real job lua. None of them
-- ask whether the gear is any good; they ask whether the file does what it
-- appears to say it does.

local lint = {}

-- Weapon skills resolve against the weaponskill tier and return before midcast
-- is consulted, so a midcast registration under one of these names is dead.
local WEAPON_SKILLS = {}
for name in ([[
Savage Blade|Requiescat|Chant du Cygne|Evisceration|Rudra's Storm|Aeolian Edge|Mandalic Stab
Victory Smite|Ascetic's Fury|Dragon Kick|Shijin Spiral|Howling Fist|Raging Fists|Spinning Attack
Decimation|Mistral Axe|Bora Axe|Ruinator|Cloudsplitter|Steel Cyclone|Upheaval|Fell Cleave
Resolution|Torcleaver|Dimidiation|Last Stand|Coronach|Trueflight|Empyreal Arrow|Namas Arrow
Jishnu's Radiance|Wildfire|Leaden Salute|Hot Shot|Black Halo|Realmrazer|Judgment|Atonement
Insurgency|Entropy|Cross Reaper|Quietus|Blade: Shun|Blade: Hi|Blade: Ten|Tachi: Fudo|Tachi: Shoha
Impulse Drive|Stardiver|Camlann's Torment|Drakesbane|Geirskogul|Exenterator|Pyrrhic Kleos
Sanguine Blade|Seraph Blade|Vidohunir|Omniscience|Tetra Slash|Expiacion|Ground Strike
Rampage|Retribution|Full Break|King's Justice|Primal Rend|Ukko's Fury|Armor Break|Myrkr
]]):gmatch("[^|\n]+") do
    name = name:match("^%s*(.-)%s*$")
    if name ~= "" then WEAPON_SKILLS[name] = true end
end

local function finding(out, level, message, detail)
    table.insert(out, { level = level, message = message, detail = detail })
end

-- ------------------------------------------------------------- source checks

local function check_source(src, out)
    -- A condition chained after and_combine's closing paren attaches to the
    -- outer set, gating the whole thing instead of just the overlay.
    for line in src:gmatch("[^\r\n]+") do
        if line:find("})):when()", 1, true) then
            finding(out, "WARN",
                "condition chained after and_combine() closes -- it gates the whole set, not the overlay",
                (line:gsub("^%s+", "")))
        end
    end

    -- Corsair rolls and shots arrive as spell.type; action_type is "Ability".
    for kind in src:gmatch('action_type%("(Corsair%w+)"%)') do
        finding(out, "WARN",
            ('action_type("%s") never matches -- use spell_type("%s")'):format(kind, kind))
    end

    -- Middleware runs before any set is evaluated, so a once-only transition on
    -- "any" clears the mode during the action that was meant to consume it.
    if src:find('register_middleware%("any",%s*create_once_mode_transition') then
        finding(out, "WARN",
            'create_once_mode_transition on the "any" phase clears the mode before the sets are read -- use "aftercast"')
    end

    -- GearSwap provides include(); require() goes through Lua's package path.
    if src:find('require%(["\']snugswap["\']%)') then
        finding(out, "INFO", "uses require() where GearSwap provides include()")
    end

    -- A duplicate key in a table constructor silently discards the earlier one.
    local slot = "main|sub|range|ammo|head|body|hands|legs|feet|neck|waist|left_ear|right_ear|left_ring|right_ring|back"
    local depth, seen, line_no = 0, {}, 0
    for line in src:gmatch("[^\r\n]+") do
        line_no = line_no + 1
        local key = line:match("^%s*(%a[%w_]*)%s*=")
        if key and ("|" .. slot .. "|"):find("|" .. key .. "|", 1, true) then
            if seen[key] then
                finding(out, "WARN",
                    ("slot %q is set twice in the same set -- the first is discarded"):format(key),
                    "line " .. line_no)
            end
            seen[key] = true
        end
        local opens = select(2, line:gsub("{", ""))
        local closes = select(2, line:gsub("}", ""))
        if closes > opens then seen = {} end
        depth = depth + opens - closes
    end

    -- Locals that look like gear but are never referenced again.
    for name in src:gmatch("local%s+([%w_]+)%s*=%s*gearset") do
        local n = select(2, src:gsub("[^%w_]" .. name .. "[^%w_]", ""))
        if n <= 1 then finding(out, "INFO", ("local %q is built but never used"):format(name)) end
    end
    for name in src:gmatch("local%s+([%w_]+)%s*=%s*set_combine") do
        local n = select(2, src:gsub("[^%w_]" .. name .. "[^%w_]", ""))
        if n <= 1 then finding(out, "INFO", ("local %q is built but never used"):format(name)) end
    end

    -- Registering a weapon skill name in the midcast tier never fires.
    for call, key in src:gmatch('snugs:(%a+)%("([^"]*)"') do
        if (call == "midcast" or call == "precast" or call == "premidcast") and WEAPON_SKILLS[key] then
            finding(out, "WARN",
                ("snugs:%s(%q) never fires -- weapon skills resolve against the weaponskill tier"):format(call, key))
        end
    end
    for call, key in src:gmatch("snugs:(%a+)%('([^']*)'") do
        if (call == "midcast" or call == "precast" or call == "premidcast") and WEAPON_SKILLS[key] then
            finding(out, "WARN",
                ("snugs:%s(%q) never fires -- weapon skills resolve against the weaponskill tier"):format(call, key))
        end
    end
end

-- ------------------------------------------------------------ runtime checks

local function check_runtime(env, report, out)
    for _, e in ipairs(report.errors) do
        finding(out, "ERROR", e)
    end
    if not report.ok then return end

    for _, m in ipairs(report.messages) do
        finding(out, m:find("error:", 1, true) and "ERROR" or "WARN", m)
    end

    for _, u in ipairs(report.undefined) do
        finding(out, "WARN",
            ("%q is read but never defined -- it evaluates to nil"):format(u.name))
    end

    for _, g in ipairs(report.leaked) do
        finding(out, "INFO", ("%q is a global; it is probably missing a `local`"):format(g))
    end

    local snugs = report.snugs

    -- Drive every action through every phase, then every mode through all of
    -- its values, catching anything that errors only in a particular state.
    local function drive(where)
        for _, action in ipairs(env.ACTIONS) do
            for _, hook in ipairs({ "do_precast", "do_midcast", "do_aftercast", "do_pet_midcast" }) do
                local ok, err = pcall(snugs[hook], snugs, action)
                if not ok then
                    finding(out, "ERROR", ("%s(%s) errors%s: %s"):format(hook, action.label, where, tostring(err)))
                end
            end
        end
        for _, status in ipairs({ "Idle", "Engaged", "Resting" }) do
            _G.player.status = status
            local ok, err = pcall(snugs.do_status_change, snugs, status, "Idle")
            if not ok then
                finding(out, "ERROR", ("status_change(%s) errors%s: %s"):format(status, where, tostring(err)))
            end
        end
        _G.player.status = "Idle"
    end

    drive("")

    local mode_keys = {}
    for key in pairs(_G.sets.modes or {}) do table.insert(mode_keys, key) end
    table.sort(mode_keys)
    for _, key in ipairs(mode_keys) do
        local mode = _G.sets.modes[key]
        local values = mode.cycle_values or {}
        for _, value in ipairs(values) do
            mode.v = value
            drive((" with %s=%s"):format(key, tostring(value)))
        end
        mode.v = values[1] or mode.v
    end

    for _, cmd in ipairs({ "cycle weapon", "list modes" }) do
        local ok, err = pcall(snugs.do_self_command, snugs, cmd)
        if not ok then finding(out, "ERROR", ("gs c %s errors: %s"):format(cmd, tostring(err))) end
    end

    -- A registration that resolves to nothing is usually an unfinished set. But
    -- a file where *every* set is empty is a template rather than a file with a
    -- hundred bugs, so say that once instead of repeating it per registration.
    local empty, total = {}, 0
    for _, tier in ipairs({ "idle", "engaged", "weaponskill", "midcast", "precast", "fastcast" }) do
        local keys = {}
        for key in pairs(_G.sets[tier] or {}) do table.insert(keys, key) end
        table.sort(keys)
        for _, key in ipairs(keys) do
            local set = _G.sets[tier][key]
            local ctx = snugs:_new_context("midcast", {})
            local ok, resolved = pcall(function()
                local s = get_set_from_path(set)
                if is_gearset(s) then s = s:eval(ctx) end
                return s
            end)
            if ok and type(resolved) == "table" then
                total = total + 1
                if next(resolved) == nil then
                    table.insert(empty, ("%s %q"):format(tier, key))
                end
            end
        end
    end

    if total > 0 and #empty == total then
        finding(out, "INFO",
            ("all %d registered sets are empty -- this looks like an unfilled template"):format(total))
    else
        for _, e in ipairs(empty) do
            finding(out, "INFO", ("%s set evaluates to nothing"):format(e))
        end
    end

    for _, hook in ipairs({ "precast", "midcast", "aftercast", "status_change",
                            "self_command", "pet_change", "pet_midcast", "pet_aftercast" }) do
        if type(_G[hook]) ~= "function" then
            finding(out, "WARN", ("the %s hook was never installed -- is snugs:wire_all() missing?"):format(hook))
        end
    end
end

--- Lint one job lua. Returns a list of findings.
function lint.run(env, path, opts)
    local out = {}
    local src = env.read(path)
    if src then check_source(src, out) end
    local report = env.load(path, opts)
    check_runtime(env, report, out)
    return out, report
end

return lint
