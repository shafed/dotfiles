# Machine overrides

`dots` first looks for `machines/<hostname>.toml`. If it does not exist, it uses
`machines/default.toml`. A machine file only selects profiles and adds/removes
capabilities; package, link, service, generator and prerequisite definitions
stay in `profiles/`.

Example:

```toml
[machine]
profiles = ["laptop", "ai"]
capabilities = []
disable_capabilities = []
```

`laptop` already inherits `desktop` and declares its battery/power differences,
so machine files should not repeat those capabilities unless the hardware needs
an explicit override.

For one-off testing, `dots plan --profile laptop,ai` overrides the machine's
profile list without editing tracked files.
