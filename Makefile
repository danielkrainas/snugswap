LUA ?= lua

SOURCES := snugswap.lua
TESTS   := $(wildcard test/*.lua)

.DEFAULT_GOAL := help

.PHONY: help test check lint

help: ## Show this help
	@echo "SnugSwap $(shell cat VERSION 2>/dev/null)"
	@echo
	@grep -hE '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
		| awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-10s\033[0m %s\n", $$1, $$2}'
	@echo
	@echo "  Run one file:   make test FILE=predicates"
	@echo "  Run one test:   make test MATCH=\"obi\""
	@echo "  Override Lua:   make test LUA=lua5.4"

test: ## Run the test suite
	@$(LUA) test/run.lua $(FILE) $(if $(MATCH),-m $(MATCH))

check: ## Syntax-check the library and the tests
	@for f in $(SOURCES) $(TESTS); do \
		$(LUA) -e "assert(loadfile('$$f'))" || exit 1; \
	done
	@echo "syntax ok"

lint: check ## Alias for check
