local M = {}

local function setup_pipeline()
  local pipeline = require("core.lib.pipeline")
  local discover = require("core.lib.pipeline.discover")
  local load_stage = require("core.lib.pipeline.load")
  local validate_stage = require("core.lib.pipeline.validate")
  local transform = require("core.lib.pipeline.transform")

  pipeline.register_stage("discover", discover.run)
  pipeline.register_stage("load", load_stage.run)
  pipeline.register_stage("validate", validate_stage.run)
  pipeline.register_stage("transform", transform.run)

  return pipeline
end

local function report_errors(result)
  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, result.errors)

  if #critical > 0 then
    local msg = "[LuxVim] FATAL: Cannot start\n"
    for _, e in ipairs(critical) do
      msg = msg .. "  " .. (e.file or "unknown") .. ": " .. e.message .. "\n"
    end
    vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
    return false
  end

  local notify = require("core.lib.notify")
  local non_critical = vim.tbl_filter(function(e)
    return e.level ~= "critical"
  end, result.errors)

  for _, e in ipairs(non_critical) do
    notify.warn("Plugin skipped: " .. (e.file or "unknown") .. "\n  " .. e.message)
  end

  if #result.warnings > 0 then
    vim.defer_fn(function()
      notify.info("Started with " .. #result.warnings .. " warnings. Run :LuxVimErrors for details.")
    end, 100)
  end

  return true
end

function M.setup()
  local pipeline = setup_pipeline()
  local bootstrap = require("core.lib.bootstrap")
  local actions = require("core.lib.actions")
  local keymap = require("core.lib.keymap")
  local autocmd = require("core.lib.autocmd")

  local result = pipeline.run()

  if not report_errors(result) then
    return false
  end

  bootstrap.setup_lazy(result.lazy_specs)

  actions.register_core_actions()

  for _, spec in ipairs(result.raw_specs) do
    actions.register_from_spec(spec)
  end

  keymap.setup()
  autocmd.setup()

  M._result = result
  M._create_commands()

  return true
end

function M._create_commands()
  local notify = require("core.lib.notify")

  vim.api.nvim_create_user_command("SearchText", function()
    local actions = require("core.lib.actions")
    actions.invoke("core.search_text")
  end, { desc = "Search text in current directory" })

  vim.api.nvim_create_user_command("LuxVimErrors", function()
    local errors = M._result and M._result.errors or {}
    local warnings = M._result and M._result.warnings or {}

    if #errors == 0 and #warnings == 0 then
      notify.info("No errors or warnings")
      return
    end

    local lines = { "=== LuxVim Errors ===" }
    for _, e in ipairs(errors) do
      table.insert(lines, string.format("[%s] %s: %s", (e.level or "error"):upper(), e.file or "unknown", e.message))
    end
    table.insert(lines, "\n=== LuxVim Warnings ===")
    for _, w in ipairs(warnings) do
      table.insert(lines, string.format("[%s] %s: %s", "WARNING", w.file or "unknown", w.message))
    end

    notify.warn(table.concat(lines, "\n"))
  end, { desc = "Show LuxVim errors and warnings" })

  vim.api.nvim_create_user_command("LuxDevStatus", function()
    local debug_mod = require("core.lib.debug")
    local plugins = debug_mod.list_debug_plugins()

    local lines = { "LuxVim Development Status", "============================" }

    if #plugins == 0 then
      table.insert(lines, "No debug plugins found in /debug directory")
    else
      table.insert(lines, "Active debug plugins:")
      for _, plugin in ipairs(plugins) do
        local path = debug_mod.get_debug_path(plugin)
        table.insert(lines, "  " .. plugin .. " -> " .. path)
      end
    end

    notify.info(table.concat(lines, "\n"))
  end, { desc = "Show LuxVim development status" })

  vim.api.nvim_create_user_command("LuxVimGenerateTypes", function()
    local typegen = require("core.lib.typegen")
    typegen.write()
  end, { desc = "Generate LuxVim type annotations" })
end

return M
