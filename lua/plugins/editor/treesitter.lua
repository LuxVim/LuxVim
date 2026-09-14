return {
  source = "nvim-treesitter/nvim-treesitter",
  -- NOTE: :TSUpdate updates parsers that are ALREADY installed — with none
  -- installed it is a no-op, which is why this build step never provisioned
  -- anything. Installing the declared set is core.lib.provision's job.
  build = ":TSUpdate",
  lazy = {
    lazy = false,
    priority = 900,
  },
  config = function()
    local data = require("core.lib.data")
    local provision = require("core.lib.provision")
    local treesitter_report = require("core.lib.treesitter_report")

    require("nvim-treesitter.config").setup({
      install_dir = data.parser_path(),
    })

    local report_deps = treesitter_report.default_deps()
    local attach = treesitter_report.new(report_deps)
    local function reattach(installed)
      local ready = {}
      for _, lang in ipairs(installed) do
        ready[lang] = true
      end
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_is_loaded(buf) then
          local filetype = vim.bo[buf].filetype
          local row = report_deps.declared[filetype]
          if row and ready[row.parser] then
            attach({ buf = buf, match = filetype })
          end
        end
      end
    end

    -- Blocking, for `nvim --headless +LuxVimInstallParsers +qa` in install.sh:
    -- an async install would be killed by the exit before it finished.
    vim.api.nvim_create_user_command(provision.COMMAND, function()
      local _, err = provision.ensure(nil, {
        wait_ms = provision.BOOTSTRAP_TIMEOUT_MS,
        on_complete = reattach,
      })
      if err and #vim.api.nvim_list_uis() == 0 then
        -- A Lua error followed by +qa still exits zero; installers need an
        -- explicit failing exit status. Interactive sessions keep running.
        vim.cmd("cquit 1")
      end
    end, { desc = "Install every treesitter parser declared in lua/languages/" })

    -- Report failures rather than discarding them: a swallowed error here
    -- makes a missing parser indistinguishable from a working one, which is
    -- how a dead treesitter install stays invisible. The notification is
    -- deduped per filetype; the failure itself is recorded for
    -- :checkhealth luxvim on every occurrence.
    vim.api.nvim_create_autocmd("FileType", {
      group = vim.api.nvim_create_augroup("LuxVimTreesitter", { clear = true }),
      callback = attach,
    })

    -- Self-heal, so a language declaration is sufficient on its own: adding
    -- lua/languages/go.lua and restarting installs the parser, with no second
    -- step to remember and nothing to keep in sync by hand. Scheduled and
    -- non-blocking — installing a parser compiles C, and startup must not
    -- wait on that.
    vim.schedule(function()
      provision.ensure(nil, { on_complete = reattach })
    end)
  end,
}
