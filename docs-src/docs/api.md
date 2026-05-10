# API

The public surface of Template::HAML is small today.

## `HAML.render`

```raku
use Template::HAML;

my Str $html = HAML.render(:src("..."));

my Str $html = HAML.render(
  :src("= \$name\n"),
  :locals(%(:name<World>)),
);
```

| Parameter | Type    | Description                                                          |
|-----------|---------|----------------------------------------------------------------------|
| `:src`    | `Str:D` | The HAML source to parse and render.                                 |
| `:locals` | `%h`    | Optional name → value map; each key is bound as a `$name` lexical visible to embedded Raku in `=`/`-`/`!=`/`&=` lines. |

Returns the rendered HTML as a `Str`.

`HAML` is exported as a class from the `Template::HAML` module. There is no instance state today; `HAML.render` is effectively a class method.

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
| `Template::HAML::Renderer`   | Walks the parse tree and emits HTML.                          |
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
