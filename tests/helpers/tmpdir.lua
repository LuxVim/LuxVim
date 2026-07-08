-- tests/helpers/tmpdir.lua
-- Materializes directory trees on the real filesystem for tests that
-- exercise vim.uv.fs_scandir / dofile. Using real files avoids fragile
-- mocks and keeps tests exercising the production code path.

local M = {}

local function new_root()
  local root = vim.fn.tempname()
  vim.fn.mkdir(root, "p")
  return root
end

local function write_tree(root, tree)
  for name, content in pairs(tree) do
    local path = root .. "/" .. name
    if type(content) == "table" then
      vim.fn.mkdir(path, "p")
      write_tree(path, content)
    else
      assert(
        type(content) == "string",
        "tmpdir tree leaf must be string or table, got " .. type(content) .. " at " .. path
      )
      local f = assert(io.open(path, "w"))
      f:write(content)
      f:close()
    end
  end
end

function M.new(tree)
  local root = new_root()
  if tree then
    write_tree(root, tree)
  end
  local cleanup = function()
    vim.fn.delete(root, "rf")
  end
  return root, cleanup
end

return M
