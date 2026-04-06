local M = {}
local notify = require("core.lib.notify")

M._registry = {}

function M.register(namespace, name, fn)
  M._registry[namespace] = M._registry[namespace] or {}
  M._registry[namespace][name] = fn
end

function M.register_namespace(namespace, actions_table)
  for name, fn in pairs(actions_table) do
    M.register(namespace, name, fn)
  end
end

function M.unregister(namespace, name)
  if M._registry[namespace] then
    M._registry[namespace][name] = nil
  end
end

local function split_action(action_string)
  -- Longest-prefix match against registered namespaces.
  -- Namespaces can contain dots (e.g., "fzf.vim"), so simple first-dot
  -- split would break. Sort by length descending for longest match.
  local sorted_ns = vim.tbl_keys(M._registry)
  table.sort(sorted_ns, function(a, b) return #a > #b end)

  for _, ns in ipairs(sorted_ns) do
    local prefix = ns .. "."
    if action_string:sub(1, #prefix) == prefix then
      return ns, action_string:sub(#prefix + 1)
    end
  end

  -- Fallback: simple dot split for unregistered namespaces
  local namespace, method = action_string:match("^([^.]+)%.(.+)$")
  return namespace, method
end

function M.resolve(action_string)
  local namespace, method = split_action(action_string)
  if not namespace or not method then
    return nil, "invalid action format: " .. action_string
  end

  if M._registry[namespace] and M._registry[namespace][method] then
    return M._registry[namespace][method]
  end

  return nil, "unregistered action: " .. action_string
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

return M
