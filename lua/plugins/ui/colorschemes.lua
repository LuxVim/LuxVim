return {
  source = "LuxVim/lux.nvim",
  debug_name = "lux.nvim",
  lazy = {
    priority = 1000,
  },
  opts = {
    variant = "vesper",
    transparent = false,
  },
  config = function(_, opts)
    require("lux").setup(opts)
    local status_ok, _ = pcall(vim.cmd, "colorscheme lux")
    if not status_ok then
      vim.api.nvim_echo({ { "LuxVim: Failed to load colorscheme", "WarningMsg" } }, true, {})
    end
  end,
}
