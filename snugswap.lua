local DEFAULT_SET_NAME = '$default'

local _trace = false
local _debug = false
local _warnings = {}

local function snugs_error(...)
    local msgs = {...}
    local full_msg = table.concat(msgs, "")
    windower.add_to_chat(123, "[snugs]: error: " .. full_msg)
end

local function snugs_warn(key, ...)
    if _trace or not _warnings[key] then
        local msgs = {...}
        local full_msg = table.concat(msgs, "")
        windower.add_to_chat(123, "[snugs]: warning: " .. full_msg)
        _warnings[key] = true
    end    
end

local function snugs_trace(...)
    if not _trace then return end
    local msgs = {...}
    local full_msg = table.concat(msgs, "")
    windower.add_to_chat(8, "[snugs]: trace: " .. full_msg)
end

local function snugs_log(...)
    local msgs = {...}
    local full_msg = table.concat(msgs, "")
    windower.add_to_chat(123, "[snugs]: " .. full_msg)
end

local function snugs_debug(...)
    if not _debug then return end
    local msgs = {...}
    local full_msg = table.concat(msgs, "")
    windower.add_to_chat(123, "[snugs]: debug: " .. full_msg)
end


local PREDICATE_EXTENSIONS = {}

local function extend_predicate(name, factory, opts)
    opts = opts or {}

    if Predicate[name] then
        snugs_error("'" .. name .. "' is a reserved predicate method name and cannot be used as a predicate name.")
        return
    end

    local existing = PREDICATE_EXTENSIONS[name]
    if existing and opts.wrap then
        local old_factory = existing.factory
        PREDICATE_EXTENSIONS[name] = {
            factory = factory(old_factory),
            opts    = opts,
        }
        return
    end

    if existing and opts.override and _debug then
        snugs_warn("predicate." .. name .. ".overridden", "Predicate '" .. name .. "' overridden by new registration.")
    end

    PREDICATE_EXTENSIONS[name] = { factory = factory, opts = opts }
end

local function get_predicate_extension_factory(name)
    local entry = PREDICATE_EXTENSIONS[name]
    return entry and entry.factory or nil
end

SnugContext = {}
SnugContext.__index = SnugContext

function SnugContext:new(phase, fields)
    local x = fields or {}
    x.meta = x.meta or {}
    x.phase = phase
    x.lookups = x.lookups or {}
    x.lookup_set = x.lookup_set or {}

    return setmetatable(x, SnugContext)
end

function SnugContext:resolve_set_from_keys(sets)
    for _, key in ipairs(self.lookups) do
        if sets[key] then
            return sets[key]
        end
    end

    return nil
end

function SnugContext:prepend_lookup(key)
    if not key then
        snugs_warn("prepend_lookup_nil_key", "Attempted to prepend a nil key to lookups.")
        return
    elseif self.lookup_set[key] then
        return
    end

    table.insert(self.lookups, 1, key)
    self.lookup_set[key] = true
end

function SnugContext:add_lookup(key)
    if not key then
        snugs_warn("add_lookup_nil_key", "Attempted to add a nil key to lookups.")
        return
    elseif self.lookup_set[key] then
        return
    end

    table.insert(self.lookups, key)
    self.lookup_set[key] = true
end

function SnugContext:has_lookup(key)
    return self.lookup_set[key] == true
end

function SnugContext:set_meta(key, value)
    self.meta[key] = value
end

function SnugContext:get_meta(key)
    return self.meta[key]
end

-- Main SnugSwap class - Primarily for encapsulating/namespacing the main api functions
local SnugSwap = {}
SnugSwap.__index = SnugSwap

function SnugSwap:new()
    local obj = setmetatable({
        VERSION = "1.0.0-beta",
        DEFAULT_SET_NAME = DEFAULT_SET_NAME,
        weaponset_cycle_list = {},
        current_weapon = nil,

        _middleware = {
            any        = {}, -- runs for all phases
            precast    = {},
            midcast    = {},
            aftercast  = {},
            pet_midcast   = {},
            pet_aftercast = {},
            pet_change    = {},
            status_change = {},
            self_command  = {},
        },
    }, SnugSwap)

    sets.util = {}
    sets.weapons = {}
    sets.idle = {}
    sets.status = {}
    sets.engaged = {}
    sets.fastcast = {}
    sets.precast = {}
    sets.midcast = {}
    sets.aftercast = {}
    sets.weaponskill = {}
    sets.modes = {}
    return obj
end

function SnugSwap:register_middleware(phase, fn, opts)
    -- phase: 'any', 'precast', 'midcast', 'aftercast', 'pet_midcast', ...
    opts = opts or {}

    if not self._middleware[phase] then
        snugs_warn("invalid_context_phase_" .. tostring(phase),
            "No such context phase for middleware: " .. tostring(phase))
        return
    end

    table.insert(self._middleware[phase], {
        fn       = fn,
        priority = opts.priority or 0,
        name     = opts.name or "anon",
    })

    table.sort(self._middleware[phase], function(a, b)
        return a.priority > b.priority
    end)
end

function SnugSwap:_new_context(phase, fields)
    -- phase: 'precast', 'midcast', 'aftercast', 'pet_midcast', etc.
    -- fields: optional initial values like { spell = spell }

    local ctx = SnugContext:new(phase, fields)
    if ctx.spell then
        ctx:add_lookup(ctx.spell.english)
        ctx:add_lookup(ctx.spell.type)
        if ctx.spell.skill then
            ctx:add_lookup(ctx.spell.skill)
        end
    end
    
    -- run context middleware here
    self:_run_middleware('any', ctx)
    self:_run_middleware(phase, ctx)

    return ctx
end

function SnugSwap:_run_middleware(phase, ctx)
    local list = self._middleware[phase]
    if not list or #list == 0 then return end

    for _, entry in ipairs(list) do
        snugs_trace("Running middleware '" .. entry.name .. "' for phase '" .. phase .. "'")
        entry.fn(ctx)
    end
