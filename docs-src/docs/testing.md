# Tests

The test suite lives under `t/`. Each file uses Raku's built-in `Test` module.

## Run the suite

```shell
prove6 -Ilib t/
```

`prove6` is a TAP runner; `-Ilib` puts the project's modules on the include path. Install test-depends from `META6.json` first if you don't have them:

```shell
zef install --deps-only --/test --test-depends .
```

## META validation

`t/000-meta.t6` validates `META6.json` via `Test::META`. It runs as part of the suite; if the metadata file is malformed, missing a required field, or refers to a non-existent module, the test fails.

## CI

Every push to `main` and every PR runs `prove6 -Ilib t/` on Linux via the GitHub Actions workflow at `.github/workflows/ci.yml`.
