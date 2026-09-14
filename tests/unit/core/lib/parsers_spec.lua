-- tests/unit/core/lib/parsers_spec.lua
local parsers = require("core.lib.parsers")
local tmpdir = require("tests.helpers.tmpdir")

describe("parsers.parse_inherits", function()
  local function langs(text)
    return vim.tbl_map(function(e)
      return e.lang
    end, parsers.parse_inherits(text))
  end

  it("extracts a single inherited language", function()
    assert.same({ "html" }, langs("; inherits: html\n(raw_text) @none\n"))
  end)

  it("extracts a comma-separated list", function()
    assert.same({ "ecma", "jsx" }, langs("; inherits: ecma,jsx\n"))
  end)

  it("returns an empty list when there is no inherits modeline", function()
    assert.same({}, langs("(identifier) @variable\n"))
  end)

  it("stops at the first non-comment line, as Neovim does", function()
    assert.same({}, langs("(x) @y\n; inherits: html\n"))
  end)

  -- Neovim scans the whole LEADING comment block, not just line 1.
  it("finds the modeline below other leading comments", function()
    assert.same({ "html" }, langs(";; a note about this file\n; inherits: html\n"))
  end)

  -- Neovim's MODELINE_FORMAT makes the colon optional.
  it("accepts the colon-less form Neovim accepts", function()
    assert.same({ "html" }, langs("; inherits html\n"))
  end)

  -- Parenthesized entries are OPTIONAL inherits, and the parens are not
  -- part of the language name.
  it("strips parens from optional inherits and flags them", function()
    local result = parsers.parse_inherits("; inherits: c,(comment)\n")
    assert.equal("c", result[1].lang)
    assert.is_false(result[1].optional)
    assert.equal("comment", result[2].lang)
    assert.is_true(result[2].optional)
  end)

  -- NEGATIVE TEST: leading whitespace makes it NOT a modeline for Neovim,
  -- so honoring it here would report gaps Neovim never has.
  it("rejects a leading-whitespace line that Neovim does not treat as a modeline", function()
    assert.same({}, langs("  ; inherits: html\n"))
  end)

  -- NEGATIVE TEST: the tail is strictly anchored. A prose comment that merely
  -- starts with "inherits" is not a modeline for Neovim. Without `%s*$` this
  -- parses as inheriting a language called "from" and :checkhealth emits a
  -- bogus "inherits 'from', which is not installed" warning.
  it("rejects a prose comment whose tail is not a bare language list", function()
    assert.same({}, langs("; inherits from html\n"))
  end)

  -- NEGATIVE TEST: pins the `^` anchor; without it the pattern matches a
  -- modeline-shaped fragment in the middle of a comment line.
  it("rejects an inherits fragment that is not at the start of the line", function()
    assert.same({}, langs("; see the query that ; inherits: html\n"))
  end)
end)

describe("parsers.installed_parsers", function()
  it("lists languages by stripping the shared-library extension", function()
    local root, cleanup = tmpdir.new({
      parser = { ["svelte.so"] = "", ["html.so"] = "" },
    })
    local found = parsers.installed_parsers(root)
    assert.is_true(found.svelte)
    assert.is_true(found.html)
    cleanup()
  end)

  it("returns an empty table when the parser directory does not exist", function()
    local root, cleanup = tmpdir.new({})
    assert.same({}, parsers.installed_parsers(root))
    cleanup()
  end)
end)

describe("parsers.installed_queries", function()
  it("lists plain query directories", function()
    local root, cleanup = tmpdir.new({ queries = { svelte = { ["highlights.scm"] = "" } } })
    assert.is_true(parsers.installed_queries(root).svelte)
    cleanup()
  end)

  -- NEGATIVE TEST: this is how the real install is laid out. nvim-treesitter
  -- SYMLINKS query dirs into install_dir, so fs_scandir reports them as
  -- "link". A filter on entry_type == "directory" passes every other test in
  -- this file while returning {} in production, silently disabling every gap
  -- check. This test fails if that regression is reintroduced.
  it("follows symlinked query directories the way a real install lays them out", function()
    local root, cleanup = tmpdir.new({
      real = { svelte = { ["highlights.scm"] = "; inherits: html\n" } },
      queries = {},
    })
    vim.uv.fs_symlink(root .. "/real/svelte", root .. "/queries/svelte", { dir = true })

    local found = parsers.installed_queries(root)
    assert.is_true(found.svelte, "symlinked query directory was not detected")
    cleanup()
  end)

  it("ignores loose files that are not directories", function()
    local root, cleanup = tmpdir.new({ queries = { ["README.md"] = "not a language" } })
    assert.same({}, parsers.installed_queries(root))
    cleanup()
  end)
end)

