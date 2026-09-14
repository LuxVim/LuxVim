-- lua/core/lib/provision.lua
-- Makes the declared parsers exist.
--
-- This is the step LuxVim never had. install.sh synced plugins and stopped;
-- the treesitter spec's `build = ":TSUpdate"` updates parsers that are already
-- installed and is a no-op when there are none. So a fresh install shipped
-- zero parsers, treesitter was dead for every language, and the only signal
-- was a one-time warning per filetype.
--
-- Called twice, from the same declarations:
--   * install.sh, blocking, so a new install arrives with its parsers built
--   * startup, non-blocking, so adding a language file is enough on its own
--
-- Non-blocking is not optional at startup: installing a parser compiles C.

local M = {}

--- The user command that runs the blocking path. Named here rather than at
--- the call sites so the installers, the runtime registration, and the drift
--- guard between them all read the same string.
M.COMMAND = "LuxVimInstallParsers"

--- Timeout for the blocking path. Compiling a couple dozen grammars on a cold
--- machine is minutes, not seconds.
M.BOOTSTRAP_TIMEOUT_MS = 600000

function M.default_deps()
  local languages = require("core.lib.languages")
  local notify = require("core.lib.notify")

  return {
    missing = function()
      return languages.missing_parsers(languages.rows())
    end,
    install = function(langs)
      -- The upstream installed check also counts query directories. This set
      -- already excludes resolvable binaries, so force repairs incomplete installs.
      return require("nvim-treesitter").install(langs, { force = true })
    end,
    info = notify.info,
    warn = notify.warn,
  }
end

--- Installs every declared parser that is not resolvable.
---
--- `opts.wait_ms` blocks until the install finishes — for `nvim --headless`
--- bootstrap, where exiting early would leave the parsers half-built. Omit it
--- everywhere else.
---
--- Returns the list of languages it acted on ({} when nothing was missing),
--- plus an error for an immediate or blocking failure. Background errors arrive
--- through `opts.on_complete(installed, err)`, scheduled after the attempt settles.
--- `installed` includes only requested parsers that now resolve, even on failure.
--- Every failure path warns rather than throwing: a broken tree-sitter CLI
--- must not take the editor's startup down with it. The blocking command decides
--- whether a failure should exit a headless process.
function M.ensure(deps, opts)
  deps = deps or M.default_deps()
  opts = opts or {}

  local function complete(installed, err)
    if err then
      deps.warn(err)
    end
    if opts.on_complete then
      vim.schedule(function()
        local ok, callback_err = pcall(opts.on_complete, installed, err)
        if not ok then
          deps.warn("treesitter provisioning callback failed: " .. tostring(callback_err))
        end
      end)
    end
    return err
  end

  local ok, missing = pcall(deps.missing)
  if not ok then
    return {}, complete({}, "could not determine which treesitter parsers are missing: " .. tostring(missing))
  end

  if #missing == 0 then
    return {}
  end

  deps.info(("installing %d missing treesitter parser(s): %s"):format(#missing, table.concat(missing, ", ")))

  local started, task = pcall(deps.install, missing)
  if not started or not task then
    return missing,
      complete({}, "treesitter parser install failed: " .. tostring(started and "installer returned no task" or task))
  end

  local function finish(task_err, result)
    local errors = {}
    if task_err then
      table.insert(errors, "treesitter parser install did not complete: " .. tostring(task_err))
    elseif result ~= true then
      -- Task:wait() returns false for build/download failures without throwing.
      table.insert(errors, "treesitter parser install failed")
    end

    local installed, unresolved = {}, {}
    local resolved, remaining = pcall(deps.missing)
    if not resolved then
      table.insert(errors, "could not verify treesitter parsers: " .. tostring(remaining))
    else
      for _, lang in ipairs(missing) do
        if vim.tbl_contains(remaining, lang) then
          table.insert(unresolved, lang)
        else
          table.insert(installed, lang)
        end
      end
      if #unresolved > 0 then
        table.insert(errors, "treesitter parsers still missing: " .. table.concat(unresolved, ", "))
      end
    end

    return complete(installed, #errors > 0 and table.concat(errors, "; ") or nil)
  end

  if opts.wait_ms then
    local waited, result = pcall(function()
      return task:wait(opts.wait_ms)
    end)
    return missing, finish(not waited and result or nil, result)
  end

  local watching, err = pcall(function()
    task:await(function(task_err, result)
      -- Completion can run inside a libuv callback; resolve parsers and notify
      -- only after returning to Neovim's main loop.
      vim.schedule(function()
        finish(task_err, result)
      end)
    end)
  end)
  if not watching then
    return missing, complete({}, "could not watch treesitter parser install: " .. tostring(err))
  end

  return missing
end

return M
