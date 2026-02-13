local discover = require("core.lib.discover")
local transform = require("core.lib.transform")
local diagnostics_mod = require("core.lib.diagnostics")

local M = {}

M._diagnostics = nil

function M.discover_all()
  M._diagnostics = diagnostics_mod.create()
  discover.discover_all(M._diagnostics)
end

function M.get_lazy_specs()
  return transform.transform_all(discover._specs, discover._specs_by_name)
end

function M.report_errors()
  return M._diagnostics:report()
end

function M.get_errors()
  return M._diagnostics and M._diagnostics.errors or {}
end

function M.get_warnings()
  return M._diagnostics and M._diagnostics.warnings or {}
end

return M
