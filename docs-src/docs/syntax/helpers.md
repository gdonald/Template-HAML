# Helpers

`Template::HAML::Helpers` exports a small set of convenience subroutines that
embedded Raku code can call directly. They are visible to every `=`, `!=`,
`&=`, and `-` expression without explicit `use`.

```raku
use Template::HAML::Helpers;
```

The module is loaded automatically by the renderer. Importing it from your own
code is only necessary when you want to call the helpers from outside a
template (e.g. in tests).

## `html-safe($s)`

Wraps a string in a `SafeString` sentinel so the renderer leaves it
unescaped, even when [`escape_html`](config.md) is on.

```haml
= html-safe('<b>raw</b>')
```

renders:

```html
<b>raw</b>
```

`!=` already disables escaping per-line. Reach for `html-safe` when you want
the value to flow through other helpers (e.g. `surround`) and remain unescaped
at the final `=` site.

## `escape-once($s)`

HTML-escapes `&`, `<`, `>`, `"`, `'` — but skips ampersands that are already
the start of a numeric (`&#39;`, `&#x27;`) or named (`&amp;`) entity.

```raku
escape-once('&amp; <');   # → '&amp; &lt;'
escape-once('a & b');     # → 'a &amp; b'
```

Useful when round-tripping content that has already been partially escaped.

## `surround($pre, $post, &block)` / `precede($pre, &block)` / `succeed($post, &block)`

Concatenate fixed text around the trimmed result of a block.

```haml
%p
  != surround('(', ')', { 'middle' })
%p
  != precede('* ', { 'item' })
%p
  != succeed('.',  { 'sentence' })
```

renders:

```html
<p>
  (middle)
</p>
<p>
  * item
</p>
<p>
  sentence.
</p>
```

The block's return value is stringified and stripped of leading/trailing
whitespace before the fixed text is added.

## `list-of($items, &block)`

Wraps each call to the block in a `<li>` element and joins the results with
newlines.

```haml
%ul
  != list-of($items, -> $x { $x.uc })
```

with locals `:items(<a b c>)` renders:

```html
<ul>
  <li>A</li>
<li>B</li>
<li>C</li>
</ul>
```

`$items` accepts any `.list`-able value.

## `find-and-preserve($html)`

Scans a rendered HTML fragment for `<pre>` and `<textarea>` blocks and replaces
literal newlines inside them with `&#x000A;`. Lets you render with `:pretty`
output style without disturbing whitespace-sensitive content nested deeper than
the [`preserve`](config.md) tag list reaches.

```raku
find-and-preserve("<pre>line1\nline2</pre>");
# → '<pre>line1&#x000A;line2</pre>'
```

## `capture-haml(&block)`

Calls the block, treats its return value as HAML source, and renders it to a
string.

```haml
- my $fragment = capture-haml({ '%p hi' });
= html-safe($fragment)
```

The block must return a HAML source string. There is no implicit "HAML block"
syntax — Ruby HAML's `capture_haml do ... end` form is not available because
embedded code in this implementation is plain Raku, not HAML.
