-- tests/helpers/fixtures.lua
-- Schema-valid builders for plugin specs used by tests across phases.

local M = {}

function M.build_spec(overrides)
  return vim.tbl_deep_extend("force", {
    source = "fake/plugin",
    opts = {},
    enabled = true,
  }, overrides or {})
end

return M
