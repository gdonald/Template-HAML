# API

The public surface of Template::HAML is small today.

## `HAML.render`

```raku
use Template::HAML;
use Template::HAML::Config;

my Str $html = HAML.render(:src("..."));

my Str $html = HAML.render(
  :src("= \$name\n"),
  :locals(%(:name<World>)),
);

my $cfg = Template::HAML::Config.new(:format<xhtml>);
my Str $html = HAML.render(:src("%br\n"), :config($cfg));
```

| Parameter | Type    | Description                                                          |
|-----------|---------|----------------------------------------------------------------------|
| `:src`    | `Str:D` | The HAML source to parse and render.                                 |
| `:locals` | `%h`    | Optional name → value map; each key is bound as a `$name` lexical visible to embedded Raku in `=`/`-`/`!=`/`&=` lines. |
| `:config` | `Template::HAML::Config` | Optional rendering options. See [Configuration](syntax/config.md). |
| `:context`| any     | Optional view-context object. Bare-identifier expressions resolve against its methods. Defaults to `Template::HAML::ViewContext.new`. See [Render context](syntax/context.md). |

Returns the rendered HTML as a `Str`.

`HAML.render` may be called as either a class method (a fresh default config is
used) or an instance method (the instance's stored config is used unless
`:config` is passed at the call site). Construct an instance via
`HAML.new(:config(...))` to reuse the same config across renders.

## `HAML.compile-source-to-raku`

```raku
use Template::HAML;

my Str $raku-source = HAML.compile-source-to-raku(:src("%p hi\n"));
my &compiled        = EVAL $raku-source;
my Str $html        = compiled(%(:name<World>));
```

Compiles a HAML source string to a self-contained Raku source string. The
emitted source defines an anonymous sub with the signature

```raku
sub (%locals = (), Template::HAML::Config :$config, :$ctx --> Str)
```

When `EVAL`ed, the emitted source returns that sub. Calling it produces the
same HTML that `HAML.render(:src(...), :%locals, :config(...))` would.

| Parameter | Type    | Description                                                         |
|-----------|---------|---------------------------------------------------------------------|
| `:src`    | `Str:D` | The HAML source to compile.                                          |
| `:config` | `Template::HAML::Config` | Optional configuration baked into the emitted output. |

The emitted code rebuilds the parse tree with the per-class constructors in
`Template::HAML::*` and runs `Template::HAML::Renderer` on it, so feature
coverage matches the interpreter exactly. The `:$ctx` parameter (a
`Template::HAML::Context`) is plumbed through `$*HAML-CTX` so that helper
functions like `yield` and `render(:partial)` work from the compiled sub.

This is the substrate for cached/compiled templates. The emitted code
preserves source line and column information on every node, so eval
failures inside compiled templates raise an `X::HAML::Eval` whose `.line`
and `.column` point back to the originating HAML template — the same as
the interpreter.

## On-disk compiled-template cache

