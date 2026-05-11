# Configuration

Rendering options live on a `Template::HAML::Config` object. Pass one to
`HAML.render(:config(...))` for per-render overrides, or to
`HAML.new(:config(...))` for an instance default.

```raku
use Template::HAML;
use Template::HAML::Config;

my $cfg = Template::HAML::Config.new(:format<xhtml>);

HAML.render(:src("%br\n"), :config($cfg));   # "<br />\n"

my $h = HAML.new(:config($cfg));
$h.render(:src("%br\n"));                     # uses the instance config
```

## Options

| Option                | Default      | Effect                                                                                          |
|-----------------------|--------------|-------------------------------------------------------------------------------------------------|
| `format`              | `'html5'`    | One of `html5`, `html4`, `xhtml`. Drives default doctype, void self-close, boolean attrs.       |
| `escape-html`         | `True`       | When false, `=` does not HTML-escape its output. `&=` always escapes; `!=` never escapes.       |
| `escape-attrs`        | `True`       | When false, attribute values are emitted raw (only the active quote char is escaped).           |
| `output-style`        | `'pretty'`   | `pretty` (indented) or `ugly` (single-line, no inter-tag whitespace).                            |
| `attr-quote`          | `"'"`        | Quote character used around attribute values; `"'"` or `'"'`.                                    |
| `encoding`            | `'utf-8'`    | Used for `!!! XML` output and any future encoding helpers.                                       |
| `suppress-eval`       | `False`      | When true, `=`, `-`, `!=`, `&=` produce no output and the expression body is not evaluated.     |
| `cdata`               | `False`      | When true, the `:javascript` and `:css` filters wrap their body in a `CDATA` marker even outside XHTML. |
| `mime-type`           | `''`         | When set, `:javascript` / `:css` emit a `type="…"` attribute with this value.                    |
| `hyphenate-data-attrs`| `False`      | When true, `camelCase` keys under `data:` / `aria:` hashes are emitted as `kebab-case`.          |
| `output-indent-width` | `2`          | Number of spaces per indent level in pretty output.                                              |
| `autoclose`           | HTML5 voids  | List of element names that auto-self-close: `area base br col embed hr img input link meta param source track wbr`. |
| `preserve`            | `<pre textarea>` | List of elements whose inner whitespace is preserved.                                       |

## Format effects

* **html5**: void elements emit `<br>`; boolean attributes are bare (`<input disabled>`); default doctype is `<!DOCTYPE html>`.
* **html4**: same shape as HTML5 but the default doctype is HTML 4.01 Transitional.
* **xhtml**: void elements emit `<br />` (note the space-slash); boolean attributes use the `name="name"` form (`<input disabled="disabled" />`); default doctype is XHTML 1.0 Transitional.

## Escape behavior

| Operator | Default (`escape-html: True`) | `escape-html: False` |
|----------|-------------------------------|----------------------|
| `=`      | escape                        | no escape            |
| `&=`     | escape (force)                | escape (force)       |
| `!=`     | no escape                     | no escape            |
| `==`     | interpolation only            | interpolation only   |

`escape-attrs` is independent of `escape-html` and only affects attribute values.

## Output style

`output-style: 'ugly'` emits all output on a single line with leading whitespace
trimmed and blank lines dropped. Useful for production where the extra bytes
matter:

```haml
%div
  %p hi
```

Pretty (default):

```html
<div>
  <p>hi</p>
</div>
```

Ugly:

```html
<div><p>hi</p></div>
```

## Autoclose

The `autoclose` option replaces the built-in void list. To add a custom void
element while keeping the defaults, pass the full list:

```raku
my $cfg = Template::HAML::Config.new(
  :autoclose(<area base br col embed hr img input link meta param source track wbr custom-tag>),
);
```

## suppress-eval

When `suppress-eval: True`, the renderer does not call `EVAL` for `=`/`-`/`!=`/`&=`
lines. The line's children are still rendered (so structural tags around
suppressed expressions still appear). Use this for templates where the embedded
expressions are not trusted.

## Filter rendering: `cdata` and `mime-type`

The `:javascript` and `:css` filters look at two config options when emitting
their wrapper tags:

* When format is `xhtml`, or when `cdata: True` is set explicitly, the body is
  wrapped in a `CDATA` marker:

    ```html
    <script type='text/javascript'>
      //<![CDATA[
      alert(1);
      //]]>
    </script>
    ```

    `:css` uses the comment-wrapped form `/*<![CDATA[*/ ... /*]]>*/`.

* `mime-type` sets the `type="…"` attribute on the emitted `<script>` /
  `<style>` tag. When unset, XHTML defaults to `text/javascript` /
  `text/css`; HTML5 omits the attribute.

## `hyphenate-data-attrs`

When the `data:` or `aria:` shorthand expands a hash whose keys are
camelCase, setting `hyphenate-data-attrs: True` rewrites each key to
kebab-case:

```haml
%a{data: {fooBar: 1}}
```

renders as `<a data-fooBar='1'>` by default and `<a data-foo-bar='1'>` with
the option on. The conversion is recursive, so nested hashes have every level
hyphenated.
