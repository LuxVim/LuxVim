local paths = require("core.lib.paths")

local M = {}

local _luxvim_root = nil

function M._is_luxvim_root(candidate)
  return vim.fn.filereadable(paths.join(candidate, "init.lua")) == 1
      and vim.fn.isdirectory(paths.join(candidate, "lua", "core")) == 1
end

function M.get_luxvim_root()
  if _luxvim_root then
    return _luxvim_root
  end

  local info = debug.getinfo(1, "S")
  if info and info.source and info.source:sub(1, 1) == "@" then
    local this_file = info.source:sub(2)
    local candidate = paths.normalize(vim.fn.fnamemodify(this_file, ":p:h:h:h:h"))
    if M._is_luxvim_root(candidate) then
      _luxvim_root = candidate
      return _luxvim_root
    end
  end

  for _, path in ipairs(vim.opt.runtimepath:get()) do
    local normalized = paths.normalize(path)
    if M._is_luxvim_root(normalized) then
      _luxvim_root = normalized
      return _luxvim_root
    end
  end

  _luxvim_root = paths.normalize(vim.fn.getcwd())
  return _luxvim_root
end

function M.get_debug_path(plugin_name)
  return paths.join(M.get_luxvim_root(), "debug", plugin_name)
end

function M.has_debug_plugin(plugin_name)
  local debug_path = M.get_debug_path(plugin_name)
  local stat = vim.uv.fs_stat(debug_path)
  if not stat or stat.type ~= "directory" then
    return false
  end

  local plugin_dir = paths.join(debug_path, "plugin")
  local lua_dir = paths.join(debug_path, "lua")
  local plugin_stat = vim.uv.fs_stat(plugin_dir)
  local lua_stat = vim.uv.fs_stat(lua_dir)

  return (plugin_stat and plugin_stat.type == "directory")
      or (lua_stat and lua_stat.type == "directory")
end

function M.resolve_debug_name(spec)
  if spec.debug_name then
    return spec.debug_name
  end
  return paths.basename(spec.source)
end

function M.list_debug_plugins()
  local debug_dir = paths.join(M.get_luxvim_root(), "debug")

  local entries = paths.scandir(debug_dir, function(name, entry_type)
    return (entry_type == "directory" or entry_type == "link") and M.has_debug_plugin(name)
  end)

  local plugins = {}
  for _, entry in ipairs(entries) do
    table.insert(plugins, entry.name)
  end
  return plugins
end

return M
