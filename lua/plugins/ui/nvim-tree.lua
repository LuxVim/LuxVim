return {
  source = "LuxVim/nvim-tree.lua",
  debug_name = "nvim-tree",
  dependencies = { "nvim-web-devicons" },
  cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeOpen" },
  lazy = {
    commit = "2eb3cd1b5d87026757e278289c91545b04ed9708",
    init = function()
      require("core.lib.directory_startup").setup()
    end,
  },
  actions = {
    toggle = function()
      require("nvim-tree.api").tree.toggle()
    end,
    focus = function()
      require("nvim-tree.api").tree.focus()
    end,
  },
  opts = require("plugins.ui.config.nvim-tree"),
}
