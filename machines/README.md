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

The primary desktop `shafed` selects `desktop`, `documents`, `development`,
`networking`, `storage`, `printing` and its private `hardware-shafed` driver
profile. The `arch-laptop` machine reuses the workload profiles while replacing
`desktop` with `laptop`; it intentionally omits `printing` and the desktop
hardware profile. Add `printing` to that machine's profile list before
provisioning if the laptop later needs the shared Canon printer/scanner setup.
