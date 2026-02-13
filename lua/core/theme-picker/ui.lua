local renderer = require("core.theme-picker.renderer")
local input = require("core.theme-picker.input")
local preview = require("core.theme-picker.preview")
local persistence = require("core.theme-picker.persistence")
local notify = require("core.lib.notify")

local M = {}

M.buf = nil
M.win = nil
M.cursor_line = 1
M.items = {}

local function refresh()
  M.items = renderer.build_items()
  M.cursor_line = input.find_first_selectable(M.items)
  renderer.render(M.buf, M.items)
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_set_cursor(M.win, { M.cursor_line, 0 })
  end
end

local function on_select()
  local item = M.items[M.cursor_line]
  if not item then return end

  if item.type == "installed" then
    preview.apply(item.theme.colorscheme)
    preview.confirm()
    M.close()
  elseif item.type == "available" then
    persistence.add(item.theme.name)
    refresh()
    notify.info(item.theme.name .. " added. Run :Lazy sync to install, then restart LuxVim.")
  end
end

local function on_uninstall()
  local item = M.items[M.cursor_line]
  if not item or item.type ~= "installed" then return end

  if item.is_default then
    notify.warn("Cannot uninstall default theme")
    return
  end

  persistence.remove(item.theme.name)
  notify.info("Removed " .. item.theme.name .. ". Run :Lazy clean to delete files.")
  refresh()
end

local function on_close()
  preview.restore()
  M.close()
end

function M.close()
  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_close(M.win, true)
  end
  if M.buf and vim.api.nvim_buf_is_valid(M.buf) then
    vim.api.nvim_buf_delete(M.buf, { force = true })
  end
  M.win = nil
  M.buf = nil
end

function M.open()
  preview.save_current()
  M.items = renderer.build_items()

  local width = 50
  local height = #M.items + 3
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  M.buf = vim.api.nvim_create_buf(false, true)

  M.win = vim.api.nvim_open_win(M.buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Themes ",
    title_pos = "center",
  })

  vim.bo[M.buf].bufhidden = "wipe"
  vim.wo[M.win].cursorline = true

  M.cursor_line = input.find_first_selectable(M.items)
  renderer.render(M.buf, M.items)

  if M.win and vim.api.nvim_win_is_valid(M.win) then
    vim.api.nvim_win_set_cursor(M.win, { M.cursor_line, 0 })
  end

  local state = M
  input.setup_keymaps(M.buf, {
    ["j"] = function() input.move_cursor(1, state, preview.apply) end,
    ["k"] = function() input.move_cursor(-1, state, preview.apply) end,
    ["<Down>"] = function() input.move_cursor(1, state, preview.apply) end,
    ["<Up>"] = function() input.move_cursor(-1, state, preview.apply) end,
    ["<CR>"] = on_select,
    ["x"] = on_uninstall,
    ["q"] = on_close,
    ["<Esc>"] = on_close,
  })

  if M.items[M.cursor_line] and M.items[M.cursor_line].type == "installed" then
    preview.apply(M.items[M.cursor_line].theme.colorscheme)
  end
end

return M
