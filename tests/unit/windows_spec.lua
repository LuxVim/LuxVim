describe("window balancing", function()
  local windows = require("core.lib.windows")
  local columns, lines, equalalways

  before_each(function()
    columns, lines, equalalways = vim.o.columns, vim.o.lines, vim.o.equalalways
    vim.o.columns, vim.o.lines, vim.o.equalalways = 160, 48, false
    vim.cmd("tabnew")
  end)

  after_each(function()
    vim.cmd("tabonly!")
    vim.cmd("only!")
    vim.o.columns, vim.o.lines, vim.o.equalalways = columns, lines, equalalways
    pcall(vim.api.nvim_del_augroup_by_name, "LuxVimWindowResize")
  end)

  it("preserves usable manual proportions and permits explicit balancing", function()
    local left = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    vim.api.nvim_win_set_width(left, 45)
    assert.is_false(windows.rebalance(false))
    assert.equal(45, vim.api.nvim_win_get_width(left))
    assert.is_true(windows.rebalance(true))
    assert.is_true(math.abs(vim.api.nvim_win_get_width(left) - vim.api.nvim_win_get_width(0)) <= 1)
  end)

  it("repairs cramped panes without changing utility width, buffers, focus or cursors", function()
    local tree = vim.api.nvim_get_current_win()
    local tree_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_win_set_buf(tree, tree_buf)
    vim.cmd("rightbelow vnew")
    local left = vim.api.nvim_get_current_win()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "one", "two", "three" })
    vim.api.nvim_win_set_cursor(left, { 2, 1 })
    vim.cmd("rightbelow vsplit")
    local right = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_width(tree, 30)
    vim.api.nvim_win_set_width(left, 20)
    local buf = vim.api.nvim_win_get_buf(left)
    assert.is_true(windows.rebalance(false))
    assert.equal(right, vim.api.nvim_get_current_win())
    assert.equal(30, vim.api.nvim_win_get_width(tree))
    assert.is_false(vim.wo[tree].winfixwidth)
    assert.equal(buf, vim.api.nvim_win_get_buf(left))
    assert.same({ 2, 1 }, vim.api.nvim_win_get_cursor(left))
    assert.is_true(vim.api.nvim_win_get_width(left) >= 30)
    assert.is_true(vim.api.nvim_win_get_width(right) >= 30)
  end)

  it("leaves fixed windows and floats alone while repairing short editing panes", function()
    local upper = vim.api.nvim_get_current_win()
    vim.cmd("rightbelow split")
    local lower = vim.api.nvim_get_current_win()
    vim.api.nvim_win_set_height(upper, 4)
    local float = vim.api.nvim_open_win(vim.api.nvim_create_buf(false, true), true, {
      relative = "editor",
      row = 1,
      col = 1,
      width = 12,
      height = 2,
    })
    vim.wo[upper].winfixheight = true
    assert.is_false(windows.rebalance(false))
    vim.wo[upper].winfixheight = false
    assert.is_true(windows.rebalance(false))
    assert.is_true(vim.fn.getwininfo(upper)[1].height >= 6)
    assert.equal(2, vim.api.nvim_win_get_height(float))
    assert.equal(float, vim.api.nvim_get_current_win())
    vim.api.nvim_win_close(float, true)
    assert.equal(lower, vim.api.nvim_get_current_win())
  end)

  it("defers hidden tab balancing until that tab is entered", function()
    local hidden = vim.api.nvim_get_current_tabpage()
    local small = vim.api.nvim_get_current_win()
    vim.cmd("vsplit")
    vim.api.nvim_win_set_width(small, 20)
    vim.cmd("tabnew")
    local visible = vim.api.nvim_get_current_tabpage()
    windows.setup()
    vim.api.nvim_exec_autocmds("VimResized", {})
    vim.wait(150, function()
      return false
    end, 10)
    assert.equal(visible, vim.api.nvim_get_current_tabpage())
    assert.equal(20, vim.api.nvim_win_get_width(small))
    vim.api.nvim_set_current_tabpage(hidden)
    assert.is_true(vim.wait(300, function()
      return vim.api.nvim_win_get_width(small) >= 30
    end, 10))
    assert.equal(hidden, vim.api.nvim_get_current_tabpage())
  end)
end)