The emitter from [`compile-source-to-raku`](#hamlcompile-source-to-raku) can be
written to a per-user cache directory and loaded back on subsequent runs,
skipping the parse + emit step. This is opt-in; `HAML.render` does not
consult the cache.

Invalidation is automatic for both flavors of the API:

* String-based cache (`render-cached(:src)`): the cache key embeds a 64-bit
  hash of the source string, so changing the source produces a different key
  and a clean cache miss.
* File-based cache (`render-file-cached(:file)`): the cache key embeds the
  file's mtime, so editing the file produces a different key and a clean
  cache miss — no slurp + re-hash is needed on a cache hit.

Stale entries left behind on disk are not garbage-collected automatically; see
[`clear-compiled-cache`](#clear-compiled-cache) below.

### `HAML.new(:compiled-cache-dir(...))`

```raku
my $haml = HAML.new(:compiled-cache-dir('/var/cache/Template-HAML'.IO));
```

Default cache directory resolution order:

1. The constructor's `:compiled-cache-dir` argument.
2. The `HAML_COMPILED_CACHE` environment variable.
3. `$*TMPDIR/Template-HAML/`.

### `HAML.compiled-cache-key`

```raku
my $key = $haml.compiled-cache-key(:src("%p hi\n"));
my $key = $haml.compiled-cache-key(:src(...), :config(...));
```

Returns a 16-character hex digest of `(source, config)`. Stable across
processes; changes whenever either input changes.

### `HAML.compiled-cache-path`

```raku
my IO::Path $path = $haml.compiled-cache-path(:src(...), :config(...));
```

Returns the absolute path where the compiled artifact for `(src, config)`
would live. Layout: `<cache-dir>/<first-2-chars-of-key>/<key>.raku-haml`.
The 2-char shard avoids one large directory.

### `HAML.compile-to-cache`

```raku
my IO::Path $path = $haml.compile-to-cache(:src(...), :config(...));
```

If the cache file already exists, returns its path unchanged (the file is
not rewritten). Otherwise, parses the source, emits Raku, writes it to the
cache path, and returns the path.

### `HAML.load-from-cache`

```raku
my &fn = $haml.load-from-cache($path);
my $html = fn(%locals, :config($cfg));
```

Reads the cached file and `EVAL`s it, returning the anonymous sub that the
emitter produced.

### `HAML.render-cached`

```raku
my $html = $haml.render-cached(:src(...), :%locals, :config(...));
```

Convenience wrapper: `compile-to-cache` + `load-from-cache` + invocation
with the appropriate `Template::HAML::Context` plumbed through `$*HAML-CTX`.

### File-based cache API

The same on-disk layout is reused for cached compilations keyed by file
path + mtime + config, so editing the template file is enough to invalidate.

```raku
my IO::Path $path = $haml.compiled-cache-path-for-file(:file<views/home>);
my IO::Path $path = $haml.compile-file-to-cache(:file<views/home>);
my Str      $html = $haml.render-file-cached(:file<views/home>, :%locals);
```

File names are resolved through `:search-paths` and the same extension
fallbacks as `HAML.render(:file)` (bare name, `.haml`, `.html.haml`, partial
`_name` variants). The cache key changes whenever the resolved file's mtime
changes, so touching the file or editing it both force a recompile.

`render-file-cached` plumbs `:current-dir` through to the
`Template::HAML::Context` so that `render(:partial)` inside the template
resolves relative paths the same way `HAML.render(:file)` does.

### `HAML.clear-compiled-cache`

```raku
my Int $removed = $haml.clear-compiled-cache;
```

Removes every `.raku-haml` file under the cache directory and returns the
count. Empty shard directories are removed too. Use this when configuration
changes, after upgrading Template::HAML, or any time the cache is suspected
of being stale.

## `register-filter`

```raku
use Template::HAML::Filters;

register-filter :name<upper>, :handler(-> Str $body, %locals --> Str {
  $body.uc;
});
```

Registers a custom filter handler. The handler signature is
`(Str $body, %locals --> Str)`. `$body` is the filter's indented block
dedented to column zero; the handler returns the rendered text. The renderer
applies the filter's own source indent to each line of the result.

`Template::HAML::Filters` also exports `lookup-filter(Str $name)`,
`has-filter(Str $name)`, and `filter-names()`.

See [filters](syntax/filters.md) for the built-in handlers.

## Internal modules

The implementation is split across several modules under `lib/Template/HAML/`. These are not part of the stable public API yet, but documented here for contributors:

| Module                       | Responsibility                                                |
|------------------------------|---------------------------------------------------------------|
| `Template::HAML::Grammar`    | The Raku Grammar that recognizes HAML source.                 |
| `Template::HAML::Actions`    | Builds the parse tree from grammar matches.                   |
| `Template::HAML::Node`       | Generic tree node holding a `Tag` or `Statement` payload.     |
| `Template::HAML::Tag`        | AST node representing a single HAML tag.                      |
| `Template::HAML::Statement`  | AST node representing an embedded-code line (`=`, `-`, `!=`, `&=`). |
| `Template::HAML::Eval`       | EVALs embedded Raku expressions with caching.                 |
| `Template::HAML::Multiline`  | Pre-grammar pass that joins continued code lines (trailing comma / unbalanced brackets). |
| `Template::HAML::Renderer`   | Walks the parse tree and emits HTML.                          |
| `Template::HAML::Codegen`    | Emits Raku source that reconstructs the parse tree and renders it.  |
| `Template::HAML::Cache`      | Cache-key hashing and on-disk layout for compiled templates.        |
| `Template::HAML::Filter`     | AST node representing a filter line and its dedented body.    |
| `Template::HAML::Filters`    | Filter registry plus the built-in filter handlers.            |
| `Template::HAML::Config`     | Per-render configuration: format, escape options, output style, etc. |
| `Template::HAML::X`          | Exception types raised by the parser.                         |

## Exceptions

Every `X::HAML::*` subclass inherits from `X::HAML` and carries the
following attributes when raised:

| Attribute  | Description                                            |
|------------|--------------------------------------------------------|
| `line`     | 1-based line number where the error was detected.     |
| `column`   | 1-based column within that line.                       |
| `file`     | Source file path, when `HAML.render(:file(...))` was used. |
| `snippet`  | The source line containing the error, used for the caret pointer. |

The `.message` of every subclass includes a `[HAML <file>:<line>:<col>]`
prefix and (when a snippet was captured) a one-line caret-pointer that
underlines the offending column:

```
[HAML source:3:1] mixed tabs and spaces in indent
  3 | 	%b bye
    | ^
```

| Exception                    | When                                                       |
|------------------------------|------------------------------------------------------------|
| `X::HAML::IllegalIndent`     | A line's leading whitespace isn't a valid indent.          |
| `X::HAML::IndentMixed`       | Tabs and spaces are combined in one indent.                |
| `X::HAML::IndentInconsistent`| Indent isn't a multiple of the first observed unit.        |
| `X::HAML::DuplicateId`       | A tag has both `#id` shorthand and an `id:` attr.          |
| `X::HAML::VoidWithChildren`  | A void element (`br`, `img`, …) was given child nodes.     |
| `X::HAML::ParseFail`         | The source did not parse; `snippet` is the failing line.   |
| `X::HAML::UnknownDoctype`    | `!!! foo` named a doctype variant that is not recognized.  |
| `X::HAML::DoctypeNotFirst`   | A `!!!` line appeared after non-blank content.             |
| `X::HAML::Eval`              | An embedded `=`/`-`/`!=`/`&=` expression failed to compile or run. |
| `X::HAML::UnbalancedExpression` | A multi-line code expression ran to end of source with open brackets or a trailing comma. |
| `X::HAML::UnknownFilter`     | A `:name` line referenced a filter that is not registered. |
| `X::HAML::OrphanElse`        | An `- elsif`/`- else` had no preceding `if`/`unless`.      |
| `X::HAML::TemplateNotFound`  | `HAML.render(:file(...))` could not locate the template.   |
| `X::HAML::PartialDepthExceeded` | A partial recursed past the configured depth limit.     |
| `X::HAML::YieldOutsideLayout`| `yield()` was called outside a layout rendering context.   |

### Debug logging

`Template::HAML::X` exports `haml-debug(*@msg)` for low-noise diagnostics.
It is a no-op unless the `HAML_DEBUG` environment variable is set, in
which case each call writes a `[HAML DEBUG]`-prefixed line to STDERR.
Use it sparingly inside the implementation; it must never be left on a
hot path.
