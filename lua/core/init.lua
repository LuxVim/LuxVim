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

  for _, spec in ipairs(loader._specs) do
    actions.register_from_spec(spec)
  end

  keymap.setup()
  autocmd.setup()

  M._create_commands()

  return true
end

function M._create_commands()
  vim.api.nvim_create_user_command("LuxVimErrors", function()
    local loader = require("core.lib.loader")
    local errors = loader.get_errors()
    local warnings = loader.get_warnings()

    if #errors == 0 and #warnings == 0 then
      print("No errors or warnings")
      return
    end

    print("=== LuxVim Errors ===")
    for _, e in ipairs(errors) do
      print(string.format("[%s] %s: %s", e.level:upper(), e.file, e.message))
    end

    print("\n=== LuxVim Warnings ===")
    for _, w in ipairs(warnings) do
      print(string.format("[%s] %s: %s", w.level:upper(), w.file, w.message))
    end
  end, { desc = "Show LuxVim errors and warnings" })

  vim.api.nvim_create_user_command("LuxDevStatus", function()
    local debug_mod = require("core.lib.debug")
    local plugins = debug_mod.list_debug_plugins()

    print("LuxVim Development Status")
    print("============================")

    if #plugins == 0 then
      print("No debug plugins found in /debug directory")
    else
      print("Active debug plugins:")
      for _, plugin in ipairs(plugins) do
        local path = debug_mod.get_debug_path(plugin)
        print("  " .. plugin .. " -> " .. path)
      end
    end
  end, { desc = "Show LuxVim development status" })
end

return M
