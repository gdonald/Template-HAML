# Changelog

All notable changes to this project will be documented in this file.

## v0.9.2 — 2026-05-25

### Changed

- **CI workflow.** Added a `name:` and `workflow_dispatch` trigger so the
  pipeline can be re-run manually from the GitHub Actions UI.
- **CI dependencies.** Dropped the explicit install step for `BDD::Behave`
  from git; it now resolves through normal `--test-depends` from the Raku
  ecosystem.

## v0.9.1 — 2026-05-23

### Added

- **Tag shorthand interpolation.** `#{...}` and `!{...}` inside class and id
  shorthand (`.#{cls}`, `##{id}`).
- **Object references.** `[obj]` / `[obj, :prefix]` after a tag emits stable
  `class` and `id` derived from the object's type and identity.
- **Attribute splats.** `*%h` and `*@a` inside `{...}` / `(...)` to merge hashes
  and pair-lists into the attribute set, with the same ordering and boolean
  rules as literal attributes.
- **Template codegen.** Compile a parsed template to a reusable Raku sub via
  `Template::HAML::Codegen`, cached on disk and keyed on source + config.
- **Direct-emit codegen.** `Template::HAML::DirectEmit` lowers templates to
  straight-line `print` / `write` calls for hot paths, bypassing the AST walker.
- **Streaming render.** `render-stream` writes incrementally to any `IO::Handle`
  or `Supplier`, with backpressure-aware chunking.
- **Cross-process precompilation cache.** Compiled templates persist under
  `.precomp/` keyed on path + mtime + config hash and are reused across
  processes.
- **Cache invalidation.** Mtime + config-hash checks invalidate stale entries;
  manual `Template::HAML::Cache.clear` for tests and dev loops.
- **Codegen error mapping.** Runtime exceptions thrown from generated code map
  back to original template `:file`, `:line`, `:column` via a side-table.
- **Render-time scope.** Locals, helpers, and `content-for` blocks share a
  single scope object so partials and layouts see consistent state.
- **Function memoization.** Pure helpers can opt in to per-render memoization
  with `is memoized`.
- **Plugin API.** `Template::HAML::Plugin` lets third-party packages register
  filters, helpers, doctypes, and tag transformers from a single entry point.
- **AST visitor hook.** `Template::HAML::Visitor` exposes pre- and post-order
  walks over the parsed tree for linters, formatters, and analyzers.
- **Tag transformer registry.** Register callbacks that rewrite tag nodes
  before codegen (e.g. auto-`rel="noopener"` on external links).
- **Pluggable markdown filter.** `:markdown` filter backed by any registered
  markdown implementation; ships with a default adapter.
- **`haml render`.** Render a template file or stdin to stdout / `-o`, with
  `--locals`, `--format`, `--escape-html` / `--no-escape-html`, `--ugly`.
- **`haml fmt`.** Canonicalize indentation, attribute order, and quote style;
  `--check` exits non-zero on diff for CI.
- **`haml lint`.** Static checks for duplicate ids, unused locals, illegal
  indentation, and unknown filters/doctypes.
- **`--watch` for CLI.** Re-renders on file change with debounce.
- **Trace for template debugging.** `TEMPLATE_HAML_TRACE=1` annotates output
  with source positions as HTML comments.
- **String encoding validation.** Non-UTF-8 input fails fast with a clear
  `X::HAML::ParseFail` instead of silently producing mojibake.
- **`page-class` helper.** Emits a stable `class` attribute for the document
  body based on controller/action or template path.
- **Bench harness.** `bench/` scripts for parse, codegen, and render timings
  against a fixed corpus.
- **Meta-provides testing.** `AUTHOR_TESTING=1` checks every module under
  `lib/` is listed in `META6.json` provides.

### Changed

- **Interior whitespace.** Runs of internal whitespace in plain text and
  attribute values are squeezed to a single space under `:ugly` output, matching
  Ruby HAML.

### Fixed

- **Grammar bugs.** Several edge cases around nested interpolation, attribute
  parsing, and indent re-entry after blank lines.
- **CI.** Test matrix and dependency installation on GitHub Actions.

