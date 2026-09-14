-- lua/core/lib/declarations.lua
-- Primitive: a directory of one-file-per-thing declarations -> rows.
--
-- Domain-agnostic on purpose. This module carries no product vocabulary: it
-- knows about files, defaults, and directory precedence, and nothing about
-- languages, plugins, or anything else declared on top of it. Every consumer
-- that wants "drop a file in a directory to declare a thing" builds on this
-- rather than writing its own scan/dofile/merge loop.
--
-- Precedence: directories are applied in order, later over earlier, so a user
-- directory listed after the framework one wins. The default merge is a deep
-- extend, which is what makes a user file able to override a single nested
-- option without restating the whole declaration; a row that sets
-- `replaces = true` opts out and discards the earlier row wholesale.

local paths = require("core.lib.paths")

local M = {}

M.DEFAULTS_FILE = "_defaults.lua"

--- Rows are keyed by basename, so `_defaults.lua` is not a row and neither is
--- anything else underscore-prefixed: the prefix is reserved for files that
--- support the directory rather than declare a member of it.
local function is_declaration_file(name)
  return name:match("%.lua$") ~= nil and not vim.startswith(name, "_")
end

--- NOTE: deliberately does NOT filter on scandir's entry_type. nvim-treesitter
--- taught this codebase (see core.lib.parsers) that a perfectly ordinary entry
--- can arrive as type "link"; filtering on "file" silently empties the result.
local function declaration_files(dir)
  return paths.scandir(dir, function(name)
    return is_declaration_file(name)
  end)
end

local function read_table(path)
  local ok, result = pcall(dofile, path)
  if not ok then
    return nil, "failed to load: " .. tostring(result)
  end
  if type(result) ~= "table" then
    return nil, "declaration must return a table, got " .. type(result)
  end
  return result
end

local function read_defaults(dir)
  local path = paths.join(dir, M.DEFAULTS_FILE)
  if not vim.uv.fs_stat(path) then
    return {}
  end
  local defaults = read_table(path)
  return defaults or {}
end

--- Later row wins. `replaces` discards the earlier row rather than merging
--- into it, and is consumed so it never leaks into the returned declaration.
local function combine(existing, incoming)
  if incoming.replaces then
    incoming.replaces = nil
    return incoming
  end
  if not existing then
    return incoming
  end
  return vim.tbl_deep_extend("force", existing, incoming)
end

local function load_dir(dir, source, rows, errors)
  local defaults = read_defaults(dir)

  for _, entry in ipairs(declaration_files(dir)) do
    local path = paths.join(dir, entry.name)
    local row, err = read_table(path)

    if not row then
      table.insert(errors, { file = path, message = err })
    else
      local name = entry.name:match("^(.*)%.lua$")
      -- deepcopy per row: tbl_deep_extend copies tables by reference when only
      -- one side has the key, so without this every row would share the very
      -- same defaults sub-tables and a mutation in one would surface in all.
      row = vim.tbl_deep_extend("force", vim.deepcopy(defaults), row)
      row._file = path
      row._source = source
      rows[name] = combine(rows[name], row)
    end
  end
end

--- Loads every declaration directory in `opts.dirs` (in order, later wins).
--- Returns rows keyed by basename, plus a list of { file, message } errors for
--- declarations that could not be loaded. A directory that does not exist is
--- not an error — user overlay directories are optional by design.
function M.load(opts)
  local rows, errors = {}, {}
  for _, dir in ipairs((opts and opts.dirs) or {}) do
    load_dir(dir.path, dir.source, rows, errors)
  end
  return rows, errors
end

return M
