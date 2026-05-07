# Getting Started

## Project layout

A typical project that uses Template::HAML keeps its templates under an `app/views/` (or any other) directory, organized by controller / feature, with the `.html.haml` extension:

```
my-project/
├── lib/
│   └── MyApp.rakumod
└── app/
    └── views/
        ├── home/
        │   └── index.html.haml
        └── layouts/
            └── app.html.haml
```

## Your first template

Create `hello.haml`:

```haml
%html
  %body
    %h1 Hello, world
    %p.lead This page was rendered by Template::HAML.
```

Render it from Raku:

```raku
use Template::HAML;

my $html = HAML.render(:src(slurp 'hello.haml'));
say $html;
```

You should see:

```html
<html>
  <body>
    <h1>Hello, world</h1>
    <p class='lead'>This page was rendered by Template::HAML.</p>
  </body>
</html>
```

## Rendering from a string

`HAML.render` takes any string, so you can also embed templates inline:

```raku
my $src = q:to/HAML/;
%section.container
  %h1 Title
  %h2 Subtitle
HAML

say HAML.render(:$src);
```

## Where to go next

- [Tags](syntax/tags.md) — element names, sigils, class and id shorthand
- [Attributes](syntax/attributes.md) — hash-style attribute syntax
- [Indentation](syntax/indentation.md) — how nesting works
- [API](api.md) — the public Raku API
