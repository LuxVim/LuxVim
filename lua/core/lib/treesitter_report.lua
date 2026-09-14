-- lua/core/lib/treesitter_report.lua
-- FileType callback that reports treesitter startup failures.
--
-- Two rules this module exists to hold:
--
-- 1. Dedupe the NOTIFICATION, never the FACT. Warning on every FileType event
--    is spam, so each filetype is announced once. But a deduped warning used
--    to be the only trace a failure ever left: the second Go buffer of a
--    session said nothing while treesitter was exactly as dead as in the
--    first, so silence read as "resolved" when it meant "still broken, no
--    longer mentioned". Every failure is therefore recorded for the whole
--    session and reported by :checkhealth luxvim, announced or not.
--
-- 2. Never put Neovim internals in user-facing text. This module used to emit
--    the raw pcall error ("...runtime/lua/vim/treesitter.lua:460: Parser could
--    not be created...") through vim.notify at DEBUG level, on the assumption
--    that DEBUG is not displayed. Neovim's default handler displays it exactly
--    like every other level, so that line was unconditionally in the user's
--    face and read as a crash. The detail lives in the session record, which
--    :checkhealth luxvim renders on demand.

local notify = require("core.lib.notify")

local M = {}

--- Session record of treesitter startup failures, keyed by filetype.
--- Written by the handler, read by :checkhealth luxvim. This is the durable
--- surface that makes a one-time notification safe.
M.failures = {}

function M.default_deps()
  local languages = require("core.lib.languages")

  return {
    start = function(buf, lang)
      return pcall(vim.treesitter.start, buf, lang)
    end,
    get_lang = vim.treesitter.language.get_lang,
    get_available = function()
      return require("nvim-treesitter.config").get_available()
    end,
    declared = languages.by_filetype(languages.rows()),
    warn = notify.warn,
    record = M.failures,
  }
end

--- A declared language failing is a broken promise — LuxVim said it supports
--- this and provisioning should have installed the parser. An undeclared one
--- is a gap in the language set, and the permanent fix is a declaration, not
--- a one-off :TSInstall that the next machine will not have.
local function message(filetype, lang, declared)
  if declared then
    return (
      "treesitter parser for '%s' is missing but LuxVim declares it — "
      .. "run :TSInstall %s (:checkhealth luxvim for details)"
    ):format(filetype, lang)
  end
  return (
    "no treesitter parser for '%s' — run :TSInstall %s for this session, "
    .. "or declare it in lua/languages/%s.lua to install it every time"
  ):format(filetype, lang, lang)
end

--- Creates a FileType autocmd callback that handles treesitter attachment failure.
function M.new(deps)
  deps = deps or M.default_deps()
  local announced = {}

  return function(args)
    local filetype = args.match
    local row = deps.declared[filetype]
    if row and row.parser == false then
      return
    end
    local lang = (row and row.parser) or (deps.get_lang and deps.get_lang(filetype)) or filetype
    local ok, err = deps.start(args.buf, lang)
    if ok then
      return
    end

    -- Only report when a parser actually exists upstream to install.
    -- NOTE: do NOT use vim.treesitter.language.get_lang() as this guard — it
    -- falls back to returning the filetype itself, so get_lang("zig") returns
    -- "zig", never nil, and the guard would never fire.
    if not vim.tbl_contains(deps.get_available(), lang) then
      return -- no upstream parser for this filetype; nothing to suggest
    end

    local declared = row ~= nil

    -- Recorded on EVERY failure, before the dedupe guard: the notification is
    -- a courtesy, this is the evidence.
    deps.record[filetype] = { lang = lang, declared = declared, error = err }

    if announced[filetype] then
      return
    end
    announced[filetype] = true

    deps.warn(message(filetype, lang, declared))
  end
end

return M
