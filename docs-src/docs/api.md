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

Returns the rendered HTML as a `Str`.

`HAML.render` may be called as either a class method (a fresh default config is
used) or an instance method (the instance's stored config is used unless
`:config` is passed at the call site). Construct an instance via
`HAML.new(:config(...))` to reuse the same config across renders.

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
| `Template::HAML::Filter`     | AST node representing a filter line and its dedented body.    |
| `Template::HAML::Filters`    | Filter registry plus the built-in filter handlers.            |
| `Template::HAML::Config`     | Per-render configuration: format, escape options, output style, etc. |
| `Template::HAML::X`          | Exception types raised by the parser.                         |

## Exceptions

| Exception                    | When                                                       |
|------------------------------|------------------------------------------------------------|
| `X::HAML::IllegalIndent`     | A line's leading whitespace isn't a valid indent.          |
| `X::HAML::IndentMixed`       | Tabs and spaces are combined in one indent.                |
| `X::HAML::IndentInconsistent`| Indent isn't a multiple of the first observed unit.        |
| `X::HAML::DuplicateId`       | A tag has both `#id` shorthand and an `id:` attr.          |
| `X::HAML::VoidWithChildren`  | A void element (`br`, `img`, …) was given child nodes.     |
| `X::HAML::ParseFail`         | The source did not parse.                                  |
| `X::HAML::UnknownDoctype`    | `!!! foo` named a doctype variant that is not recognized.  |
| `X::HAML::DoctypeNotFirst`   | A `!!!` line appeared after non-blank content.             |
| `X::HAML::Eval`              | An embedded `=`/`-`/`!=`/`&=` expression failed to compile or run. |
| `X::HAML::UnbalancedExpression` | A multi-line code expression ran to end of source with open brackets or a trailing comma. |
| `X::HAML::UnknownFilter`     | A `:name` line referenced a filter that is not registered. |
