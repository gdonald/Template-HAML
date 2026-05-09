# Doctype

A line beginning with `!!!` declares the document's doctype. It must be the first non-blank line of the template; placing it after any tag or statement raises `X::HAML::DoctypeNotFirst`.

## Argument-less form

```haml
!!!
```

```html
<!DOCTYPE html>
```

With no argument, `!!!` emits the format-default doctype. The default format is HTML5 today; configurable formats arrive in Phase 10.

## Named variants

| Source           | Output |
|------------------|--------|
| `!!! 5`          | `<!DOCTYPE html>` |
| `!!! 1.1`        | XHTML 1.1 |
| `!!! Strict`     | XHTML 1.0 Strict |
| `!!! Frameset`   | XHTML 1.0 Frameset |
| `!!! Mobile`     | XHTML Mobile 1.2 |
| `!!! RDFa`       | XHTML+RDFa 1.0 |
| `!!! Basic`      | XHTML Basic 1.1 |
| `!!! XML`        | `<?xml version='1.0' encoding='utf-8' ?>` |
| `!!! XML <enc>`  | XML declaration with the given encoding |

```haml
!!! XML iso-8859-1
```

```html
<?xml version='1.0' encoding='iso-8859-1' ?>
```

## Errors

An unrecognized variant raises `X::HAML::UnknownDoctype`:

```haml
!!! Bogus
```

```text
[HAML source:1:1] unknown doctype 'Bogus'; expected one of: 5 1.1 Strict Frameset Mobile RDFa Basic XML
```
