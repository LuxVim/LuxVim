return {
  source = "LuxVim/vim-luxpane",
  event = "VeryLazy",
  config = function()
    vim.g.luxpane_protected_bt = { "quickfix", "help", "nofile", "terminal" }
    vim.g.luxpane_protected_ft = { "NvimTree" }
  end,
}
