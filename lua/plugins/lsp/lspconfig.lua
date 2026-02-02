return {
  source = "neovim/nvim-lspconfig",
  debug_name = "nvim-lspconfig",
  dependencies = { "plenary.nvim" },
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local ok, luxlsp = pcall(require, "luxlsp")
    if ok then
      luxlsp.setup({
        install_root = vim.fs.joinpath(vim.fs.dirname(vim.fn.stdpath("config")), "data", "luxlsp"),
      })
    end
  end,
}
