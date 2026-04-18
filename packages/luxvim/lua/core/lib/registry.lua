local data = require("core.lib.data")
local paths = require("core.lib.paths")

local M = {}

local function run_validator(validator, ...)
  if not validator then
    return true
  end

  local ok, err = validator(...)
  if ok == false or ok == nil then
    return nil, err or "validation failed"
  end

  return true
end

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
          if #merged[key] > 0 or #value > 0 then
            merged[key] = vim.list_extend(vim.deepcopy(merged[key]), value)
          else
            merged[key] = vim.tbl_deep_extend("force", merged[key], value)
          end
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
    validate_user = config.validate_user,
    validate_entries = config.validate_entries,
  }

  function instance:load()
    local ok, framework = pcall(require, self.framework_module)
    if not ok then
      return nil, "Failed to load " .. self.name .. " registry: " .. tostring(framework)
    end

    local user_path = paths.join(data.user_config_path(), self.user_file)
    local user = nil
    if vim.uv.fs_stat(user_path) then
      local uok, loaded = pcall(dofile, user_path)
      if uok and type(loaded) == "table" then
        user = loaded
        local vok, verr = run_validator(self.validate_user, user, user_path)
        if not vok then
          return nil, verr
        end
      elseif not uok then
        return nil, "Failed to load user " .. self.name .. " config: " .. tostring(loaded)
      end
    end

    local entries = framework
    if user then
      entries = merge(framework, user)
    end

    local vok, verr = run_validator(self.validate_entries, entries, {
      framework = framework,
      user = user,
      user_path = user_path,
    })
    if not vok then
      return nil, verr
    end

    return entries
  end

  function instance:setup()
    local entries, err = self:load()
    if not entries then
      return nil, err
    end

    local ok, reg_err = self.register(entries)
    if ok == false or (ok == nil and reg_err ~= nil) then
      return nil, reg_err
    end

    return true
  end

  return instance
end

return M
