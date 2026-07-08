local actions = require("core.lib.actions")
local registry = require("core.lib.registry")

local M = {}

local function legacy_keymap_error(user_path, section_name)
  return string.format(
    "User keymap config %s section '%s' uses unsupported dict-style entries. Use list-style mappings with explicit lhs, for example %s = { { lhs = '<leader>xx', action = 'core.save', desc = 'Example' } }.",
    user_path,
    section_name,
    section_name
  )
end

local function invalid_mapping_error(section_name, message)
  return string.format("Invalid keymap in section '%s': %s", section_name, message)
end

local function unresolved_action_error(section_name, lhs, action)
  return string.format(
    "Keymap '%s' in section '%s' references unsupported action '%s'. Actions must be registered explicitly; module-backed require() fallback is no longer supported.",
    lhs,
    section_name,
    action
  )
end

local function validate_user_registry(user, user_path)
  for section_name, section in pairs(user) do
    if section_name ~= "extends" and section_name ~= "replaces" then
      if type(section) ~= "table" or not vim.islist(section) then
        return nil, legacy_keymap_error(user_path, section_name)
      end
    end
  end

  return true
end

local function validate_mapping(mapping, section_name)
  if type(mapping) ~= "table" then
    return nil, invalid_mapping_error(section_name, "expected a table entry")
  end

  if type(mapping.lhs) ~= "string" or mapping.lhs == "" then
    return nil,
      invalid_mapping_error(
        section_name,
        "missing required lhs; use list-style entries like { lhs = '<leader>xx', action = 'core.save' }"
      )
  end

  if type(mapping.action) ~= "string" or mapping.action == "" then
    return nil,
      invalid_mapping_error(section_name, string.format("mapping '%s' is missing required action", mapping.lhs))
  end

  local _, err = actions.resolve(mapping.action)
  if err then
    return nil, unresolved_action_error(section_name, mapping.lhs, mapping.action)
  end

  return true
end

local function validate_entries(entries)
  for section_name, section in pairs(entries) do
    if type(section) ~= "table" or not vim.islist(section) then
      return nil, invalid_mapping_error(section_name, "section must be a list of mappings")
    end

    for _, mapping in ipairs(section) do
      local ok, err = validate_mapping(mapping, section_name)
      if not ok then
        return nil, err
      end
    end
  end

  return true
end

function M.register_one(mapping)
  local mode = mapping.mode or "n"
  local desc = mapping.desc or mapping.action

  local rhs = function()
    actions.invoke(mapping.action)
  end

  local opts = {
    desc = desc,
    silent = true,
    noremap = true,
  }

  if type(mode) == "table" then
    for _, m in ipairs(mode) do
      local ok, err = pcall(vim.keymap.set, m, mapping.lhs, rhs, opts)
      if not ok then
        return nil, string.format("Failed to register keymap '%s': %s", mapping.lhs, tostring(err))
      end
    end
  else
    local ok, err = pcall(vim.keymap.set, mode, mapping.lhs, rhs, opts)
    if not ok then
      return nil, string.format("Failed to register keymap '%s': %s", mapping.lhs, tostring(err))
    end
  end

  return true
end

local function register_all(entries)
  for _, section in pairs(entries) do
    for _, mapping in ipairs(section) do
      local ok, err = M.register_one(mapping)
      if not ok then
        return nil, err
      end
    end
  end

  return true
end

local keymap_registry = registry.new({
  name = "keymaps",
  framework_module = "core.registry.keymaps",
  user_file = "registry/keymaps.lua",
  validate_user = validate_user_registry,
  validate_entries = validate_entries,
  register = register_all,
})

function M.setup()
  return keymap_registry:setup()
end

return M
