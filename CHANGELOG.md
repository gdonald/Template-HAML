# Changelog

All notable changes to this project will be documented in this file.

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