## v0.9.0 — 2026-05-11

First release. Targets feature parity with Ruby HAML 5.x. Built on Raku
Grammars.

### Added

- **Grammar foundations.** Line-type dispatch (`tag`, `statement`, `comment`,
  `silent-comment`, `doctype`, `filter`, `plain`, `blank`), CRLF normalization,
  indent-unit auto-detection with strict mixed-tab/space and inconsistent-indent
  errors, and source positions (file/line/column) threaded through every
  `X::HAML::*` exception.
- **Tag syntax.** Implicit-div shorthand (`.foo`, `#bar`), combined explicit
  shorthand in any order (`%tag.a.b#main`), id concatenation with `_`,
  self-closing (explicit `/` and implicit for HTML void elements), inline-plus-
  block content, whitespace-removal modifiers (`>`, `<`, `<>`, `><`), XML
  namespaced names, and custom-element names containing `-`.
- **Attributes.** Hash form (`{...}`), HTML-style (`(...)`), old-style hash
  rocket (`{:foo => 'bar'}`), hyphenated string keys, `data:` / `aria:`
  shorthand with recursive expansion and optional camelCase → kebab-case,
  boolean and `Nil` value rules, HTML escaping by default, configurable quote
  style, and stable attribute ordering.
- **Embedded Raku code.** `=`, `-`, `!=`, `&=`, `==` output operators backed by
  a cached `EVAL` substrate; multiline continuation on trailing comma or
  unbalanced brackets; errors wrapped in `X::HAML::Eval` with source position.
- **Control flow.** `if` / `unless` / `elsif` / `else`, `for`, `while` (capped),
  `given` / `when` / `default`, and `repeat N`. Loop variables are scoped to
  the block.
- **Plain text and interpolation.** `#{...}` (escaped) and `!{...}` (raw) in
  tag content, attribute values, and plain text; backslash escape; no legacy
  `|` continuation.
- **Comments.** HTML comments (`/`), conditional comments (`/[if IE]`),
  revealed conditional, and silent comments (`-#`) whose children are opaque.
- **Doctypes.** `!!!` with `5`, `1.1`, `Strict`, `Frameset`, `Mobile`, `RDFa`,
  `Basic`, `XML`, and `XML <encoding>` variants; format-aware defaults.
- **Filters.** Pluggable registry (`Template::HAML.register-filter`) with
  built-ins: `:plain`, `:escaped`, `:javascript`, `:css`, `:cdata`,
  `:preserve`, `:raku`. Interpolation rules match Ruby HAML per filter.
- **Configuration.** `Template::HAML::Config` covering `format`
  (`:html5` / `:html4` / `:xhtml`), `escape_html`, `escape_attrs`,
  `output-style` (`:pretty` / `:ugly`), `autoclose`, `preserve`, `encoding`,
  `cdata`, `mime_type`, `suppress_eval`, and `attr_quote`.
- **Whitespace operators.** Outer (`>`), inner (`<`), combined, and `~ expr`
  to force preserve on a single tag; `find-and-preserve` helper.
- **Helpers.** `capture-haml`, `haml-concat`, `surround`, `precede`, `succeed`,
  `tab-up` / `tab-down`, `find-and-preserve`, `escape-once`, `html-safe`,
  `list-of`.
- **Layouts and partials.** `= yield` (named and unnamed), `content-for`,
  `= render :partial<name>` with `:locals`, `:collection` / `:as`, search-path
  resolution, and a per-process compile cache keyed on path + mtime.
- **Errors.** `X::HAML::ParseFail`, `IndentMixed`, `IndentInconsistent`,
  `UnknownFilter`, `UnknownDoctype`, `Eval`, `TemplateNotFound`, `DuplicateId`,
  `IllegalIndent`, each carrying `:file`, `:line`, `:column`, `:snippet`.
  Parse failures render a one-line caret-pointer snippet.
- **CLI.** `haml render` (with `-o`, `--locals`, `--format`,
  `--escape-html` / `--no-escape-html`, `--ugly`), `haml check`, `haml --help`,
  and per-subcommand help.
