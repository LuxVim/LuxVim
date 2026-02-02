local debug_mod = require("core.lib.debug")

local M = {}

function M.get_lazy_path()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share/LuxVim")
  return data_dir .. "/data/lazy/lazy.nvim"
end

function M.get_lazy_root()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share/LuxVim")
  return data_dir .. "/data/lazy"
end

function M.get_lockfile_path()
  local data_dir = vim.env.XDG_DATA_HOME or vim.fn.expand("~/.local/share/LuxVim")
  return data_dir .. "/lazy-lock.json"
end

function M.ensure_lazy()
  local lazypath = M.get_lazy_path()

  if not vim.uv.fs_stat(lazypath) then
    local lazyrepo = "https://github.com/folke/lazy.nvim.git"
    local out = vim.fn.system({
      "git",
      "clone",
      "--filter=blob:none",
      "--branch=stable",
      lazyrepo,
      lazypath,
    })

    if vim.v.shell_error ~= 0 then
      vim.api.nvim_echo({
        { "Failed to clone lazy.nvim:\n", "ErrorMsg" },
        { out, "WarningMsg" },
        { "\nPress any key to exit..." },
      }, true, {})
      vim.fn.getchar()
      os.exit(1)
    end
  end

  vim.opt.rtp:prepend(lazypath)
end

function M.setup_lazy(specs)
  M.ensure_lazy()

  require("lazy").setup({
    spec = specs,
    defaults = {
      lazy = false,
      version = false,
    },
    install = { colorscheme = { "lux", "habamax" } },
    checker = { enabled = false },
    performance = {
      cache = { enabled = true },
      reset_packpath = true,
      rtp = {
        reset = true,
        disabled_plugins = {
          "gzip",
          "matchit",
          "matchparen",
          "netrwPlugin",
          "tarPlugin",
          "tohtml",
          "tutor",
          "zipPlugin",
        },
      },
    },
    root = M.get_lazy_root(),
    lockfile = M.get_lockfile_path(),
  })
end

return M
