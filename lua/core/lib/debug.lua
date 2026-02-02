local M = {}

local _luxvim_root = nil

function M.get_luxvim_root()
  if _luxvim_root then
    return _luxvim_root
  end

  local info = debug.getinfo(1, "S")
  if info and info.source and info.source:sub(1, 1) == "@" then
    local this_file = info.source:sub(2)
    _luxvim_root = vim.fn.fnamemodify(this_file, ":p:h:h:h:h")
    if vim.fn.isdirectory(_luxvim_root .. "/debug") == 1 then
      return _luxvim_root
    end
  end

  for _, path in ipairs(vim.opt.runtimepath:get()) do
    if vim.fn.isdirectory(path .. "/debug") == 1 and vim.fn.filereadable(path .. "/init.lua") == 1 then
      _luxvim_root = path
      return _luxvim_root
    end
  end

  _luxvim_root = vim.fn.getcwd()
  return _luxvim_root
end

function M.extract_plugin_name(source)
  return source:match("([^/]+)$")
end

function M.get_debug_path(plugin_name)
  return M.get_luxvim_root() .. "/debug/" .. plugin_name
end

function M.has_debug_plugin(plugin_name)
  local debug_path = M.get_debug_path(plugin_name)
  local stat = vim.uv.fs_stat(debug_path)
  if not stat or stat.type ~= "directory" then
    return false
  end

  local plugin_dir = debug_path .. "/plugin"
  local lua_dir = debug_path .. "/lua"
  local plugin_stat = vim.uv.fs_stat(plugin_dir)
  local lua_stat = vim.uv.fs_stat(lua_dir)

  return (plugin_stat and plugin_stat.type == "directory")
      or (lua_stat and lua_stat.type == "directory")
end

function M.resolve_debug_name(spec)
  if spec.debug_name then
    return spec.debug_name
  end
  return M.extract_plugin_name(spec.source)
end

function M.list_debug_plugins()
  local debug_dir = M.get_luxvim_root() .. "/debug"
  local handle = vim.uv.fs_scandir(debug_dir)
  if not handle then
    return {}
  end

  local plugins = {}
  while true do
    local name, type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if (type == "directory" or type == "link") and M.has_debug_plugin(name) then
      table.insert(plugins, name)
    end
  end
  return plugins
end

return M
