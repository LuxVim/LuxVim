local notify = require("core.lib.notify")
local data = require("core.lib.data")
local paths = require("core.lib.paths")

local M = {}

local function merge(framework, user)
  if user.replaces then
    user.replaces = nil
    return user
  end

  if user.extends then
    user.extends = nil
    local merged = vim.deepcopy(framework)
    for key, value in pairs(user) do
      if merged[key] then
        if type(merged[key]) == "table" and type(value) == "table" then
          merged[key] = vim.tbl_deep_extend("force", merged[key], value)
        else
          merged[key] = value
        end
      else
        merged[key] = value
      end
    end
    return merged
  end

  return framework
end

function M.new(config)
  local instance = {
    name = config.name,
    framework_module = config.framework_module,
    user_file = config.user_file,
    register = config.register,
  }

  function instance:load()
    local ok, framework = pcall(require, self.framework_module)
    if not ok then
      notify.warn("Failed to load " .. self.name .. " registry: " .. tostring(framework))
      return nil
    end

    local user_path = paths.join(data.user_config_path(), self.user_file)
    if vim.uv.fs_stat(user_path) then
      local uok, user = pcall(dofile, user_path)
      if uok and type(user) == "table" then
        return merge(framework, user)
      elseif not uok then
        notify.warn("Failed to load user " .. self.name .. " config: " .. tostring(user))
      end
    end

    return framework
  end

  function instance:setup()
    local entries = self:load()
    if entries then
      self.register(entries)
    end
  end

  return instance
end

return M
