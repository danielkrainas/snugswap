-- jobcheck -- check real GearSwap job luas against SnugSwap, outside the game.
--
--   lua tools/jobcheck.lua lint     <jobs-dir> [--common dek.lua]
--   lua tools/jobcheck.lua snapshot <jobs-dir> <out-dir> [--common dek.lua]
--   lua tools/jobcheck.lua verify   <jobs-dir> <out-dir> [--common dek.lua]
--
-- lint     reports structural problems: things a file says but does not do.
-- snapshot records what each file equips, per scenario and per mode.
-- verify   re-records and diffs against the snapshot, so an edit that changes
--          behaviour shows up as a diff rather than as a surprise in game.

local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)/jobcheck%.lua$") or "tools"

local env = dofile(here .. "/jobcheck/env.lua")
local lint = dofile(here .. "/jobcheck/lint.lua")
local snapshot = dofile(here .. "/jobcheck/snapshot.lua")

local RED, YELLOW, DIM, BOLD, GREEN, RESET =
    "\27[31m", "\27[33m", "\27[2m", "\27[1m", "\27[32m", "\27[0m"
if os.getenv("NO_COLOR") then
    RED, YELLOW, DIM, BOLD, GREEN, RESET = "", "", "", "", "", ""
end

local COLOR = { ERROR = RED, WARN = YELLOW, INFO = DIM }

local function usage(msg)
    if msg then io.stderr:write("jobcheck: " .. msg .. "\n\n") end
    io.stderr:write([[
usage:
  jobcheck lint     <jobs-dir> [--common <file>]
  jobcheck snapshot <jobs-dir> <out-dir> [--common <file>]
  jobcheck verify   <jobs-dir> <out-dir> [--common <file>]

  --common <file>   a shared include every job lua calls, such as dek.lua.
                    Loaded for real so interactions with it are visible.
                    Defaults to <jobs-dir>/dek.lua when that exists.
]])
    os.exit(2)
end

-- ------------------------------------------------------------ argument parse

local command = arg[1]
local positional, common = {}, nil
local i = 2
while i <= #arg do
    if arg[i] == "--common" then
        common = arg[i + 1]; i = i + 2
    else
        table.insert(positional, arg[i]); i = i + 1
    end
end

if not command then usage("no command given") end

local jobs_dir = positional[1]
if not jobs_dir then usage("no jobs directory given") end
jobs_dir = jobs_dir:gsub("/$", "")

if not common then
    local default = jobs_dir .. "/dek.lua"
    if env.read(default) then common = default end
end

local opts = { common = common }
local files = env.job_files(jobs_dir, common and common:match("([^/]+)$") or nil)

if #files == 0 then
    io.stderr:write(("jobcheck: no .lua files found in %s\n"):format(jobs_dir))
    io.stderr:write("  point it at your GearSwap data folder, for example:\n")
    io.stderr:write("    make jobs JOBS=~/Windower/addons/GearSwap/data\n")
    os.exit(1)
end

local function mkdir(path)
    os.execute(("mkdir -p %q"):format(path))
end

-- --------------------------------------------------------------------- lint

if command == "lint" then
    local errors, warnings, infos = 0, 0, 0

    for _, path in ipairs(files) do
        local findings = lint.run(env, path, opts)
        if #findings > 0 then
            print(BOLD .. path:match("([^/]+)$") .. RESET)
            for _, f in ipairs(findings) do
                print(("  %s%-5s%s %s"):format(COLOR[f.level] or "", f.level, RESET, f.message))
                if f.detail then print(("        %s%s%s"):format(DIM, f.detail, RESET)) end
                if f.level == "ERROR" then errors = errors + 1
                elseif f.level == "WARN" then warnings = warnings + 1
                else infos = infos + 1 end
            end
            print()
        end
    end

    print(("%d file%s checked -- %s%d error%s%s, %s%d warning%s%s, %d note%s"):format(
        #files, #files == 1 and "" or "s",
        errors > 0 and RED or "", errors, errors == 1 and "" or "s", RESET,
        warnings > 0 and YELLOW or "", warnings, warnings == 1 and "" or "s", RESET,
        infos, infos == 1 and "" or "s"))

    os.exit(errors > 0 and 1 or 0)
end

-- ----------------------------------------------------------------- snapshot

if command == "snapshot" or command == "verify" then
    local out_dir = positional[2]
    if not out_dir then usage("no snapshot directory given") end
    out_dir = out_dir:gsub("/$", "")

    if command == "snapshot" then
        mkdir(out_dir)
        for _, path in ipairs(files) do
            local name = path:match("([^/]+)$")
            local target = snapshot.path_for(out_dir, name)
            local fh = assert(io.open(target, "w"))
            fh:write(snapshot.render(env, path, opts))
            fh:close()
            print(("  recorded %s"):format(target))
        end
        print(("%d snapshot%s written to %s"):format(#files, #files == 1 and "" or "s", out_dir))
        os.exit(0)
    end

    local changed, missing = 0, 0
    for _, path in ipairs(files) do
        local name = path:match("([^/]+)$")
        local target = snapshot.path_for(out_dir, name)
        local recorded = env.read(target)
        local current = snapshot.render(env, path, opts)

        if not recorded then
            print(("%s%s%s  %sno snapshot recorded%s"):format(BOLD, name, RESET, YELLOW, RESET))
            missing = missing + 1
        elseif recorded ~= current then
            print(BOLD .. name .. RESET)
            -- Line-by-line so the report names the exact action that moved.
            local a, b = {}, {}
            for l in recorded:gmatch("[^\n]*") do table.insert(a, l) end
            for l in current:gmatch("[^\n]*") do table.insert(b, l) end
            local shown = 0
            for n = 1, math.max(#a, #b) do
                if a[n] ~= b[n] then
                    if shown < 12 then
                        if a[n] then print(("  %s- %s%s"):format(RED, a[n], RESET)) end
                        if b[n] then print(("  %s+ %s%s"):format(GREEN, b[n], RESET)) end
                    end
                    shown = shown + 1
                end
            end
            if shown > 12 then print(("  %s... and %d more differing lines%s"):format(DIM, shown - 12, RESET)) end
            print()
            changed = changed + 1
        end
    end

    if changed == 0 and missing == 0 then
        print(("%s%d file%s match their snapshots%s"):format(GREEN, #files, #files == 1 and "" or "s", RESET))
        os.exit(0)
    end

    print(("%d changed, %d without a snapshot (run `make snapshot` to accept)"):format(changed, missing))
    os.exit(1)
end

usage("unknown command: " .. tostring(command))
