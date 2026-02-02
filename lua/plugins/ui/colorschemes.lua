return {
  source = "josstei/nami.nvim",
  debug_name = "nami.nvim",
  lazy = {
    lazy = false,
    priority = 1000,
  },
  opts = {
    transparent = false,
  },
  config = function(_, opts)
    require("nami").setup(opts)
    local status_ok, _ = pcall(vim.cmd, "colorscheme nami")
    if not status_ok then
      vim.api.nvim_echo({ { "LuxVim: Failed to load colorscheme", "WarningMsg" } }, true, {})
    end
  end,
}
