-- Minimal stand-in for the globals Windower and GearSwap inject into a job lua.
--
-- snugswap.lua is a script, not a module: loading it creates the global `snugs`
-- instance, resets the `sets` table and registers the built-in middleware. So each
-- test gets a completely fresh library by rebuilding this environment and loading
-- snugswap.lua again.

local stub = {}

local SLOTS = {
    "main", "sub", "range", "ammo", "head", "body", "hands", "legs",
    "feet", "neck", "waist", "left_ear", "right_ear", "left_ring", "right_ring", "back",
}

stub.SLOTS = SLOTS

local function project_root()
    local this = debug.getinfo(1, "S").source:sub(2)
    return this:match("^(.*)/test/gearswap_stub%.lua$") or "."
end

stub.root = project_root()

-- Everything the stub captured since the last reset.
stub.equipped = {}
stub.chat = {}
stub.commands = {}

-- GearSwap's set_combine: right-hand slots win, neither input is modified.
local function set_combine(a, b)
    local out = {}
    for k, v in pairs(a or {}) do out[k] = v end
    for k, v in pairs(b or {}) do out[k] = v end
    return out
end

--- Rebuild the fake game environment and load a fresh copy of snugswap.lua.
-- @param opts table optional overrides: player, world, buffactive, pet
-- @return the freshly created global `snugs` instance
function stub.reset(opts)
    opts = opts or {}

    stub.equipped = {}
    stub.chat = {}
    stub.commands = {}

    _G.sets = {}

    _G.player = opts.player or {
        id = 1001,
        name = "Tester",
        status = "Idle",
        hpp = 100,
        mpp = 100,
        tp = 0,
        main_job = "WHM",
        sub_job = "RDM",
    }

    _G.world = opts.world or { weather_element = "None", day_element = "Fire" }
    _G.buffactive = opts.buffactive or {}
    _G.pet = opts.pet or { isvalid = false }

    _G.windower = {
        add_to_chat = function(_, msg) table.insert(stub.chat, msg) end,
        send_command = function(cmd) table.insert(stub.commands, cmd) end,
    }

    -- GearSwap accumulates across every equip() call within one event, rather
    -- than replacing what an earlier call in the same event asked for.
    _G.equip = function(set)
        for k, v in pairs(set or {}) do
            stub.equipped[k] = v
        end
    end

    _G.set_combine = set_combine

    -- Drop anything a previous load installed, so wire_all() sees a clean slate.
    for _, hook in ipairs({"precast", "midcast", "aftercast", "status_change",
                           "self_command", "pet_midcast", "pet_aftercast",
                           "pet_change", "get_sets"}) do
        _G[hook] = nil
    end

    local chunk = assert(loadfile(stub.root .. "/snugswap.lua"))
    chunk()

    return _G.snugs
end

--- Forget what is currently equipped without disturbing the library state.
-- Call between actions so each assertion sees only that action's swaps.
function stub.clear_equipped()
    stub.equipped = {}
end

--- Name of the item in a slot, whether it was given as a string or an item table.
function stub.slot(name)
    local item = stub.equipped[name]
    if item == nil then return nil end
    if type(item) == "table" then return item.name end
    return tostring(item)
end

--- The equipped set as a "slot=item, slot=item" string, in canonical slot order.
function stub.summary()
    local parts = {}
    for _, name in ipairs(SLOTS) do
        local item = stub.slot(name)
        if item then
            table.insert(parts, name .. "=" .. item)
        end
    end
    return table.concat(parts, ", ")
end

--- Build a spell table shaped like the one GearSwap passes to the hooks.
function stub.spell(fields)
    local sp = {
        english = "Cure",
        type = "WhiteMagic",
        skill = "Healing Magic",
        action_type = "Magic",
        element = "Light",
    }
    for k, v in pairs(fields or {}) do sp[k] = v end
    return sp
end

--- True if any captured chat line contains `needle`.
function stub.said(needle)
    for _, line in ipairs(stub.chat) do
        if line:find(needle, 1, true) then return true end
    end
    return false
end

return stub
