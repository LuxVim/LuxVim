-- lua/core/lib/deps.lua
-- Single source of truth for the external commands LuxVim needs on PATH.
-- Consumed by install.sh / install.ps1 (via scripts/check-deps.lua) and by
-- :checkhealth luxvim. Adding a dependency is a row here, not an edit in
-- three places.

local platform = require("core.lib.platform")

local M = {}

M.manifest = {
  {
    cmd = "nvim",
    min_version = "0.12.0",
    version_args = { "--version" },
    reason = "LuxVim's host editor; nvim-treesitter main requires 0.12+",
    bootstrap = true,
    hints = {
      linux = "your package manager, e.g. `pacman -S neovim` or `apt install neovim`",
      mac = "brew install neovim",
      windows = "winget install Neovim.Neovim",
    },
  },
  {
    cmd = "git",
    version_args = { "--version" },
    reason = "clones lazy.nvim and every plugin",
    bootstrap = true,
    hints = {
      linux = "your package manager, e.g. `pacman -S git` or `apt install git`",
      mac = "xcode-select --install",
      windows = "winget install Git.Git",
    },
  },
  {
    cmd = "tree-sitter",
    min_version = "0.26.1",
    version_args = { "--version" },
    reason = "compiles treesitter parsers (:TSInstall / :TSUpdate). Without it "
      .. "every parser build fails and syntax highlighting is dead",
    hints = {
      linux = "your package manager, e.g. `pacman -S tree-sitter-cli` or " .. "`apt install tree-sitter-cli` (NOT npm)",
      mac = "brew install tree-sitter (NOT npm)",
      windows = "scoop install tree-sitter (NOT npm)",
    },
  },
  {
    cmd = "curl",
    version_args = { "--version" },
    reason = "downloads parser grammars for nvim-treesitter",
    hints = {
      linux = "your package manager, e.g. `pacman -S curl` or `apt install curl`",
      mac = "preinstalled; reinstall with `brew install curl`",
      windows = "preinstalled on Windows 10+; otherwise `winget install cURL.cURL`",
    },
  },
  {
    cmd = "tar",
    version_args = { "--version" },
    reason = "unpacks downloaded parser grammars",
    hints = {
      linux = "your package manager, e.g. `pacman -S tar` or `apt install tar`",
      mac = "preinstalled",
      windows = "preinstalled on Windows 10+",
    },
  },
  {
    cmd = "cc",
    alternatives = { "cc", "gcc", "clang", "cl" },
    version_args = { "--version" },
    reason = "C compiler used by the treesitter CLI to build parsers",
    hints = {
      linux = "your package manager, e.g. `pacman -S gcc` or `apt install build-essential`",
      mac = "xcode-select --install",
      windows = "install Visual Studio Build Tools, or `scoop install gcc`",
    },
  },
}

--- Extracts a {major, minor, patch} triple from arbitrary --version output.
--- Returns nil when no version-looking number is present.
function M.parse_version(str)
  if type(str) ~= "string" then
    return nil
  end
  local major, minor, patch = str:match("(%d+)%.(%d+)%.(%d+)")
  if not major then
    major, minor = str:match("(%d+)%.(%d+)")
    patch = "0"
  end
  if not major then
    return nil
  end
  return { tonumber(major), tonumber(minor), tonumber(patch) }
end

--- Compares two {major, minor, patch} triples numerically.
function M.compare(a, b)
  for i = 1, 3 do
    local left, right = a[i] or 0, b[i] or 0
    if left < right then
      return -1
    elseif left > right then
      return 1
    end
  end
  return 0
end

--- True when `found_str` parses to a version >= `min_str`.
--- Unparseable output is treated as NOT ok — never assume it is fine.
function M.version_ok(found_str, min_str)
  local found = M.parse_version(found_str)
  local min = M.parse_version(min_str)
  if not found or not min then
    return false
  end
  return M.compare(found, min) >= 0
end

