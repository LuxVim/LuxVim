local M = {}
local notify = require("core.lib.notify")

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

  local debug_mod = require("core.lib.debug")
  local plugin_name = debug_mod.resolve_debug_name(spec)
  for action_name, fn in pairs(spec.actions) do
    if type(fn) == "string" and fn:sub(1, 1) == ":" then
      local cmd = fn:sub(2)
      fn = function()
        vim.cmd(cmd)
      end
    elseif type(fn) ~= "function" then
      notify.warn("Invalid action type for " .. plugin_name .. "." .. action_name .. ": expected function or :command string")
      fn = nil
    end
    if fn then
      M.register(plugin_name, action_name, fn)
    end
  end
end

local function split_action(action_string)
  for ns, _ in pairs(M._registry) do
    if action_string:sub(1, #ns + 1) == ns .. "." then
      return ns, action_string:sub(#ns + 2)
    end
  end

  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  return namespace, method
end

function M.resolve(action_string)
  if M._cache[action_string] then
    return M._cache[action_string]
  end

  local namespace, method = split_action(action_string)
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
    notify.warn(err)
    return false
  end

  local ok, result = pcall(fn)
  if not ok then
    notify.error("Action error: " .. tostring(result))
    return false
  end
  return true
end

function M.register_core_actions()
  local core_actions = require("core.registry.actions")

  for _, group in pairs(core_actions) do
    for name, fn in pairs(group) do
      if type(fn) == "string" and fn:sub(1, 1) == ":" then
        local cmd = fn:sub(2)
        M.register("core", name, function()
          vim.cmd(cmd)
        end)
      elseif type(fn) == "function" then
        M.register("core", name, fn)
      end
    end
  end
end

return M
