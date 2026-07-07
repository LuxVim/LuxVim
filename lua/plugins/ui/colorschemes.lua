return {
  source = "josstei/fathom.nvim",
  lazy = {
    lazy = false,
    priority = 1000,
  },
  opts = {
    transparent = true,
  },
  config = function(_, opts)
    require("fathom").setup(opts)
    local status_ok, _ = pcall(vim.cmd, "colorscheme fathom")
    if not status_ok then
      require("core.lib.notify").warn("Failed to load colorscheme")
    end
  end,
}
