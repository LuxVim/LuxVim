local actions = require("core.lib.actions")
local notify = require("core.lib.notify")

local M = {}

function M.register_all(registry)
  for section_name, section in pairs(registry) do
    if section_name == "extends" or section_name == "replaces" then
      goto continue
    end
    if #section > 0 then
      for _, mapping in ipairs(section) do
        M.register_one(mapping.lhs, mapping, section_name)
      end
    else
      for lhs, mapping in pairs(section) do
        M.register_one(lhs, mapping, section_name)
      end
    end
    ::continue::
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

local function merge_registries(framework, user)
  if user.replaces then
    user.replaces = nil
    return user
  end

  if user.extends then
    user.extends = nil
    local merged = vim.deepcopy(framework)
    for section_name, section in pairs(user) do
      if merged[section_name] then
        merged[section_name] = vim.tbl_deep_extend("force", merged[section_name], section)
      else
        merged[section_name] = section
      end
    end
    return merged
  end

  return framework
end

function M.setup()
  local ok, registry = pcall(require, "core.registry.keymaps")
  if not ok then
    notify.warn("Failed to load keymap registry: " .. tostring(registry))
    return
  end

  local data = require("core.lib.data")
  local paths = require("core.lib.paths")
  local user_keymaps_path = paths.join(data.user_config_path(), "registry", "keymaps.lua")
  if vim.uv.fs_stat(user_keymaps_path) then
    local uok, user_registry = pcall(dofile, user_keymaps_path)
    if uok and type(user_registry) == "table" then
      registry = merge_registries(registry, user_registry)
    end
  end

  M.register_all(registry)
end

return M
