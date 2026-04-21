local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")

local M = {}

function M.get_vendor_root()
  local root = vim.env.LUXVIM_ROOT or debug_mod.get_luxvim_root()
  return paths.join(root, "vendor", "plugins")
end

function M.get_vendored_path(plugin_name)
  return paths.join(M.get_vendor_root(), plugin_name)
end

function M.has_vendored_plugin(plugin_name)
  local path = M.get_vendored_path(plugin_name)
  local stat = vim.uv.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

return M
