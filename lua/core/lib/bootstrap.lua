local data = require("core.lib.data")

local M = {}

function M.ensure_lazy()
  local lazypath = data.lazy_path()

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

function M.lazy_opts(specs)
  return {
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
        -- reset = true discards everything init.lua prepended, including the
        -- LuxVim root itself — which is where lua/luxvim/health.lua lives.
        -- Without this, :checkhealth luxvim reports "no healthcheck found".
        paths = { data.root() },
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
    root = data.lazy_root(),
    lockfile = data.lockfile_path(),
  }
end

function M.setup_lazy(specs)
  M.ensure_lazy()

  require("lazy").setup(M.lazy_opts(specs))
end

return M
