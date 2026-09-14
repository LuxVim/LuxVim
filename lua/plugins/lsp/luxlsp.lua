return {
  source = "LuxVim/nvim-luxlsp",
  lazy = { commit = "55f0f10fcdb5dade76993edab5f0bd96a94b12eb" },
  dependencies = { "nvim-lspconfig", "plenary.nvim" },
  event = { "VimEnter", "BufReadPre", "BufNewFile" },
  cmd = { "LuxLspInstall", "LuxLsp", "LuxLspHealth", "LspInfo" },
  opts = { auto_install = true, servers = {} },
  config = function(_, opts)
    require("core.lib.lsp").setup(opts)
  end,
}
