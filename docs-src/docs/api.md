# API

The public surface of Template::HAML is small today.

## `HAML.render`

```raku
use Template::HAML;

my Str $html = HAML.render(:src("..."));
```

| Parameter | Type    | Description                                |
|-----------|---------|--------------------------------------------|
| `:src`    | `Str:D` | The HAML source to parse and render.       |

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
| `Template::HAML::Statement`  | AST node representing a control-flow statement.               |
| `Template::HAML::Renderer`   | Walks the parse tree and emits HTML.                          |
| `Template::HAML::X`          | Exception types raised by the parser.                         |

## Exceptions

| Exception            | When                                              |
|----------------------|---------------------------------------------------|
| `X::IllegalIndent`   | A line's leading whitespace isn't a valid indent. |
| `X::DuplicateId`     | A tag has both `#id` shorthand and an `id:` attr. |
