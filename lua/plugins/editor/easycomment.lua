return {
  source = "josstei/vim-easycomment",
  debug_name = "vim-easycomment",
  cmd = { "EasyComment" },
  lazy = {
    keys = {
      { "<leader>cc", "<cmd>EasyComment<CR>", mode = { "n", "v" }, desc = "Toggle comment" },
    },
  },
  opts = {},
}
