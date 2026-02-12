local M = {}

function M.setup()
  local bootstrap = require("core.lib.bootstrap")
  local loader = require("core.lib.loader")
  local keymap = require("core.lib.keymap")
  local autocmd = require("core.lib.autocmd")
  local actions = require("core.lib.actions")

  loader.discover_all()

  if not loader.report_errors() then
    return false
  end

  local lazy_specs = loader.get_lazy_specs()
  bootstrap.setup_lazy(lazy_specs)

  actions.register_core_actions()

  local discover = require("core.lib.discover")
  for _, spec in ipairs(discover._specs) do
    actions.register_from_spec(spec)
  end

  keymap.setup()
  autocmd.setup()

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
    local loader = require("core.lib.loader")
    local errors = loader.get_errors()
    local warnings = loader.get_warnings()

    if #errors == 0 and #warnings == 0 then
      notify.info("No errors or warnings")
      return
    end

    local lines = { "=== LuxVim Errors ===" }
    for _, e in ipairs(errors) do
      table.insert(lines, string.format("[%s] %s: %s", e.level:upper(), e.file, e.message))
    end
    table.insert(lines, "\n=== LuxVim Warnings ===")
    for _, w in ipairs(warnings) do
      table.insert(lines, string.format("[%s] %s: %s", w.level:upper(), w.file, w.message))
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
