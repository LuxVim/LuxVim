local lsp = require("core.lib.lsp")

describe("declared LSP provisioning", function()
  local controller, callback, installs, activations, attachments, available, notifications

  before_each(function()
    installs, activations, attachments, available, notifications = 0, 0, 0, false, {}
    controller = lsp.new({
      servers = { lua_ls = { filetypes = { "lua" } } },
      provider = {
        resolve = function(_, opts)
          return opts
        end,
        available = function()
          return available
        end,
        activate = function()
          activations = activations + 1
        end,
        attach = function()
          attachments = attachments + 1
        end,
        name = function(name)
          return name
        end,
      },
      install = function(_, opts)
        installs = installs + 1
        callback = opts.callback
      end,
      notify = function(msg)
        table.insert(notifications, msg)
      end,
    })
  end)

  it("shares one install across buffers and attaches after completion", function()
    controller:ensure("lua_ls")
    controller:ensure("lua_ls")
    assert.equal(1, installs)
    assert.equal(0, activations)
    assert.equal("installing", controller:report()[1].status)
    available = true
    callback(true)
    assert.is_true(vim.wait(500, function()
      return activations == 1
    end))
    controller:ensure("lua_ls")
    assert.equal(1, installs)
    assert.equal(1, attachments)
    assert.equal("configured", controller:report()[1].status)
  end)

  it("does not repeatedly install after failure; an explicit retry works", function()
    controller:ensure("lua_ls")
    callback(false, "download failed")
    assert.is_true(vim.wait(500, function()
      return controller.states.lua_ls.status == "failed"
    end))
    controller:ensure("lua_ls")
    assert.equal(1, installs)
    assert.equal("download failed", controller:report()[1].error)
    controller:ensure("lua_ls", true)
    assert.equal(2, installs)
    available = true
    callback(true)
    assert.is_true(vim.wait(500, function()
      return activations == 1
    end))
    assert.is_nil(controller:report()[1].error)
  end)

  it("rejects installer success when no executable is available", function()
    controller:ensure("lua_ls")
    callback(true)
    assert.is_true(vim.wait(500, function()
      return controller.states.lua_ls.status == "failed"
    end))
    assert.equal(0, activations)
  end)

  it("activates existing commands without downloading", function()
    available = true
    controller:ensure("lua_ls")
    assert.equal(0, installs)
    assert.equal(1, activations)
    assert.equal("configured", controller:report()[1].status)
    assert.equal(0, controller:report()[1].attached_buffers)
  end)

  it("preserves an explicit command and reports a missing executable", function()
    controller.servers.lua_ls.cmd = { "/missing/custom-server", "--stdio" }
    controller:ensure("lua_ls")
    assert.equal(0, installs)
    assert.equal("failed", controller:report()[1].status)
  end)

  it("supports opting out of automatic installation", function()
    controller.auto_install = false
    controller:ensure("lua_ls")
    assert.equal(0, installs)
    assert.equal("missing", controller:report()[1].status)
    controller:ensure("lua_ls", true)
    assert.equal(1, installs)
  end)

  it("retains errors thrown before installation starts", function()
    controller.install = function()
      error("missing installer")
    end
    controller:ensure("lua_ls")
    assert.is_true(vim.wait(500, function()
      return controller.states.lua_ls.status == "failed"
    end))
    assert.matches("missing installer", controller:report()[1].error)
  end)

  it("handles a duplicate completion only once", function()
    controller:ensure("lua_ls")
    available = true
    callback(true)
    callback(true)
    assert.is_true(vim.wait(500, function()
      return activations == 1
    end))
  end)

  it("ignores utility buffers and undeclared filetypes", function()
    local buf = vim.api.nvim_create_buf(false, true)
    vim.bo[buf].filetype = "lua"
    controller:on_buffer(buf)
    assert.equal(0, installs)
    vim.bo[buf].buftype = ""
    vim.bo[buf].filetype = "text"
    controller:on_buffer(buf)
    assert.equal(0, installs)
    vim.api.nvim_buf_delete(buf, { force = true })
  end)
end)
