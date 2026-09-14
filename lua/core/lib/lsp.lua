-- Coordinate declared language servers without blocking editing or retrying failed downloads forever.
local M = {}
local Controller = {}
Controller.__index = Controller

local function message(err)
  if type(err) == "table" then
    return err.message or err.error or vim.inspect(err)
  end
  return tostring(err)
end

function M.new(opts)
  return setmetatable({
    servers = opts.servers,
    provider = opts.provider,
    install = opts.install,
    notify = opts.notify or vim.notify,
    states = {},
    auto_install = opts.auto_install ~= false,
  }, Controller)
end

function Controller:fail(server, err)
  self.states[server] = { status = "failed", error = message(err) }
  self.notify(
    "LSP " .. server .. " failed. See :LuxVimErrors; retry with :LuxLspInstall " .. server,
    vim.log.levels.WARN
  )
end

function Controller:ensure(server, retry)
  local options = self.servers[server]
  if not options then
    self:fail(server, "Server is not declared by a language")
    return
  end
  local previous = self.states[server]
  if previous and (previous.status == "installing" or (not retry and previous.status == "failed")) then
    return
  end
  local ok, config = pcall(self.provider.resolve, server, options)
  if not ok then
    self:fail(server, config)
    return
  end
  if self.provider.available(config) then
    local activate = previous and previous.status == "configured" and self.provider.attach or self.provider.activate
    local activated, err = pcall(activate, server, config)
    if activated then
      self.states[server] = { status = "configured" }
    else
      self:fail(server, err)
    end
    return
  end
  if options.cmd then
    self:fail(server, "Configured command is not executable: " .. vim.inspect(options.cmd))
    return
  end
  if not retry and not self.auto_install then
    self.states[server] = { status = "missing" }
    return
  end
  self.states[server] = { status = "installing" }
  self.notify("Installing language server: " .. server, vim.log.levels.INFO)
  local completed = false
  local function finish(success, err)
    if completed then
      return
    end
    completed = true
    vim.schedule(function()
      if not success then
        self:fail(server, err)
        return
      end
      local resolved, installed = pcall(self.provider.resolve, server, options)
      if not resolved or not self.provider.available(installed) then
        self:fail(server, resolved and "Installation finished without an executable" or installed)
        return
      end
      local activated, activation_error = pcall(self.provider.activate, server, installed)
      if activated then
        self.states[server] = { status = "configured" }
      else
        self:fail(server, activation_error)
      end
    end)
  end
  local started, err = pcall(self.install, server, { callback = finish })
  if not started then
    finish(false, err)
  end
end

function Controller:on_buffer(buf)
  if not vim.api.nvim_buf_is_valid(buf) or not vim.api.nvim_buf_is_loaded(buf) or vim.bo[buf].buftype ~= "" then
    return
  end
  for server, config in pairs(self.servers) do
    if vim.tbl_contains(config.filetypes, vim.bo[buf].filetype) then
      self:ensure(server)
    end
  end
end

function Controller:report()
  local out = {}
  for _, server in ipairs(vim.fn.sort(vim.tbl_keys(self.servers))) do
    local row = vim.deepcopy(self.states[server] or { status = "missing" })
    row.name = server
    row.attached_buffers = 0
    for _, client in ipairs(vim.lsp.get_clients({ name = self.provider.name(server) })) do
      for buf in pairs(client.attached_buffers or {}) do
        if vim.api.nvim_buf_is_valid(buf) then
          row.attached_buffers = row.attached_buffers + 1
        end
      end
    end
    if row.attached_buffers > 0 then
      row.status = "attached"
    end
    table.insert(out, row)
  end
  return out
end

function M.setup(opts)
  opts = opts or {}
  local ok, err = pcall(function()
    local manager = require("luxlsp")
    manager.setup({ install_root = require("core.lib.data").luxlsp_path(), auto_setup = false })
    local languages = require("core.lib.languages")
    local servers = languages.lsp_servers(languages.rows())
    for name, config in pairs(servers) do
      servers[name] = vim.tbl_deep_extend("force", config, (opts.servers or {})[name] or {})
    end
    M._default = M.new({
      servers = servers,
      provider = require("luxlsp.lsp.client_config"),
      install = manager.install_server,
      auto_install = opts.auto_install,
    })
    vim.api.nvim_create_user_command("LuxLspInstall", function(args)
      M._default:ensure(args.args, true)
    end, {
      nargs = 1,
      complete = function()
        return vim.tbl_keys(servers)
      end,
    })
    local group = vim.api.nvim_create_augroup("LuxVimLsp", { clear = true })
    vim.api.nvim_create_autocmd("FileType", {
      group = group,
      callback = function(args)
        M._default:on_buffer(args.buf)
      end,
    })
    vim.schedule(function()
      for _, buf in ipairs(vim.api.nvim_list_bufs()) do
        M._default:on_buffer(buf)
      end
    end)
  end)
  M._setup_error = not ok and message(err) or nil
  if not ok then
    vim.notify("Language server setup failed. See :LuxVimErrors", vim.log.levels.ERROR)
  end
end

function M.errors()
  local errors = {}
  if M._setup_error then
    table.insert(errors, { file = "LSP setup", message = M._setup_error })
  end
  for name, state in pairs(M._default and M._default.states or {}) do
    if state.error then
      table.insert(errors, { file = "LSP " .. name, message = state.error })
    end
  end
  return errors
end

function M.report()
  return M._default and M._default:report() or {}
end

return M
