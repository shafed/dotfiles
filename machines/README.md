# Machine overrides

`dots` first looks for `machines/<hostname>.toml`. If it does not exist, it uses
`machines/default.toml`. A machine file only selects profiles and adds/removes
capabilities; package, link, service and generator definitions stay in
`profiles/`.

Example:

```toml
[machine]
profiles = ["laptop", "gaming", "ai"]
capabilities = ["bluetooth", "battery"]
disable_capabilities = []
```

For one-off testing, `dots plan --profile laptop,ai` overrides the machine's
profile list without editing tracked files.
