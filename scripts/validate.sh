#!/bin/bash
# Runs LuxVim's pipeline up through the validate stage only (no
# bootstrap, no keymaps, no autocmds). Exits 0 on clean config, 1
# on critical errors. Prints a human-readable report to stdout.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PKG="$ROOT/packages/luxvim"
cd "$PKG"

LUXVIM_ROOT="$PKG" NVIM_APPNAME="LuxVim" XDG_DATA_HOME="$PKG/data" \
  exec nvim --headless --cmd "set rtp+=$PKG" -u "$PKG/init.lua" \
  -c "lua require('core').validate_only_or_exit()"
