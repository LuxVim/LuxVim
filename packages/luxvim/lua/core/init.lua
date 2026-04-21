local M = {}

local function report_fatal_message(message)
  local msg = "[LuxVim] FATAL: Cannot start\n  " .. tostring(message):gsub("\n", "\n  ") .. "\n"
  vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
  return false
end

local function setup_pipeline()
  local pipeline = require("core.lib.pipeline")
  local discover = require("core.lib.pipeline.discover")
  local load_stage = require("core.lib.pipeline.load")
  local validate_stage = require("core.lib.pipeline.validate")
  local transform = require("core.lib.pipeline.transform")

  local merge = require("core.lib.pipeline.merge")

  pipeline.register_stage("discover", discover.run)
  pipeline.register_stage("load", load_stage.run)
  pipeline.register_stage("merge", merge.run)
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
  -- Prepend user config lua/ to package.path for require() overrides
  local data = require("core.lib.data")
  local user_config = data.user_config_path()
  local user_lua = user_config .. "/lua"
  if vim.uv.fs_stat(user_lua) then
    package.path = user_lua .. "/?.lua;" .. user_lua .. "/?/init.lua;" .. package.path
  end

  -- Load user init.lua early (schema extensions, pipeline hooks)
  local user_init = user_config .. "/init.lua"
  if vim.uv.fs_stat(user_init) then
    dofile(user_init)
  end

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

  -- Register actions from all specs (including virtual ones)
  for _, spec in ipairs(result.raw_specs) do
    actions.register_from_spec(spec)
  end

  -- Run config functions for virtual specs directly — they have no plugin code
  -- so lazy.nvim doesn't handle them. This runs at a deterministic time during
  -- framework setup, before keymaps are bound.
  for _, spec in ipairs(result.raw_specs) do
    if spec.source == "virtual" and spec.config then
      local ok, err = pcall(spec.config, nil, spec.opts)
      if not ok then
        require("core.lib.notify").warn("Virtual spec config error: " .. tostring(err))
      end
    end
  end

  local ok, err = keymap.setup()
  if not ok then
    return report_fatal_message(err)
  end

  ok, err = autocmd.setup()
  if not ok then
    return report_fatal_message(err)
  end

  M._result = result
  M._create_commands()

  return true
end

function M._create_commands()
  local notify = require("core.lib.notify")

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

  vim.api.nvim_create_user_command("LuxVimGenerateTypes", function()
    local typegen = require("core.lib.typegen")
    typegen.write()
  end, { desc = "Generate LuxVim type annotations" })

  vim.api.nvim_create_user_command("LuxVimValidate", function()
    local result = M.validate_only()

    if #result.errors == 0 and #result.warnings == 0 then
      notify.info("LuxVim config validates cleanly")
      return
    end

    local lines = { "=== LuxVim Validate ===" }
    for _, e in ipairs(result.errors) do
      table.insert(lines, string.format("[%s] %s: %s",
        (e.level or "error"):upper(), e.file or "unknown", e.message))
    end
    for _, w in ipairs(result.warnings) do
      table.insert(lines, string.format("[WARNING] %s: %s",
        w.file or "unknown", w.message))
    end

    notify.warn(table.concat(lines, "\n"))
  end, { desc = "Validate LuxVim config without applying" })
end

function M._run_validate_only()
  local pipeline_mod = require("core.lib.pipeline")
  local discover = require("core.lib.pipeline.discover")
  local load_stage = require("core.lib.pipeline.load")
  local merge = require("core.lib.pipeline.merge")
  local validate_stage = require("core.lib.pipeline.validate")

  local p = pipeline_mod.new()
  p:register_stage("discover", discover.run)
  p:register_stage("load", load_stage.run)
  p:register_stage("merge", merge.run)
  p:register_stage("validate", validate_stage.run)
  return p:run()
end

function M.validate_only()
  return M._run_validate_only()
end

function M.validate_only_or_exit()
  local result = M._run_validate_only()

  local lines = {}
  for _, e in ipairs(result.errors) do
    table.insert(lines, string.format("[%s] %s: %s",
      (e.level or "error"):upper(), e.file or "unknown", e.message))
  end
  for _, w in ipairs(result.warnings) do
    table.insert(lines, string.format("[WARNING] %s: %s",
      w.file or "unknown", w.message))
  end

  if #lines == 0 then
    io.stdout:write("OK: no errors or warnings\n")
  else
    io.stdout:write(table.concat(lines, "\n") .. "\n")
  end

  local critical = vim.tbl_filter(function(e)
    return e.level == "critical"
  end, result.errors)

  if #critical > 0 then
    os.exit(1)
  end
  os.exit(0)
end

return M