end

function SnugSwap:wire_all()
    local snugs = self

    -- Only install hooks if user hasn't defined them
    if not rawget(_G, "precast") then
        _G.precast = function(spell)
            snugs:do_precast(spell)
        end
    end

    if not rawget(_G, "midcast") then
        _G.midcast = function(spell)
            snugs:do_midcast(spell)
        end
    end

    if not rawget(_G, "aftercast") then
        _G.aftercast = function(spell)
            snugs:do_aftercast(spell)
        end
    end

    if not rawget(_G, "status_change") then
        _G.status_change = function(new, old)
            snugs:do_status_change(new, old)
        end
    end

    if not rawget(_G, "self_command") then
        _G.self_command = function(cmd)
            snugs:do_self_command(cmd)
        end
    end

    if not rawget(_G, "pet_midcast") then
        _G.pet_midcast = function(spell)
            snugs:do_pet_midcast(spell)
        end
    end

    if not rawget(_G, "pet_aftercast") then
        _G.pet_aftercast = function(spell)
            snugs:do_pet_aftercast(spell)
        end
    end

    if not rawget(_G, "pet_change") then
        _G.pet_change = function(pet, gain)
            snugs:do_pet_change(pet, gain)
        end
    end

    local original_get_sets = _G.get_sets or function() end
    _G.get_sets = function()
        original_get_sets()
        snugs:bind_modes()
    end
end

function SnugSwap:extend_predicate(name, factory, opts)
    extend_predicate(name, factory, opts)
end

function SnugSwap:is_tracing()
    return _trace
end

function SnugSwap:trace(v)
    if type(v) ~= 'boolean' then
        v = false
    end

    _trace = v
end

function SnugSwap:is_debugging()
    return _debug
end

function SnugSwap:debug(v)
    if type(v) ~= 'boolean' then
        v = false
    end

    _debug = v
end

function SnugSwap:default_weaponset(set)
    self:weaponset(DEFAULT_SET_NAME, set)
end

function SnugSwap:weaponset(name, set)
    if self:add(sets.weapons, name, set) then
        table.insert(self.weaponset_cycle_list, name)
    end
end

function SnugSwap:default_idle(set)
    self:idle(set)
end

function SnugSwap:idle(set)
    self:add(sets.idle, DEFAULT_SET_NAME, set)
end

function SnugSwap:default_engaged(set)
    self:engaged(set)
end

-- set the engaged set for the default key
function SnugSwap:engaged(set)
    self:add(sets.engaged, DEFAULT_SET_NAME, set)
end

function SnugSwap:default_fastcast(set)
    self:fastcast(DEFAULT_SET_NAME, set)
end

function SnugSwap:fastcast(name, set)
    self:add(sets.fastcast, name, set)
end

function SnugSwap:default_weaponskill(set)
    self:weaponskill(DEFAULT_SET_NAME, set)
end

function SnugSwap:weaponskill(name, set)
    self:add(sets.weaponskill, name, set)
end

function SnugSwap:weaponskill_all(names, set)
    for _, name in ipairs(names) do
        self:add(sets.weaponskill, name, set)
    end
end

function SnugSwap:default_precast(set)
    self:precast(DEFAULT_SET_NAME, set)
end

function SnugSwap:default_midcast(set)
    self:midcast(DEFAULT_SET_NAME, set)
end

function SnugSwap:midcast(name, set)
    self:add(sets.midcast, name, set)
end

function SnugSwap:precast(name, set)
    self:add(sets.precast, name, set)
end

function SnugSwap:premidcast(name, set)
    self:add(sets.precast, name, set)
    self:add(sets.midcast, name, set)
end

function SnugSwap:premidcast_all(keys, set)
    for _, key in ipairs(keys) do
        self:add(sets.precast, key, set)
        self:add(sets.midcast, key, set)
    end
end

function SnugSwap:precast_all(keys, set)
    for _, key in ipairs(keys) do
        self:add(sets.precast, key, set)
    end
end

function SnugSwap:midcast_all(keys, set)
    for _, key in ipairs(keys) do
        self:add(sets.midcast, key, set)
    end
end

function SnugSwap:add(setTable, name, set)
    if not name or name == "" then
        snugs_error("Set name must be provided.")
        return false
    elseif setTable[name] then
        snugs_warn("set_duplicate_" .. name, "Set with name '", name, "' already exists and will be overwritten.")
        return false
    end

    setTable[name] = set or {}
    return true
end

function SnugSwap:add_mode(modeKey, options)
    options = options or {}
    local initial_value = options.initial_value or true
    local description = options.description or nil
    local shortcut = options.shortcut or nil
    local cycle_values = options.cycle_values or nil
    local gearset_mappings = options.gearset_mappings or nil

    if not cycle_values and gearset_mappings then
        cycle_values = {}
        for value, _ in pairs(gearset_mappings) do
            table.insert(cycle_values, value)
        end
    end

    sets.modes[modeKey] = {
        v = initial_value,
        description = description or "",
        shortcut = shortcut or nil,
        cycle_values = cycle_values or nil,
        gearset_mappings = gearset_mappings or nil,
    }
end

function SnugSwap:list_modes()
    for modeKey, mode in pairs(sets.modes) do
        local line = modeKey .. ": " .. tostring(mode.v)
        if mode.description and mode.description ~= "" then
            line = line .. " (" .. mode.description .. ")"
        end

        if mode.cycle_values then
            line = line .. " [cycle values: " .. table.concat(mode.cycle_values, ", ") .. "]"
        end

        snugs_log("mode - ", line)
    end
end

function SnugSwap:bind_modes()
    for modeKey, mode in pairs(sets.modes) do
        if mode.shortcut then
            windower.send_command('bind ' .. mode.shortcut .. ' gs c toggle ' .. modeKey)
        end
    end
