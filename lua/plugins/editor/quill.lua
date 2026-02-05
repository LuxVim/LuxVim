return {
  source = "josstei/quill.nvim",
  debug_name = "quill.nvim",
  event = { "BufReadPost", "BufNewFile" },
  config = function()
    require("quill").setup({
      warn_on_override = false,
    })
  end,
}
