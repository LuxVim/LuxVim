return {
  source = "nvim-treesitter/nvim-treesitter",
  build = ":TSUpdate",
  lazy = {
    lazy = false,
    priority = 900,
  },
  config = function()
    local paths = require("core.lib.paths")
    local data_dir = vim.env.XDG_DATA_HOME or vim.fn.stdpath("data")
    local parser_install_dir = paths.join(data_dir, "data", "site")

    require("nvim-treesitter.config").setup({
      install_dir = parser_install_dir,
    })

    vim.api.nvim_create_autocmd("FileType", {
      callback = function(args)
        pcall(vim.treesitter.start, args.buf)
      end,
    })
  end,
}
