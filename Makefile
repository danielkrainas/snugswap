LUA ?= lua

SOURCES   := snugswap.lua
TESTS     := $(wildcard test/*.lua)
TOOLS     := tools/jobcheck.lua $(wildcard tools/jobcheck/*.lua)

# Where your GearSwap job luas live, and where their snapshots are kept.
JOBS      ?= data
SNAPSHOTS ?= snapshots

.DEFAULT_GOAL := help

.PHONY: help test check lint jobs snapshot verify

help: ## Show this help
	@echo "SnugSwap $(shell cat VERSION 2>/dev/null)"
	@echo
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Run one file:   make test FILE=predicates"
	@echo "  Run one test:   make test MATCH=\"obi\""
	@echo "  Check job luas: make jobs JOBS=~/Windower/addons/GearSwap/data"
	@echo "  Override Lua:   make test LUA=lua5.4"

test: ## Run the test suite
	@$(LUA) test/run.lua $(FILE) $(if $(MATCH),-m $(MATCH))

check: ## Syntax-check the library, the tests and the tools
	@for f in $(SOURCES) $(TESTS) $(TOOLS); do \
		$(LUA) -e "assert(loadfile('$$f'))" || exit 1; \
	done
	@echo "syntax ok"

jobs: ## Lint your job luas (JOBS=<dir>)
	@$(LUA) tools/jobcheck.lua lint $(JOBS)

snapshot: ## Record what each job lua equips (JOBS=<dir> SNAPSHOTS=<dir>)
	@$(LUA) tools/jobcheck.lua snapshot $(JOBS) $(SNAPSHOTS)

verify: ## Diff your job luas against the recorded snapshots
	@$(LUA) tools/jobcheck.lua verify $(JOBS) $(SNAPSHOTS)

lint: check ## Alias for check
