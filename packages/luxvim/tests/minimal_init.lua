-- tests/minimal_init.lua
-- Plenary-busted bootstrap. Clones plenary on first run into a dedicated
-- test-only location (data/test-plenary) so it cannot collide with the
-- runtime-managed copy in data/lazy/.

local cwd = vim.fn.getcwd()

if vim.fn.filereadable(cwd .. "/lua/core/init.lua") == 0 then
  io.stderr:write("minimal_init.lua must be run from the LuxVim repo root (cwd=" .. cwd .. ")\n")
  os.exit(1)
end

vim.opt.runtimepath:prepend(cwd)

local lua_dir = cwd .. "/lua"
package.path = cwd .. "/?.lua;" .. cwd .. "/?/init.lua;"
  .. lua_dir .. "/?.lua;" .. lua_dir .. "/?/init.lua;" .. package.path

local plenary_path = cwd .. "/data/test-plenary/plenary.nvim"
if vim.fn.isdirectory(plenary_path) == 0 then
  vim.fn.mkdir(cwd .. "/data/test-plenary", "p")
  local out = vim.fn.system({
    "git", "clone", "--depth", "1",
    "https://github.com/nvim-lua/plenary.nvim.git",
    plenary_path,
  })
  if vim.v.shell_error ~= 0 and vim.fn.isdirectory(plenary_path) == 0 then
    io.stderr:write("Failed to clone plenary.nvim\n" .. out .. "\n")
    os.exit(1)
  end
end

vim.opt.runtimepath:prepend(plenary_path)
