
## Template::HAML

[![CI](https://github.com/gdonald/Template-HAML/actions/workflows/ci.yml/badge.svg)](https://github.com/gdonald/Template-HAML/actions/workflows/ci.yml)

HAML template engine for Raku, targeting feature parity with Ruby HAML 5.x.
A Raku-flavored take on [Ruby HAML](https://haml.info/) built on Raku Grammars.

### Install

```bash
zef install Template::HAML
```

### Quick start

```raku
use Template::HAML;

my $src = q:to/HAML/;
%section.container
  %h1 Hello, #{$name}!
  %p Welcome to Template::HAML.
HAML

say HAML.render(:$src, :locals(%(:name<world>)));
```

Output:

```html
<section class='container'>
  <h1>Hello, world!</h1>
  <p>Welcome to Template::HAML.</p>
</section>
```

### CLI

A `haml` script is installed with the module:

```bash
haml render path/to/view.haml
haml render path/to/view.haml -o out.html
haml render path/to/view.haml --locals 'name=world,count=3'
haml check path/to/view.haml         # parse-only, non-zero exit on failure
haml --help                          # list subcommands
haml render --help                   # list flags
```

### Supported syntax

| Feature                              | Example                                                                                                                                           |
| ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| Tag                                  | `%h1 Hello`                                                                                                                                       |
| Class / id shorthand                 | `%div.foo#bar`                                                                                                                                    |
| Implicit `%div`                      | `.foo` / `#bar` / `.foo#bar`                                                                                                                      |
| Hash-style attrs                     | `%a{href: '/', class: 'x'}`                                                                                                                       |
| HTML-style attrs                     | `%a(href='/' class='x')`                                                                                                                          |
| Hash-rocket attrs                    | `%a{:href => '/'}`                                                                                                                                |
| `data:` / `aria:` shorthand          | `%div{data: {id: 1, role: 'x'}}`                                                                                                                  |
| Output / silent / unescaped          | `= expr` / `- code` / `!= expr` / `&= expr`                                                                                                       |
| Control flow                         | `- if`, `- unless`, `- else`, `- elsif`, `- for`, `- while`, `- given`/`- when`, `- repeat`                                                       |
| Plain text + interpolation           | `Hello #{$name}!` and `!{$raw}`                                                                                                                   |
| HTML / conditional / silent comments | `/ note`, `/[if IE]`, `-#`                                                                                                                        |
| Doctypes                             | `!!!`, `!!! 5`, `!!! XML`                                                                                                                         |
| Filters                              | `:plain`, `:escaped`, `:javascript`, `:css`, `:cdata`, `:preserve`, `:raku`                                                                       |
| Layouts and partials                 | `= yield`, `= render :partial<header>`                                                                                                            |
| Helpers                              | `capture-haml`, `haml-concat`, `surround`, `precede`, `succeed`, `tab-up`, `tab-down`, `find-and-preserve`, `escape-once`, `html-safe`, `list-of` |
| Whitespace trim                      | `%p>`, `%p<`, `%p<>`                                                                                                                              |
| Preserved tags                       | `pre`, `textarea`, `~ expr`                                                                                                                       |

### Configuration

Pass a [`Template::HAML::Config`](lib/Template/HAML/Config.rakumod) instance per render
or to the `HAML.new` constructor.

| Option                 | Default           | Description                                               |
| ---------------------- | ----------------- | --------------------------------------------------------- |
| `format`               | `'html5'`         | `'html5'`, `'html4'`, or `'xhtml'`.                       |
| `escape-html`          | `True`            | HTML-escape `= expr` output by default.                   |
| `escape-attrs`         | `True`            | HTML-escape attribute values by default.                  |
| `output-style`         | `'pretty'`        | `'pretty'` (indented) or `'ugly'` (single-line).          |
| `attr-quote`           | `"'"`             | Quote style for emitted attributes: `'` or `"`.           |
| `encoding`             | `'utf-8'`         | Encoding for XML doctype and HTML `<meta>` helpers.       |
| `suppress-eval`        | `False`           | Disable `=` / `-` evaluation (untrusted templates).       |
| `cdata`                | `False`           | Wrap `:javascript` / `:css` content in CDATA (XHTML).     |
| `mime-type`            | `''`              | MIME type emitted on `<script>` / `<style>` from filters. |
| `hyphenate-data-attrs` | `False`           | camelCase → kebab-case for `data:` / `aria:` keys.        |
| `output-indent-width`  | `2`               | Spaces per indent level in pretty mode.                   |
| `autoclose`            | HTML void         | Elements that self-close (`<br />` etc).                  |
| `preserve`             | `pre`, `textarea` | Tags whose inner whitespace is preserved.                 |

Example:

```raku
use Template::HAML;
use Template::HAML::Config;

my $cfg = Template::HAML::Config.new(:format<xhtml>, :output-style<ugly>);
say HAML.render(:src("%br/\n"), :config($cfg));
# <br />
```

### Layouts and partials

```raku
my $haml = HAML.new(:search-paths<views>);

say $haml.render(
  :file<home/index>,
  :layout<layouts/app>,
  :locals(%(:title<Home>)),
);
```

Templates are looked up against the configured search paths with the
`name.html.haml` and `_name.html.haml` (partial) conventions.

### Filters

```haml
:javascript
  console.log('hello from #{$name}');
```

Register a custom filter:

```raku
use Template::HAML::Filters;

register-filter(:name<shout>, :handler(-> $body, %locals { $body.uc }));
```

### Run tests

```bash
./test.raku
```

### License

Released under the [Artistic License 2.0](https://opensource.org/licenses/Artistic-2.0).
