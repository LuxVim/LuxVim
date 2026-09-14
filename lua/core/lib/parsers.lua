-- lua/core/lib/parsers.lua
-- Pure introspection over a treesitter install directory.
--
-- The value here is inherit_gaps(): a query file whose header declares
-- `; inherits: X` is non-functional without X's queries, but nvim-treesitter
-- does not declare that as an install dependency. svelte/highlights.scm
-- inherits html while svelte.requires is only { "html_tags" }, so :TSInstall
-- reports "2/2 languages" while highlighting produces zero captures.

local paths = require("core.lib.paths")

local M = {}

local function query_kinds(install_dir, lang)
  local kinds = {}
  for _, e in ipairs(paths.scandir(paths.join(install_dir, "queries", lang))) do
    local kind = e.name:match("^(.*)%.scm$")
    if kind then
      table.insert(kinds, kind)
    end
  end
  table.sort(kinds)
  return kinds
end

local function strip_lib_extension(name)
  return name:match("^(.-)%.so$") or name:match("^(.-)%.dylib$") or name:match("^(.-)%.dll$")
end

--- Set of languages with a compiled parser in `install_dir/parser/`.
function M.installed_parsers(install_dir)
  local found = {}
  local entries = paths.scandir(paths.join(install_dir, "parser"))
  for _, entry in ipairs(entries) do
    local lang = strip_lib_extension(entry.name)
    if lang then
      found[lang] = true
    end
  end
  return found
end

--- Set of languages with a query directory in `install_dir/queries/`.
---
--- CRITICAL: nvim-treesitter main SYMLINKS each query directory into
--- install_dir rather than copying it, so vim.uv.fs_scandir reports these
--- entries as type "link", NOT "directory". Filtering on
--- `entry_type == "directory"` returns an empty set against a real install
--- and silently kills every gap check below. fs_stat follows the symlink,
--- so stat the joined path instead of trusting the scandir entry type.
function M.installed_queries(install_dir)
  local found = {}
  local queries_dir = paths.join(install_dir, "queries")
  for _, entry in ipairs(paths.scandir(queries_dir)) do
    local stat = vim.uv.fs_stat(paths.join(queries_dir, entry.name))
    if stat and stat.type == "directory" then
      found[entry.name] = true
    end
  end
  return found
end

-- Copied verbatim from Neovim's own modeline parser
-- (/usr/share/nvim/runtime/lua/vim/treesitter/query.lua:9) so this module
-- agrees with what Neovim actually honors. Note: the colon is OPTIONAL,
-- leading whitespace is NOT allowed, the tail is strictly anchored, and
-- `(lang)` marks an OPTIONAL inherit.
local MODELINE_FORMAT = "^;+%s*inherits%s*:?%s*([a-z_,()]+)%s*$"

--- Languages named in a query file's `; inherits:` modeline.
---
--- Mirrors Neovim's algorithm: scan the LEADING comment block, breaking at
--- the first line that does not start with ';'. Reading only line 1 would
--- miss `;; some note\n; inherits: html`, which Neovim does honor.
--- Parenthesized entries are optional inherits; the parens are stripped and
--- the entry is reported with optional = true so callers can soften them.
function M.parse_inherits(text)
  local result = {}
  if type(text) ~= "string" then
    return result
  end

  for line in text:gmatch("([^\n]*)\n?") do
    if not vim.startswith(line, ";") then
      break
    end
    local langlist = line:match(MODELINE_FORMAT)
    if langlist then
      for _, entry in ipairs(vim.split(langlist, ",")) do
        if entry ~= "" then
          local optional = entry:match("^%((.*)%)$")
          table.insert(result, {
            lang = optional or entry,
            optional = optional ~= nil,
          })
        end
      end
    end
  end

  return result
end

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