describe("parsers.inherit_gaps", function()
  -- NEGATIVE TEST: this is the exact svelte fault. It MUST be detected.
  it("detects the svelte -> html gap that :TSInstall reports as healthy", function()
    local root, cleanup = tmpdir.new({
      parser = { ["svelte.so"] = "" },
      queries = {
        svelte = { ["highlights.scm"] = "; inherits: html\n(raw_text) @none\n" },
        html_tags = { ["highlights.scm"] = "(tag_name) @tag\n" },
      },
    })

    local gaps = parsers.inherit_gaps(root)

    local found = false
    for _, gap in ipairs(gaps) do
      if gap.lang == "svelte" and gap.missing == "html" then
        found = true
      end
    end
    assert.is_true(found, "svelte -> html inherit gap was not detected")
    cleanup()
  end)

  it("reports no gap once the inherited language's queries are installed", function()
    local root, cleanup = tmpdir.new({
      parser = { ["svelte.so"] = "" },
      queries = {
        svelte = { ["highlights.scm"] = "; inherits: html\n" },
        html = { ["highlights.scm"] = "(tag_name) @tag\n" },
      },
    })
    assert.same({}, parsers.inherit_gaps(root))
    cleanup()
  end)

  it("checks every query kind, not just highlights", function()
    local root, cleanup = tmpdir.new({
      parser = { ["svelte.so"] = "" },
      queries = {
        svelte = {
          ["highlights.scm"] = "(x) @y\n",
          ["injections.scm"] = "; inherits: html_tags\n",
        },
      },
    })
    local gaps = parsers.inherit_gaps(root)
    local found = false
    for _, gap in ipairs(gaps) do
      if gap.kind == "injections" and gap.missing == "html_tags" then
        found = true
      end
    end
    assert.is_true(found, "injections.scm inherit gap was not detected")
    cleanup()
  end)

  it("reports an inherit gap declared in ANY query kind", function()
    for _, kind in ipairs({ "highlights", "injections", "indents", "folds", "locals" }) do
      local root, cleanup = tmpdir.new({
        parser = { ["astro.so"] = "" },
        queries = { astro = { [kind .. ".scm"] = "; inherits: html\n" } },
      })
      local hit = false
      for _, g in ipairs(parsers.inherit_gaps(root)) do
        if g.kind == kind and g.missing == "html" then
          hit = true
        end
      end
      assert.is_true(hit, kind .. ".scm inherit gap was not detected")
      cleanup()
    end
  end)

  -- Bundled queries in $VIMRUNTIME (such as c/highlights.scm) resolve on the runtimepath
  -- and should not be reported as missing inherit gaps.
  it("does not report an inherit gap when the inherited query is bundled in Neovim runtime", function()
    local root, cleanup = tmpdir.new({
      parser = { ["cpp.so"] = "" },
      queries = {
        cpp = {
          ["highlights.scm"] = "; inherits: c\n(type_identifier) @type\n",
        },
      },
    })
    assert.same({}, parsers.inherit_gaps(root))
    cleanup()
  end)

  -- Per-kind resolution: $VIMRUNTIME provides c/highlights.scm but not c/indents.scm.
  -- cpp/indents.scm inheriting c must still be reported as an inherit gap.
  it("reports an inherit gap when an inherit target query kind is absent from Neovim runtime", function()
    local root, cleanup = tmpdir.new({
      parser = { ["cpp.so"] = "" },
      queries = {
        cpp = {
          ["indents.scm"] = "; inherits: c\n",
        },
      },
    })
    local gaps = parsers.inherit_gaps(root)
    local found = false
    for _, g in ipairs(gaps) do
      if g.lang == "cpp" and g.kind == "indents" and g.missing == "c" then
        found = true
      end
    end
    assert.is_true(found, "cpp/indents.scm inheriting c was not detected as gap")
    cleanup()
  end)

  it("honors custom query resolver when supplied", function()
    local root, cleanup = tmpdir.new({
      parser = { ["sample.so"] = "" },
      queries = {
        sample = {
          ["highlights.scm"] = "; inherits: custom_runtime,missing_target\n",
        },
      },
    })
    local custom_resolvers = {
      query = function(lang, _)
        return lang == "custom_runtime"
      end,
    }
    local gaps = parsers.inherit_gaps(root, custom_resolvers)
    assert.equal(1, #gaps)
    assert.equal("missing_target", gaps[1].missing)
    cleanup()
  end)

  it("returns an empty list for an empty install directory", function()
    local root, cleanup = tmpdir.new({})
    assert.same({}, parsers.inherit_gaps(root))
    cleanup()
  end)
end)

describe("parsers.parse_injection_languages", function()
  it("extracts injected language names from #set! injection.language directives", function()
    local text = '((code_block) @injection.content (#set! injection.language "python"))\n'
    assert.same({ "python" }, parsers.parse_injection_languages(text))
  end)

  -- NEGATIVE TEST: commented-out directives must NOT be parsed as injections.
  -- Otherwise, commented TODOs/examples create false injection gaps for nonexistent parsers.
  it("ignores #set! injection.language directives inside comment lines", function()
    local text = '; ((instruction) @injection.content\n;  (#set! injection.language "asm"))\n'
    assert.same({}, parsers.parse_injection_languages(text))
  end)

  it("ignores trailing inline comments on injection lines", function()
    local text = '((code) @injection.content (#set! injection.language "lua")) ; (#set! injection.language "asm")\n'
    assert.same({ "lua" }, parsers.parse_injection_languages(text))
  end)
end)

describe("parsers.injection_gaps", function()
  local SVELTE_INJECTIONS = [[
; inherits: html_tags

((svelte_raw_text) @injection.content
  (#set! injection.language "javascript"))

((script_element
  (raw_text) @injection.content)
  (#set! injection.language "typescript"))
]]

  -- NEGATIVE TEST: injected languages without parsers must be detected.
  it("detects injected languages that have no compiled parser", function()
    local root, cleanup = tmpdir.new({
      parser = { ["svelte.so"] = "" },
      queries = { svelte = { ["injections.scm"] = SVELTE_INJECTIONS } },
    })

    local missing = {}
    for _, gap in ipairs(parsers.injection_gaps(root)) do
      missing[gap.missing] = true
    end
    assert.is_true(missing.javascript, "javascript injection gap not detected")
    assert.is_true(missing.typescript, "typescript injection gap not detected")
    cleanup()
  end)

  it("reports no gap once the injected parsers are installed", function()
    local root, cleanup = tmpdir.new({
      parser = { ["svelte.so"] = "", ["javascript.so"] = "", ["typescript.so"] = "" },
      queries = { svelte = { ["injections.scm"] = SVELTE_INJECTIONS } },
    })
    assert.same({}, parsers.injection_gaps(root))
    cleanup()
  end)

  it("ignores capture references rather than treating them as languages", function()
    local root, cleanup = tmpdir.new({
      parser = { ["x.so"] = "" },
      queries = { x = { ["injections.scm"] = "((a) @injection.content)\n" } },
    })
    assert.same({}, parsers.injection_gaps(root))
    cleanup()
  end)

  -- NEGATIVE TEST: predicate forms name a language being TESTED or EXCLUDED,
  -- never injected. This is verbatim from ecma/injections.scm:22 — a broad
  -- `injection.language "x"` pattern reads it as "ecma injects svg", which is
  -- backwards. This test fails if the pattern is broadened.
  it("does not treat #not-any-of? exclusions as injected languages", function()
    local root, cleanup = tmpdir.new({
      parser = { ["ecma.so"] = "" },
      queries = {
        ecma = {
          ["injections.scm"] = "((x) @injection.content\n" .. '  (#not-any-of? @injection.language "svg" "css"))\n',
        },
      },
    })
    assert.same({}, parsers.injection_gaps(root))
    cleanup()
  end)

  it("does not treat #eq? predicate matches as injected languages", function()
    local root, cleanup = tmpdir.new({
      parser = { ["svelte.so"] = "" },
      queries = {
        svelte = {
          ["injections.scm"] = "((x) @injection.content\n" .. '  (#eq? @injection.language "pug"))\n',
        },
      },
    })
    assert.same({}, parsers.injection_gaps(root))
    cleanup()
  end)

  it("ignores commented #set! injection.language directives in query files", function()
    local root, cleanup = tmpdir.new({
      parser = { ["objdump.so"] = "" },
      queries = {
        objdump = {
          ["injections.scm"] = "; TODO: https://github.com/nvim-treesitter/nvim-treesitter/pull/5548\n"
            .. "; ((instruction) @injection.content\n"
            .. ';  (#set! injection.language "asm"))\n',
        },
      },
    })
    assert.same({}, parsers.injection_gaps(root))
    cleanup()
  end)

  -- Bundled parsers in $VIMRUNTIME (such as vim.so, lua.so, c.so) resolve on the runtimepath
  -- and should not be reported as missing injection gaps.
  it("does not report an injection gap when the parser is bundled in Neovim runtime", function()
    local root, cleanup = tmpdir.new({
      parser = { ["lua.so"] = "" },
      queries = {
        lua = {
          ["injections.scm"] = '((treesitter) @injection.content (#set! injection.language "vim"))\n',
        },
      },
    })
    assert.same({}, parsers.injection_gaps(root))
    cleanup()
  end)

  it("honors custom parser resolver when supplied", function()
    local root, cleanup = tmpdir.new({
      parser = { ["sample.so"] = "" },
      queries = {
        sample = {
          ["injections.scm"] = '((a) @injection.content (#set! injection.language "custom_parser"))\n'
            .. '((b) @injection.content (#set! injection.language "missing_parser"))\n',
        },
      },
    })
    local custom_resolvers = {
      parser = function(lang)
        return lang == "custom_parser"
      end,
    }
    local gaps = parsers.injection_gaps(root, custom_resolvers)
    assert.equal(1, #gaps)
    assert.equal("missing_parser", gaps[1].missing)
    cleanup()
  end)

  it("returns an empty list for an empty install directory", function()
    local root, cleanup = tmpdir.new({})
    assert.same({}, parsers.injection_gaps(root))
    cleanup()
  end)
end)
