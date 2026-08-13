-- Loads a real GearSwap job lua outside the game and reports what happened.
--
-- Deliberately reuses test/gearswap_stub.lua rather than keeping a second copy
-- of the fake environment: if the stub ever drifts from what GearSwap actually
-- does, both the library tests and this harness are wrong together rather than
-- disagreeing silently.

local env = {}

-- Globals leaked by the previously loaded job lua, cleared before the next one.
env._leaked_last_load = {}

local function project_root()
    local this = debug.getinfo(1, "S").source:sub(2)
    return this:match("^(.*)/tools/jobcheck/env%.lua$") or "."
end

env.root = project_root()

local stub = dofile(env.root .. "/test/gearswap_stub.lua")
env.stub = stub

-- Globals a job lua may legitimately read without defining: provided by
-- GearSwap, by Windower, or by another addon the file includes.
local PROVIDED_GLOBALS = {
    windower = true, player = true, world = true, pet = true, alliance = true,
    party = true, buffactive = true, sets = true, equip = true, set_combine = true,
    send_command = true, include = true, require = true, res = true,
    organizer_items = true, gearswap = true,
}

-- Names a job lua is expected to define at the top level.
local EXPECTED_GLOBALS = {
    get_sets = true, precast = true, midcast = true, aftercast = true,
    status_change = true, self_command = true, pet_change = true,
    pet_midcast = true, pet_aftercast = true, sub_job_change = true,
    filtered_action = true, buff_change = true, job_setup = true, user_setup = true,
}

--- One representative action per spell type, so a job is driven through every
--- branch of the resolution ladder regardless of which job it is.
env.ACTIONS = {
    { label = "Cure IV",        english = "Cure IV",       type = "WhiteMagic",     skill = "Healing Magic",    action_type = "Magic",         element = "Light" },
    { label = "Curaga II",      english = "Curaga II",     type = "WhiteMagic",     skill = "Healing Magic",    action_type = "Magic",         element = "Light" },
    { label = "Haste",          english = "Haste",         type = "WhiteMagic",     skill = "Enhancing Magic",  action_type = "Magic" },
    { label = "Refresh II",     english = "Refresh II",    type = "WhiteMagic",     skill = "Enhancing Magic",  action_type = "Magic" },
    { label = "Slow II",        english = "Slow II",       type = "WhiteMagic",     skill = "Enfeebling Magic", action_type = "Magic" },
    { label = "Fire VI",        english = "Fire VI",       type = "BlackMagic",     skill = "Elemental Magic",  action_type = "Magic",         element = "Fire" },
    { label = "Drain III",      english = "Drain III",     type = "BlackMagic",     skill = "Dark Magic",       action_type = "Magic",         element = "Dark" },
    { label = "Stun",           english = "Stun",          type = "BlackMagic",     skill = "Dark Magic",       action_type = "Magic" },
    { label = "Katon: Ni",      english = "Katon: Ni",     type = "Ninjutsu",       skill = "Ninjutsu",         action_type = "Magic" },
    { label = "Utsusemi: Ni",   english = "Utsusemi: Ni",  type = "Ninjutsu",       skill = "Ninjutsu",         action_type = "Magic" },
    { label = "Valor Minuet",   english = "Valor Minuet",  type = "BardSong",       skill = "Singing",          action_type = "Magic" },
    { label = "Indi-Haste",     english = "Indi-Haste",    type = "Geomancy",       skill = "Geomancy",         action_type = "Magic" },
    { label = "Head Butt",      english = "Head Butt",     type = "BlueMagic",      skill = "Blue Magic",       action_type = "Magic" },
    { label = "Savage Blade",   english = "Savage Blade",  type = "WeaponSkill",    skill = "Sword",            action_type = "Ability" },
    { label = "Ranged",         english = "Ranged",        type = "WeaponSkill",    skill = "Archery",          action_type = "Ranged Attack" },
    { label = "Provoke",        english = "Provoke",       type = "JobAbility",                                 action_type = "Ability" },
    { label = "Chaos Roll",     english = "Chaos Roll",    type = "CorsairRoll",                                action_type = "Ability" },
    { label = "Fire Shot",      english = "Fire Shot",     type = "CorsairShot",                                action_type = "Ability" },
    { label = "Inferno",        english = "Inferno",       type = "BloodPactRage",  skill = "Summoning Magic",  action_type = "Ability" },
    { label = "Shining Ruby",   english = "Shining Ruby",  type = "BloodPactWard",  skill = "Summoning Magic",  action_type = "Ability" },
    { label = "Wing Slap",      english = "Wing Slap",     type = "Monster",                                    action_type = "Ability" },
}

