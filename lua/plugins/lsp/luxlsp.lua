return {
  source = "LuxVim/nvim-luxlsp",
  debug_name = "nvim-luxlsp",
  dependencies = { "plenary.nvim" },
  cmd = { "LuxLsp", "LuxLspInstall", "LuxLspUninstall", "LuxLspList" },
  lazy = {
    keys = {
      { "<leader>L", "<cmd>LuxLsp<cr>", desc = "Toggle LuxLSP Manager" },
    },
  },
  opts = {},
}
