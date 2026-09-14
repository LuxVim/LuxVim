local M = {}

function M.directory_argument()
  if vim.fn.argc() ~= 1 then
    return nil
  end
  local path = vim.fn.fnamemodify(vim.fn.argv(0), ":p")
  if vim.fn.isdirectory(path) == 1 then
    return path
  end
end

function M.open(path)
  local buf = vim.api.nvim_get_current_buf()
  -- A startup command may already have opened a file or begun an edit.
  if vim.bo[buf].modified or vim.fn.isdirectory(vim.api.nvim_buf_get_name(buf)) ~= 1 then
    return
  end
  vim.cmd("cd " .. vim.fn.fnameescape(path))
  require("luxdash.core").open()
  if vim.api.nvim_buf_is_valid(buf) and not vim.bo[buf].modified then
    vim.api.nvim_buf_delete(buf, { force = false })
  end
  require("nvim-tree.api").tree.open({ path = path, focus = true })
end

function M.setup()
  local path = M.directory_argument()
  if not path then
    return
  end
  local group = vim.api.nvim_create_augroup("LuxVimDirectoryStartup", { clear = true })
  vim.api.nvim_create_autocmd("VimEnter", {
    group = group,
    once = true,
    callback = function()
      vim.schedule(function()
        M.open(path)
      end)
    end,
  })
end

return M
