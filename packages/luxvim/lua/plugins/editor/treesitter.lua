return {
  source = "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  lazy = {
    lazy = false,
    priority = 900,
  },
  config = function()
    local data = require("core.lib.data")

    require("nvim-treesitter.config").setup({
      install_dir = data.parser_path(),
    })

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
