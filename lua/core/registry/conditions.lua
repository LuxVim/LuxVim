local platform = require("core.lib.platform")

local function has_executable(name)
  return function()
    return vim.fn.executable(name) == 1
  end
end

return {
  is_mac = function() return platform.is_mac end,
  is_linux = function() return platform.is_linux end,
  is_windows = function() return platform.is_windows end,

  has_git = has_executable("git"),
  has_node = has_executable("node"),
  has_npm = has_executable("npm"),
  has_cargo = has_executable("cargo"),
  has_make = has_executable("make"),
  has_go = has_executable("go"),

  is_gui = function() return vim.fn.has("gui_running") == 1 end,
  is_vscode = function() return vim.g.vscode ~= nil end,
}
