local function quit()
  local ok, err = pcall(vim.cmd, "quit")
  if ok then
    return true
  end
  local message = tostring(err)
  if message:find("Vim(quit):E37:", 1, true) or message:find("Vim(quit):E162:", 1, true) then
    require("core.lib.notify").warn("Unsaved changes. Save with Space fs or discard with Space FQ.")
    return false
  end
  error(err, 0)
end

return {
  source = "virtual",
  debug_name = "core",
  actions = {
    save = ":write",
    quit = quit,
    force_quit = ":quit!",
    quit_all = ":quitall!",
    save_quit = ":wq",
    vsplit = ":rightbelow vsplit",
    hsplit = ":rightbelow split",
    equalize = function()
      require("core.lib.windows").rebalance(true)
    end,
  },
  config = function()
    require("core.lib.windows").setup()
    local actions = require("core.lib.actions")
    for i = 1, 6 do
      actions.register("core", "win" .. i, function()
        if i <= vim.fn.winnr("$") then
          vim.cmd(i .. "wincmd w")
        end
      end)
    end
  end,
}
