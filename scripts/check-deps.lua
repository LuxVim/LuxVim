-- scripts/check-deps.lua
-- `nvim -l` entrypoint so install.sh and install.ps1 consume the same
-- dependency manifest as :checkhealth luxvim. Prints one tab-separated
-- line per dependency: status<TAB>cmd<TAB>version<TAB>message
--
-- Exit 0 when all required dependencies resolve (outdated nvim is advisory), 1 otherwise.
-- `nvim -l` does not source init.lua, so package.path is set here.

local script = _G.arg and _G.arg[0] or "scripts/check-deps.lua"
local root = script:gsub("[\\/]scripts[\\/]check%-deps%.lua$", "")
if root == script or root == "" then
  root = "."
end

package.path = root .. "/lua/?.lua;" .. root .. "/lua/?/init.lua;" .. package.path

local ok, deps = pcall(require, "core.lib.deps")
if not ok then
  io.stderr:write("check-deps: could not load core.lib.deps: " .. tostring(deps) .. "\n")
  os.exit(1)
end

local lines, failed = deps.report(deps.check_all())
for _, line in ipairs(lines) do
  io.write(line, "\n")
end

os.exit(failed and 1 or 0)