end

function SnugSwap:util(name, set)
    self:add(sets.util, name, set)
end

function SnugSwap:do_pet_midcast(spell)
    local ctx = self:_new_context('pet_midcast', { spell = spell })
    if sets.midcast[DEFAULT_SET_NAME] then
        snugs_trace("Equipping default pet midcast set")
        self:equip_ex(ctx, sets.midcast[DEFAULT_SET_NAME])
    end

    local next_set = ctx:resolve_set_from_keys(sets.midcast)
    if next_set then
        snugs_trace("Equipping pet midcast set for ", spell.english)
        self:equip_ex(ctx, next_set)
    else
        self:reset_to_status(ctx)
    end
end

function SnugSwap:do_pet_aftercast(spell)
    local ctx = self:_new_context('pet_aftercast', { spell = spell })
    self:reset_to_status(ctx)
end

function SnugSwap:do_pet_change(pet, gain)
    local ctx = self:_new_context('pet_change', { pet = pet, gain = gain })
    self:reset_to_status(ctx)
end

function SnugSwap:do_precast(spell)
    local ctx = self:_new_context('precast', { spell = spell })
    if sets.precast[DEFAULT_SET_NAME] then
        snugs_trace("Equipping default precast set")
        self:equip_ex(ctx, sets.precast[DEFAULT_SET_NAME])
    end

    local next_set = ctx:resolve_set_from_keys(sets.precast)
    if next_set then
        snugs_trace("Equipping precast set for ", spell.english)
        self:equip_ex(ctx, next_set)
        return
    elseif string.find(spell.type, 'Magic') then
        if sets.fastcast[DEFAULT_SET_NAME] then
            snugs_trace("Equipping default fastcast set")
            self:equip_ex(ctx, sets.fastcast[DEFAULT_SET_NAME])
        end

        next_set = ctx:resolve_set_from_keys(sets.fastcast)
        if next_set then
            snugs_trace("Equipping fastcast set for ", spell.english)
            self:equip_ex(ctx, next_set)
        end
    end
end

function SnugSwap:do_midcast(spell)
    local ctx = self:_new_context('midcast', { spell = spell })
    if sets.midcast[DEFAULT_SET_NAME] then
        snugs_trace("Equipping default midcast set")
        self:equip_ex(ctx, sets.midcast[DEFAULT_SET_NAME])
    end

    local next_set = nil
    if spell.type == "WeaponSkill" then
        next_set = ctx:resolve_set_from_keys(sets.weaponskill)
        if not next_set then
            next_set = sets.weaponskill[DEFAULT_SET_NAME]
        end

        if next_set then
            snugs_trace("Equipping weaponskill set for ", spell.english)
            self:equip_ex(ctx, next_set)
            return
        end
    end

    next_set = ctx:resolve_set_from_keys(sets.midcast)
    if next_set then
        snugs_trace("Equipping midcast set for ", spell.english)
        self:equip_ex(ctx, next_set)
        return
    end
end

function SnugSwap:do_aftercast(spell)
    local ctx = self:_new_context('aftercast', { spell = spell })
    self:reset_to_status(ctx)
end

function SnugSwap:do_status_change(new, old)
    local ctx = self:_new_context('status_change', { new = new, old = old })
    self:reset_to_status(ctx)
end

