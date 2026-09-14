-- tests/unit/core/lib/autocmd_spec.lua
-- Proves the FileType options LuxVim applies are DERIVED from the language
-- declarations rather than restated in a second hand-maintained table, and
-- that deriving them did not cost users their registry/filetypes.lua overlay.

local autocmd = require("core.lib.autocmd")
local tmpdir = require("tests.helpers.tmpdir")

local function with_user_config(root, fn)
  local orig = vim.env.LUXVIM_CONFIG
  vim.env.LUXVIM_CONFIG = root
  local ok, err = pcall(fn)
  vim.env.LUXVIM_CONFIG = orig
  if not ok then
    error(err)
  end
end

--- Opens a scratch buffer, sets its filetype (which fires FileType), and
--- returns the resulting value of a buffer-local option.
local function option_after_filetype(filetype, option)
  vim.cmd("enew!")
  vim.bo.filetype = filetype
  local value = vim.bo[option]
  vim.cmd("bdelete!")
  return value
end

describe("core.lib.autocmd filetype options", function()
  -- NOTE on the three tests below: they assert values that the pre-migration
  -- hand-written core/registry/filetypes.lua also produced. That is their job
  -- — they are behavior-preservation guards for the migration. The test that
  -- actually proves the entries are DERIVED is the one in the "derivation"
  -- block at the bottom, which uses a language the old table never contained.
  local empty_config, cleanup

  before_each(function()
    -- Isolate from the developer's real ~/.config/luxvim so their overlay
    -- cannot decide whether these pass.
    empty_config, cleanup = tmpdir.new({})
  end)

  after_each(function()
    if cleanup then
      cleanup()
    end
  end)

  it("applies options a language declaration owns to that language's filetype", function()
    with_user_config(empty_config, function()
      assert.is_true(autocmd.setup())
      -- lua/languages/javascript.lua declares tabstop = 2; the editor default
      -- is 8, so this cannot pass unless the declaration was actually read.
      assert.equal(2, option_after_filetype("javascript", "tabstop"))
    end)
  end)

  -- Negative partner: a registration that blanket-applied one language's
  -- options to every filetype would pass the test above and fail this one.
  it("leaves a filetype alone when its language declares no options", function()
    with_user_config(empty_config, function()
      assert.is_true(autocmd.setup())
      -- lua/languages/go.lua declares no options.
      assert.equal(8, option_after_filetype("go", "tabstop"))
    end)
  end)

  it("still honors a user registry/filetypes.lua overlay on the derived entries", function()
    local user_root, user_cleanup = tmpdir.new({
      registry = {
        ["filetypes.lua"] = "return { extends = true, go = { tabstop = 3 } }",
      },
    })

    with_user_config(user_root, function()
      assert.is_true(autocmd.setup())
      assert.equal(3, option_after_filetype("go", "tabstop"), "the user overlay must still reach the filetype registry")
      assert.equal(
        2,
        option_after_filetype("javascript", "tabstop"),
        "extending must not discard the derived declarations"
      )
    end)

    user_cleanup()
  end)

  describe("derivation", function()
    it("applies options from a language declared only in the user's languages dir", function()
      -- Nothing in lua/ knows about this language. It can only reach the
      -- FileType autocmd if the filetype registry is derived from the language
      -- declarations; a hand-written framework table cannot produce it.
      local user_root, user_cleanup = tmpdir.new({
        languages = {
          ["zonk.lua"] = "return { filetypes = { 'zonk' }, options = { tabstop = 7 } }",
        },
      })

      with_user_config(user_root, function()
        assert.is_true(autocmd.setup())
        assert.equal(7, option_after_filetype("zonk", "tabstop"))
      end)

      user_cleanup()
    end)
  end)
  -- Languages where the indent character is SEMANTIC, not cosmetic: a Makefile
  -- recipe line must begin with a literal tab or make fails with "missing
  -- separator", and gofmt writes tabs, so spaces make every save a diff.
  --
  -- Neovim's own ftplugin/make.vim and ftplugin/go.vim already set
  -- `noexpandtab`, which correctly overrides LuxVim's global expandtab=true
  -- per buffer. Nothing in lua/languages/ needs to restate that, and this file
  -- deliberately does not — restating a fact the runtime already enforces is
  -- how the two copies drift.
  --
  -- What this guards is the hazard the language registry introduces: these
  -- declarations sit next to javascript.lua and python.lua, which DO set
  -- expandtab = true, so one copy-paste silently breaks every Makefile in the
  -- repo with no error anywhere. LuxVim's FileType autocmds run after the
  -- ftplugin, so a declaration always wins.
  describe("languages where a tab is semantic", function()
    for _, filetype in ipairs({ "go", "make" }) do
      it(("keeps a literal tab as the indent character for '%s'"):format(filetype), function()
        with_user_config(empty_config, function()
          assert.is_true(autocmd.setup())
          assert.is_false(
            option_after_filetype(filetype, "expandtab"),
            (
              "'%s' indents with spaces; a declaration in lua/languages/ has "
              .. "overridden the ftplugin that keeps it on tabs"
            ):format(filetype)
          )
        end)
      end)
    end
  end)
end)
