-- lua/luxvim/health.lua
-- :checkhealth luxvim
--
-- Surfaces the failure modes that are otherwise silent:
--   1. a missing/outdated external dependency (notably the tree-sitter CLI,
--      without which every parser build fails)
--   2. a declared language whose parser is missing, unknown to upstream, or
--      whose declaration does not load — the gap that let treesitter be dead
--      for a whole language while health reported a parser count and nothing
--      else, because nothing declared which languages were expected
--   3. a treesitter failure recorded during this session, since the FileType
--      warning fires once per filetype and then never again
--   4. a treesitter query that inherits from, or injects, a language that
--      is not installed — which :TSInstall itself reports as success

local M = {}

local function check_dependencies()
  vim.health.start("LuxVim: external dependencies")

  local deps = require("core.lib.deps")
  for _, result in ipairs(deps.check_all()) do
    local label = result.cmd .. (result.version and (" " .. result.version) or "")
    if result.status == "ok" then
      vim.health.ok(label .. " — " .. result.reason)
    elseif result.status == "missing" then
      vim.health.error(result.cmd .. " not found — " .. result.reason, { "Install via " .. result.hint })
    elseif result.status == "outdated" then
      vim.health.error(
        ("%s is %s, but %s or later is required — %s"):format(
          result.cmd,
          result.version or "?",
          result.min_version or "?",
          result.reason
        ),
        { "Update via " .. result.hint }
      )
    else
      vim.health.warn(label .. " found at " .. (result.path or "?") .. " but its version could not be determined")
    end
  end
end

--- The declared language set, and whether reality matches it.
---
--- This section exists because of a bug it would have caught immediately: go
--- had no parser, treesitter was dead in every Go buffer for a whole session,
--- and health reported "6 parsers installed" and called it a day. With nothing
--- declaring which languages LuxVim supports, "installed" had nothing to be
--- measured against, so a missing parser and an unwanted one looked identical.
local function check_languages()
  vim.health.start("LuxVim: languages")

  local languages = require("core.lib.languages")
  local rows, errors = languages.load()

  for _, err in ipairs(errors) do
    vim.health.error(("%s: %s"):format(err.file, err.message), {
      "Fix or remove the declaration — until then that language is unconfigured",
    })
  end

  if #rows == 0 then
    vim.health.error(
      "no languages are declared, so nothing is provisioned, no filetype "
        .. "options are applied, and every check below examines nothing",
      { "Expected declarations in lua/languages/*.lua" }
    )
    return
  end

  local names = vim.tbl_map(function(row)
    return row.name
  end, rows)
  vim.health.ok(("%d languages declared: %s"):format(#rows, table.concat(names, ", ")))

  -- A parser name that upstream does not recognize can never be installed, so
  -- it would otherwise sit in the missing list forever looking like a build
  -- failure. Guarded by pcall: nvim-treesitter is absent under `nvim -l`.
  local has_upstream, available = pcall(function()
    return require("nvim-treesitter.config").get_available()
  end)
  if has_upstream then
    for _, row in ipairs(rows) do
      if row.parser and not vim.tbl_contains(available, row.parser) then
        vim.health.error(
          ("%s declares parser '%s', which nvim-treesitter does not provide"):format(row._file or row.name, row.parser),
          { "Check the spelling against :TSInstall <Tab>" }
        )
      end
    end
  end

  local missing = languages.missing_parsers(rows)
  if #missing == 0 then
    vim.health.ok("every declared parser is installed")
  else
    vim.health.error(
      ("%d declared %s not installed: %s"):format(
        #missing,
        #missing == 1 and "parser is" or "parsers are",
        table.concat(missing, ", ")
      ),
      {
        "Run :LuxVimInstallParsers",
        "If installs fail, check the tree-sitter CLI above",
      }
    )
  end

  -- The durable half of the runtime report. The FileType warning fires once
  -- per filetype per session by design; without this, a failure noticed at
  -- 09:00 leaves no trace to inspect at 17:00, which is precisely how a dead
  -- parser passed for a transient blip.
  local failures = require("core.lib.treesitter_report").failures
  local failed_filetypes = vim.tbl_keys(failures)
  table.sort(failed_filetypes)
  for _, filetype in ipairs(failed_filetypes) do
    local failure = failures[filetype]
    vim.health.warn(
      ("treesitter failed to start for '%s' (language '%s') earlier in this session"):format(filetype, failure.lang),
      { tostring(failure.error or "no detail recorded") }
    )
  end
end

local function check_treesitter()
  vim.health.start("LuxVim: treesitter")

  local data = require("core.lib.data")
  local parsers = require("core.lib.parsers")
  local install_dir = data.parser_path()

  vim.health.info("install_dir: " .. install_dir)

  local on_rtp = false
  for _, entry in ipairs(vim.opt.runtimepath:get()) do
    if vim.fn.fnamemodify(entry, ":p") == vim.fn.fnamemodify(install_dir, ":p") then
      on_rtp = true
    end
  end
  if on_rtp then
    vim.health.ok("install_dir is on the runtimepath")
  else
    vim.health.error(
      "install_dir is not on the runtimepath — installed parsers " .. "and queries will not be found",
      {
        "Confirm nvim-treesitter's setup() ran with install_dir set " .. "(lua/plugins/editor/treesitter.lua)",
      }
    )
  end

  local installed = vim.tbl_keys(parsers.installed_parsers(install_dir))
  table.sort(installed)
  if #installed == 0 then
    vim.health.error("no parsers are installed", {
      "Run :TSInstall <language>",
      "If installs fail, check the tree-sitter CLI above",
    })
  else
    vim.health.ok(("%d parsers installed: %s"):format(#installed, table.concat(installed, ", ")))
  end

  local inherit_gaps = parsers.inherit_gaps(install_dir)
  if #inherit_gaps == 0 then
    vim.health.ok("every inherited query language is installed")
  else
    for _, gap in ipairs(inherit_gaps) do
      vim.health.warn(
        ("%s/%s.scm inherits '%s', which is not installed — those captures are inactive"):format(
          gap.lang,
          gap.kind,
          gap.missing
        ),
        { "Run :TSInstall " .. gap.missing }
      )
    end
  end

  -- Injected languages are grouped into ONE line rather than one warning per
  -- gap. ecma/injections.scm alone injects ~8 niche languages (jsdoc, regex,
  -- glimmer, groq, ...) that almost nobody installs; emitting a warning each
  -- buries the signal and trains people to ignore this report. Unlike an
  -- inherit gap, a missing injection degrades gracefully — the host language
  -- still highlights — so this is informational, not a warning.
  local injection_gaps = parsers.injection_gaps(install_dir)
  if #injection_gaps == 0 then
    vim.health.ok("every injected language has a parser")
  else
    local missing = {}
    local seen = {}
    for _, gap in ipairs(injection_gaps) do
      if not seen[gap.missing] then
        seen[gap.missing] = true
        table.insert(missing, gap.missing)
      end
    end
    table.sort(missing)
    -- NOTE: vim.health.info(msg) takes ONE argument — unlike warn/error it
    -- accepts no advice table, so the suggestion is folded into the message.
    vim.health.info(
      (
        "%d injected languages have no parser; embedded blocks of these stay "
        .. "unhighlighted: %s. Install any you care about with :TSInstall <language>"
      ):format(#missing, table.concat(missing, ", "))
    )
  end
end

function M.check()
  check_dependencies()
  check_languages()
  check_treesitter()
end

return M
