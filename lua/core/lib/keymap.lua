local actions = require("core.lib.actions")
local registry = require("core.lib.registry")

local M = {}

function M.register_one(mapping)
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
      vim.keymap.set(m, mapping.lhs, rhs, opts)
    end
  else
    vim.keymap.set(mode, mapping.lhs, rhs, opts)
  end
end

local function register_all(entries)
  for section_name, section in pairs(entries) do
    for _, mapping in ipairs(section) do
      M.register_one(mapping)
    end
  end
end

local keymap_registry = registry.new({
  name = "keymaps",
  framework_module = "core.registry.keymaps",
  user_file = "registry/keymaps.lua",
  register = register_all,
})

function M.setup()
  keymap_registry:setup()
end

return M
