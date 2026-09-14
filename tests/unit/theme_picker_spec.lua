describe("theme picker layout", function()
  it("keeps controls visible while scrolling and resizing, and restores the theme on cancel", function()
    local columns, lines = vim.o.columns, vim.o.lines
    local original_win = vim.api.nvim_get_current_win()
    vim.cmd("colorscheme default")
    local original_theme = vim.g.colors_name
    local themes = {}
    for i = 1, 25 do
      table.insert(
        themes,
        { name = "Theme" .. i .. "界", colorscheme = "default", description = "A long description 界面界面" }
      )
    end
    require("plugins.ui.config.theme-picker").setup({ themes = themes })
    vim.o.columns, vim.o.lines = 80, 24
    vim.cmd("Themes")
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    local function check()
      local content = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
      local text = table.concat(content, "\n")
      assert.matches("Enter: Apply", text)
      assert.matches("x: Uninstall", text)
      assert.matches("q/Esc: Close", text)
      assert.is_true(#content <= vim.api.nvim_win_get_height(win))
      for _, line in ipairs(content) do
        assert.is_true(vim.fn.strdisplaywidth(line) <= vim.api.nvim_win_get_width(win))
      end
    end
    check()
    for _ = 1, 24 do
      vim.cmd("normal j")
    end
    check()
    vim.o.columns, vim.o.lines = 40, 12
    vim.api.nvim_exec_autocmds("VimResized", {})
    check()
    local cursor = vim.api.nvim_win_get_cursor(win)[1]
    assert.is_truthy(vim.api.nvim_buf_get_lines(buf, cursor - 1, cursor, false)[1]:find("Theme", 1, true))
    vim.cmd("normal q")
    assert.equal(original_win, vim.api.nvim_get_current_win())
    assert.equal(original_theme, vim.g.colors_name)
    vim.o.columns, vim.o.lines = columns, lines
  end)
end)
