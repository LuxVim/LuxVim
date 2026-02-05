local M = {}

M.is_windows = vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1

function M.normalize(path)
  if not path then
    return nil
  end
  path = path:gsub("\\", "/"):gsub("/+", "/")
  if path:sub(-1) == "/" then
    return path:sub(1, -2)
  end
  return path
end

function M.join(...)
  local parts = { ... }
  local filtered = vim.tbl_filter(function(p)
    return p and p ~= ""
  end, parts)
  return M.normalize(table.concat(filtered, "/"))
end

function M.basename(path)
  if not path then
    return nil
  end
  return M.normalize(path):match("([^/]+)$")
end

return M
