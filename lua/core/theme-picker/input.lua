local M = {}

function M.find_first_selectable(items)
  for i, item in ipairs(items) do
    if item.type == "installed" or item.type == "available" then
      return i
    end
  end
  return 1
end

function M.move_cursor(direction, state, on_preview)
  local new_line = state.cursor_line + direction
  while new_line >= 1 and new_line <= #state.items do
    local item = state.items[new_line]
    if item.type == "installed" or item.type == "available" then
      state.cursor_line = new_line
      if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_cursor(state.win, { state.cursor_line, 0 })
      end
      if item.type == "installed" and on_preview then
        on_preview(item.theme.colorscheme)
      end
      return
    end
    new_line = new_line + direction
  end
end

function M.setup_keymaps(buf, handlers)
  local opts = { buffer = buf, silent = true }
  for key, fn in pairs(handlers) do
    vim.keymap.set("n", key, fn, opts)
  end
end

return M
