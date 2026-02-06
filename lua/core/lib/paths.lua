local M = {}

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

function M.scandir(dir, filter_fn)
  local results = {}
  local handle = vim.uv.fs_scandir(dir)
  if not handle then
    return results
  end
  while true do
    local name, entry_type = vim.uv.fs_scandir_next(handle)
    if not name then
      break
    end
    if not filter_fn or filter_fn(name, entry_type) then
      table.insert(results, { name = name, type = entry_type })
    end
  end
  return results
end

return M
