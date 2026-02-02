return {
  source = "josstei/voidpulse.nvim",
  debug_name = "voidpulse.nvim",
  lazy = {
    lazy = false,
    priority = 1000,
  },
  opts = {
    palette = "fathom",
    transparent = false,
  },
  config = function(_, opts)
    require("voidpulse").setup(opts)
    local status_ok, _ = pcall(vim.cmd, "colorscheme voidpulse")
    if not status_ok then
      vim.api.nvim_echo({ { "LuxVim: Failed to load colorscheme", "WarningMsg" } }, true, {})
    end
  end,
}
