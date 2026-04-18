local paths = require("core.lib.paths")
local debug_mod = require("core.lib.debug")

local M = {}

local _root

function M.root()
  if _root then
    return _root
  end
  _root = vim.env.LUXVIM_ROOT or debug_mod.get_luxvim_root()
  return _root
end

function M.state_root()
  return vim.fn.stdpath("data")
end

function M.lazy_path()
  return paths.join(M.state_root(), "lazy", "lazy.nvim")
end

function M.lazy_root()
  return paths.join(M.state_root(), "lazy")
end

function M.lockfile_path()
  return paths.join(M.root(), "lazy-lock.json")
end

function M.luxlsp_path()
  return paths.join(M.state_root(), "luxlsp")
end

function M.parser_path()
  return paths.join(M.state_root(), "site")
end

function M.installed_themes_path()
  return paths.join(M.state_root(), "installed-themes.json")
end

function M.dynamic_specs_dir()
  return paths.join(M.state_root(), "dynamic-specs")
end

function M.user_config_path()
  if vim.env.LUXVIM_CONFIG and vim.env.LUXVIM_CONFIG ~= "" then
    return vim.env.LUXVIM_CONFIG
  end
  local base = vim.env.XDG_CONFIG_HOME or paths.join(vim.env.HOME or "", ".config")
  return paths.join(base, "LuxVim")
end

return M
