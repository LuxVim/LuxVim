return {
  source = "nvim-tree/nvim-tree.lua",
  debug_name = "nvim-tree",
  dependencies = { "nvim-web-devicons" },
  cmd = { "NvimTreeToggle", "NvimTreeFocus", "NvimTreeOpen" },
  lazy = {
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
