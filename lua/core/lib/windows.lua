local M = {}

local function editing(win)
  return vim.api.nvim_win_get_config(win).relative == "" and vim.bo[vim.api.nvim_win_get_buf(win)].buftype == ""
end

-- Native equalization respects fixed dimensions and the existing split layout.
-- Protect utility panes too, and only equalize the dimension that is cramped.
function M.rebalance(force)
  local wins = vim.api.nvim_tabpage_list_wins(0)
  local width, height = force, force
  for _, win in ipairs(wins) do
    if editing(win) then
      width = width or (not vim.wo[win].winfixwidth and vim.api.nvim_win_get_width(win) < 30)
      height = height or (not vim.wo[win].winfixheight and vim.fn.getwininfo(win)[1].height < 6)
    end
  end
  if not width and not height then
    return false
  end

  local saved = {}
  local direction = vim.o.eadirection
  for _, win in ipairs(wins) do
    if vim.api.nvim_win_get_config(win).relative == "" then
      saved[win] = {
        width = vim.wo[win].winfixwidth,
        height = vim.wo[win].winfixheight,
        view = vim.api.nvim_win_call(win, vim.fn.winsaveview),
      }
      if not editing(win) then
        vim.wo[win].winfixwidth, vim.wo[win].winfixheight = true, true
      end
    end
  end
  vim.o.eadirection = width and (height and "both" or "hor") or "ver"
  local ok, err = pcall(vim.cmd, "wincmd =")
  vim.o.eadirection = direction
  for win, state in pairs(saved) do
    if vim.api.nvim_win_is_valid(win) then
      vim.wo[win].winfixwidth, vim.wo[win].winfixheight = state.width, state.height
      vim.api.nvim_win_call(win, function()
        vim.fn.winrestview(state.view)
      end)
    end
  end
  if not ok then
    error(err)
  end
  return true
end

function M.setup()
  local dirty, generation = {}, 0
  local group = vim.api.nvim_create_augroup("LuxVimWindowResize", { clear = true })
  local function apply()
    local tab = vim.api.nvim_get_current_tabpage()
    if dirty[tab] then
      dirty[tab] = nil
      M.rebalance(false)
    end
  end
  vim.api.nvim_create_autocmd("VimResized", {
    group = group,
    callback = function()
      dirty = {}
      for _, tab in ipairs(vim.api.nvim_list_tabpages()) do
        dirty[tab] = true
      end
      generation = generation + 1
      local pending = generation
      vim.defer_fn(function()
        if pending == generation then
          apply()
        end
      end, 80)
    end,
  })
  vim.api.nvim_create_autocmd("TabEnter", {
    group = group,
    callback = function()
      vim.schedule(apply)
    end,
  })
end

return M
