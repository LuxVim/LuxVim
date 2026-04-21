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

function M.resolve_debug_name(spec)
  if spec.debug_name then
    return spec.debug_name
  end
  return paths.basename(spec.source)
end

return M
