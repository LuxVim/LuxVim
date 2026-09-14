return {
  source = "LuxVim/vim-luxpane",
  event = "VeryLazy",
  lazy = { commit = "2eb64eb7512ecb992ceacc6645671f3b28426747" },
  globals = {
    luxpane_protected_bt = { "quickfix", "help", "nofile", "terminal" },
    luxpane_protected_ft = { "NvimTree" },
    luxpane_replaceable_ft = { "luxdash" },
  },
}
