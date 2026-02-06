return {
  source = "josstei/nami.nvim",
  lazy = {
    lazy = false,
    priority = 1000,
  },
  opts = {
    transparent = true
  },
  config = function(_, opts)
    require("nami").setup(opts)
    local status_ok, _ = pcall(vim.cmd, "colorscheme nami")
    if not status_ok then
      require("core.lib.notify").warn("Failed to load colorscheme")
    end
  end,
}
