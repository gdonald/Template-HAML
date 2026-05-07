# Tests

The test suite lives under `t/`. Each file uses Raku's built-in `Test` module.

## Run the suite

The canonical command is `zef test .`, which honors `META6.json` and installs any missing test-depends:

```shell
zef test .
```

For a faster inner-dev loop, use `prove6` directly:

```shell
prove6 -Ilib t/
```

`prove6` is a TAP runner; it doesn't read `META6.json`, so you have to point it at `lib/` with `-I` and install test-deps yourself.

## Author tests

`t/000-meta.t6` validates `META6.json` via `Test::META`. It's gated on the `AUTHOR_TESTING` environment variable so it doesn't fail for downstream installs:

```shell
AUTHOR_TESTING=1 zef test .
```

## CI

Every push to `main` and every PR runs `zef test .` on Linux via the GitHub Actions workflow at `.github/workflows/ci.yml`.
