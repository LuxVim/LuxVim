return {
  source = "virtual",
  debug_name = "core",
  actions = {
    save = ":write",
    quit = ":quit",
    force_quit = ":quit!",
    quit_all = ":quitall!",
    save_quit = ":wq",
    vsplit = ":rightbelow vs new",
    hsplit = ":rightbelow split new",
  },
  config = function()
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
