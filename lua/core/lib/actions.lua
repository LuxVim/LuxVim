-- lua/core/lib/actions.lua
-- Factory-pattern action registry. Production uses actions.default();
-- tests use actions.new(). Module-level functions forward to default.

local notify = require("core.lib.notify")

local Actions = {}
Actions.__index = Actions

function Actions:register(namespace, name, fn)
  self._registry[namespace] = self._registry[namespace] or {}
  self._registry[namespace][name] = fn
end

function Actions:register_namespace(namespace, actions_table)
  for name, fn in pairs(actions_table) do
    self:register(namespace, name, fn)
  end
end

function Actions:unregister(namespace, name)
  if self._registry[namespace] then
    self._registry[namespace][name] = nil
  end
end

function Actions:_split_action(action_string)
  local sorted_ns = vim.tbl_keys(self._registry)
  table.sort(sorted_ns, function(a, b) return #a > #b end)

  for _, ns in ipairs(sorted_ns) do
    local prefix = ns .. "."
    if action_string:sub(1, #prefix) == prefix then
      return ns, action_string:sub(#prefix + 1)
    end
  end

  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  return namespace, method
end

function Actions:resolve(action_string)
  local namespace, method = self:_split_action(action_string)
  if not namespace or not method then
    return nil, "invalid action format: " .. action_string
  end

  if self._registry[namespace] and self._registry[namespace][method] then
    return self._registry[namespace][method]
  end

  return nil, "unregistered action: " .. action_string
end

function Actions:invoke(action_string)
  local fn, err = self:resolve(action_string)
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

function Actions:register_from_spec(spec)
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
      self:register(plugin_name, action_name, fn)
    end
  end
end

local M = {}

function M.new()
  return setmetatable({ _registry = {} }, Actions)
end

local _default
function M.default()
  if not _default then
    _default = M.new()
  end
  return _default
end

function M.register(ns, name, fn)         return M.default():register(ns, name, fn) end
function M.register_namespace(ns, tbl)    return M.default():register_namespace(ns, tbl) end
function M.unregister(ns, name)           return M.default():unregister(ns, name) end
function M.resolve(str)                   return M.default():resolve(str) end
function M.invoke(str)                    return M.default():invoke(str) end
function M.register_from_spec(spec)       return M.default():register_from_spec(spec) end

-- Expose _registry on the module for tests/tools that inspect the default.
-- Production code should never read this directly.
setmetatable(M, {
  __index = function(_, key)
    if key == "_registry" then
      return M.default()._registry
    end
  end,
})

return M
