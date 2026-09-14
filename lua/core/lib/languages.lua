-- lua/core/lib/languages.lua
-- The language abstraction: LuxVim's single source of truth for what it means
-- to "support" a language.
--
-- One file per language under lua/languages/ declares the parser, the
-- filetypes it owns, and the editor options those filetypes get. Everything
-- downstream is DERIVED from that declaration rather than restated:
--
--   parsers()          -> what install.sh provisions and startup self-heals
--   missing_parsers()  -> what :checkhealth luxvim reports as a gap
--   filetype_options() -> the FileType autocmds core.lib.autocmd registers
--   by_filetype()      -> whether a failing FileType is one LuxVim promised
--
-- Adding a language is therefore a new file, not an edit to a shared table and
-- not a second entry in three other places. Before this existed, "which
-- languages does LuxVim support" had no answer in the repo at all: parsers
-- were whatever happened to be sitting in the gitignored data/site/parser/,
-- so a missing parser was indistinguishable from a language nobody wanted.

local data = require("core.lib.data")
local declarations = require("core.lib.declarations")
local parsers = require("core.lib.parsers")
local paths = require("core.lib.paths")

local M = {}

--- Framework declarations first, user declarations second: core.lib.declarations
--- applies directories in order and lets the later one win, which is what makes
--- ~/.config/luxvim/languages/go.lua able to retune a shipped language.
function M.default_dirs()
  return {
    { path = paths.join(data.root(), "lua", "languages"), source = "framework" },
    { path = paths.join(data.user_config_path(), "languages"), source = "user" },
  }
end

--- Every field is optional; the filename carries the defaults. `parser = false`
--- declares a language LuxVim configures but has no treesitter grammar for, so
--- it is never provisioned and never reported as a gap.
local function normalize(name, row)
  local parser = row.parser
  if parser == nil then
    parser = name
  end

  return {
    name = name,
    parser = parser,
    filetypes = row.filetypes or { name },
    options = row.options or {},
    _file = row._file,
    _source = row._source,
  }
end

--- Loads the declared languages as a list sorted by name.
--- Returns rows plus a list of { file, message } errors for declarations that
--- could not be loaded — surfaced, never swallowed.
function M.load(opts)
  local dirs = (opts and opts.dirs) or M.default_dirs()
  local raw, errors = declarations.load({ dirs = dirs })

  local names = vim.tbl_keys(raw)
  table.sort(names)

  local rows = {}
  for _, name in ipairs(names) do
    table.insert(rows, normalize(name, raw[name]))
  end
  return rows, errors
end

--- The declarations alone, for consumers that do not handle load errors.
---
--- load() returns (rows, errors), and Lua splices multiple returns into the
--- argument list of an enclosing call: `missing_parsers(load())` quietly
--- passes `errors` as the resolver. This exists so the common case cannot
--- make that mistake. Callers that must surface broken declarations — health —
--- still use load().
function M.rows(opts)
  local rows = M.load(opts)
  return rows
end

--- The deduped, sorted set of treesitter parsers the declarations require.
function M.parsers(rows)
  local seen, out = {}, {}
  for _, row in ipairs(rows) do
    if row.parser and not seen[row.parser] then
      seen[row.parser] = true
      table.insert(out, row.parser)
    end
  end
  table.sort(out)
  return out
end

--- filetype -> editor options, for every language that declares any.
--- Languages with no options are omitted so no empty autocmd gets registered.
function M.filetype_options(rows)
  local out = {}
  for _, row in ipairs(rows) do
    if next(row.options) then
      for _, filetype in ipairs(row.filetypes) do
        out[filetype] = row.options
      end
    end
  end
  return out
end

--- filetype -> language row, for callers asking "did we promise this one?".
function M.by_filetype(rows)
  local out = {}
  for _, row in ipairs(rows) do
    for _, filetype in ipairs(row.filetypes) do
      out[filetype] = row
    end
  end
  return out
end

--- Declared parsers that cannot be resolved, sorted.
---
--- Resolution goes through the RUNTIMEPATH, not the install directory: parsers
--- bundled with Neovim (c, lua, markdown, query, vim, vimdoc) are never
--- installed by anyone and must never be reported as a gap. Checking
--- install_dir alone is exactly the bug commit 4b64584 fixed for query gaps.
--- `resolve` is injectable so tests do not depend on the host's parsers.
function M.missing_parsers(rows, resolve)
  resolve = resolve or parsers.default_resolvers.parser

  local missing = {}
  for _, parser in ipairs(M.parsers(rows)) do
    if not resolve(parser) then
      table.insert(missing, parser)
    end
  end
  return missing
end

return M
