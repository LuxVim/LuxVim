return {
  FileType = {
    pattern = { "fzf", "qf" },
    callback = function()
      local ft = vim.bo.filetype
      if ft == "fzf" then
        vim.opt_local.laststatus = 0
        vim.opt_local.showmode = false
        vim.opt_local.ruler = false
      elseif ft == "qf" then
        vim.keymap.set("n", "<CR>", "<CR>:cclose<CR>", { buffer = true })
      end
    end,
  },
  BufLeave = {
    callback = function()
      if vim.bo.filetype == "fzf" then
        vim.opt.laststatus = 3
        vim.opt.showmode = true
        vim.opt.ruler = true
      end
    end,
  },
}
