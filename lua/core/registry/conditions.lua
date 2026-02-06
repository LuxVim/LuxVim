local platform = require("core.lib.platform")

return {
  is_mac = function()
    return platform.is_mac
  end,

  is_linux = function()
    return platform.is_linux
  end,

  is_windows = function()
    return platform.is_windows
  end,

  has_git = function()
    return vim.fn.executable("git") == 1
  end,

  has_node = function()
    return vim.fn.executable("node") == 1
  end,

  has_npm = function()
    return vim.fn.executable("npm") == 1
  end,

  has_cargo = function()
    return vim.fn.executable("cargo") == 1
  end,

  has_make = function()
    return vim.fn.executable("make") == 1
  end,

  has_go = function()
    return vim.fn.executable("go") == 1
  end,

  is_gui = function()
    return vim.fn.has("gui_running") == 1
  end,

  is_vscode = function()
    return vim.g.vscode ~= nil
  end,
}