function SnugSwap:do_self_command(command)
    local args = {}
    for word in command:gmatch("%S+") do
        table.insert(args, word)
    end

    local ctx = self:_new_context('self_command', {})
    if args[1] == 'set' and args[2] then
        local modeKey = args[2]
        local modeValue = args[3]
        if modeKey == "debug" then
            if modeValue == 'true' then
                self:debug(true)
                snugs_log("debugging enabled")
            elseif modeValue == 'false' then
                self:debug(false)
                snugs_log("debugging disabled")
            else
                snugs_warn("invalid_debug_value_" .. tostring(modeValue), "invalid value for debug: " .. tostring(modeValue))
            end
        elseif modeKey == "trace" then
            if modeValue == 'true' then
                self:trace(true)
                snugs_log("tracing enabled")
            elseif modeValue == 'false' then
                self:trace(false)
                snugs_log("tracing disabled")
            else
                snugs_warn("invalid_trace_value_" .. tostring(modeValue), "invalid value for trace: " .. tostring(modeValue))
            end
        elseif sets.modes[modeKey] then
            if sets.modes[modeKey].cycle_values then
                if modeValue and (modeValue ~= "") then
                    local found = false
                    for _, v in ipairs(sets.modes[modeKey].cycle_values) do
                        if tostring(v) == modeValue then
                            sets.modes[modeKey].v = v
                            found = true
                            break
                        end
                    end

                    if found then
                        snugs_log("mode '", modeKey, "' set to: ", tostring(sets.modes[modeKey].v))
                    else
                        snugs_warn("invalid_mode_" .. modeKey, "invalid value for mode '", modeKey, "': ", tostring(modeValue))
                    end
                else
                    snugs_warn("mode_no_value_provided_"..modeKey, "no value provided to set mode '", modeKey, "'")
                end
            else
                if modeValue and (modeValue ~= "") then
                    if modeValue == 'true' then
                        sets.modes[modeKey].v = true
                    elseif modeValue == 'false' then
                        sets.modes[modeKey].v = false
                    else
                        snugs_error("Invalid value for boolean mode '" .. modeKey .. "': " .. tostring(modeValue))
                    end
                else
                    snugs_error("No value provided to set boolean mode '" .. modeKey .. "'")
                end
            end

            self:reset_to_status(ctx)
        else
            snugs_error("No such mode to set: " .. modeKey)
        end
    elseif args[1] == 'toggle' and args[2] then
        local modeKey = args[2]
        if sets.modes[modeKey] then
            if sets.modes[modeKey].cycle_values then
                local current_value = sets.modes[modeKey].v
                local next_value = nil
                for i, v in ipairs(sets.modes[modeKey].cycle_values) do
                    if v == current_value then
                        next_value = sets.modes[modeKey].cycle_values[i % #sets.modes[modeKey].cycle_values + 1]
                        break
                    end
                end
                if not next_value then
                    next_value = sets.modes[modeKey].cycle_values[1]
                end
                sets.modes[modeKey].v = next_value
                snugs_log("Mode '" .. modeKey .. "' set to: " .. tostring(next_value))
            else
                sets.modes[modeKey].v = not sets.modes[modeKey].v
                snugs_log("Mode '" .. modeKey .. "' toggled to: " .. tostring(sets.modes[modeKey].v))
            end
        else
            snugs_error("No such mode to toggle: " .. modeKey)
        end

        self:reset_to_status(ctx)
    elseif args[1] == 'list' and args[2] == 'modes' then
        self:list_modes()
    elseif args[1] == 'util' and args[2] then
        local utilName = args[2]
        snugs_log("Equipping utility set: " .. utilName)
        if sets.util[utilName] then
            self:equip_ex(ctx, sets.util[utilName])
        else
            snugs_warn("no_such_util_set_" .. utilName, "no such utility set: " .. utilName)
        end
    elseif args[1] == 'warp' then
        snugs_log("Equipping utility set: warp")
        if sets.util.warp then
            self:equip_ex(ctx, sets.util.warp)
        else
            snugs_warn("no_warp_set", "no warp utility set defined")
        end
    elseif args[1] == 'nexus' then
        snugs_log("Equipping utility set: nexus")
        if sets.util.nexus then
            self:equip_ex(ctx, sets.util.nexus)
        else
            snugs_warn("no_nexus_set", "no nexus utility set defined")
        end
    elseif args[1] == 'speed' then
        snugs_log("Equipping utility set: speed")
        if sets.util.speed then
            self:equip_ex(ctx, sets.util.speed)
        else
            snugs_warn("no_speed_set", "no speed utility set defined")
        end
    elseif args[1] == 'cycle' and args[2] then
        if args[2] == 'weapon' then
            if #self.weaponset_cycle_list == 0 then
                snugs_warn("no_weapon_sets", "no weapon sets defined to cycle through")
                return
            end

            local current_weapon = self.current_weapon or DEFAULT_SET_NAME

            local next_weapon = nil
            for i, name in ipairs(self.weaponset_cycle_list) do
                if name == current_weapon then
                    next_weapon = self.weaponset_cycle_list[i % #self.weaponset_cycle_list + 1]
                    break
                end
            end
        
            if not next_weapon then
                next_weapon = self.weaponset_cycle_list[1]
            end

            self.current_weapon = next_weapon
            snugs_log("weapon: " .. tostring(current_weapon) .. " -> " .. tostring(next_weapon))
            self:reset_to_status(ctx)
        else
            snugs_error("unknown cycle target: " .. args[2])
        end
    else
        snugs_error("unknown command: " .. command)
    end
end

function SnugSwap:reset_to_status(ctx)
--    snugs_log("Resetting to status: " .. tostring(status or player.status))
    local status = player.status
    if sets.status[status] then
        self:equip_ex(ctx, sets.status[status])
    else
        status = status:lower()
        if sets[status] and sets[status][DEFAULT_SET_NAME] then
            -- snugs_log("Equipping status set: " .. status)
            self:equip_ex(ctx, sets[status][DEFAULT_SET_NAME])
        end
    end

    if not self.current_weapon and sets.weapons[DEFAULT_SET_NAME] then
        -- snugs_log("Equipping default weapon set: " .. DEFAULT_SET_NAME)
        self:equip_ex(ctx, sets.weapons[DEFAULT_SET_NAME])
    elseif self.current_weapon and sets.weapons[self.current_weapon] then
        -- snugs_log("Equipping weapon set: " .. self.current_weapon)
        self:equip_ex(ctx, sets.weapons[self.current_weapon])
    end
end

function SnugSwap:equip_ex(ctx, set)
    -- for k, v in pairs(getmetatable(set) or {}) do
    --     snugs_log("ctx key: " .. tostring(k) .. ", value: " .. tostring(v))
    -- end

    -- snugs_log("set __index: is_gearset: " .. tostring(is_gearset(set)) .. ", is_virtualset: " .. tostring(is_virtualset(set)))
    set = get_set_from_path(set)
    if is_gearset(set) then
        -- snugs_log("Evaluating gearset...")
        set = set:eval(ctx)
    end

    if _trace then
        local trace_line = "Final set to equip: \n" .. "--------------------\n"
        local slot_key = {"main", "sub", "range", "ammo", "head", "body", "hands", "legs", "feet", "neck", "waist", "left_ear", "right_ear", "left_ring", "right_ring", "back"}
        for i, slot in ipairs(slot_key) do
            local item = set[slot]
            if item then
                if type(item) == 'table' then
                    trace_line = trace_line .. "Slot: " .. slot .. ", Item: " .. item.name .. "\n"
                else
                    trace_line = trace_line .. "Slot: " .. slot .. ", Item: " .. tostring(item) .. "\n"
                end
            end
        end

        trace_line = trace_line .. "--------------------"
        snugs_log(trace_line)
    end

    equip(set)
end

function get_set_from_path(pathOrSet)
    -- pathOrSet can be a table (set) or a period delimited string to a set within the sets table
    -- with each token representing a key/subkey like "weapons.th" would be sets["weapons"]["th"]
    if type(pathOrSet) == 'table' then
        return pathOrSet
    elseif type(pathOrSet) == 'string' then
        local keys = {}
        for key in pathOrSet:gmatch("[^.]+") do
            table.insert(keys, key)
        end

        local currentSet = sets
        for _, key in ipairs(keys) do
            if currentSet[key] then
                currentSet = currentSet[key]
            else
                return {}
            end
        end

        return currentSet
    end

    return {}
end

function compare_with_op(left, op, right)
    if op == "==" or op == "~=" then
        if type(left) ~= type(right) then
            snugs_error("Both left and right must be of the same type for equality comparison.")
            return false
        end

        return (left == right) == (op == "==")
    end

    if type(left) ~= 'number' or type(right) ~= 'number' then
        snugs_error("Both left and right must be numbers for comparison.")
        return false
    end

    if op == '>' then
        return left > right
    elseif op == '<' then
        return left < right
    elseif op == '>=' then
        return left >= right
    elseif op == '<=' then
        return left <= right
    else
        snugs_error("Invalid operator: " .. tostring(op))
        return false
    end
end

local PREDICATE_GROUP_OR = 'or'
local PREDICATE_GROUP_AND = 'and'
local PREDICATE_LOGIC_ALL = 'all'
local PREDICATE_LOGIC_ANY = 'any'

Predicate = {}
Predicate.__index = function(self, key)
    local method = Predicate[key]
    if method then
        return method
    end

    local factory = get_predicate_extension_factory(key)
    if factory then
        return function(self, ...)
            local res = factory(...)
            -- res can be:
            --  - a function(ctx) -> boolean
            --  - another Predicate object
            if type(res) == "function" then
                self:where(res)
            elseif is_predicate(res) then
                self:and_also(res)
            end
            return self
        end
    end

    return nil
end

function Predicate:new()
    local obj = setmetatable({
        tests = {},
        groups = {},
        _priority = 0,
        _logic = PREDICATE_LOGIC_ALL,
    }, Predicate)

    return obj
end

function when()
    return Predicate:new()
end

function where(fn)
    return Predicate:new():where(fn)
end

function is_predicate(obj)
    return getmetatable(obj) == Predicate
end

function Predicate:any()
    self._logic = PREDICATE_LOGIC_ANY
    return self
end

function Predicate:where(fn)
    if type(fn) ~= 'function' then
        -- snugs_error("where requires a function.")
        return self
    end

    table.insert(self.tests, fn)
    return self
end

function Predicate:and_also(otherPredicate)
    if not is_predicate(otherPredicate) then
        --snugs_error("and_also requires another Predicate instance.")
        return self
    end

    table.insert(self.groups, {otherPredicate, PREDICATE_GROUP_AND})
    return self
end

function Predicate:or_instead(otherPredicate)
    if not is_predicate(otherPredicate) then
        --snugs_error("or_else requires another Predicate instance.")
        return self
    end

    table.insert(self.groups, {otherPredicate, PREDICATE_GROUP_OR})
    return self
end

function Predicate:priority(value)
    self._priority = value or 0
    return self
end

function Predicate:eval(ctx)
    -- snugs_log("Evaluating Predicate...")
    local result = true

    if self._logic == PREDICATE_LOGIC_ALL then
        for _, test in ipairs(self.tests) do
            if not test(ctx) then
                result = false
                break
            end
        end
    elseif self._logic == PREDICATE_LOGIC_ANY then
        result = false
        for _, test in ipairs(self.tests) do
            if test(ctx) then
                result = true
                break
            end
        end
    end

    for _, group in ipairs(self.groups) do
        local otherPredicate = group[1]
        local operator = group[2]

        if operator == PREDICATE_GROUP_AND then
            result = result and otherPredicate:eval(ctx)
        elseif operator == PREDICATE_GROUP_OR then
            result = result or otherPredicate:eval(ctx)
        end
    end

    return result
end

extend_predicate("phase", function(phaseName)
    if not phaseName then
        snugs_error("phase_is requires a phase name.")
        return
    end

    return function(ctx) return ctx.phase == phaseName end
end)

extend_predicate("spell_name", function(name)
    if not name then
        snugs_error("spell_name requires a name.")
        return
    end

    return function(ctx) return ctx.spell and ctx.spell.english == name end
end)

extend_predicate("spell_name_any", function(names)
    if not names or type(names) ~= 'table' then
        snugs_error("spell_name_any requires a table of names.")
        return
    end

    return function(ctx) 
        if not ctx.spell then return false end
        for _, name in ipairs(names) do
            if ctx.spell.english == name then
                return true
            end
        end

        return false
    end
end)

extend_predicate("spell_type", function(type_name)
    if not type_name then
        snugs_error("spell_type requires a type name.")
        return
    end

    return function(ctx) return ctx.spell and ctx.spell.type == type_name end
end)

extend_predicate("spell_type_any", function(type_names)
    if not type_names or type(type_names) ~= 'table' then
        snugs_error("spell_type_any requires a table of type names.")
        return
    end

    return function(ctx) 
        if not ctx.spell then return false end
        for _, type_name in ipairs(type_names) do
            if ctx.spell.type == type_name then
                return true
            end
        end
        return false
    end
end)

extend_predicate("action_type", function(type_name)
    if not type_name then
        snugs_error("action_type requires a type name.")
        return
    end

    return function(ctx) return ctx.spell and ctx.spell.action_type == type_name end
end)

extend_predicate("status", function(status)
    if not status then
        snugs_error("status requires a status name.")
        return
    end

    return function() return player.status == status end
end)

extend_predicate("subjob", function(subjobCode)
    if not subjobCode then
        snugs_error("subjob requires a subjob code.")
        return
    end

    return function() return player.sub_job == subjobCode end
end)

extend_predicate("buff", function(buffName)
    if not buffName then
        snugs_error("buff requires a buff name.")
        return
    end

    return function() return buffactive[buffName] end
end)

extend_predicate("hpp_less_than", function(value)
    if not value then
        snugs_error("hpp_less_than value must be provided.")
        return
    end

    return function()
        if not player.hpp then
            snugs_error("Player hpp is not available.")
            return false
        end

        return player.hpp < value
    end
end)

extend_predicate("hpp_greater_than", function(value)
    if not value then
        snugs_error("hpp_greater_than value must be provided.")
        return
    end

    return function()
        if not player.hpp then
            snugs_error("Player hpp is not available.")
            return false
        end

        return player.hpp > value
    end
end)

extend_predicate("hpp_equal_to", function(value)
    if not value then
        snugs_error("hpp_equal_to value must be provided.")
        return
    end

    return function()
        if not player.hpp then
            snugs_error("Player hpp is not available.")
            return false
        end

        return player.hpp == value
    end
end)

extend_predicate("hpp_greater_than_or_equal_to", function(value)
    if not value then
        snugs_error("hpp_greater_than_or_equal_to value must be provided.")
        return
    end

    return function()
        if not player.hpp then
            snugs_error("Player hpp is not available.")
            return false
        end

        return player.hpp >= value
    end
end)

extend_predicate("hpp_less_than_or_equal_to", function(value)
    if not value then
        snugs_error("hpp_less_than_or_equal_to value must be provided.")
        return
    end

    return function()
        if not player.hpp then
            snugs_error("Player hpp is not available.")
            return false
        end

        return player.hpp <= value
    end
end)

extend_predicate("hpp", function(op, value)
    if not op or not value then
        snugs_error("hpp operator and value must be provided.")
        return
    end

    return function()
        if not player.hpp then
            snugs_error("Player hpp is not available.")
            return false
        end

        return compare_with_op(player.hpp, op, value)
    end
end)

extend_predicate("tp_less_than", function(value)
    if not value then
        snugs_error("tp_less_than value must be provided.")
        return
    end

    return function()
        if not player.tp then
            snugs_error("Player tp is not available.")
            return false
        end

        return player.tp < value
    end
end)

extend_predicate("tp_greater_than", function(value)
    if not value then
        snugs_error("tp_greater_than value must be provided.")
        return
    end

    return function()
        if not player.tp then
            snugs_error("Player tp is not available.")
            return false
        end

        return player.tp > value
    end
end)

extend_predicate("tp_equal_to", function(value)
    if not value then
        snugs_error("tp_equal_to value must be provided.")
        return
    end

    return function()
        if not player.tp then
            snugs_error("Player tp is not available.")
            return false
        end

        return player.tp == value
    end
end)

extend_predicate("tp_greater_than_or_equal_to", function(value)
    if not value then
        snugs_error("tp_greater_than_or_equal_to value must be provided.")
        return
    end

    return function()
        if not player.tp then
            snugs_error("Player tp is not available.")
            return false
        end

        return player.tp >= value
    end
end)

extend_predicate("tp_less_than_or_equal_to", function(value)
    if not value then
        snugs_error("tp_less_than_or_equal_to value must be provided.")
        return
    end

    return function()
        if not player.tp then
            snugs_error("Player tp is not available.")
            return false
        end

        return player.tp <= value
    end
end)

extend_predicate("tp", function(op, value)
    if not op or not value then
        snugs_error("tp operator and value must be provided.")
        return
    end

    return function()
        if not player.tp then
            snugs_error("Player tp is not available.")
            return false
        end

        return compare_with_op(player.tp, op, value)
    end
end)

extend_predicate("mpp_less_than", function(value)
    if not value then
        snugs_error("mpp_less_than value must be provided.")
        return
    end

    return function()
        if not player.mpp then
            snugs_error("Player mpp is not available.")
            return false
        end

        return player.mpp < value
    end
end)

extend_predicate("mpp_greater_than", function(value)
    if not value then
        snugs_error("mpp_greater_than value must be provided.")
        return
    end

    return function()
        if not player.mpp then
            snugs_error("Player mpp is not available.")
            return false
        end

        return player.mpp > value
    end
end)

extend_predicate("mpp_equal_to", function(value)
    if not value then
        snugs_error("mpp_equal_to value must be provided.")
        return
    end

    return function()
        if not player.mpp then
            snugs_error("Player mpp is not available.")
            return false
        end

        return player.mpp == value
    end
end)

extend_predicate("mpp_greater_than_or_equal_to", function(value)
    if not value then
        snugs_error("mpp_greater_than_or_equal_to value must be provided.")
        return
    end

    return function()
        if not player.mpp then
            snugs_error("Player mpp is not available.")
            return false
        end

        return player.mpp >= value
    end
end)

extend_predicate("mpp_less_than_or_equal_to", function(value)
    if not value then
        snugs_error("mpp_less_than_or_equal_to value must be provided.")
        return
    end

    return function()
        if not player.mpp then
            snugs_error("Player mpp is not available.")
            return false
        end

        return player.mpp <= value
    end
end)

extend_predicate("mpp", function(op, value)
    if not op or not value then
        snugs_error("mpp operator and value must be provided.")
        return
    end

    return function()
        if not player.mpp then
            snugs_error("Player mpp is not available.")
            return false
        end

        return compare_with_op(player.mpp, op, value)
    end
end)

extend_predicate("mode_is", function(modeName, expectedValue)
    if not modeName or expectedValue == nil then
        snugs_error("mode_is requires a mode name and expected value.")
        return
    end

    return function()
        if not sets.modes[modeName] then
            return false
        end

        return sets.modes[modeName].v == expectedValue
    end
end)

extend_predicate("weather", function(name)
    if not name then
        snugs_error("weather requires a weather name.")
        return
    end

    return function() return world.weather_element == name end
end)

extend_predicate("day", function(name)
    if not name then
        snugs_error("day requires a day name.")
        return
    end

    return function() return world.day_element == name end
end)

extend_predicate("mode", function(name, op, value)
    if not name then
        snugs_error("mode requires a mode name.")
        return
    end

    return function()
        if not sets.modes[name] then
            return false
        end

        if not op or not value then
            return sets.modes[name].v
        end

        return compare_with_op(sets.modes[name].v, op, value)
    end
end)

extend_predicate("key", function(key)
    return function(ctx)
        return ctx:has_lookup(key)
    end
end)

extend_predicate("has_pet", function(v)
    if v == nil then
        v = true
    end

    return function() return pet and pet.isvalid == v end
end)

GearsetWithOptions = {}
GearsetWithOptions.__index = function (self, key)
    local method = GearsetWithOptions[key]
    if method then
        return method
    end

    if PREDICATE_EXTENSIONS[key] then
        return function(self, ...)
            self.has_predicate = true
            self.predicate[key](self.predicate, ...)
            return self
        end
    end

    return nil
end

function gearset_from_mode(mode_name, gearset_mappings)
    return GearsetWithOptions:new(nil, {
        mode_name = mode_name,
        gearset_mappings = gearset_mappings,
    })
end

function gearset(set)
    return GearsetWithOptions:new(set)
end

function is_virtualset(x)
    return type(x) == "table"
        and x.__is_snugs_virtual_set == true
        and type(x.eval) == "function"
end

function is_gearset(x)
    if type(x) ~= 'table' then return false end
    local mt = getmetatable(x)
    if mt == GearsetWithOptions then
        return true
    end

    return is_virtualset(x)
end

function GearsetWithOptions:new(set, options)
    options = options or {}
    local obj = setmetatable({
        overlays = {},
        conditions = {},
        set = set or {},
        other = nil,
        sourceModeName = options.mode_name or nil,
        predicate = Predicate:new(),
        has_predicate = nil,
        gearset_mappings = options.gearset_mappings or nil,
    }, GearsetWithOptions)

    return obj
end

-- syntactic sugar for GearsetWithOptions
function GearsetWithOptions:when()
    return self
end

function GearsetWithOptions:otherwise(set)
    self.other = set or {}
    return self
end

function GearsetWithOptions:where(fn)
    self.has_predicate = true
    self.predicate:where(fn)
    return self
end

function GearsetWithOptions:and_combine(basicOrGearset)
    if not basicOrGearset then
        -- snugs_error("basicOrGearset must be provided.")
        return self
    end

    table.insert(self.overlays, basicOrGearset)
    return self
end

function GearsetWithOptions:and_also(otherPredicate)
    if not is_predicate(otherPredicate) then
        -- snugs_error("otherPredicate must be a Predicate.")
        return self
    end

    self.has_predicate = true
    self.predicate:and_also(otherPredicate)
    return self
end

function GearsetWithOptions:or_instead(otherPredicate)
    if not is_predicate(otherPredicate) then
        -- snugs_error("otherPredicate must be a Predicate.")
        return self
    end

    self.has_predicate = true
    self.predicate:or_instead(otherPredicate)
    return self
end

function GearsetWithOptions:eval_mode(ctx)
    --snugs_log("Evaluating gearset from mode: " .. tostring(self.sourceModeName))
    if not self.sourceModeName then
        -- snugs_error("No source mode name specified for gearset_from_mode.")
        return {}
    end

    local mode = sets.modes[self.sourceModeName]
    if not mode then
        -- snugs_error("No such mode defined: " .. self.sourceModeName)
        return {}
    end

    if self.gearset_mappings then
        -- snugs_log("Using gearset mappings from GearsetWithOptions for mode: " .. self.sourceModeName)
        if not self.gearset_mappings[mode.v] then
            -- snugs_error("No gearset mapping for mode value: " .. tostring(mode.v))
            return {}
        end

        local setPath = self.gearset_mappings[mode.v]
        local set = get_set_from_path(setPath)
        if is_gearset(set) then
            return set:eval(ctx)
        else
            return set
        end
    elseif mode.gearset_mappings and mode.gearset_mappings[mode.v] then
        -- snugs_log("Using gearset mappings from mode for mode: " .. self.sourceModeName)
        local setPath = mode.gearset_mappings[mode.v]
        local set = get_set_from_path(setPath)
        if is_gearset(set) then
            return set:eval(ctx)
        else
            return set
        end
    end

    -- snugs_error("No gearset mapping for mode value: " .. tostring(mode.v))
    return {}
end

function GearsetWithOptions:eval(ctx)
    -- snugs_log("Evaluating GearsetWithOptions...")
    -- should we apply this set at all?
    if self.has_predicate then
        if not self.predicate:eval(ctx) then
            return self.other or {}
        end
    end

    local set = self.set
    
    -- snugs_log("-------#1 ".. tostring(#set))
    if self.sourceModeName then
        -- snugs_log("-------#2 ".. tostring(#set))
        -- snugs_log("Evaluating gearset from mode: " .. tostring(self.sourceModeName))
        set = self:eval_mode(ctx)
    end
    
    set = get_set_from_path(set or {}) or {}
    if is_gearset(set) then
        set = set:eval(ctx)  -- if it's a GearsetWithOptions, evaluate it first
    end

    -- for slot, item in pairs(set) do
    --     if type(item) == 'table' then
    --         snugs_log("Slot: " .. slot .. ", Item: " .. item.name)
    --     else
    --         snugs_log("Slot: " .. slot .. ", Item: " .. tostring(item))
    --     end
    -- end

    set = set_combine({}, set)

    -- snugs_log("-------#3 ".. tostring(#set))
    -- if we have any overlays, combine them
    for _, overlay in ipairs(self.overlays) do
        if type(overlay) == 'table' then
            if is_gearset(overlay) then
                set = set_combine(set, overlay:eval(ctx))
            else
                set = set_combine(set, overlay)
            end
        elseif type(overlay) == 'string' then
            set = set_combine(set, get_set_from_path(overlay))
        end
    end

    -- snugs_log("-------#4 ".. tostring(#set))

    return set
end

Selector = {}
Selector.__index = Selector

function Selector:new(set, cond)
    local obj = setmetatable({
        __is_snugs_virtual_set = true,
        _set = set or nil,
        _cond = cond or nil,
        _priority = 0,
    }, Selector)

    return obj
end

function use(set, cond)
    return Selector:new(set, cond)
end

function is_selector(obj)
    return getmetatable(obj) == Selector
end

function Selector:priority(n)
    self._priority = n or 0
    return self
end

function Selector:eval(ctx)
    -- snugs_log("Evaluating Selector...")
    if not self._set then
        -- snugs_error("No set defined in selector.")
        return {}
    end

    if not self._cond or (is_predicate(self._cond) and self._cond:eval(ctx)) then
        if is_gearset(self._set) then
            return self._set:eval(ctx)
        else
            return self._set
        end
    end

    return {}
end

local SELECTOR_MODE_FIRST = 'first'
local SELECTOR_MODE_ALL = 'all'

SelectorSet = {}
SelectorSet.__index = SelectorSet

function SelectorSet:new(selectors, opts)
    opts = opts or {}

    local obj = setmetatable({
        __is_snugs_virtual_set = true,
        _selectors = selectors or {},
        _mode = opts.mode or SELECTOR_MODE_FIRST,
    }, SelectorSet)

    table.sort(obj._selectors, function(a, b) return (a._priority or 0) > (b._priority or 0) end)

    return obj
end

function choose_from(...)
    local selectors = {...}
    return SelectorSet:new(selectors, {mode = SELECTOR_MODE_FIRST})
end

function choose_all(...)
    local selectors = {...}
    return SelectorSet:new(selectors, {mode = SELECTOR_MODE_ALL})
end

function SelectorSet:eval(ctx)
    -- snugs_log("Evaluating SelectorSet in mode: " .. self._mode)
    if self._mode == SELECTOR_MODE_FIRST then
        for _, selector in ipairs(self._selectors) do
            local evalSet = selector:eval(ctx)
            if evalSet and next(evalSet) then
                return evalSet
            end
        end
    elseif self._mode == SELECTOR_MODE_ALL then
        local combinedSet = {}

        for _, selector in ipairs(self._selectors) do
            local evalSet = selector:eval(ctx)
            if evalSet and next(evalSet) then
                combinedSet = set_combine(combinedSet, evalSet)
            end
        end

        return combinedSet
    end

    return {}
end

function spell_families(ctx, next)
    if ctx.spell then
        if ctx.spell.type == "Ninjutsu" then
            -- get name of spell without ": Ichi/Ni/San" suffix
            local base_name = ctx.spell.english:match("^(.-):%s*(Ichi|Ni|San)$")
            if base_name then
                ctx:add_lookup("All" .. base_name)
            end
        else
            -- get name of spell without "I/II/III/IV/V/VI" suffix
            local base_name = ctx.spell.english:match("^(.-)%s*(I|II|III|IV|V|VI)$")
            if base_name then
                ctx:add_lookup("All" .. base_name)
            end
        end
    end
end

function friendly_ninjutsu_helpers(ctx, next)
    if ctx.spell and ctx.spell.type == "Ninjutsu" then
        local spell_category_lookup = {
            ["Katon: Ichi"] = "ElementalNinjutsu", ["Suiton: Ichi"] = "ElementalNinjutsu", ["Raiton: Ichi"] = "ElementalNinjutsu",
            ["Doton: Ichi"] = "ElementalNinjutsu", ["Huton: Ichi"] = "ElementalNinjutsu", ["Hyoton: Ichi"] = "ElementalNinjutsu",
            ["Katon: Ni"] = "ElementalNinjutsu", ["Suiton: Ni"] = "ElementalNinjutsu", ["Raiton: Ni"] = "ElementalNinjutsu",
            ["Doton: Ni"] = "ElementalNinjutsu", ["Huton: Ni"] = "ElementalNinjutsu", ["Hyoton: Ni"] = "ElementalNinjutsu",
            ["Katon: San"] = "ElementalNinjutsu", ["Suiton: San"] = "ElementalNinjutsu", ["Raiton: San"] = "ElementalNinjutsu",
            ["Doton: San"] = "ElementalNinjutsu", ["Huton: San"] = "ElementalNinjutsu", ["Hyoton: San"] = "ElementalNinjutsu",
            ["Monomi: Ichi"] = "UtilityNinjutsu", ["Tonko: Ichi"] = "UtilityNinjutsu",
            ["Monomi: Ni"] = "UtilityNinjutsu", ["Tonko: Ni"] = "UtilityNinjutsu",
            ["Monomi: San"] = "UtilityNinjutsu", ["Tonko: San"] = "UtilityNinjutsu",
            ["Kurayami: Ichi"] = "DebuffNinjutsu", ["Hojo: Ichi"] = "DebuffNinjutsu",
            ["Dokumori: Ichi"] = "DebuffNinjutsu", ["Yurin: Ichi"] = "DebuffNinjutsu",
            ["Kurayami: Ni"] = "DebuffNinjutsu", ["Hojo: Ni"] = "DebuffNinjutsu",
            ["Aisha: Ichi"] = "DebuffNinjutsu",
        }

        local category = spell_category_lookup[ctx.spell.english]
        if category then
            ctx:add_lookup(category)
        end
    end
end

function create_once_mode_transition(mode_name, reset_value, cond)
    if not sets.modes[mode_name] then
        snugs_error("No such mode to create once transition for: " .. mode_name)
        return
    end

    if not is_predicate(cond) then
        snugs_error("Condition for once mode transition must be a Predicate.")
        return
    end

    return function(ctx)
        local mode = sets.modes[mode_name]
        if mode and cond:eval(ctx) then
            snugs_log("Once transition condition met for mode: " .. mode_name .. ", setting once transition.")
            mode.v = reset_value
        end
    end
end

snugs = SnugSwap:new()

snugs:register_middleware("any", friendly_ninjutsu_helpers, {
    name = "friendly_ninjutsu_helpers",
    priority = 0,
})

snugs:register_middleware("any", spell_families, {
    name = "spell_families",
    priority = 0,
})