--- Default resolvers that query the Neovim runtimepath.
--- Bundled parsers and queries in $VIMRUNTIME (e.g. c, lua, vim) resolve
--- here even when absent from install_dir.
M.default_resolvers = {
  query = function(lang, kind)
    return #vim.api.nvim_get_runtime_file(("queries/%s/%s.scm"):format(lang, kind), false) > 0
  end,
  parser = function(lang)
    return #vim.api.nvim_get_runtime_file(("parser/%s.*"):format(lang), false) > 0
  end,
}

--- Every declared inherit whose target has no installed queries on disk
--- or resolvable on the Neovim runtimepath.
--- Returns a list of { lang, kind, missing, optional }.
function M.inherit_gaps(install_dir, resolvers)
  local resolve = (resolvers and resolvers.query) or M.default_resolvers.query
  local available = M.installed_queries(install_dir)
  local gaps = {}

  for lang in pairs(available) do
    for _, kind in ipairs(query_kinds(install_dir, lang)) do
      local query_path = paths.join(install_dir, "queries", lang, kind .. ".scm")
      local content = read_file(query_path)
      if content then
        for _, inherited in ipairs(M.parse_inherits(content)) do
          if not available[inherited.lang] and not resolve(inherited.lang, kind) then
            table.insert(gaps, {
              lang = lang,
              kind = kind,
              missing = inherited.lang,
              optional = inherited.optional,
            })
          end
        end
      end
    end
  end

  table.sort(gaps, function(a, b)
    if a.lang ~= b.lang then
      return a.lang < b.lang
    end
    return a.kind < b.kind
  end)

  return gaps
end

local function strip_query_comments(text)
  local lines = vim.split(text, "\n")
  local out = {}
  for _, line in ipairs(lines) do
    local in_string = false
    local cut = nil
    local i = 1
    while i <= #line do
      local ch = line:sub(i, i)
      if in_string then
        if ch == "\\" then
          i = i + 1
        elseif ch == '"' then
          in_string = false
        end
      elseif ch == '"' then
        in_string = true
      elseif ch == ";" then
        cut = i
        break
      end
      i = i + 1
    end
    table.insert(out, cut and line:sub(1, cut - 1) or line)
  end
  return table.concat(out, "\n")
end

--- Languages unconditionally injected by a query file.
---
--- ONLY `(#set! injection.language "x")` counts. Do NOT broaden this to any
--- occurrence of `injection.language "x"`: predicate forms name a language
--- being *tested*, not injected, and `#not-any-of?` names languages being
--- EXCLUDED. ecma/injections.scm:22 contains
--- `(#not-any-of? @injection.language "svg" "css")` — a broad pattern reads
--- that as "ecma injects svg", which is precisely backwards and produces
--- false-positive health warnings.
function M.parse_injection_languages(text)
  local result = {}
  if type(text) ~= "string" then
    return result
  end
  local stripped = strip_query_comments(text)
  local seen = {}
  for lang in stripped:gmatch('#set!%s+injection%.language%s+"([%w_]+)"') do
    if not seen[lang] then
      seen[lang] = true
      table.insert(result, lang)
    end
  end
  return result
end

--- Injected languages that have no compiled parser installed in install_dir
--- or resolvable on the Neovim runtimepath.
--- Returns a list of { lang, missing }.
function M.injection_gaps(install_dir, resolvers)
  local resolve = (resolvers and resolvers.parser) or M.default_resolvers.parser
  local available_parsers = M.installed_parsers(install_dir)
  local available_queries = M.installed_queries(install_dir)
  local gaps = {}
  local seen = {}

  for lang in pairs(available_queries) do
    local content = read_file(paths.join(install_dir, "queries", lang, "injections.scm"))
    if content then
      for _, injected in ipairs(M.parse_injection_languages(content)) do
        local key = lang .. "/" .. injected
        if not available_parsers[injected] and not resolve(injected) and not seen[key] then
          seen[key] = true
          table.insert(gaps, { lang = lang, missing = injected })
        end
      end
    end
  end

  table.sort(gaps, function(a, b)
    if a.lang ~= b.lang then
      return a.lang < b.lang
    end
    return a.missing < b.missing
  end)

  return gaps
end

return M
