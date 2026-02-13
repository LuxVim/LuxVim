local notify = require("core.lib.notify")

local M = {}

function M.create()
  local collector = {
    errors = {},
    warnings = {},
  }

  function collector:add_error(source, message, level)
    table.insert(self.errors, { level = level or "critical", file = source, message = message })
  end

  function collector:add_warning(source, message)
    table.insert(self.warnings, { level = "warning", file = source, message = message })
  end

  function collector:collect(source, errors, warnings)
    for _, e in ipairs(errors) do
      self:add_error(source, e.message, e.level)
    end
    for _, w in ipairs(warnings) do
      self:add_warning(source, w.message)
    end
  end

  function collector:has_errors()
    return #self.errors > 0
  end

  function collector:has_warnings()
    return #self.warnings > 0
  end

  function collector:report()
    local critical = vim.tbl_filter(function(e)
      return e.level == "critical"
    end, self.errors)

    if #critical > 0 then
      local msg = "[LuxVim] FATAL: Cannot start\n"
      for _, e in ipairs(critical) do
        msg = msg .. "  " .. e.file .. ": " .. e.message .. "\n"
      end
      vim.api.nvim_echo({ { msg, "ErrorMsg" } }, true, {})
      return false
    end

    local non_critical = vim.tbl_filter(function(e)
      return e.level ~= "critical"
    end, self.errors)

    for _, e in ipairs(non_critical) do
      notify.warn("Plugin skipped: " .. e.file .. "\n  " .. e.message)
    end

    if #self.warnings > 0 then
      vim.defer_fn(function()
        notify.info("Started with " .. #self.warnings .. " warnings. Run :LuxVimErrors for details.")
      end, 100)
    end

    return true
  end

  return collector
end

return M
