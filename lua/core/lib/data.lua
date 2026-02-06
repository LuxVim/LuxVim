local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")

local M = {}

local _root

function M.root()
  if _root then
    return _root
  end
  _root = vim.env.XDG_DATA_HOME or debug_mod.get_luxvim_root()
  return _root
end

function M.lazy_path()
  return paths.join(M.root(), "data", "lazy", "lazy.nvim")
end

function M.lazy_root()
  return paths.join(M.root(), "data", "lazy")
end

function M.lockfile_path()
  return paths.join(M.root(), "lazy-lock.json")
end

function M.luxlsp_path()
  return paths.join(M.root(), "data", "luxlsp")
end

function M.parser_path()
  return paths.join(M.root(), "data", "site")
end

return M
