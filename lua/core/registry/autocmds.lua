local M = {}

local fzf_group = vim.api.nvim_create_augroup("fzf_buffer", { clear = true })

vim.api.nvim_create_autocmd("FileType", {
  group = fzf_group,
  pattern = "fzf",
  callback = function()
    vim.opt_local.laststatus = 0
    vim.opt_local.showmode = false
    vim.opt_local.ruler = false
  end,
})

vim.api.nvim_create_autocmd("BufLeave", {
  group = fzf_group,
  pattern = "*",
  callback = function()
    if vim.bo.filetype == "fzf" then
      vim.opt.laststatus = 3
      vim.opt.showmode = true
      vim.opt.ruler = true
    end
  end,
})

vim.api.nvim_create_autocmd("FileType", {
  pattern = "qf",
  callback = function()
    vim.keymap.set("n", "<CR>", "<CR>:cclose<CR>", { buffer = true })
  end,
})

vim.api.nvim_create_autocmd("VimEnter", {
  callback = function()
    vim.defer_fn(function()
      local current_config = vim.diagnostic.config()
      if current_config.virtual_text == false then
        vim.diagnostic.config({
          virtual_text = {
            prefix = "●",
            spacing = 4,
          },
          signs = current_config.signs,
          underline = current_config.underline,
          update_in_insert = current_config.update_in_insert,
          severity_sort = current_config.severity_sort,
          float = current_config.float,
        })
      end
    end, 100)
  end,
})

return M
