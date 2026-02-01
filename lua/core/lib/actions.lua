local M = {}

M._registry = {}
M._cache = {}

function M.register(namespace, name, fn)
  M._registry[namespace] = M._registry[namespace] or {}
  M._registry[namespace][name] = fn
  M._cache[namespace .. "." .. name] = fn
end

function M.register_from_spec(spec)
  if not spec.actions then
    return
  end

  local plugin_name = spec.debug_name or spec.source:match("([^/]+)$")
  for action_name, fn in pairs(spec.actions) do
    M.register(plugin_name, action_name, fn)
  end
end

function M.resolve(action_string)
  if M._cache[action_string] then
    return M._cache[action_string]
  end

  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  if not namespace or not method then
    return nil, "invalid action format: " .. action_string
  end

  if M._registry[namespace] and M._registry[namespace][method] then
    local fn = M._registry[namespace][method]
    M._cache[action_string] = fn
    return fn
  end

  local ok, module = pcall(require, namespace)
  if ok and type(module) == "table" and type(module[method]) == "function" then
    M._cache[action_string] = function()
      module[method]()
    end
    return M._cache[action_string]
  end

  return nil, "could not resolve action: " .. action_string
end

function M.invoke(action_string)
  local fn, err = M.resolve(action_string)
  if not fn then
    vim.notify("[LuxVim] " .. err, vim.log.levels.WARN)
    return false
  end

  local ok, result = pcall(fn)
  if not ok then
    vim.notify("[LuxVim] Action error: " .. tostring(result), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.register_core_actions()
  M.register("core", "save", function()
    vim.cmd("write")
  end)

  M.register("core", "quit", function()
    vim.cmd("quit")
  end)

  M.register("core", "force_quit", function()
    vim.cmd("quit!")
  end)

  M.register("core", "quit_all", function()
    vim.cmd("quitall!")
  end)

  M.register("core", "save_quit", function()
    vim.cmd("wq")
  end)

  M.register("core", "vsplit", function()
    vim.cmd("rightbelow vs new")
  end)

  M.register("core", "hsplit", function()
    vim.cmd("rightbelow split new")
  end)

  M.register("core", "win1", function()
    vim.cmd("1wincmd w")
  end)

  M.register("core", "win2", function()
    vim.cmd("2wincmd w")
  end)

  M.register("core", "win3", function()
    vim.cmd("3wincmd w")
  end)

  M.register("core", "win4", function()
    vim.cmd("4wincmd w")
  end)

  M.register("core", "win5", function()
    vim.cmd("5wincmd w")
  end)

  M.register("core", "win6", function()
    vim.cmd("6wincmd w")
  end)
end

return M
