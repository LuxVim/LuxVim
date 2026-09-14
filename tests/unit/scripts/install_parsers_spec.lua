-- tests/unit/scripts/install_parsers_spec.lua
-- Drift guard between the two installers and the runtime.
--
-- A fresh install must arrive with its declared parsers built. That is shell
-- wiring, and shell wiring is exactly what rots: install.sh and install.ps1
-- are maintained in parallel, so a step added to one is routinely forgotten in
-- the other. The expected command name is DERIVED from core.lib.provision
-- rather than written here as a literal, so renaming it cannot leave this
-- guard passing against a string nothing defines.

local provision = require("core.lib.provision")

local function read(path)
  local fd = assert(io.open(vim.fn.getcwd() .. "/" .. path, "r"))
  local content = fd:read("*a")
  fd:close()
  return content
end

describe("installer parser provisioning", function()
  it("names the provisioning command in core.lib.provision", function()
    -- Without this the assertions below could pass against nil, matching
    -- every file trivially.
    assert.is_string(provision.COMMAND)
    assert.is_true(#provision.COMMAND > 0)
  end)

  it("install.sh runs the provisioning command", function()
    assert.is_not_nil(
      read("install.sh"):find(provision.COMMAND, 1, true),
      "install.sh never provisions parsers, so a fresh install has none"
    )
  end)

  it("install.ps1 runs the provisioning command", function()
    assert.is_not_nil(
      read("install.ps1"):find(provision.COMMAND, 1, true),
      "install.ps1 never provisions parsers, so a fresh Windows install has none"
    )
  end)

  it("registers the command the installers invoke", function()
    -- Cross-checks the name against the code that actually creates it, so the
    -- installers cannot be calling a command that does not exist.
    assert.is_not_nil(
      read("lua/plugins/editor/treesitter.lua"):find(provision.COMMAND, 1, true),
      "the treesitter config does not register the command the installers call"
    )
  end)
end)

describe("parser provisioning headless exit status", function()
  local cases = {
    { name = "successful install", wait = "present = true; return true", code = 0 },
    { name = "failed build returning false", wait = "return false", code = 1 },
    { name = "task exception", wait = "error('controlled task error')", code = 1 },
    { name = "successful task leaving a parser missing", wait = "return true", code = 1 },
  }

  for _, case in ipairs(cases) do
    it("exits " .. case.code .. " for a " .. case.name .. " followed by +qa", function()
      -- Exercise the real command and provisioner in a separate process: a Lua
      -- error alone still exits zero when the next command is +qa.
      local setup = ([=[
        package.path = './lua/?.lua;./lua/?/init.lua;' .. package.path
        package.loaded['nvim-treesitter.config'] = { setup = function() end }
        package.loaded['core.lib.languages'] = {
          rows = function() return {} end,
          by_filetype = function() return {} end,
        }
        local present = false
        local provision = require('core.lib.provision')
        provision.default_deps = function()
          return {
            missing = function() return present and {} or { 'luxvim_probe' } end,
            install = function()
              return {
                wait = function() %s end,
                await = function() end,
              }
            end,
            info = function() end,
            warn = function(msg) io.stderr:write(msg, '\n') end,
          }
        end
        dofile('lua/plugins/editor/treesitter.lua').config()
      ]=]):format(case.wait)

      local res = vim
        .system({
          vim.fn.fnamemodify(vim.v.progpath, ":p"),
          "--headless",
          "--clean",
          "-n",
          "-i",
          "NONE",
          "-c",
          "lua " .. setup,
          "+" .. provision.COMMAND,
          "+qa",
        }, { cwd = vim.fn.getcwd(), text = true, timeout = 10000 })
        :wait()

      assert.equal(case.code, res.code, res.stderr)
      if case.code ~= 0 then
        assert.is_not_nil(res.stderr:find("treesitter", 1, true))
      end
    end)
  end
end)
