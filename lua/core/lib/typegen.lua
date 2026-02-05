local schema = require("core.lib.schema")
local debug_mod = require("core.lib.debug")
local paths = require("core.lib.paths")

local M = {}

local function lua_type_to_annotation(type_def)
  if type(type_def) == "string" then
    if type_def == "list" then
      return "any[]"
    end
    return type_def
  end

  if type(type_def) == "table" then
    if type_def.type then
      return lua_type_to_annotation(type_def.type)
    end
    local types = {}
    for _, t in ipairs(type_def) do
      table.insert(types, lua_type_to_annotation(t))
    end
    return table.concat(types, "|")
  end

  return "any"
end

local function generate_class(name, schema_def)
  local lines = { "---@class " .. name }

  local fields = {}
  for field, _ in pairs(schema_def) do
    table.insert(fields, field)
  end
  table.sort(fields)

  for _, field in ipairs(fields) do
    local rules = schema_def[field]
    local type_str = lua_type_to_annotation(rules.type or "any")
    local optional = not rules.required and "?" or ""
    local desc = rules.desc or ""

    table.insert(lines, string.format("---@field %s%s %s %s", field, optional, type_str, desc))
  end

  return table.concat(lines, "\n")
end

function M.generate()
  local output = {
    "-- lua/types/plugin.lua",
    "-- GENERATED FILE - DO NOT EDIT",
    "-- Run :LuxVimGenerateTypes to regenerate",
    "",
  }

  table.insert(output, generate_class("BuildSpec", schema.build_spec))
  table.insert(output, "")
  table.insert(output, generate_class("PluginSpec", schema.plugin_spec))
  table.insert(output, "")
  table.insert(output, generate_class("KeymapEntry", schema.keymap_entry))
  table.insert(output, "")
  table.insert(output, generate_class("AutocmdEntry", schema.autocmd_entry))

  return table.concat(output, "\n")
end

function M.write()
  local root = debug_mod.get_luxvim_root()
  local types_dir = paths.join(root, "lua", "types")
  local output_path = paths.join(types_dir, "plugin.lua")

  vim.fn.mkdir(types_dir, "p")

  local content = M.generate()
  local file = io.open(output_path, "w")
  if file then
    file:write(content)
    file:close()
    print("Generated: " .. output_path)
  else
    print("Failed to write: " .. output_path)
  end
end

vim.api.nvim_create_user_command("LuxVimGenerateTypes", function()
  M.write()
end, { desc = "Generate LuxVim type annotations" })

return M
