describe("core quit action", function()
  local notify = require("core.lib.notify")
  local actions = require("core.lib.actions")
  local warn, report, hidden, registry, warnings, errors

  before_each(function()
    warn, report, hidden = notify.warn, notify.error, vim.o.hidden
    warnings, errors = {}, {}
    notify.warn = function(message)
      table.insert(warnings, message)
    end
    notify.error = function(message)
      table.insert(errors, message)
    end
    vim.o.hidden = false
    vim.cmd("tabnew")
    registry = actions.new()
    registry:register_from_spec(require("plugins.editor.core-actions"))
  end)

  after_each(function()
    pcall(vim.api.nvim_del_augroup_by_name, "LuxVimTestQuit")
    vim.cmd("tabonly!")
    vim.bo.modified = false
    notify.warn, notify.error, vim.o.hidden = warn, report, hidden
  end)

  it("refuses an unsaved quit with useful guidance and preserves the edits", function()
    local win, buf = vim.api.nvim_get_current_win(), vim.api.nvim_get_current_buf()
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, { "unsaved content" })
    assert.is_false(registry:invoke("core.quit"))
    assert.equal(win, vim.api.nvim_get_current_win())
    assert.equal(buf, vim.api.nvim_get_current_buf())
    assert.same({ "unsaved content" }, vim.api.nvim_buf_get_lines(buf, 0, -1, false))
    assert.is_true(vim.bo[buf].modified)
    assert.same({ "Unsaved changes. Save with Space fs or discard with Space FQ." }, warnings)
    assert.same({}, errors)
  end)

  it("quits unmodified windows normally", function()
    local win = vim.api.nvim_get_current_win()
    assert.is_true(registry:invoke("core.quit"))
    assert.is_false(vim.api.nvim_win_is_valid(win))
    assert.same({}, warnings)
    assert.same({}, errors)
  end)

  it("retains unexpected quit errors", function()
    local group = vim.api.nvim_create_augroup("LuxVimTestQuit", { clear = true })
    vim.api.nvim_create_autocmd("QuitPre", {
      group = group,
      callback = function()
        error("unexpected quit hook failure")
      end,
    })
    assert.is_false(registry:invoke("core.quit"))
    assert.same({}, warnings)
    assert.equal(1, #errors)
    assert.matches("unexpected quit hook failure", errors[1])
  end)

  it("retains the explicit force quit action", function()
    local win = vim.api.nvim_get_current_win()
    vim.api.nvim_buf_set_lines(0, 0, -1, false, { "explicitly discarded" })
    assert.is_true(registry:invoke("core.force_quit"))
    assert.is_false(vim.api.nvim_win_is_valid(win))
    assert.same({}, warnings)
    assert.same({}, errors)
  end)
end)