--- Player and world states worth recording separately, because conditional
--- overlays in real job luas hang off exactly these.
env.SCENARIOS = {
    { name = "idle",    player = { status = "Idle" } },
    { name = "engaged", player = { status = "Engaged" } },
    { name = "low-mp",  player = { status = "Idle", mpp = 40 } },
    { name = "low-hp",  player = { status = "Idle", hpp = 40 } },
    { name = "pet-out", player = { status = "Idle" }, pet = { isvalid = true } },
}

--- Apply a scenario to the stubbed globals.
function env.apply(scenario)
    for k, v in pairs(scenario.player or {}) do _G.player[k] = v end
    for k, v in pairs(scenario.pet or {}) do _G.pet[k] = v end
    for k, v in pairs(scenario.world or {}) do _G.world[k] = v end
    for k, v in pairs(scenario.buffactive or {}) do _G.buffactive[k] = v end
end

--- Load a job lua and run its get_sets().
--
-- @param path  path to the job lua
-- @param opts  { common = "<path to a shared include such as dek.lua>" }
-- @return report table
function env.load(path, opts)
    opts = opts or {}

    local report = {
        path = path,
        name = path:match("([^/]+)$"),
        ok = true,
        errors = {},      -- fatal: could not load or run
        messages = {},    -- what snugswap printed during registration
        undefined = {},   -- globals read but never defined
        leaked = {},      -- globals written that were not expected hook names
    }

    local snugs = stub.reset()

    _G.include = function() end
    _G.require = function() end
    _G.send_command = function() end
    _G.alliance = {}
    _G.party = {}

    -- Load the shared common-sets include for real when one is available, so
    -- interactions with it (a job set being shadowed, say) are visible.
    if opts.common then
        local chunk = loadfile(opts.common)
        if chunk then
            local ok, err = pcall(chunk)
            if not ok then
                table.insert(report.errors, "could not run " .. opts.common .. ": " .. tostring(err))
            end
        end
    end
    if type(_G.dek_include_common_sets) ~= "function" then
        _G.dek_include_common_sets = function() end
    end

    -- Globals a previous load leaked would still be present, so __newindex
    -- would not fire for them a second time and the leak would go unreported.
    -- Clear them, then diff the whole global table around the load rather than
    -- relying on metatable events alone.
    for name in pairs(env._leaked_last_load) do rawset(_G, name, nil) end
    env._leaked_last_load = {}

    local before = {}
    for k in pairs(_G) do before[k] = true end

    local declared, read_missing = {}, {}
    setmetatable(_G, {
        __newindex = function(t, k, v) declared[k] = true; rawset(t, k, v) end,
        __index = function(t, k)
            if type(k) == "string" then read_missing[k] = (read_missing[k] or 0) + 1 end
            return nil
        end,
    })

    local function finish()
        setmetatable(_G, nil)
        for k in pairs(_G) do
            if not before[k] then declared[k] = true end
        end
        for k, n in pairs(read_missing) do
            if not declared[k] and not PROVIDED_GLOBALS[k] and not EXPECTED_GLOBALS[k] then
                table.insert(report.undefined, { name = k, count = n })
            end
        end
        for k in pairs(declared) do
            if type(k) == "string" and not EXPECTED_GLOBALS[k] and not PROVIDED_GLOBALS[k] then
                table.insert(report.leaked, k)
                env._leaked_last_load[k] = true
            end
        end
        table.sort(report.undefined, function(a, b) return a.name < b.name end)
        table.sort(report.leaked)
        for _, line in ipairs(stub.chat) do
            table.insert(report.messages, (line:gsub("^%[snugs%]: ", "")))
        end
        report.snugs = snugs
        return report
    end

    local chunk, load_err = loadfile(path)
    if not chunk then
        setmetatable(_G, nil)
        report.ok = false
        table.insert(report.errors, "syntax: " .. tostring(load_err))
        return report
    end

    local ok, err = pcall(chunk)
    if not ok then
        report.ok = false
        table.insert(report.errors, "while loading: " .. tostring(err))
        return finish()
    end

    if type(_G.get_sets) ~= "function" then
        report.ok = false
        table.insert(report.errors, "no get_sets() was defined")
        return finish()
    end

    local ok2, err2 = pcall(_G.get_sets)
    if not ok2 then
        report.ok = false
        table.insert(report.errors, "in get_sets(): " .. tostring(err2))
    end

    return finish()
end

--- Read a file, or nil if it is not there.
function env.read(path)
    local fh = io.open(path)
    if not fh then return nil end
    local body = fh:read("a")
    fh:close()
    return body
end

--- Every *.lua in a directory, sorted, excluding a shared include.
function env.job_files(dir, exclude)
    local files = {}
    local pipe = io.popen("ls " .. dir .. "/*.lua 2>/dev/null | sort")
    if not pipe then return files end
    for line in pipe:lines() do
        local name = line:match("([^/]+)$")
        if name ~= exclude then table.insert(files, line) end
    end
    pipe:close()
    return files
end

return env
