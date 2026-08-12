-- Test runner. Loads every test/*_test.lua, runs them, exits non-zero on failure.
--
--   lua test/run.lua                 run everything
--   lua test/run.lua predicates      run only files whose name matches
--   lua test/run.lua -m "obi"        run only tests whose label matches

local here = debug.getinfo(1, "S").source:sub(2):match("^(.*)/run%.lua$") or "test"

local harness = dofile(here .. "/harness.lua")
harness.install()

local FILES = {
    "resolution_test.lua",
    "gearsets_test.lua",
    "predicates_test.lua",
    "modes_test.lua",
    "commands_test.lua",
    "middleware_test.lua",
    "templates_test.lua",
}

local file_filter, test_filter

local i = 1
while i <= #arg do
    if arg[i] == "-m" or arg[i] == "--match" then
        test_filter = arg[i + 1]
        i = i + 2
    else
        file_filter = arg[i]
        i = i + 1
    end
end

local loaded = 0
for _, name in ipairs(FILES) do
    if not file_filter or name:find(file_filter, 1, true) then
        local path = here .. "/" .. name
        local chunk, err = loadfile(path)
        if not chunk then
            io.stderr:write("could not load " .. path .. ": " .. tostring(err) .. "\n")
            os.exit(1)
        end
        chunk()
        loaded = loaded + 1
    end
end

if loaded == 0 then
    io.stderr:write("no test files matched " .. tostring(file_filter) .. "\n")
    os.exit(1)
end

local results = harness.run(test_filter)
os.exit(harness.report(results) == 0 and 0 or 1)
