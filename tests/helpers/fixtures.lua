-- tests/helpers/fixtures.lua
-- Schema-valid builders for plugin specs, user keymap registries, and
-- a per-test core context (fresh pipeline/actions/schema instances).

local M = {}

local function deep_merge(base, overrides)
  if type(overrides) ~= "table" then
    return overrides
  end
  local result = {}
  for k, v in pairs(base) do
    if type(v) == "table" then
      result[k] = vim.deepcopy(v)
    else
      result[k] = v
    end
  end
  for k, v in pairs(overrides) do
    if type(v) == "table" and type(result[k]) == "table" then
      result[k] = deep_merge(result[k], v)
    else
      result[k] = v
    end
  end
  return result
end

function M.build_spec(overrides)
  local base = {
    source = "fake/plugin",
    opts = {},
    enabled = true,
  }
  return deep_merge(base, overrides or {})
end

function M.build_user_keymap_registry(sections)
  sections = sections or {}
  local result = {}
  for name, mappings in pairs(sections) do
    result[name] = mappings
  end
  return result
end

function M.build_context()
  local pipeline = require("core.lib.pipeline")
  local actions = require("core.lib.actions")
  local schema = require("core.lib.schema")
  return {
    pipeline = pipeline.new(),
    actions = actions.new(),
    schema = schema.new(),
  }
end

return M
