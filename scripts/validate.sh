#!/bin/bash
# Runs LuxVim's pipeline up through the validate stage only (no
# bootstrap, no keymaps, no autocmds). Exits 0 on clean config, 1
# on critical errors. Prints a human-readable report to stdout.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

LUXVIM_ROOT="$ROOT" NVIM_APPNAME="LuxVim" XDG_DATA_HOME="$ROOT/data" \
  exec nvim --headless --cmd "set rtp+=$ROOT" -u "$ROOT/init.lua" \
  -c "lua require('core').validate_only_or_exit()"
