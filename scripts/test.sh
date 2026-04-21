#!/bin/bash
# Runs the plenary-busted test suite under a clean headless Neovim.
# --clean ignores the user's Neovim config; -u tests/minimal_init.lua
# bootstraps plenary into data/test-plenary/ on first run.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT/packages/luxvim"

exec nvim --headless --clean -u tests/minimal_init.lua \
  -c "lua require('plenary.test_harness').test_directory('tests/unit', { minimal_init = 'tests/minimal_init.lua', sequential = true })" \
  -c "qa!"
