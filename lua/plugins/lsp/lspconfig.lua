return {
  source = "neovim/nvim-lspconfig",
  dependencies = { "plenary.nvim" },
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local ok, luxlsp = pcall(require, "luxlsp")
    if ok then
      local data = require("core.lib.data")
      luxlsp.setup({
        install_root = data.luxlsp_path(),
      })
    end
  end,
}