--- Determines whether a dependency check result is fatal for installer gates.
--- Missing dependencies are ALWAYS fatal (including git, nvim, tree-sitter, etc.).
--- Outdated dependencies are fatal UNLESS the row is nvim: Neovim's 0.12.0 floor
--- is advisory while the 0.10-vs-0.12 support policy remains unresolved.
--- Unknown versions remain non-fatal.
function M.is_fatal(result)
  if result.status == "missing" then
    return true
  elseif result.status == "outdated" and result.cmd ~= "nvim" then
    return true
  end
  return false
end

M.FIELD_SEP = "\t"

--- Formats a single dependency check result's human-readable message.
function M.format_message(result)
  if result.status == "ok" then
    return result.reason
  elseif result.status == "missing" then
    return ("not found — %s. Install via %s"):format(result.reason, result.hint)
  elseif result.status == "outdated" then
    return ("%s is older than the required %s — %s. Update via %s"):format(
      result.version or "?",
      result.min_version or "?",
      result.reason,
      result.hint
    )
  else
    return ("found at %s but its version could not be determined"):format(result.path or "?")
  end
end

--- Renders check_all() results into installer wire-format lines.
--- Returns lines (table of tab-delimited strings) and failed (boolean).
function M.report(results)
  local lines = {}
  local failed = false
  for _, result in ipairs(results) do
    if M.is_fatal(result) then
      failed = true
    end
    local message = M.format_message(result)
    table.insert(
      lines,
      table.concat({
        result.status,
        result.cmd,
        result.version or "-",
        message,
      }, M.FIELD_SEP)
    )
  end
  return lines, failed
end

--- The install hint for the current OS.
function M.hint(row)
  return (row.hints and row.hints[platform.os]) or "see the project README"
end

--- Default PATH resolution. Returns nil rather than "" when absent.
local function default_resolve(cmd)
  local path = vim.fn.exepath(cmd)
  if path == nil or path == "" then
    return nil
  end
  return path
end

--- Default version probe. Returns combined stdout+stderr; some tools
--- (notably older compilers) print --version to stderr.
local function default_probe(path, args)
  local cmd = { path }
  for _, a in ipairs(args or {}) do
    table.insert(cmd, a)
  end
  local ok, result = pcall(function()
    return vim.system(cmd, { text = true, timeout = 5000 }):wait()
  end)
  if not ok or not result then
    return nil
  end
  return (result.stdout or "") .. (result.stderr or "")
end

--- Resolves one manifest row against the environment.
--- opts.resolve / opts.probe are injectable so tests never depend on
--- what happens to be installed on the machine running them.
function M.check(row, opts)
  opts = opts or {}
  local resolve = opts.resolve or default_resolve
  local probe = opts.probe or default_probe

  local candidates = row.alternatives or { row.cmd }
  local path
  for _, candidate in ipairs(candidates) do
    path = resolve(candidate)
    if path then
      break
    end
  end

  local result = {
    cmd = row.cmd,
    path = path,
    reason = row.reason,
    hint = M.hint(row),
    bootstrap = row.bootstrap or false,
  }

  if not path then
    result.status = "missing"
    return result
  end

  local output = probe(path, row.version_args)
  local parsed = M.parse_version(output)
  result.version = parsed and table.concat({ parsed[1], parsed[2], parsed[3] }, ".") or nil

  if not row.min_version then
    result.status = "ok"
    return result
  end

  if M.version_ok(output, row.min_version) then
    result.status = "ok"
  elseif parsed then
    result.status = "outdated"
    result.min_version = row.min_version
  else
    result.status = "unknown"
  end

  return result
end

--- Resolves every manifest row. Order matches the manifest.
function M.check_all(opts)
  opts = opts or {}
  local manifest = opts.manifest or M.manifest
  local results = {}
  for _, row in ipairs(manifest) do
    table.insert(results, M.check(row, opts))
  end
  return results
end

return M
