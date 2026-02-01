local actions = require("core.lib.actions")

local M = {}

function M.register_all(registry)
  for section_name, section in pairs(registry) do
    for lhs, mapping in pairs(section) do
      M.register_one(lhs, mapping, section_name)
    end
  end
end

function M.register_one(lhs, mapping, section)
  local mode = mapping.mode or "n"
  local desc = mapping.desc or mapping.action

  local rhs = function()
    actions.invoke(mapping.action)
  end

  local opts = {
    desc = desc,
    silent = true,
    noremap = true,
  }

  if type(mode) == "table" then
    for _, m in ipairs(mode) do
      vim.keymap.set(m, lhs, rhs, opts)
    end
  else
    vim.keymap.set(mode, lhs, rhs, opts)
  end
end

function M.setup()
  local ok, registry = pcall(require, "core.registry.keymaps")
  if not ok then
    vim.notify("[LuxVim] Failed to load keymap registry: " .. tostring(registry), vim.log.levels.WARN)
    return
  end

  actions.register_core_actions()
  M.register_all(registry)
end

return M
