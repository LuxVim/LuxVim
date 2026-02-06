return {
  source = "LuxVim/vim-luxpane",
  event = "VeryLazy",
  globals = {
    luxpane_protected_bt = { "quickfix", "help", "nofile", "terminal" },
    luxpane_protected_ft = { "NvimTree" },
  },
}
