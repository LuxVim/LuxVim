return {
  source = "neovim/nvim-lspconfig",
  lazy = { commit = "77d3fdfb3554632c7a3b101ded643d422de7626f" },
  event = { "BufReadPre", "BufNewFile" },
}
